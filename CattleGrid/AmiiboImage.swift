//
//  AmiiboImage.swift
//  CattleGrid
//
//  Created by Eric Betts on 4/11/20.
//  Copyright © 2020 Eric Betts. All rights reserved.
//

import Foundation

struct AmiiboImage: Identifiable {
    let id : URL
    let path : URL
    let url : URL
    let filename : String

    init(_ path: URL) {
        self.path = path
        self.url = path
        self.id = path
        self.filename = path.lastPathComponent
    }
}
