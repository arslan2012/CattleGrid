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

enum MifareCommands : UInt8 {
    case read = 0x30

}

class TagStore : NSObject, ObservableObject, NFCTagReaderSessionDelegate {
    static let shared = TagStore()

    func start() {
        print("Hello world")
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
        let command = Data([MifareCommands.read.rawValue, 0x00])

        tag.sendMiFareCommand(commandPacket: command) { (data, error) in
            if ((error) != nil) {
                print(error as Any)
                return
            }
            print(data.hexDescription)

            let uid = data.subdata(in: 0..<7)
            let cc = data.subdata(in: 12..<16) // f1 10 ff ee
            let pwd = self.calculatePWD(tag.identifier)

            print("\(uid.hexDescription): \(cc.hexDescription) \(pwd.hexDescription)")
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
