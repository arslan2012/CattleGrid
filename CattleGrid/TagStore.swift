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

        switch tags.first! {
            case let .iso7816(tag):
                print("iso7816 \(tag)")
                break
            case let .iso15693(tag):
                print("iso15693 \(tag)")
                break
            case let .miFare(tag):
                print("miFare \(tag)")
                break
            default:
                print("unhandled tag type")
                return
        }
    }

}
