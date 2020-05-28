//
//  Data+page.swift
//  CattleGrid
//
//  Created by Eric Betts on 5/5/20.
//  Copyright © 2020 Eric Betts. All rights reserved.
//

import Foundation

extension Data {
    func page(_ pageNum: UInt8) -> Data {
        let start = Int(pageNum) * 4
        let end = Int(pageNum) * 4 + 4
        return subdata(in: start..<end)
    }
}
