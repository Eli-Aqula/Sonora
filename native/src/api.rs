use std::ffi::{c_char, c_uint};
use std::os::raw::c_void;
use std::path::PathBuf;

/// Request to align lyrics with audio timestamps.
#[repr(C)]
pub struct LrcLine {
    pub time_ms: c_uint,
    pub text: *mut c_char,
}

/// Check if whisper model is available at given path.
#[no_mangle]
pub extern "C" fn check_model_available(model_path: *const c_char) -> bool {
    if model_path.is_null() {
        return false;
    }
    unsafe {
        let c_str = std::ffi::CStr::from_ptr(model_path);
        if let Ok(s) = c_str.to_str() {
            return PathBuf::from(s).exists();
        }
        false
    }
}

/// Align plain lyrics text with the audio file using whisper.
/// Returns null pointer - real implementation requires whisper.cpp model.
#[no_mangle]
pub extern "C" fn align_lyrics(
    _audio_path: *const c_char,
    _lyrics_text: *const c_char,
    out_len: *mut c_uint,
) -> *mut LrcLine {
    unsafe {
        *out_len = 0;
    }
    std::ptr::null_mut()
}

/// Free the result array from align_lyrics.
#[no_mangle]
pub extern "C" fn free_align_result(_ptr: *mut LrcLine, _len: c_uint) {
    // Placeholder
}