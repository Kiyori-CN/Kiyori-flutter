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
  bool output_failed = false;
};
int interrupted(JSRuntime *, void *opaque) {
  auto &control = *static_cast<Control *>(opaque);
  return control.output_failed || control.stop(control.opaque);
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
                      KiyoriScriptEmit emit_callback, KiyoriScriptEmit result) {
  if (!source || !operation || !stop || !emit_callback || !result ||
      !source_length || source_length > 2 * 1024 * 1024 ||
      operation_length > 2 * 1024 * 1024 || memory < 1024 * 1024 ||
      memory > 128 * 1024 * 1024 || stack < 64 * 1024 || stack > 1024 * 1024 ||
      !max_jobs || max_jobs > 100000)
    return 6;
  Control control{opaque, stop, emit_callback};
  try {
    int status = execute(
        std::string(reinterpret_cast<const char *>(source), source_length),
        std::string(reinterpret_cast<const char *>(operation),
                    operation_length),
        memory, stack, max_jobs, control, result);
    if (control.output_failed)
      return 3;
    return stop(opaque) ? 1 : status;
  } catch (...) {
    // C++ exception text and QuickJS exception values never cross the public
    // boundary.
    return 2;
  }
}
