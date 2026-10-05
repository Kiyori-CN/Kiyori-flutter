#include "scripts.h"
#include <memory>
#include <quickjs.h>
#include <string>

namespace {
constexpr size_t MaxOutput = 8 * 1024 * 1024;
struct Control {
  void *opaque;
  KiyoriScriptStop stop;
  KiyoriScriptEmit emit;
  KiyoriScriptHttp http;
  bool output_failed = false;
  bool http_failed = false;
  bool http_active = false;
};
int interrupted(JSRuntime *, void *opaque) {
  auto &control = *static_cast<Control *>(opaque);
  return control.output_failed || control.http_failed || control.stop(control.opaque);
}
JSValue emit(JSContext *context, JSValueConst, int argc, JSValueConst *argv) {
  auto &control = *static_cast<Control *>(JS_GetContextOpaque(context));
  if (argc != 1 || control.output_failed || control.stop(control.opaque))
    return JS_ThrowInternalError(context, "Execution stopped");
  size_t length = 0;
  const char *bytes = JS_ToCStringLen(context, &length, argv[0]);
  if (!bytes)
    return JS_EXCEPTION;
  bool accepted =
      length <= 1024 * 1024 &&
      control.emit(control.opaque, reinterpret_cast<const uint8_t *>(bytes),
                   length);
  JS_FreeCString(context, bytes);
  if (!accepted) {
    control.output_failed = true;
    return JS_ThrowInternalError(context, "Output rejected");
  }
  return JS_UNDEFINED;
}
JSModuleDef *deny_module(JSContext *context, const char *, void *) {
  JS_ThrowReferenceError(context, "Module access is unavailable");
  return nullptr;
}
struct Value {
  JSContext *context;
  JSValue value;
  Value(JSContext *ctx, JSValue val) : context(ctx), value(val) {}
  ~Value() { JS_FreeValue(context, value); }
  Value(const Value &) = delete;
  Value &operator=(const Value &) = delete;
  bool failed() const { return JS_IsException(value); }
};
struct HttpResponse {
  JSContext *context;
  JSValueConst callback;
  JSValue value = JS_UNDEFINED;
  std::string bytes;
  bool failed = false;
  bool received = false;
  ~HttpResponse() { JS_FreeValue(context,value); }
};
int http_chunk(void *opaque,const uint8_t *bytes,size_t length) {
  auto &response=*static_cast<HttpResponse *>(opaque);
  if (response.failed || !bytes || length>64*1024) return 0;
  if (!JS_IsFunction(response.context,response.callback)) return 1;
  Value text(response.context,JS_NewStringLen(response.context,reinterpret_cast<const char *>(bytes),length));
  if(text.failed()) {response.failed=true;return 0;}
  Value emitted(response.context,JS_Call(response.context,response.callback,JS_UNDEFINED,1,&text.value));
  response.failed=emitted.failed();
  return !response.failed;
}
int http_result(void *opaque,const uint8_t *bytes,size_t length) {
  auto &response=*static_cast<HttpResponse *>(opaque);
  if(response.failed || response.received || !bytes || length>8*1024*1024) return 0;
  response.received=true;
  // Rust的network/serde调用栈尚未退回时不进入QuickJS解析，避免把宿主栈算进JS栈限额。
  try { response.bytes.assign(reinterpret_cast<const char *>(bytes),length); }
  catch (...) { response.failed=true;return 0; }
  return 1;
}
JSValue http_request(JSContext *context, JSValueConst, int argc, JSValueConst *argv) {
  auto &control=*static_cast<Control *>(JS_GetContextOpaque(context));
  if(argc!=2 || !control.http || control.http_failed || control.http_active || control.stop(control.opaque))
    return JS_ThrowInternalError(context,"HTTP unavailable");
  size_t length=0;
  const char *bytes=JS_ToCStringLen(context,&length,argv[0]);
  if(!bytes) return JS_EXCEPTION;
  HttpResponse response{context,argv[1]};
  control.http_active=true;
  bool accepted=length<=2*1024*1024 && control.http(control.opaque,reinterpret_cast<const uint8_t *>(bytes),length,&response,http_chunk,http_result);
  control.http_active=false;
  JS_FreeCString(context,bytes);
  if(!accepted || response.failed || !response.received) {
    control.http_failed=true;
    return JS_ThrowInternalError(context,"HTTP rejected");
  }
  response.value=JS_ParseJSON(context,response.bytes.data(),response.bytes.size(),"http-result");
  if(JS_IsException(response.value)) {control.http_failed=true;return JS_EXCEPTION;}
  return JS_DupValue(context,response.value);
}
// Intrinsics and null-prototype directory snapshots prevent package prototype
// patches from changing registration identity. Ordinary handler results remain
// package data.
constexpr char Bootstrap[] = R"JS(
(() => {
  const stringify = JSON.stringify;
  const parse = JSON.parse;
  const create = Object.create;
  const setPrototypeOf = Object.setPrototypeOf;
  const freeze = Object.freeze;
  const apply = Reflect.apply;
  const trim = String.prototype.trim;
  const test = RegExp.prototype.test;
  const idPattern = /^[A-Za-z0-9_.-]{1,128}$/;
  const nativeEmit = globalThis.__kiyoriEmit;
  delete globalThis.__kiyoriEmit;
  const nativeHttp=globalThis.__kiyoriHttp;
  delete globalThis.__kiyoriHttp;
  const entries = [];
  setPrototypeOf(entries,null);
  const required = ['listModels','sendMessage','testConnection','calculateInputTokens'];
  let sealed = false;
  const exports = {};
  Object.defineProperty(globalThis,'exports',{value:exports});
  const registration = p => {
    if (sealed || !p || typeof p !== 'object' || typeof p.id !== 'string' ||
        !apply(test,idPattern,[p.id]) ||
        typeof p.displayName !== 'string' || !apply(trim,p.displayName,[]) ||
        p.displayName.length > 1024 || (p.description != null && typeof p.description !== 'string') ||
        (p.description || '').length > 4096 || entries.length >= 32) throw Error('Invalid provider registration');
    for (let i=0;i<entries.length;i++) if (entries[i].id===p.id) throw Error('Duplicate provider');
    const handlers = create(null);
    for (let i=0;i<required.length;i++) {
      const name = required[i];
      if (!p[name] || typeof p[name].function !== 'function') throw Error('Missing handler');
      handlers[name] = p[name].function;
    }
    const entry = create(null);
    entry.id=p.id; entry.displayName=p.displayName; entry.description=p.description || ''; entry.handlers=handlers;
    entries[entries.length]=entry;
  };
  Object.defineProperty(globalThis,'ToolPkg',{value:freeze({registerAiProvider:registration})});
  Object.defineProperty(globalThis,'sendIntermediateResult',{value:value=>{
    const text = stringify(value);
    if (typeof text !== 'string') throw Error('Intermediate result is not JSON');
    nativeEmit(text);
  }});
  const installHttp=()=>{
    if(typeof nativeHttp!=='function' || globalThis.OkHttp!==undefined) return;
    const client=timeout=>freeze({newRequest:()=>{
      let url='',method='GET',headers={},body=null;
      const builder=freeze({
        url:value=>{url=value;return builder;},
        method:value=>{method=value;return builder;},
        headers:value=>{headers=value;return builder;},
        body:(value,type)=>{body=type==='json'?stringify(value):String(value);return builder;},
        build:()=>freeze({execute:async options=>{
          const callback=options && options.onIntermediateResult;
          const streaming=typeof callback==='function';
          const response=nativeHttp(stringify({url,method,headers,body,stream:streaming,timeoutMs:timeout}),
            streaming?text=>callback({type:'chunk',chunk:text}):undefined);
          return freeze({statusCode:response.statusCode,ok:response.ok,content:response.content,
            json:()=>parse(response.content || '{}'),isSuccessful:()=>response.ok});
        }})
      });
      return builder;
    }});
    Object.defineProperty(globalThis,'OkHttp',{value:freeze({newBuilder:()=>{
      let timeout=30000;
      const builder=freeze({connectTimeout:value=>{timeout=value;return builder;},
        readTimeout:value=>{timeout=value;return builder;},writeTimeout:value=>{timeout=value;return builder;},
        build:()=>client(timeout)});
      return builder;
    }})});
  };
  return freeze({
    start:()=>{
      if (typeof exports.registerToolPkg !== 'function') throw Error('Missing registerToolPkg');
      return exports.registerToolPkg();
    },
    run:text=>{
      sealed = true;
      const op = parse(text);
      if (op.kind === 'register') {
        const snapshot=[];
        setPrototypeOf(snapshot,null);
        for (let i=0;i<entries.length;i++) {
          const item=create(null), e=entries[i];
          item.id=e.id; item.displayName=e.displayName; item.description=e.description;
          snapshot[i]=item;
        }
        return snapshot;
      }
      let provider=null, supported=false;
      for (let i=0;i<entries.length;i++) if (entries[i].id===op.provider_id) provider=entries[i];
      for (let i=0;i<required.length;i++) if (required[i]===op.handler) supported=true;
      if (!provider || !supported) throw Error('Unknown provider or handler');
      installHttp();
      return provider.handlers[op.handler]({eventPayload:op.payload});
    },
    serialize:value=>stringify(value)
  });
})()
)JS";
int settle(JSRuntime *runtime, JSContext *context, Value &result,
           Control &control, uint32_t max_jobs, uint32_t &jobs) {
  if (result.failed())
    return 2;
  while (JS_PromiseState(context, result.value) == JS_PROMISE_PENDING) {
    if (interrupted(runtime, &control))
      return 1;
    if (jobs++ >= max_jobs)
      return 5;
    JSContext *job_context = nullptr;
    int count = JS_ExecutePendingJob(runtime, &job_context);
    if (count < 0)
      return 2;
    if (!count)
      return 4;
  }
  if (JS_PromiseState(context, result.value) == JS_PROMISE_REJECTED)
    return 2;
  if (JS_PromiseState(context, result.value) == JS_PROMISE_FULFILLED) {
    JSValue settled = JS_PromiseResult(context, result.value);
    JS_FreeValue(context, result.value);
    result.value = settled;
  }
  return interrupted(runtime, &control) ? 1 : 0;
}
int execute(const std::string &source, const std::string &operation,
            size_t memory, size_t stack, uint32_t max_jobs, Control &control,
            KiyoriScriptEmit final) {
  std::unique_ptr<JSRuntime, decltype(&JS_FreeRuntime)> runtime(JS_NewRuntime(),
                                                                JS_FreeRuntime);
  if (!runtime)
    return 2;
  JS_SetMemoryLimit(runtime.get(), memory);
  JS_SetMaxStackSize(runtime.get(), stack);
  JS_SetInterruptHandler(runtime.get(), interrupted, &control);
  JS_SetModuleLoaderFunc(runtime.get(), nullptr, deny_module, nullptr);
  std::unique_ptr<JSContext, decltype(&JS_FreeContext)> context(
      JS_NewContext(runtime.get()), JS_FreeContext);
  if (!context)
    return 2;
  JS_SetContextOpaque(context.get(), &control);
  Value global(context.get(), JS_GetGlobalObject(context.get()));
  if (JS_SetPropertyStr(context.get(), global.value, "__kiyoriEmit",
                        JS_NewCFunction(context.get(), emit, "emit", 1)) < 0)
    return 2;
  if(control.http && JS_SetPropertyStr(context.get(),global.value,"__kiyoriHttp",
      JS_NewCFunction(context.get(),http_request,"http",2))<0) return 2;
  Value sdk(context.get(),
            JS_Eval(context.get(), Bootstrap, sizeof(Bootstrap) - 1,
                    "kiyori-sdk", JS_EVAL_TYPE_GLOBAL));
  if (sdk.failed())
    return 2;
  uint32_t jobs = 0;
  {
    Value loaded(context.get(),
                 JS_Eval(context.get(), source.c_str(), source.size(),
                         "toolpkg", JS_EVAL_TYPE_GLOBAL));
    if (loaded.failed())
      return 2;
  }
  Value start(context.get(),
              JS_GetPropertyStr(context.get(), sdk.value, "start"));
  Value registered(context.get(), JS_Call(context.get(), start.value,
                                          JS_UNDEFINED, 0, nullptr));
  int status =
      settle(runtime.get(), context.get(), registered, control, max_jobs, jobs);
  if (status)
    return status;
  Value run(context.get(), JS_GetPropertyStr(context.get(), sdk.value, "run"));
  Value input(context.get(), JS_NewStringLen(context.get(), operation.data(),
                                             operation.size()));
  Value output(context.get(), JS_Call(context.get(), run.value, JS_UNDEFINED, 1,
                                      &input.value));
  status =
      settle(runtime.get(), context.get(), output, control, max_jobs, jobs);
  if (status)
    return status;
  Value serialize(context.get(),
                  JS_GetPropertyStr(context.get(), sdk.value, "serialize"));
  Value json(context.get(), JS_Call(context.get(), serialize.value,
                                    JS_UNDEFINED, 1, &output.value));
  if (json.failed())
    return 2;
  if (!JS_IsString(json.value))
    return 7;
  size_t length = 0;
  const char *bytes = JS_ToCStringLen(context.get(), &length, json.value);
  if (!bytes)
    return 2;
  bool accepted =
      length <= MaxOutput && !interrupted(runtime.get(), &control) &&
      final(control.opaque, reinterpret_cast<const uint8_t *>(bytes), length);
  JS_FreeCString(context.get(), bytes);
  return accepted ? 0 : 3;
}
} // namespace
extern "C" int
kiyori_script_execute(const uint8_t *source, size_t source_length,
                      const uint8_t *operation, size_t operation_length,
                      size_t memory, size_t stack, uint32_t max_jobs,
                      void *opaque, KiyoriScriptStop stop,
                      KiyoriScriptEmit emit_callback, KiyoriScriptEmit result,
                      KiyoriScriptHttp http) {
  if (!source || !operation || !stop || !emit_callback || !result ||
      !source_length || source_length > 2 * 1024 * 1024 ||
      operation_length > 2 * 1024 * 1024 || memory < 1024 * 1024 ||
      memory > 128 * 1024 * 1024 || stack < 64 * 1024 || stack > 1024 * 1024 ||
      !max_jobs || max_jobs > 100000)
    return 6;
  Control control{opaque, stop, emit_callback, http};
  try {
    int status = execute(
        std::string(reinterpret_cast<const char *>(source), source_length),
        std::string(reinterpret_cast<const char *>(operation),
                    operation_length),
        memory, stack, max_jobs, control, result);
    if (control.output_failed)
      return 3;
    if(control.http_failed) return 2;
    return stop(opaque) ? 1 : status;
  } catch (...) {
    // C++ exception text and QuickJS exception values never cross the public
    // boundary.
    return 2;
  }
}
