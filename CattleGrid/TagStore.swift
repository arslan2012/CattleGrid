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

enum MifareCommands: UInt8 {
    case READ = 0x30
    case WRITE = 0xA2
    case PWD_AUTH = 0x1B
}

let NTAG_PAGE_SIZE = 4

enum NTAG215Pages: UInt8 {
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

class TagStore: NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    static let shared = TagStore()
    @Published private(set) var contents: [FileManagerContent] = []
    @Published private(set) var error: String = ""
    @Published private(set) var readingAvailable: Bool = NFCReaderSession.readingAvailable
    
#if JAILBREAK
    @Published private(set) var currentDir: URL = URL(fileURLWithPath: "/var/mobile/tagbin/", isDirectory: true)
    let documents = URL(fileURLWithPath: "/var/mobile/tagbin/", isDirectory: true)
#else
    @Published private(set) var currentDir: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
#endif
    
    let fm = FileManager.default
    
    var amiitool: Amiitool?
    var watcher: DirectoryWatcher? = nil
    
    private var session: NFCReaderSession?
    
    
    func start() {
        print("Start")
        print(documents)
        guard let key_retail = Bundle.main.path(forResource: "key_retail", ofType: "bin", inDirectory: nil) else {
            return
        }
        
        self.amiitool = Amiitool(path: key_retail)
        
        self.loadList()
        
        if self.watcher == nil {
            self.watcher = DirectoryWatcher.watch(self.documents)
            guard let watcher = watcher else {
                return
            }
            
            watcher.onNewFiles = { newFiles in
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
    
    func loadList() {
        contents.removeAll()
        
        let items = try? fm.contentsOfDirectory(at: self.currentDir, includingPropertiesForKeys: [], options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
        let filteredFiles = items!.filter({ (item) -> Bool in
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return isDir || (item.pathExtension == "bin")
        }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        
        for file in filteredFiles {
            let isDir = (try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let fmc = FileManagerContent(url: file.absoluteURL, isDir: isDir)
            contents.append(fmc)
        }
    }
    
    func load(_ path: URL) {
        do {
            let isDir = (try path.resourceValues(forKeys: [.isDirectoryKey])).isDirectory ?? false
            if (isDir) {
                clearSelected()
                loadFolder(path)
            }
        } catch {
            print("Couldn't read \(path)")
        }
    }
    
    private func loadFolder(_ path: URL) {
        self.currentDir = path;
        self.loadList()
    }
    
//    private func loadFile(_ path: URL) {
//        guard let amiitool = self.amiitool else {
//            self.error = "Internal error: amiitool not initialized"
//            return
//        }
//
//        do {
//            let tag = try Data(contentsOf: path)
//
//            let start = NTAG_PAGE_SIZE * Int(NTAG215Pages.characterModelHead.rawValue)
//            let end = NTAG_PAGE_SIZE * Int(NTAG215Pages.characterModelTail.rawValue + 1)
//            let id = tag.subdata(in: start..<end)
//            self.selectedCharacterId = id.hexDescription
//            print("character id: \(id.hexDescription)")
//
//            let head = id.hexDescription.lowercased().prefix(8)
//            let tail = id.hexDescription.lowercased().suffix(8)
//
//            self.selectedCharacterImageFilename = "icon_\(head)-\(tail).png"
//
//            plain = amiitool.unpack(tag)
//            print("\(path.lastPathComponent) loaded")
//            self.selected = path
//        } catch {
//            self.error = "Couldn't read \(path)"
//        }
//    }
    
    func hasSelection() -> Bool {
        for content in contents {
            if content.isSelected { return true }
        }
        return false
    }
    
    func clearSelected() {
        for content in contents {
            content.isSelected = false
        }
        
        self.error = ""
    }
    
    func setSelected(content: FileManagerContent) {
        clearSelected()
        content.isSelected = true
    }
    
    func getSelected() -> FileManagerContent? {
        for content in contents {
            if content.isSelected {
                return content
            }
        }
        return nil
    }
    
    func scan() {
        print("Scan")
        self.error = ""
        
#if targetEnvironment(simulator)
        self.error = "Unable to scan in simulator"
#else
        session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil)
        session?.alertMessage = "Hold your device near a tag to write"
        session?.begin()
#endif
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
        
        session.invalidate(errorMessage: "Error during session: \(error.localizedDescription)")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("didDetect: \(tags)")
        
        if case let NFCTag.miFare(tag) = tags.first! {
            session.connect(to: tags.first!) { (error: Error?) in
                if ((error) != nil) {
                    print("Error during connect: \(error!.localizedDescription)")
                    
                    session.invalidate(errorMessage: "Error during connect: \(error!.localizedDescription)")
                    return
                }
                
                self.connected(tag, session: session)
            }
        } else {
            print("Ignoring non-mifare tag")
            session.invalidate(errorMessage: "Ignoring non-mifare tag")
        }
    }
    
    func connected(_ tag: NFCMiFareTag, session: NFCTagReaderSession) {
        let read = Data([MifareCommands.READ.rawValue, 0])
        tag.sendMiFareCommand(commandPacket: read) { (data, error) in
            if ((error) != nil) {
                print("Error during read: \(error!.localizedDescription)")
                session.invalidate(errorMessage: "Error during read: \(error!.localizedDescription)")
                return
            }
            
            guard data.count == 16 else {
                print("Incorrect data size: \(data.hexDescription)")
                session.invalidate(errorMessage: "Couldn't read tag UID")
                return
            }
            let cc = data.subdata(in: 12..<16)
            let size = cc[2];
            if (size == 0x12) {
                session.invalidate(errorMessage: "NTAG213")
                return
            } else if (size == 0x6D) {
                session.invalidate(errorMessage: "NTAG216")
                return
            } else if (size == 0x3E) {
                //NTAG215
            } else {
                print("Unexpected size from CC: \(size)")
            }
            
            guard let amiitool = self.amiitool else {
                session.invalidate(errorMessage: "Internal error: amiitool not initialized")
                return
            }
            
            //Amiitool plain text stores first 2 pages (uid) towards the end
            var plain: Data = self.getSelected()!.plain
            plain.replaceSubrange(468..<476, with: data.subdata(in: 0..<8))
            
            let modified = amiitool.pack(plain)
            self.writeTag(tag: tag, newImage: modified) { () in
                print("done writing")
                session.alertMessage = "Writing Complete"
                session.invalidate()
            }
        }
    }
    
    func writeTag(tag: NFCMiFareTag, newImage: Data, completionHandler: @escaping () -> Void) {
        self.writeUserPages(tag: tag, startPage: NTAG215Pages.userMemoryFirst.rawValue, data: newImage) { () in
            let pwd = self.calculatePWD(tag.identifier)
            print("\(tag.identifier.hexDescription): \(pwd.hexDescription)")
            self.writePage(tag: tag, page: NTAG215Pages.pwd.rawValue, data: pwd) {
                self.writePage(tag: tag, page: NTAG215Pages.pack.rawValue, data: PACKRFUI) {
                    self.writePage(tag: tag, page: NTAG215Pages.capabilityContainer.rawValue, data: CC) {
                        self.writePage(tag: tag, page: NTAG215Pages.cfg0.rawValue, data: CFG0) {
                            self.writePage(tag: tag, page: NTAG215Pages.cfg1.rawValue, data: CFG1) {
                                self.writePage(tag: tag, page: NTAG215Pages.dynamicLockBits.rawValue, data: DLB) {
                                    self.writePage(tag: tag, page: NTAG215Pages.staticLockBits.rawValue, data: SLB) {
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
    
    func writeUserPages(tag: NFCMiFareTag, startPage: UInt8, data: Data, completionHandler: @escaping () -> Void) {
        if (startPage > NTAG215Pages.userMemoryLast.rawValue) {
            completionHandler()
            return
        }
        
        let page = data.page(startPage)
        writePage(tag: tag, page: startPage, data: page) {
            self.writeUserPages(tag: tag, startPage: startPage + 1, data: data) { () in
                completionHandler()
            }
        }
    }
    
    func writePage(tag: NFCMiFareTag, page: UInt8, data: Data, completionHandler: @escaping () -> Void) {
        print("Write page \(page) \(data.hexDescription)")
        let write = Data([MifareCommands.WRITE.rawValue, page]) + data
        tag.sendMiFareCommand(commandPacket: write) { (_, error) in
            if ((error) != nil) {
                print("Error during write: \(error!.localizedDescription)")
                self.session?.invalidate(errorMessage: "Error during write: \(error!.localizedDescription)")
                return
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
            self.readAllPages(tag, startPage: startPage + 4) { (contents) in
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
