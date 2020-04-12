//
//  TagStore.swift
//  CattleGrid
//
//  Created by Eric Betts on 4/10/20.
//  Copyright © 2020 Eric Betts. All rights reserved.
//

import Foundation
import SwiftUI
import CoreNFC
import amiitool

enum MifareCommands : UInt8 {
    case READ = 0x30
    case WRITE = 0xA2
    case PWD_AUTH = 0x1B
}

let NTAG215_SIZE = 540

enum NTAG215Pages : UInt8 {
    case capabilityContainer = 3
    case userMemoryFirst = 4
    case userMemoryLast = 129
    case cfg0 = 131
    case cfg1 = 132
    case pwd = 133
    case pack = 134
    case total = 135
}

let PACKRFUI = Data([0x80, 0x80, 0x00, 0x00])
let CC = Data([0xf1, 0x10, 0xff, 0xee])

class TagStore : NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    static let shared = TagStore()
    @Published private(set) var amiibos: [AmiiboImage] = []
    @Published private(set) var selected: AmiiboImage?
    @Published private(set) var lastPageWritten : UInt8 = 0
    @Published private(set) var error : String = ""

    var amiiboKeys : UnsafeMutablePointer<nfc3d_amiibo_keys> = UnsafeMutablePointer<nfc3d_amiibo_keys>.allocate(capacity: 1)
    var plain : Data = Data()

    func start() {
        print("Start")
        let fm = FileManager.default

        do {
            let items = try fm.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: [], options: [.skipsHiddenFiles])

            for item in items {
                //print("Found \(item)")
                amiibos.append(AmiiboImage(item))
            }
        } catch {
            // failed to read directory – bad permissions, perhaps?
        }


        let key_retail = Bundle.main.path(forResource: "key_retail", ofType: "bin")!
        if (!nfc3d_amiibo_load_keys(amiiboKeys, key_retail)) {
            print("Could not load keys from \(key_retail)")
            return
        }
        //print(amiiboKeys.pointee.data)
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    func load(_ amiibo: AmiiboImage) {
        do {
            let tag = try Data(contentsOf: amiibo.path)
            let output = UnsafeMutablePointer<UInt8>.allocate(capacity: NTAG215_SIZE)
            let unsafeDump = tag.unsafeBytes

            if (!nfc3d_amiibo_unpack(amiiboKeys, unsafeDump, output)) {
                print("!!! WARNING !!!: Tag signature was NOT valid")
            }

            plain = Data(bytes: output, count: tag.count)
            print("\(amiibo.filename) selected")
            self.selected = amiibo
            // print("Unpacked: \(plain.hexDescription)")
        } catch {
            print("Couldn't read file \(amiibo.path)")
        }
    }

    func scan() {
        print("Scan")
        self.error = ""

        guard NFCReaderSession.readingAvailable else {
            print("NFCReaderSession.readingAvailable failed")
            self.error = "NFCReaderSession.readingAvailable failed"
            return
        }

        if let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil) {
            session.alertMessage = "Hold your device near a tag to write."
            session.begin()
        }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("reader active \(session)")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("didInvalidateWithError: \(error.localizedDescription)")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("didDetect: \(tags)")

        if case let NFCTag.miFare(tag) = tags.first! {
            guard tag.mifareFamily == .ultralight else {
                print("Ignoring non-ultralight \(tag.mifareFamily.rawValue)")
                self.error = "Ignoring non-ultralight"
                return
            }

            session.connect(to: tags.first!) { (error: Error?) in
                if ((error) != nil) {
                    print("Error during connect: \(error!.localizedDescription)")
                    self.error = "Error during connect: \(error!.localizedDescription)"
                    self.lastPageWritten = 0
                    return
                }

                self.connected(tag, session: session)
            }
        } else {
            print("Ignoring non-mifare tag")
            self.error = "Ignoring non-mifare tag"
        }
    }

    func connected(_ tag: NFCMiFareTag, session: NFCTagReaderSession) {
        let read = Data([MifareCommands.READ.rawValue, 0])
        tag.sendMiFareCommand(commandPacket: read) { (data, error) in
            if ((error) != nil) {
                print("Error during read: \(error!.localizedDescription)")
                self.error = "Error during read: \(error!.localizedDescription)"
                self.lastPageWritten = 0
                session.invalidate()
                return
            }

            //Amiitool plain text stores first 2 pages (uid) towards the end
            self.plain.replaceSubrange(468..<476, with: data.subdata(in: 0..<8))

            let newImage = UnsafeMutablePointer<UInt8>.allocate(capacity: NTAG215_SIZE)
            let unsafePlain = self.plain.unsafeBytes

            nfc3d_amiibo_pack(self.amiiboKeys, unsafePlain, newImage)

            let new = Data(bytes: newImage, count: NTAG215_SIZE)
            //print(new.hexDescription)

            self.writeTag(tag, newImage: new) { () in
                print("done writing")
                DispatchQueue.main.async {
                    self.lastPageWritten = 0
                    self.error = ""
                }
                session.invalidate()
            }
        }
    }

    func writeTag(_ tag: NFCMiFareTag, newImage: Data, completionHandler: @escaping () -> Void) {
        self.writeUserPages(tag, startPage: NTAG215Pages.userMemoryFirst.rawValue, data: newImage) { () in
            //write PWD
            let pwd = self.calculatePWD(tag.identifier)
            print("\(tag.identifier.hexDescription): \(pwd.hexDescription)")
            self.writePage(tag, page: NTAG215Pages.pwd.rawValue, data: pwd) {
                self.writePage(tag, page: NTAG215Pages.pack.rawValue, data: PACKRFUI) {
                    self.writePage(tag, page: NTAG215Pages.capabilityContainer.rawValue, data: CC) {
                        completionHandler()
                    }
                }
            }
        }
    }

    func writePage(_ tag: NFCMiFareTag, page: UInt8, data: Data, completionHandler: @escaping () -> Void) {
        print("Write page \(page) \(data.hexDescription)")
        let write = addChecksum(Data([MifareCommands.WRITE.rawValue, page]) + data)
        tag.sendMiFareCommand(commandPacket: write) { (_, error) in
            if ((error) != nil) {
                print("Error during write: \(error!.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = "Error during write: \(error!.localizedDescription)"
                    self.lastPageWritten = 0
                }
                return
            }
            DispatchQueue.main.async {
                self.lastPageWritten = page
            }
            completionHandler()
        }
    }

    func writeUserPages(_ tag: NFCMiFareTag, startPage: UInt8, data: Data, completionHandler: @escaping () -> Void) {
        if (startPage > NTAG215Pages.userMemoryLast.rawValue) {
            completionHandler()
            return
        }

        let page = data.subdata(in: Int(startPage) * 4 ..< Int(startPage) * 4 + 4)
        writePage(tag, page: startPage, data: page) {
            self.writeUserPages(tag, startPage: startPage+1, data: data) { () in
                completionHandler()
            }
        }
    }

    func addChecksum(_ data: Data) -> Data {
        var crc = crc16ccitt([UInt8](data))
        return data + Data(bytes: &crc, count: MemoryLayout<UInt16>.size)
    }

    func crc16ccitt(_ data: [UInt8], seed: UInt16 = 0x6363, final: UInt16 = 0xffff)-> UInt16 {
        var crc = seed
        data.forEach { (byte) in
            crc ^= UInt16(byte) << 8
            (0..<8).forEach({ _ in
                crc = (crc & UInt16(0x8000)) != 0 ? (crc << 1) ^ 0x8408 : crc << 1
            })
        }
        return UInt16(crc & final)
    }

    func dumpTag(_ tag: NFCMiFareTag, completionHandler: @escaping (Data) -> Void) {
        self.readAllPages(tag, startPage: 0, completionHandler: completionHandler)
    }

    func readAllPages(_ tag: NFCMiFareTag, startPage: UInt8, completionHandler: @escaping (Data) -> Void) {
        if (startPage > 129) {
            completionHandler(Data())
            return
        }
        print("Read page \(startPage)")
        let read = Data([MifareCommands.READ.rawValue, startPage])
        tag.sendMiFareCommand(commandPacket: read) { (data, error) in
            if ((error) != nil) {
                print(error as Any)
                return
            }
            self.readAllPages(tag, startPage: startPage+4) { (contents) in
                completionHandler(data + contents)
            }
        }
    }

    func calculatePWD(_ uid: Data) -> Data {
        var PWD = Data(count: 4)
        PWD[0] = uid[1] ^ uid[3] ^ 0xAA
        PWD[1] = uid[2] ^ uid[4] ^ 0x55
        PWD[2] = uid[3] ^ uid[5] ^ 0xAA
        PWD[3] = uid[4] ^ uid[6] ^ 0x55
        return PWD
    }
}
