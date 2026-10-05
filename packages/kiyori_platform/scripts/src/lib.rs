//! QuickJS-NG平台端口，C++句柄仅生存在调用的blocking worker中。
use kiyori_core::scripts::{ScriptAdapter, ScriptFailure, ScriptFailureKind, ScriptRequest};
use serde_json::Value;

pub struct NativeScripts;
#[cfg(kiyori_native_scripts)]
mod ffi {
    use super::*;
    use std::{
        ffi::c_void,
        panic::{AssertUnwindSafe, catch_unwind},
    };
    type Stop = extern "C" fn(*mut c_void) -> i32;
    type Emit = extern "C" fn(*mut c_void, *const u8, usize) -> i32;
    unsafe extern "C" {
        fn kiyori_script_execute(
            source: *const u8,
            source_length: usize,
            operation: *const u8,
            operation_length: usize,
            memory: usize,
            stack: usize,
            jobs: u32,
            opaque: *mut c_void,
            stop: Stop,
            emit: Emit,
            result: Emit,
        ) -> i32;
    }
    struct Call<'a> {
        stop: &'a dyn Fn() -> bool,
        emit: &'a mut dyn FnMut(&[u8]) -> bool,
        output: Option<Value>,
        panicked: bool,
        protocol_error: bool,
    }
    extern "C" fn stop(opaque: *mut c_void) -> i32 {
        let call = unsafe { &mut *opaque.cast::<Call<'_>>() };
        match catch_unwind(AssertUnwindSafe(|| call.panicked || (call.stop)())) {
            Ok(value) => i32::from(value),
            Err(_) => {
                call.panicked = true;
                1
            }
        }
    }
    extern "C" fn emit(opaque: *mut c_void, bytes: *const u8, length: usize) -> i32 {
        let call = unsafe { &mut *opaque.cast::<Call<'_>>() };
        if bytes.is_null() || length > 1024 * 1024 {
            return 0;
        }
        let bytes = unsafe { std::slice::from_raw_parts(bytes, length) };
        match catch_unwind(AssertUnwindSafe(|| (call.emit)(bytes))) {
            Ok(value) => i32::from(value),
            Err(_) => {
                call.panicked = true;
                0
            }
        }
    }
    extern "C" fn result(opaque: *mut c_void, bytes: *const u8, length: usize) -> i32 {
        let call = unsafe { &mut *opaque.cast::<Call<'_>>() };
        if bytes.is_null() || length > 8 * 1024 * 1024 || call.output.is_some() {
            return 0;
        }
        let bytes = unsafe { std::slice::from_raw_parts(bytes, length) };
        match catch_unwind(AssertUnwindSafe(|| serde_json::from_slice(bytes))) {
            Ok(Ok(value)) => {
                call.output = Some(value);
                1
            }
            Ok(Err(_)) => {
                call.protocol_error = true;
                0
            }
            Err(_) => {
                call.panicked = true;
                0
            }
        }
    }
    pub(super) fn execute(
        request: &ScriptRequest,
        stopped: &dyn Fn() -> bool,
        emit_bytes: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<Value, ScriptFailure> {
        let operation =
            serde_json::to_vec(&request.operation).map_err(|_| ScriptFailureKind::InvalidInput)?;
        let mut call = Call {
            stop: stopped,
            emit: emit_bytes,
            output: None,
            panicked: false,
            protocol_error: false,
        };
        let status = unsafe {
            kiyori_script_execute(
                request.source.as_ptr(),
                request.source.len(),
                operation.as_ptr(),
                operation.len(),
                request.limits.memory_bytes,
                request.limits.stack_bytes,
                request.limits.max_jobs,
                (&mut call as *mut Call<'_>).cast(),
                stop,
                emit,
                result,
            )
        };
        if call.panicked {
            return Err(ScriptFailureKind::Interrupted.into());
        }
        if call.protocol_error {
            return Err(ScriptFailureKind::Protocol.into());
        }
        if status == 0 {
            return call.output.ok_or(ScriptFailureKind::Protocol.into());
        }
        Err(match status {
            1 => ScriptFailureKind::Cancelled,
            2 => ScriptFailureKind::Execution,
            3 => ScriptFailureKind::OutputLimit,
            4 => ScriptFailureKind::UnresolvedPromise,
            5 => ScriptFailureKind::JobLimit,
            6 => ScriptFailureKind::InvalidInput,
            _ => ScriptFailureKind::Protocol,
        }
        .into())
    }
}
impl ScriptAdapter for NativeScripts {
    fn execute(
        &self,
        request: &ScriptRequest,
        stopped: &dyn Fn() -> bool,
        emit: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<Value, ScriptFailure> {
        #[cfg(kiyori_native_scripts)]
        {
            ffi::execute(request, stopped, emit)
        }
        #[cfg(not(kiyori_native_scripts))]
        {
            let _ = (request, stopped, emit);
            Err(ScriptFailureKind::Unsupported.into())
        }
    }
}
