//
//  LocalCache.swift
//  Pods
//
//  Created by DragonCherry on 8/22/16.
//
//

import Foundation
import TinyLog

open class LocalCache {
    
    // MARK: Singleton
    open static let `default`: LocalCache = {
        return LocalCache()
    }()
    
    // MARK: Constant
    fileprivate var localCacheExtension: String         = "dat"
    fileprivate var diskCacheParentFolder: String       = "___defaultLocalCacheFolder"
    
    // MARK: Common
    fileprivate var path: String!
    
    public init(identifier: String? = nil, cacheExtension: String? = nil) {
        if let identifier = identifier {
            diskCacheParentFolder = identifier
        }
        if let cacheExtension = cacheExtension {
            localCacheExtension = cacheExtension
        }
        
        if let libraryPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first {
            
            let mainPath = NSString(string: libraryPath).appendingPathComponent(diskCacheParentFolder)
            
            if !FileManager.default.fileExists(atPath: mainPath) {
                do {
                    try FileManager.default.createDirectory(atPath: mainPath, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    loge(error)
                }
            }
            path = mainPath
        } else {
            loge("Critical error in LocalCache!")
        }
    }
    
    open func filePath(forIdentifier identifier: String?, ext: String? = nil) -> String? {
        guard let fileName = identifier?.removingPercentEncoding else {
            loge("Critical error while replacing percent encoding!")
            return nil
        }
        return NSString(string: path).appendingPathComponent("\(fileName).\(ext ?? localCacheExtension)")
    }
    
    open func fileURL(forIdentifier identifier: String, ext: String? = nil) -> URL? {
        if let filePath = filePath(forIdentifier: identifier, ext: ext) {
            return URL(fileURLWithPath: filePath)
        } else {
            return nil
        }
    }
    
    open func cachedFileList() -> [String] {
        
        var list = [String]()
        let fileManager = FileManager.default
        
        if let objectArray = fileManager.enumerator(atPath: path)?.allObjects {
            for URLObject in objectArray {
                if let path = URLObject as? String {
                    list.append(path)
                } else {
                    logw("Failed to get path from enumeratorAtPath: \(path)")
                }
            }
        }
        return list
    }
}

// MARK: - APIs
extension LocalCache {
    
    public func purge() {
        do {
            try FileManager.default.removeItem(atPath: path)
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            loge(error)
        }
    }
    
    public func add(_ data: Data, withIdentifier identifier: String, ext: String? = nil, sync: Bool = false, completion: ((Bool, String?) -> Void)? = nil) {
        
        let addTask: (() -> Void) = {
            let callInMain: ((Bool, String?) -> Void) = { success, name in
                DispatchQueue.main.async {
                    completion?(success, name)
                }
            }
            guard let filePath = self.filePath(forIdentifier: identifier, ext: ext) else {
                callInMain(false, nil)
                return
            }
            if FileManager.default.fileExists(atPath: filePath) {
                do {
                    try FileManager.default.removeItem(atPath: filePath)
                } catch {
                    loge(error)
                    callInMain(false, nil)
                }
            }
            let success = (try? data.write(to: URL(fileURLWithPath: filePath), options: [.atomic])) != nil
            callInMain(success, success ? filePath : nil)
        }
        
        if sync {
            addTask()
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                addTask()
            }
        }
    }
    
    public func remove(_ identifier: String, ext: String? = nil) -> Bool {
        guard let filePath = self.filePath(forIdentifier: identifier, ext: ext) else {
            return false
        }
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch {
            loge(error)
            return false
        }
        return true
    }
    
    public func data(_ identifier: String, ext: String? = nil, sync: Bool = false, completion: ((Data?) -> Void)? = nil) {
        
        let fetchTask: (() -> Void) = {
            let callInMain: ((Data?) -> Void) = { data in
                DispatchQueue.main.async {
                    completion?(data)
                }
            }
            guard let filePath = self.filePath(forIdentifier: identifier, ext: ext) else {
                callInMain(nil)
                return
            }
            if FileManager.default.fileExists(atPath: filePath) {
                callInMain(FileManager.default.contents(atPath: filePath))
            } else {
                callInMain(nil)
            }
        }
        
        if sync {
            fetchTask()
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                fetchTask()
            }
        }
    }
}

