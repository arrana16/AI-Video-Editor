//
//  RustCore.swift
//  AI Video Editor
//
//  Created by Abdur-Rahman Rana on 2025-09-01.
//

import Foundation

// MARK: - Models
struct Clip: Identifiable, Equatable {
    let id: String
    let url: String
    let inPoint: UInt64
    let outPoint: UInt64
    
    var duration: UInt64 {
        outPoint - inPoint
    }
}

// MARK: - Timeline Engine Wrapper
class TimelineEngine {
    private var enginePtr: OpaquePointer?
    
    init() {
        enginePtr = engine_new()
    }
    
    deinit {
        if let ptr = enginePtr {
            engine_free(ptr)
        }
    }
    
    func addClip(_ clip: Clip, at index: Int) {
        guard let ptr = enginePtr else { return }
        
        clip.id.withCString { idPtr in
            clip.url.withCString { urlPtr in
                engine_add_clip(ptr, idPtr, urlPtr, clip.inPoint, clip.outPoint, UInt(index))
            }
        }
    }
    
    func removeClip(at index: Int) {
        guard let ptr = enginePtr else { return }
        engine_remove_clip(ptr, UInt(index))
    }
    
    func getClipCount() -> Int {
        guard let ptr = enginePtr else { return 0 }
        return Int(engine_get_clip_count(ptr))
    }
    
    func getClip(at index: Int) -> Clip? {
        guard let ptr = enginePtr, index < getClipCount() else { return nil }
        
        guard let idPtr = engine_get_clip_id(ptr, UInt(index)) else { return nil }
        defer { free_rust_string(idPtr) }
        let id = String(cString: idPtr)
        
        guard let urlPtr = engine_get_clip_url(ptr, UInt(index)) else { return nil }
        defer { free_rust_string(urlPtr) }
        let url = String(cString: urlPtr)
        
        let inPoint = engine_get_clip_in_point(ptr, UInt(index))
        let outPoint = engine_get_clip_out_point(ptr, UInt(index))
        
        return Clip(id: id, url: url, inPoint: inPoint, outPoint: outPoint)
    }
    
    func getAllClips() -> [Clip] {
        let count = getClipCount()
        var clips = [Clip]()
        
        for i in 0..<count {
            if let clip = getClip(at: i) {
                clips.append(clip)
            }
        }
        
        return clips
    }
}
