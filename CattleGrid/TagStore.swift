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

let NTAG_PAGE_SIZE = 4

let KEY_RETAIL = "key_retail.bin"
let KEY_RETAIL_SIZE = 160
let KEY_RETAIL_SHA1 = "bbdbb49a917d14f7a997d327ba40d40c39e606ce"

enum NTAG215Pages : UInt8 {
    case staticLockBits = 2
    case capabilityContainer = 3
    case userMemoryFirst = 4
    case characterModelHead = 21
    case characterModelTail = 22
    case userMemoryLast = 129
    case dynamicLockBits = 130
    case cfg0 = 131
    case cfg1 = 132
    case pwd = 133
    case pack = 134
    case total = 135
}

let SLB = Data([0x00, 0x00, 0x0f, 0xe0])
let CC = Data([0xf1, 0x10, 0xff, 0xee])
let DLB = Data([0x01, 0x00, 0x0f, 0xbd])
let CFG0 = Data([0x00, 0x00, 0x00, 0x04])
let CFG1 = Data([0x5f, 0x00, 0x00, 0x00])
let PACKRFUI = Data([0x80, 0x80, 0x00, 0x00])

class TagStore : NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    static let shared = TagStore()
    @Published private(set) var files: [URL] = []
    @Published private(set) var selected: URL?
    @Published private(set) var progress : Float = 0
    @Published private(set) var error : String = ""
    @Published private(set) var readingAvailable : Bool = NFCReaderSession.readingAvailable
    @Published private(set) var currentDir : URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    var lastPageWritten : UInt8 = 0 {
        willSet(newVal) {
            self.progress = Float(newVal) / Float(NTAG215Pages.total.rawValue)
        }
    }

    let fm = FileManager.default
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    var amiitool : Amiitool?
    var plain : Data = Data()
    var watcher : DirectoryWatcher? = nil


    func start() {
        print("Start")

        self.loadKeyRetail()
        self.loadList()

        if self.watcher == nil {
            self.watcher = DirectoryWatcher.watch(self.documents)
            guard let watcher = watcher else {
                return
            }

            watcher.onNewFiles = { newFiles in
                if (self.amiitool == nil) {
                    self.loadKeyRetail();
                }
                self.loadList()
            }

            watcher.onDeletedFiles = { deletedFiles in
                self.loadList()
            }
        }
        guard let watcher = self.watcher else {
            print("self.watcher not defined")
            return
        }
        if (watcher.startWatching()) {
            print("Documents watching started")
        }
    }

    func stop() {
        guard let watcher = self.watcher else {
            print("self.watcher not defined")
            return
        }
        if (watcher.stopWatching()) {
            print("Documents watching paused")
        }
    }

    func loadKeyRetail() -> Bool {
        let key_retail = self.documents.appendingPathComponent(KEY_RETAIL).path
        if (!fm.fileExists(atPath: key_retail)) {
            self.error = "\(KEY_RETAIL) missing"
            return false
        }
        do {
            let attr = try fm.attributesOfItem(atPath: key_retail)
            let fileSize = attr[FileAttributeKey.size] as! UInt64
            if (fileSize != KEY_RETAIL_SIZE) {
                self.error = "\(KEY_RETAIL) is not the correct size"
                return false
            }
        } catch {
            print(error)
            self.error = "Error getting size of \(KEY_RETAIL)"
            return false
        }

        guard let sha1sum = SHA1.hexString(fromFile: key_retail) else {
            self.error = "Couoldn't calculate \(KEY_RETAIL) sha1"
            return false
        }

        let normalizedSha1 = sha1sum.lowercased().filter { !$0.isNewline && !$0.isWhitespace }
        if (normalizedSha1 != KEY_RETAIL_SHA1) {
            self.error = "\(KEY_RETAIL) has the wrong sha1"
            print("\(KEY_RETAIL) sha is \(sha1sum)")
            return false
        }

        self.error = ""
        self.amiitool = Amiitool(path: key_retail)
        return true
    }

    func loadList() {
        do {
            let items = try fm.contentsOfDirectory(at: self.currentDir, includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
            let sortedItems = items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent})
            files = sortedItems.filter({ (item) -> Bool in
                return item.lastPathComponent != KEY_RETAIL
            })
        } catch {
            // failed to read directory – bad permissions, perhaps?
        }
    }

    func load(_ path: URL) {
        do {
            let isDir = (try path.resourceValues(forKeys: [.isDirectoryKey])).isDirectory ?? false
            if (isDir) {
                loadFolder(path)
            } else {
                loadFile(path)
            }
        } catch {
            print("Couldn't read \(path)")
        }
    }

    func loadFolder(_ path: URL) {
        self.currentDir = path;
        self.loadList()
    }

    func loadFile(_ path: URL) {
        guard loadKeyRetail() else {
            return
        }
        guard let amiitool = self.amiitool else {
            self.error = "Internal error: amiitool not initialized"
            return
        }

        do {
            let tag = try Data(contentsOf: path)

            let start = NTAG_PAGE_SIZE * Int(NTAG215Pages.characterModelHead.rawValue)
            let end = NTAG_PAGE_SIZE * Int(NTAG215Pages.characterModelTail.rawValue+1)
            let id = tag.subdata(in: start..<end)
            print("character id: \(id.hexDescription)")

            plain = amiitool.unpack(tag)
            print("\(path.lastPathComponent) loaded")
            self.selected = path
        } catch {
            print("Couldn't read \(path)")
        }
    }

    func scan() {
        print("Scan")
        self.error = ""

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
            return
        }
        if (error.localizedDescription == "Session invalidated by user") {
            return
        }
        DispatchQueue.main.async {
            self.error = "Error during session: \(error.localizedDescription)"
            self.lastPageWritten = 0
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("didDetect: \(tags)")

        if case let NFCTag.miFare(tag) = tags.first! {
            session.connect(to: tags.first!) { (error: Error?) in
                if ((error) != nil) {
                    print("Error during connect: \(error!.localizedDescription)")
                    DispatchQueue.main.async {
                        self.error = "Error during connect: \(error!.localizedDescription)"
                        self.lastPageWritten = 0
                    }
                    return
                }

                self.connected(tag, session: session)
            }
        } else {
            print("Ignoring non-mifare tag")
            DispatchQueue.main.async {
                self.error = "Ignoring non-mifare tag"
            }
        }
    }

    func connected(_ tag: NFCMiFareTag, session: NFCTagReaderSession) {
        let read = Data([MifareCommands.READ.rawValue, 0])
        tag.sendMiFareCommand(commandPacket: read) { (data, error) in
            if ((error) != nil) {
                print("Error during read: \(error!.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = "Error during read: \(error!.localizedDescription)"
                    self.lastPageWritten = 0
                }
                session.invalidate()
                return
            }

            guard data.count == 16 else {
                print("Incorrect data size: \(data.hexDescription)")
                DispatchQueue.main.async {
                    self.error = "Couldn't read tag UID"
                    self.lastPageWritten = 0
                }
                session.invalidate()
                return
            }
            let cc = data.subdata(in: 12..<16)
            let size = cc[2];
            if (size == 0x12) {
                DispatchQueue.main.async {
                    self.error = "NTAG213"
                }
                session.invalidate()
                return
            } else if (size == 0x6D) {
                DispatchQueue.main.async {
                    self.error = "NTAG216"
                }
                session.invalidate()
                return
            } else if (size == 0x3E) {
                //NTAG215
            } else {
                print("Unexpected size from CC: \(size)")
            }

            guard let amiitool = self.amiitool else {
                DispatchQueue.main.async {
                    self.error = "Internal error: amiitool not initialized"
                }
                return
            }

            //Amiitool plain text stores first 2 pages (uid) towards the end
            self.plain.replaceSubrange(468..<476, with: data.subdata(in: 0..<8))

            let modified = amiitool.pack(self.plain)
            self.writeTag(tag, newImage: modified) { () in
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
            let pwd = self.calculatePWD(tag.identifier)
            print("\(tag.identifier.hexDescription): \(pwd.hexDescription)")
            self.writePage(tag, page: NTAG215Pages.pwd.rawValue, data: pwd) {
                self.writePage(tag, page: NTAG215Pages.pack.rawValue, data: PACKRFUI) {
                    self.writePage(tag, page: NTAG215Pages.capabilityContainer.rawValue, data: CC) {
                        self.writePage(tag, page: NTAG215Pages.cfg0.rawValue, data: CFG0) {
                            self.writePage(tag, page: NTAG215Pages.cfg1.rawValue, data: CFG1) {
                                self.writePage(tag, page: NTAG215Pages.dynamicLockBits.rawValue, data: DLB) {
                                    self.writePage(tag, page: NTAG215Pages.staticLockBits.rawValue, data: SLB) {
                                        completionHandler()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func writeUserPages(_ tag: NFCMiFareTag, startPage: UInt8, data: Data, completionHandler: @escaping () -> Void) {
        if (startPage > NTAG215Pages.userMemoryLast.rawValue) {
            completionHandler()
            return
        }

        let page = data.page(startPage)
        writePage(tag, page: startPage, data: page) {
            self.writeUserPages(tag, startPage: startPage+1, data: data) { () in
                completionHandler()
            }
        }
    }

    func writePage(_ tag: NFCMiFareTag, page: UInt8, data: Data, completionHandler: @escaping () -> Void) {
        print("Write page \(page) \(data.hexDescription)")
        let write = Data([MifareCommands.WRITE.rawValue, page]) + data
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

    func dumpTag(_ tag: NFCMiFareTag, completionHandler: @escaping (Data) -> Void) {
        self.readAllPages(tag, startPage: 0, completionHandler: completionHandler)
    }

    func readAllPages(_ tag: NFCMiFareTag, startPage: UInt8, completionHandler: @escaping (Data) -> Void) {
        if (startPage >= NTAG215Pages.total.rawValue) {
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
