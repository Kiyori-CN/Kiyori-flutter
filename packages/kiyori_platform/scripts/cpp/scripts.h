#pragma once
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef int (*KiyoriScriptStop)(void *opaque);
typedef int (*KiyoriScriptEmit)(void *opaque, const uint8_t *bytes,
                                size_t length);
typedef int (*KiyoriScriptHttp)(void *opaque, const uint8_t *request,
                                size_t length, void *response_opaque,
                                KiyoriScriptEmit chunk, KiyoriScriptEmit result);
// callbacks and byte pointers are borrowed only for this synchronous call.
int kiyori_script_execute(const uint8_t *source, size_t source_length,
                          const uint8_t *operation, size_t operation_length,
                          size_t memory_bytes, size_t stack_bytes,
                          uint32_t max_jobs, void *opaque,
                          KiyoriScriptStop stop, KiyoriScriptEmit emit,
                          KiyoriScriptEmit result, KiyoriScriptHttp http);
#ifdef __cplusplus
}
#endif
