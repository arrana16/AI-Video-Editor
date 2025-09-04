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

struct PlaybackClipInfo {
    let id: String
    let url: String
    let timeInClipMs: UInt64
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
    
    func cutClip(at index: Int, position: UInt64) {
        guard let ptr = enginePtr else { return }
        
        // Verify index is valid
        let count = getClipCount()
        guard index < count else {
            print("TimelineEngine: Cannot cut clip - index \(index) out of bounds (count: \(count))")
            return
        }
        
        // Get the clip to verify position is valid
        guard let clip = getClip(at: index) else {
            print("TimelineEngine: Cannot cut clip - failed to get clip at index \(index)")
            return
        }
        
        // Verify position is within clip boundaries
        guard position > clip.inPoint && position < clip.outPoint else {
            print("TimelineEngine: Cannot cut clip - position \(position) is not within clip range (\(clip.inPoint)-\(clip.outPoint))")
            return
        }
        
        print("TimelineEngine: Cutting clip at index \(index) at position \(position)")
        
        engine_cut_clip(ptr, UInt(index), position)
        
        // Verify the cut worked by checking if we now have one more clip
        let newCount = getClipCount()
        print("TimelineEngine: After cut, clip count changed from \(count) to \(newCount)")
    }
    
    func updateClipRange(at index: Int, inPoint: UInt64, outPoint: UInt64) {
        guard let ptr = enginePtr else { return }
        engine_update_clip_range(ptr, UInt(index), inPoint, outPoint)
    }
    
    // MARK: - Playback Functions
    
    func play() {
        guard let ptr = enginePtr else { return }
        engine_play(ptr)
    }
    
    func pause() {
        guard let ptr = enginePtr else { return }
        engine_pause(ptr)
    }
    
    func seek(to timeMs: UInt64) {
        guard let ptr = enginePtr else { return }
        engine_seek(ptr, timeMs)
    }
    
    func tick(deltaMs: UInt64) {
        guard let ptr = enginePtr else { return }
        engine_tick(ptr, deltaMs)
    }
    
    func getPlaybackTime() -> UInt64 {
        guard let ptr = enginePtr else { return 0 }
        return engine_get_playback_time(ptr)
    }
    
    func isPlaying() -> Bool {
        guard let ptr = enginePtr else { return false }
        return engine_is_playing(ptr)
    }
    
    func getCurrentPlaybackClipInfo() -> PlaybackClipInfo? {
        guard let ptr = enginePtr else { return nil }
        guard let infoPtr = engine_get_current_playback_clip_info(ptr) else { return nil }
        defer { free_playback_clip_info(infoPtr) }
        
        let id = String(cString: infoPtr.pointee.id)
        let url = String(cString: infoPtr.pointee.url)
        let timeInClipMs = infoPtr.pointee.time_in_clip_ms
        
        return PlaybackClipInfo(id: id, url: url, timeInClipMs: timeInClipMs)
    }
    
    // MARK: - Project Management Functions
    
    func getProjectAsJson() -> String? {
        guard let ptr = enginePtr else { return nil }
        guard let jsonPtr = engine_get_project_as_json(ptr) else { return nil }
        defer { free_rust_string(jsonPtr) }
        return String(cString: jsonPtr)
    }

    func loadProject(fromJson json: String) -> Bool {
        guard let ptr = enginePtr else { return false }
        return json.withCString { jsonPtr in
            engine_load_project_from_json(ptr, jsonPtr)
        }
    }

    func setCurrentFilePath(_ filePath: String?) {
        guard let ptr = enginePtr else { return }
        if let path = filePath {
            path.withCString { pathPtr in
                engine_set_current_file_path(ptr, pathPtr)
            }
        } else {
            engine_set_current_file_path(ptr, nil)
        }
    }

    func markAsSaved() {
        guard let ptr = enginePtr else { return }
        engine_mark_as_saved(ptr)
    }
    
    func newProject() -> Bool {
        guard let ptr = enginePtr else { return false }
        return engine_new_project(ptr, nil)
    }
    
    func getProjectName() -> String? {
        guard let ptr = enginePtr else { return nil }
        guard let namePtr = engine_get_project_name(ptr) else { return nil }
        defer { free_rust_string(namePtr) }
        return String(cString: namePtr)
    }
    
    func getCurrentFilePath() -> String? {
        guard let ptr = enginePtr else { return nil }
        guard let pathPtr = engine_get_current_file_path(ptr) else { return nil }
        defer { free_rust_string(pathPtr) }
        return String(cString: pathPtr)
    }
    
    func hasUnsavedChanges() -> Bool {
        guard let ptr = enginePtr else { return false }
        return engine_has_unsaved_changes(ptr)
    }
}
