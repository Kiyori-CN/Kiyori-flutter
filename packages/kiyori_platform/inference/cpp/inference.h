#pragma once
#include <cstddef>
#include <cstdint>
using KiyoriStop = int (*)(void *);
using KiyoriEmit = int (*)(void *, const unsigned char *, size_t);
struct KiyoriInferenceResult {
  uint64_t input;
  uint64_t output;
  int reason;
};
// 0 success, 1 cancelled, 2 input, 3 load, 4 compute, 5 unsupported
// backend/template.
extern "C" int kiyori_infer(const char *request, void *state, KiyoriStop stop,
                            KiyoriEmit emit,
                            KiyoriInferenceResult *result) noexcept;
