use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use serde::{Serialize, Deserialize};

// --------------------
// Data model
// --------------------
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Clip {
    pub id: String,     // unique ID
    pub url: String,    // file:// path or UUID
    pub in_point: u64,  // ms
    pub out_point: u64, // ms
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct Timeline {
    pub clips: Vec<Clip>, // magnetic ordering
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Project {
    pub name: String,
    pub timeline: Timeline,
    pub created_at: String,
    pub modified_at: String,
}

impl Project {
    pub fn new(name: String) -> Self {
        let now = chrono::Utc::now().to_rfc3339();
        Self {
            name,
            timeline: Timeline::default(),
            created_at: now.clone(),
            modified_at: now,
        }
    }

    pub fn update_modified_time(&mut self) {
        self.modified_at = chrono::Utc::now().to_rfc3339();
    }
}

// --------------------
// Commands (from Swift)
// --------------------
pub enum Command {
    AddClip(Clip, usize),   // insert at index
    RemoveClip(usize),      // remove by index
    CutClip(usize, u64),    // cut clip at index at specified position (ms)
    UpdateClipRange(usize, u64, u64), // update in/out points of a clip
}

// --------------------
// Engine (timeline only)
// --------------------
pub struct Engine {
    pub project: Option<Project>,
    pub current_file_path: Option<String>,
    pub is_dirty: bool,
}

pub enum EngineEvent {
    TimelineChanged(Timeline),
}

impl Engine {
    pub fn new() -> Self {
        Self { 
            project: Some(Project::new("Untitled Project".to_string())),
            current_file_path: None,
            is_dirty: true, // A new project is unsaved.
        }
    }

    pub fn get_timeline(&self) -> Timeline {
        self.project.as_ref().map(|p| p.timeline.clone()).unwrap_or_default()
    }

    pub fn handle(&mut self, cmd: Command) -> EngineEvent {
        if let Some(ref mut project) = self.project {
            match cmd {
                Command::AddClip(clip, idx) => {
                    if idx <= project.timeline.clips.len() {
                        project.timeline.clips.insert(idx, clip);
                    } else {
                        project.timeline.clips.push(clip);
                    }
                }
                Command::RemoveClip(idx) => {
                    if idx < project.timeline.clips.len() {
                        project.timeline.clips.remove(idx);
                    }
                }
                Command::CutClip(idx, position) => {
                    if idx < project.timeline.clips.len() {
                        let clip = &project.timeline.clips[idx];
                        
                        // Only cut if position is within the clip's range
                        if position > clip.in_point && position < clip.out_point {
                            // Create two new fully independent clips from the original
                            let timestamp = std::time::SystemTime::now()
                                .duration_since(std::time::UNIX_EPOCH)
                                .unwrap_or_default()
                                .as_millis();
                            
                            // Use unique identifiers for the new clips
                            let first_clip = Clip {
                                id: format!("{}-{}-A", clip.id, timestamp),
                                url: clip.url.clone(),
                                in_point: clip.in_point,
                                out_point: position,
                            };
                            
                            let second_clip = Clip {
                                id: format!("{}-{}-B", clip.id, timestamp),
                                url: clip.url.clone(),
                                in_point: position,
                                out_point: clip.out_point,
                            };
                            
                            // Remove the original and insert the two new clips
                            project.timeline.clips.remove(idx);
                            project.timeline.clips.insert(idx, second_clip);
                            project.timeline.clips.insert(idx, first_clip);
                        }
                    }
                }
                Command::UpdateClipRange(idx, in_point, out_point) => {
                    if idx < project.timeline.clips.len() {
                        let clip = &mut project.timeline.clips[idx];
                        
                        // Only update if the new range is valid
                        if in_point < out_point {
                            clip.in_point = in_point;
                            clip.out_point = out_point;
                        }
                    }
                }
            }
            project.update_modified_time();
            self.is_dirty = true; // Any command makes the project dirty.
            EngineEvent::TimelineChanged(project.timeline.clone())
        } else {
            EngineEvent::TimelineChanged(Timeline::default())
        }
    }
}

// --------------------
// FFI Boundary
// --------------------

#[no_mangle]
pub extern "C" fn engine_new() -> *mut Engine {
    Box::into_raw(Box::new(Engine::new()))
}

#[no_mangle]
pub extern "C" fn engine_free(engine: *mut Engine) {
    if !engine.is_null() {
        unsafe { let _ = Box::from_raw(engine); }
    }
}

#[no_mangle]
pub extern "C" fn engine_add_clip(engine: *mut Engine, id: *const c_char, url: *const c_char, in_ms: u64, out_ms: u64, idx: usize) {
    if engine.is_null() { return; }
    let eng = unsafe { &mut *engine };
    let id = unsafe { CStr::from_ptr(id).to_string_lossy().into_owned() };
    let url = unsafe { CStr::from_ptr(url).to_string_lossy().into_owned() };
    let clip = Clip { id, url, in_point: in_ms, out_point: out_ms };
    eng.handle(Command::AddClip(clip, idx));
}

#[no_mangle]
pub extern "C" fn engine_remove_clip(engine: *mut Engine, idx: usize) {
    if engine.is_null() { return; }
    let eng = unsafe { &mut *engine };
    eng.handle(Command::RemoveClip(idx));
}

#[no_mangle]
pub extern "C" fn engine_cut_clip(engine: *mut Engine, idx: usize, position: u64) {
    if engine.is_null() { return; }
    let eng = unsafe { &mut *engine };
    eng.handle(Command::CutClip(idx, position));
}

#[no_mangle]
pub extern "C" fn engine_update_clip_range(engine: *mut Engine, idx: usize, in_point: u64, out_point: u64) {
    if engine.is_null() { return; }
    let eng = unsafe { &mut *engine };
    eng.handle(Command::UpdateClipRange(idx, in_point, out_point));
}

#[no_mangle]
pub extern "C" fn engine_get_clip_count(engine: *const Engine) -> usize {
    if engine.is_null() { return 0; }
    let eng = unsafe { &*engine };
    eng.project.as_ref().map_or(0, |p| p.timeline.clips.len())
}

#[no_mangle]
pub extern "C" fn engine_get_clip_id(engine: *const Engine, idx: usize) -> *mut c_char {
    if engine.is_null() { return std::ptr::null_mut(); }
    let eng = unsafe { &*engine };
    if let Some(clip) = eng.project.as_ref().and_then(|p| p.timeline.clips.get(idx)) {
        CString::new(clip.id.clone()).unwrap().into_raw()
    } else {
        std::ptr::null_mut()
    }
}

#[no_mangle]
pub extern "C" fn engine_get_clip_url(engine: *const Engine, idx: usize) -> *mut c_char {
    if engine.is_null() { return std::ptr::null_mut(); }
    let eng = unsafe { &*engine };
    if let Some(clip) = eng.project.as_ref().and_then(|p| p.timeline.clips.get(idx)) {
        CString::new(clip.url.clone()).unwrap().into_raw()
    } else {
        std::ptr::null_mut()
    }
}

#[no_mangle]
pub extern "C" fn engine_get_clip_in_point(engine: *const Engine, idx: usize) -> u64 {
    if engine.is_null() { return 0; }
    let eng = unsafe { &*engine };
    eng.project.as_ref().and_then(|p| p.timeline.clips.get(idx)).map_or(0, |c| c.in_point)
}

#[no_mangle]
pub extern "C" fn engine_get_clip_out_point(engine: *const Engine, idx: usize) -> u64 {
    if engine.is_null() { return 0; }
    let eng = unsafe { &*engine };
    eng.project.as_ref().and_then(|p| p.timeline.clips.get(idx)).map_or(0, |c| c.out_point)
}

// Free string resources allocated by Rust
#[no_mangle]
pub extern "C" fn free_rust_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe { let _ = CString::from_raw(ptr); }
    }
}

// Test functions for reference (defined in the header file already)
#[no_mangle]
pub extern "C" fn add_one(x: i32) -> i32 {
    x + 1
}

#[no_mangle]
pub extern "C" fn multiply_by_two(x: i32) -> i32 {
    x * 2
}

#[no_mangle]
pub extern "C" fn divide_by_two(x: i32) -> i32 {
    x / 2
}

// Project management FFI functions are now data-oriented, not file-oriented.

/// Serializes the current project to a JSON string.
/// The caller is responsible for freeing the returned string with `free_rust_string`.
#[no_mangle]
pub extern "C" fn engine_get_project_as_json(engine: *mut Engine) -> *mut c_char {
    if engine.is_null() { return std::ptr::null_mut(); }
    let eng = unsafe { &mut *engine };

    if let Some(ref project) = eng.project {
        match serde_json::to_string_pretty(project) {
            Ok(json_string) => CString::new(json_string).unwrap().into_raw(),
            Err(_) => std::ptr::null_mut(),
        }
    } else {
        std::ptr::null_mut()
    }
}

/// Loads a project from a JSON string. This resets the dirty flag.
#[no_mangle]
pub extern "C" fn engine_load_project_from_json(engine: *mut Engine, json_data: *const c_char) -> bool {
    if engine.is_null() || json_data.is_null() { return false; }
    let eng = unsafe { &mut *engine };
    let json = unsafe { CStr::from_ptr(json_data).to_string_lossy() };

    match serde_json::from_str(&json) {
        Ok(project) => {
            eng.project = Some(project);
            eng.current_file_path = None; // Path is unknown until Swift sets it.
            eng.is_dirty = false; // A freshly loaded project is not dirty.
            true
        }
        Err(e) => {
            println!("engine_load_project_from_json - Deserialization error: {}", e);
            false
        },
    }
}

/// Sets the current file path in the engine. Swift calls this after a successful save/open.
#[no_mangle]
pub extern "C" fn engine_set_current_file_path(engine: *mut Engine, file_path: *const c_char) {
    if engine.is_null() { return; }
    let eng = unsafe { &mut *engine };

    if file_path.is_null() {
        eng.current_file_path = None;
    } else {
        let path = unsafe { CStr::from_ptr(file_path).to_string_lossy().into_owned() };
        eng.current_file_path = Some(path);
    }
}

/// Marks the current project as saved by clearing the dirty flag.
#[no_mangle]
pub extern "C" fn engine_mark_as_saved(engine: *mut Engine) {
    if engine.is_null() { return; }
    let eng = unsafe { &mut *engine };
    eng.is_dirty = false;
}

#[no_mangle]
pub extern "C" fn engine_new_project(engine: *mut Engine, name: *const c_char) -> bool {
    if engine.is_null() { return false; }
    
    let eng = unsafe { &mut *engine };
    let project_name = if name.is_null() {
        "Untitled Project".to_string()
    } else {
        unsafe { CStr::from_ptr(name).to_string_lossy().into_owned() }
    };
    
    eng.project = Some(Project::new(project_name));
    eng.current_file_path = None;
    eng.is_dirty = true;
    true
}

#[no_mangle]
pub extern "C" fn engine_get_project_name(engine: *const Engine) -> *mut c_char {
    if engine.is_null() { return std::ptr::null_mut(); }
    
    let eng = unsafe { &*engine };
    if let Some(ref project) = eng.project {
        CString::new(project.name.clone()).unwrap().into_raw()
    } else {
        std::ptr::null_mut()
    }
}

#[no_mangle]
pub extern "C" fn engine_get_current_file_path(engine: *const Engine) -> *mut c_char {
    if engine.is_null() { return std::ptr::null_mut(); }
    
    let eng = unsafe { &*engine };
    if let Some(ref path) = eng.current_file_path {
        CString::new(path.clone()).unwrap().into_raw()
    } else {
        std::ptr::null_mut()
    }
}

#[no_mangle]
pub extern "C" fn engine_has_unsaved_changes(engine: *const Engine) -> bool {
    if engine.is_null() { return false; }
    
    let eng = unsafe { &*engine };
    eng.is_dirty
}
