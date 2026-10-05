//! 正式平台adapter；句柄仅存在于本次blocking worker，C++异常不跨FFI。
use kiyori_core::chat::{
    ChatFailure, ChatFailureKind,
    native::{InferenceAdapter, InferenceRequest, InferenceResult},
};
use serde_json::{Value, json};

pub struct NativeInference;
fn failure(kind: ChatFailureKind, message: &str) -> ChatFailure {
    ChatFailure {
        kind,
        message: message.into(),
        http_status: None,
    }
}

fn compile(input: &InferenceRequest) -> Result<Value, ChatFailure> {
    let invalid = || {
        failure(
            ChatFailureKind::InvalidInput,
            "本地模型参数无效或超出安全范围",
        )
    };
    let unsupported = || {
        failure(
            ChatFailureKind::Unsupported,
            "当前本地构建只支持CPU，所选GPU后端未编译",
        )
    };
    let parameters = input.parameters.as_object().ok_or_else(invalid)?;
    let mut sampling = json!({"max_tokens":4096,"temperature":1.0,"top_p":1.0,"top_k":0,"repetition_penalty":1.0,"presence_penalty":0.0,"frequency_penalty":0.0,"seed":4294967295u32,"enable_thinking":false});
    for (key, value) in parameters {
        if sampling.get(key).is_none() {
            return Err(failure(
                ChatFailureKind::Unsupported,
                &format!("本地引擎尚未支持参数 {key}"),
            ));
        }
        sampling[key] = value.clone();
    }
    let max = sampling["max_tokens"]
        .as_u64()
        .filter(|v| (1..=32768).contains(v))
        .ok_or_else(invalid)?;
    for (key, min, max) in [
        ("temperature", 0., 5.),
        ("top_p", 0.0001, 1.),
        ("repetition_penalty", 0.0001, 10.),
        ("presence_penalty", -2., 2.),
        ("frequency_penalty", -2., 2.),
    ] {
        if !sampling[key]
            .as_f64()
            .is_some_and(|v| v.is_finite() && v >= min && v <= max)
        {
            return Err(invalid());
        }
    }
    if !sampling["top_k"].as_u64().is_some_and(|v| v <= 1_000_000)
        || !sampling["seed"]
            .as_u64()
            .is_some_and(|v| v <= u32::MAX.into())
        || !sampling["enable_thinking"].is_boolean()
    {
        return Err(invalid());
    }
    let options = &input.options;
    let root = input
        .resource
        .root
        .to_str()
        .ok_or_else(invalid)?
        .replace('\\', "/")
        + "/";
    let cache = input
        .resource
        .cache
        .to_str()
        .ok_or_else(invalid)?
        .replace('\\', "/")
        + "/";
    let mut request = json!({"provider":input.provider,"root":root,"path":input.resource.model_path.to_str().ok_or_else(invalid)?,"messages":input.messages,"parameters":sampling,"max_tokens":max});
    if input.provider == "MNN" {
        if parameters.contains_key("seed") {
            return Err(failure(
                ChatFailureKind::Unsupported,
                "固定MNN引擎尚无可设置的seed接口",
            ));
        }
        // 固定MNN sampler对负惩罚/小于1的重复惩罚有跳过分支，不能宣称这些值已生效。
        if sampling["repetition_penalty"]
            .as_f64()
            .is_some_and(|v| v < 1.)
            || sampling["presence_penalty"]
                .as_f64()
                .is_some_and(|v| v < 0.)
            || sampling["frequency_penalty"]
                .as_f64()
                .is_some_and(|v| v < 0.)
        {
            return Err(failure(
                ChatFailureKind::Unsupported,
                "固定MNN引擎不支持负惩罚或小于1的重复惩罚",
            ));
        }
        if options.mnn_forward != 0 {
            return Err(unsupported());
        }
        if !(1..=128).contains(&options.mnn_threads) {
            return Err(invalid());
        }
        let configured_context = if options.max_context_mode {
            options.max_context_length
        } else {
            options.context_length
        };
        if !configured_context.is_finite() || configured_context > 64. {
            return Err(invalid());
        }
        let context = (configured_context * 1024.) as u32;
        if context < 128 {
            return Err(invalid());
        }
        let mut config = input.resource.config.clone();
        let object = config.as_object_mut().ok_or_else(invalid)?;
        for (key, value) in [
            ("backend_type", json!("cpu")),
            ("thread_num", json!(options.mnn_threads)),
            ("precision", json!("low")),
            ("memory", json!("low")),
            ("async", json!(false)),
            ("max_new_tokens", json!(max)),
            ("max_all_tokens", json!(context)),
            ("tmp_path", json!(cache)),
            ("prefix_cache_path", json!(cache)),
            ("reuse_kv", json!(false)),
            ("prompt_cache", json!(false)),
        ] {
            object.insert(key.into(), value);
        }
        let mut samplers = vec!["penalty"];
        if sampling["top_k"].as_u64().unwrap() > 0 {
            samplers.push("topK");
        }
        samplers.extend([
            "topP",
            if sampling["temperature"].as_f64() == Some(0.) {
                "greedy"
            } else {
                "temperature"
            },
        ]);
        config["sampler_type"] = json!("mixed");
        config["mixed_samplers"] = json!(samplers);
        for key in [
            "temperature",
            "repetition_penalty",
            "presence_penalty",
            "frequency_penalty",
        ] {
            config[key] = sampling[key].clone();
        }
        config["topK"] = sampling["top_k"].clone();
        config["topP"] = sampling["top_p"].clone();
        config["penalty_window"] = json!(64);
        config["n_gram"] = json!(1);
        config["ngram_factor"] = json!(1.0);
        if !config["jinja"].is_object() {
            config["jinja"] = json!({});
        }
        if !config["jinja"]["context"].is_object() {
            config["jinja"]["context"] = json!({});
        }
        config["jinja"]["context"]["enable_thinking"] = sampling["enable_thinking"].clone();
        request["config"] = config;
        request["context"] = json!(context);
    } else if input.provider == "LLAMA_CPP" {
        if options.llama_gpu_layers != 0 || options.llama_offload_kqv {
            return Err(unsupported());
        }
        if sampling["enable_thinking"] == true {
            return Err(failure(
                ChatFailureKind::Unsupported,
                "llama思考模板尚未接入",
            ));
        }
        if !(1..=128).contains(&options.llama_threads)
            || !(128..=65536).contains(&options.llama_context)
            || !(1..=4096).contains(&options.llama_batch)
            || options.llama_micro_batch == 0
            || options.llama_micro_batch > options.llama_batch
        {
            return Err(invalid());
        }
        for (key, value) in [
            ("context", json!(options.llama_context)),
            ("threads", json!(options.llama_threads)),
            ("batch", json!(options.llama_batch)),
            ("micro_batch", json!(options.llama_micro_batch)),
            ("mmap", json!(options.llama_mmap)),
            ("flash_attention", json!(options.llama_flash_attention)),
            ("kv_unified", json!(options.llama_kv_unified)),
            ("offload_kqv", json!(options.llama_offload_kqv)),
        ] {
            request[key] = value;
        }
    } else {
        return Err(invalid());
    }
    Ok(request)
}

#[cfg(kiyori_native_models)]
mod ffi {
    use super::*;
    use std::{
        ffi::{CString, c_char, c_void},
        panic::{AssertUnwindSafe, catch_unwind},
    };
    #[repr(C)]
    #[derive(Default)]
    struct ResultRaw {
        input: u64,
        output: u64,
        reason: i32,
    }
    unsafe extern "C" {
        fn kiyori_infer(
            request: *const c_char,
            state: *mut c_void,
            stop: extern "C" fn(*mut c_void) -> i32,
            emit: extern "C" fn(*mut c_void, *const u8, usize) -> i32,
            result: *mut ResultRaw,
        ) -> i32;
    }
    struct Call<'a> {
        stop: &'a dyn Fn() -> bool,
        emit: &'a mut dyn FnMut(&[u8]) -> bool,
        panicked: bool,
    }
    extern "C" fn stop(state: *mut c_void) -> i32 {
        // state是同步kiyori_infer的栈借用，不由C++保存；panic不能跨语言边界。
        let state = unsafe { &mut *state.cast::<Call<'_>>() };
        match catch_unwind(AssertUnwindSafe(|| (state.stop)())) {
            Ok(value) => i32::from(value),
            Err(_) => {
                state.panicked = true;
                1
            }
        }
    }
    extern "C" fn emit(state: *mut c_void, bytes: *const u8, length: usize) -> i32 {
        let state = unsafe { &mut *state.cast::<Call<'_>>() };
        if bytes.is_null() || length > 1024 * 1024 {
            return 0;
        }
        let bytes = unsafe { std::slice::from_raw_parts(bytes, length) };
        match catch_unwind(AssertUnwindSafe(|| (state.emit)(bytes))) {
            Ok(value) => i32::from(value),
            Err(_) => {
                state.panicked = true;
                0
            }
        }
    }
    pub(super) fn generate(
        value: Value,
        stopped: &dyn Fn() -> bool,
        emit_bytes: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<InferenceResult, ChatFailure> {
        let request = CString::new(value.to_string())
            .map_err(|_| failure(ChatFailureKind::InvalidInput, "本地请求包含无效字符"))?;
        let mut state = Call {
            stop: stopped,
            emit: emit_bytes,
            panicked: false,
        };
        let mut result = ResultRaw::default();
        let code = unsafe {
            kiyori_infer(
                request.as_ptr(),
                (&mut state as *mut Call<'_>).cast(),
                stop,
                emit,
                &mut result,
            )
        };
        if state.panicked {
            return Err(failure(ChatFailureKind::Interrupted, "本地推理回调异常"));
        }
        match code {
            0 => Ok(InferenceResult {
                input_tokens: result.input,
                output_tokens: result.output,
                reason: if result.reason == 0 { "stop" } else { "length" }.into(),
            }),
            1 => Err(failure(ChatFailureKind::Interrupted, "本地模型推理已停止")),
            2 => Err(failure(
                ChatFailureKind::InvalidInput,
                "本地模型输入超出上下文或参数无效",
            )),
            3 => Err(failure(
                ChatFailureKind::Interrupted,
                "本地模型加载失败，请检查模型和可用内存",
            )),
            5 => Err(failure(
                ChatFailureKind::Unsupported,
                "本地模型后端或聊天模板尚未支持",
            )),
            _ => Err(failure(ChatFailureKind::Interrupted, "本地模型计算失败")),
        }
    }
}
impl InferenceAdapter for NativeInference {
    fn generate(
        &self,
        input: &InferenceRequest,
        stopped: &dyn Fn() -> bool,
        emit: &mut dyn FnMut(&[u8]) -> bool,
    ) -> Result<InferenceResult, ChatFailure> {
        let request = compile(input)?;
        #[cfg(kiyori_native_models)]
        {
            ffi::generate(request, stopped, emit)
        }
        #[cfg(not(kiyori_native_models))]
        {
            let _ = (request, stopped, emit);
            Err(failure(
                ChatFailureKind::Unsupported,
                "当前平台未编译本地模型引擎",
            ))
        }
    }
}
