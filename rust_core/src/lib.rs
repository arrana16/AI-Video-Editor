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

// --------------------
// Commands (from Swift)
// --------------------
pub enum Command {
    AddClip(Clip, usize),   // insert at index
    RemoveClip(usize),      // remove by index
}

// --------------------
// Engine (timeline only)
// --------------------
pub struct Engine {
    pub timeline: Timeline,
}

pub enum EngineEvent {
    TimelineChanged(Timeline),
}

impl Engine {
    pub fn new() -> Self {
        Self { timeline: Timeline::default() }
    }

    pub fn handle(&mut self, cmd: Command) -> EngineEvent {
        match cmd {
            Command::AddClip(clip, idx) => {
                if idx <= self.timeline.clips.len() {
                    self.timeline.clips.insert(idx, clip);
                } else {
                    self.timeline.clips.push(clip);
                }
            }
            Command::RemoveClip(idx) => {
                if idx < self.timeline.clips.len() {
                    self.timeline.clips.remove(idx);
                }
            }
        }
        EngineEvent::TimelineChanged(self.timeline.clone())
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
        unsafe { Box::from_raw(engine) };
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

// Get the number of clips in the timeline
#[no_mangle]
pub extern "C" fn engine_get_clip_count(engine: *const Engine) -> usize {
    if engine.is_null() { return 0; }
    
    let eng = unsafe { &*engine };
    eng.timeline.clips.len()
}

// Get a specific clip's details by index
#[no_mangle]
pub extern "C" fn engine_get_clip_id(engine: *const Engine, idx: usize) -> *mut c_char {
    if engine.is_null() { return std::ptr::null_mut(); }
    
    let eng = unsafe { &*engine };
    if idx >= eng.timeline.clips.len() {
        return std::ptr::null_mut();
    }
    
    let clip = &eng.timeline.clips[idx];
    CString::new(clip.id.clone()).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn engine_get_clip_url(engine: *const Engine, idx: usize) -> *mut c_char {
    if engine.is_null() { return std::ptr::null_mut(); }
    
    let eng = unsafe { &*engine };
    if idx >= eng.timeline.clips.len() {
        return std::ptr::null_mut();
    }
    
    let clip = &eng.timeline.clips[idx];
    CString::new(clip.url.clone()).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn engine_get_clip_in_point(engine: *const Engine, idx: usize) -> u64 {
    if engine.is_null() { return 0; }
    
    let eng = unsafe { &*engine };
    if idx >= eng.timeline.clips.len() {
        return 0;
    }
    
    eng.timeline.clips[idx].in_point
}

#[no_mangle]
pub extern "C" fn engine_get_clip_out_point(engine: *const Engine, idx: usize) -> u64 {
    if engine.is_null() { return 0; }
    
    let eng = unsafe { &*engine };
    if idx >= eng.timeline.clips.len() {
        return 0;
    }
    
    eng.timeline.clips[idx].out_point
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
