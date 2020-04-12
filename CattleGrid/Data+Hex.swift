//
//  Data+Hex.swift
//  wlkie-tlkie
//
//  Created by Eric Betts on 1/31/20.
//  Copyright © 2020 Eric Betts. All rights reserved.
//

import Foundation

extension Data {
    var hexDescription: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }

    init(hex: String) {
        let hexArray = hex.trimmingCharacters(in: NSCharacterSet.whitespaces).components(separatedBy: " ")
        let hexBytes : [UInt8] = hexArray.map({UInt8($0, radix: 0x10)!})
        self.init(hexBytes)
    }

    
}
