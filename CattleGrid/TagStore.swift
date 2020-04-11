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
    case WRITE = 0xa2
    case PWD_AUTH = 0x1B
}

let PACK = Data([0x80, 0x80])

class TagStore : NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    static let shared = TagStore()

    func start() {
        print("Hello world")


        do {            
            let count = 1
            let amiiboKeys = UnsafeMutablePointer<nfc3d_amiibo_keys>.allocate(capacity: count)
            //pointer.initialize(repeating: 0, count: count)
            defer {
              //pointer.deinitialize(count: count)
              amiiboKeys.deallocate()
            }
            let path = Bundle.main.path(forResource: "key_retail", ofType: "bin")
            print("path = \(path!)")
            nfc3d_amiibo_load_keys(amiiboKeys, path)
            print(amiiboKeys.pointee.data)
        }


        guard NFCReaderSession.readingAvailable else {
            print("NFCReaderSession.readingAvailable failed")
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

        if (error.localizedDescription == "Session timeout") {
            // TODO: session.restartPolling()
            return
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("didDetect: \(tags)")

        if case let NFCTag.miFare(tag) = tags.first! {
            guard tag.mifareFamily == .ultralight else {
                print("Ignoring non-ultralight \(tag.mifareFamily)")
                return
            }

            session.connect(to: tags.first!) { (error: Error?) in
                if ((error) != nil) {
                    print(error as Any)
                    return
                }

                self.connected(tag)
            }
        } else {
            print("Ignoring non-mifare tag")
        }
    }

    func connected(_ tag: NFCMiFareTag) {

        let pwd = self.calculatePWD(tag.identifier)
        print("\(tag.identifier.hexDescription): \(pwd.hexDescription)")

        //let read = Data([MifareCommands.READ.rawValue, 0x00])
        //let uid = data.subdata(in: 0..<7)
        //TODO: valudate CC is correct for blank tag.
        //let cc = data.subdata(in: 12..<16) // f1 10 ff ee


        let auth = Data([MifareCommands.PWD_AUTH.rawValue, pwd[0], pwd[1], pwd[2], pwd[3]])
        tag.sendMiFareCommand(commandPacket: auth) { (data, error) in
            if ((error) != nil) {
                print(error as Any)
                return
            }
            if (data != PACK) {
                print("Error authenticating amiibo")
                return
            }
        }


        self.dumpTag(tag) { (dump) in
            print(dump.hexDescription)
        }
    }

    func dumpTag(_ tag: NFCMiFareTag, completionHandler: @escaping (Data) -> Void) {
        self.readAllPages(tag, startPage: 4, completionHandler: completionHandler)
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
        print(uid.hexDescription)
        var PWD = Data(count: 4)
        PWD[0] = uid[1] ^ uid[3] ^ 0xAA
        PWD[1] = uid[2] ^ uid[4] ^ 0x55
        PWD[2] = uid[3] ^ uid[5] ^ 0xAA
        PWD[3] = uid[4] ^ uid[6] ^ 0x55
        return PWD
    }


}
