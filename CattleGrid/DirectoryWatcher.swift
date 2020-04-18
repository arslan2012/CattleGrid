//
//  DirectoryWatcher.swift
//  DirectoryWatcher
//
//  Created by Gianni Carlo on 7/19/18.
//  https://github.com/GianniCarlo/DirectoryWatcher
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation

public class DirectoryWatcher: NSObject {
    static let retryCount = 5
    static let pollInterval = 0.2
    var watchedUrl: URL
    
    private var source: DispatchSourceFileSystemObject?
    private var previousContents: Set<URL>
    private var queue: DispatchQueue?
    private var retriesLeft: Int!
    private var directoryChanging = false

    public var ignoreDirectories = true
    public var onNewFiles: (([URL]) -> Void)?
    public var onDeletedFiles: (([URL]) -> Void)?
    
    //init
    init(watchedUrl: URL) {
        self.watchedUrl = watchedUrl
        let contentsArray = (try? FileManager.default.contentsOfDirectory(at: watchedUrl, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
        self.previousContents = Set(contentsArray)
    }
    
    public class func watch(_ url: URL) -> DirectoryWatcher? {
        let directoryWatcher = DirectoryWatcher(watchedUrl: url)

        guard directoryWatcher.startWatching() else {
            // Something went wrong, return nil
            return nil
        }

        return directoryWatcher
    }
    
    public func startWatching() -> Bool {
        // Already monitoring
        guard self.source == nil else { return false }
        
        let descriptor = open(self.watchedUrl.path, O_EVTONLY)
        guard descriptor != -1 else { return false }
        
        self.queue = DispatchQueue.global()
        self.source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: self.queue)
        
        self.source?.setEventHandler {
            [weak self] in
            self?.directoryDidChange()
        }
        
        self.source?.setCancelHandler() {
            close(descriptor)
        }
        
        self.source?.resume()
        
        return true
    }
    
    public func stopWatching() -> Bool {
        guard let source = source else {
            return false
        }
        
        source.cancel()
        self.source = nil
        
        return true
    }
    
    deinit {
        let _ = self.stopWatching()
        self.onNewFiles = nil
        self.onDeletedFiles = nil
    }
}

// MARK: - Private methods
extension DirectoryWatcher {
    private func directoryMetadata(_ url: URL) -> [String]? {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) else {
            return nil
        }
        var directoryMetadata = [String]()
        for filename in contents {

            let fileUrl = url.appendingPathComponent(filename)

            guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileUrl.path),
                let fileSize = fileAttributes[.size] as? Double else {
                    continue
            }

            let sizeString = String(Int(fileSize))
            let fileHash = filename + sizeString

            directoryMetadata.append(fileHash)
        }

        return directoryMetadata
    }

    private func checkChanges(after delay: TimeInterval) {
        guard let directoryMetadata = self.directoryMetadata(self.watchedUrl),
            let queue = self.queue else {
                return
        }

        let time = DispatchTime.now() + delay

        queue.asyncAfter(deadline: time) { [weak self] in
            self?.pollDirectoryForChangesWith(directoryMetadata)
        }
    }

    private func pollDirectoryForChangesWith(_ oldMetadata: [String]){
        guard let newDirectoryMetadata = self.directoryMetadata(self.watchedUrl) else {
            return
        }

        self.directoryChanging = newDirectoryMetadata != oldMetadata
        self.retriesLeft = self.directoryChanging
            ? DirectoryWatcher.retryCount
            : self.retriesLeft

        self.retriesLeft = self.retriesLeft - 1
        if self.directoryChanging || 0 < self.retriesLeft {
            // Either the directory is changing or
            // we should try again as more changes may occur
            self.checkChanges(after: DirectoryWatcher.pollInterval)
        } else {
            // Changes appear to be completed
            // Post a notification informing that the directory did change
            DispatchQueue.main.async {
                let contentsArray = (try? FileManager.default.contentsOfDirectory(at: self.watchedUrl, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)) ?? []
                let newContents = Set(contentsArray)

                let newElements = newContents.subtracting(self.previousContents)
                let deletedElements = self.previousContents.subtracting(newContents)

                self.previousContents = newContents

                if !deletedElements.isEmpty {
                    let elements = deletedElements.compactMap({ (element) -> URL? in
                        let isDirectory = (try? element.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                        guard (!isDirectory || !self.ignoreDirectories) else {
                            return nil
                        }
                        return element
                    })
                    self.onDeletedFiles?(elements)
                }

                if !newElements.isEmpty {
                    let elements = newElements.compactMap({ (element) -> URL? in
                        let isDirectory = (try? element.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                        guard (!isDirectory || !self.ignoreDirectories) else {
                            return nil
                        }
                        return element
                    })
                    self.onNewFiles?(elements)
                }
            }
        }
    }

    private func directoryDidChange() {
        guard !self.directoryChanging else {
            return
        }
        self.directoryChanging = true
        self.retriesLeft = DirectoryWatcher.retryCount

        self.checkChanges(after: DirectoryWatcher.pollInterval)
    }
}
