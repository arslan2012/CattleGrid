//
//  File.swift
//  CattleGrid
//
//  Created by Andrew Jackson on 08/11/2021.
//  Copyright © 2021 Eric Betts. All rights reserved.
//

import Foundation

class FileManagerContent: NSObject {
    
    public var url: URL
    public var isDir: Bool
    public var characterId: String?
    public var characterImageFilename: String?
    public var plain: Data = Data()
    public var isCharacterValid: Bool = false
    public var isSelected: Bool = false

    var isFile: Bool {
        if (isDir) { return false }
        return url.pathExtension == "bin"
    }
    
    var filenameWithoutExtension: String {
        if (isDir) { return url.lastPathComponent }
        return url.deletingPathExtension().lastPathComponent
    }
    
    var characterImageUrl: URL? {
        return URL(string: "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/\(self.characterImageFilename ?? "")" ) ?? nil
    }

    init(url: URL, isDir: Bool) {
        self.url = url
        self.isDir = isDir
        
        if (!isDir) {
            guard let amiitool = TagStore.shared.amiitool else {
                return
            }
            
            do {
                let tag = try Data(contentsOf: url)
                
                let start = NTAG_PAGE_SIZE * Int(NTAG215Pages.characterModelHead.rawValue)
                let end = NTAG_PAGE_SIZE * Int(NTAG215Pages.characterModelTail.rawValue + 1)
                let id = tag.subdata(in: start..<end)
                self.characterId = id.hexDescription
                
                let head = id.hexDescription.lowercased().prefix(8)
                let tail = id.hexDescription.lowercased().suffix(8)
                
                self.characterImageFilename = "icon_\(head)-\(tail).png"
                
                plain = amiitool.unpack(tag)
                
                isCharacterValid = true
                print("\(url.lastPathComponent) loaded")
            } catch {
                // Issue reading url, ignore and move on
            }
        }
    }
    
    
    
}
