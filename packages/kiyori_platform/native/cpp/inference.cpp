#include "inference.h"
#include "llmconfig.hpp"
#include "omni.hpp"
#include <algorithm>
#include <llama.h>
#include <llm/llm.hpp>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>
#include <sstream>
#include <stdexcept>
#include <vector>

using Json = nlohmann::json;
struct Control {
  void *state;
  KiyoriStop stop;
  KiyoriEmit emit;
  bool stopped() const { return stop(state) != 0; }
  bool write(const std::string &bytes) const {
    return !stopped() &&
           (bytes.empty() ||
            emit(state, reinterpret_cast<const unsigned char *>(bytes.data()),
                 bytes.size()) != 0);
  }
};

static int mnn(const Json &input, const Control &control,
               KiyoriInferenceResult &output) {
  auto config = std::make_shared<MNN::Transformer::LlmConfig>();
  config->base_dir_ = input.at("root").get<std::string>();
  config->config_ = ujson::json::parse(input.at("config").dump());
  config->mllm_config_ = config->config_.contains("mllm")
                             ? config->config_["mllm"]
                             : ujson::json();
  // 与上游createLLM保持类型选择；多模态模型的文本路径也需要Omni的mrope实现。
  std::unique_ptr<MNN::Transformer::Llm> model(
      config->is_visual() || config->is_audio() || config->has_talker()
          ? static_cast<MNN::Transformer::Llm *>(
                new MNN::Transformer::Omni(config))
          : new MNN::Transformer::Llm(config));
  if (control.stopped())
    return 1;
  if (!model->load())
    return control.stopped() ? 1 : 3;
  MNN::Transformer::ChatMessages messages;
  for (const auto &message : input.at("messages"))
    messages.emplace_back(message.at("role"), message.at("content"));
  const auto prompt = model->apply_chat_template(messages);
  // Omni也负责纯文本mrope；未接入受控媒体资源前，模板不能触发隐式文件读取。
  if (prompt.find("<img>") != std::string::npos ||
      prompt.find("<audio>") != std::string::npos)
    return 5;
  const auto tokens = model->tokenizer_encode(prompt);
  const int context = input.at("context");
  if (tokens.empty() || tokens.size() >= static_cast<size_t>(context))
    return 2;
  const int maximum = std::min(input.at("max_tokens").get<int>(),
                               context - static_cast<int>(tokens.size()));
  if (control.stopped())
    return 1;
  std::ostringstream text;
  // config在内存构造，任何缓存路径与模型文件均已由core冻结/验证。
  model->response(tokens, &text, "", 0);
  size_t delivered = 0;
  for (int count = 0; count < maximum && !model->stoped(); ++count) {
    if (control.stopped())
      return 1;
    model->generate(1);
    auto current = text.str();
    if (delivered + current.size() > 8 * 1024 * 1024)
      return 4;
    if (!control.write(current))
      return 1;
    delivered += current.size();
    text.str("");
    text.clear();
  }
  const auto *result = model->getContext();
  if (control.stopped())
    return 1;
  if (result->status == MNN::Transformer::LlmStatus::INTERNAL_ERROR ||
      result->status == MNN::Transformer::LlmStatus::NOT_LOADED)
    return 4;
  output.input = static_cast<uint64_t>(tokens.size());
  output.output = static_cast<uint64_t>(std::max(0, result->gen_seq_len));
  output.reason =
      result->status == MNN::Transformer::LlmStatus::NORMAL_FINISHED ? 0 : 1;
  return 0;
}

static void quiet_log(ggml_log_level, const char *, void *) {}
static bool progress(float, void *state) {
  return !static_cast<Control *>(state)->stopped();
}
static bool abort_compute(void *state) {
  return static_cast<Control *>(state)->stopped();
}
static int llama(const Json &input, Control &control,
                 KiyoriInferenceResult &output) {
  static std::once_flag initialized;
  std::call_once(initialized, [] {
    llama_log_set(quiet_log, nullptr);
    llama_backend_init();
  });
  auto model_options = llama_model_default_params();
  model_options.n_gpu_layers = 0;
  model_options.load_mode = input.at("mmap").get<bool>() ? LLAMA_LOAD_MODE_MMAP
                                                         : LLAMA_LOAD_MODE_NONE;
  model_options.progress_callback = progress;
  model_options.progress_callback_user_data = &control;
  std::unique_ptr<llama_model, decltype(&llama_model_free)> model(
      llama_model_load_from_file(input.at("path").get<std::string>().c_str(),
                                 model_options),
      llama_model_free);
  if (!model)
    return control.stopped() ? 1 : 3;
  auto options = llama_context_default_params();
  options.n_ctx = input.at("context");
  options.n_batch = input.at("batch");
  options.n_ubatch = input.at("micro_batch");
  options.n_threads = options.n_threads_batch = input.at("threads");
  options.flash_attn_type = input.at("flash_attention").get<bool>()
                                ? LLAMA_FLASH_ATTN_TYPE_ENABLED
                                : LLAMA_FLASH_ATTN_TYPE_DISABLED;
  options.kv_unified = input.at("kv_unified");
  options.offload_kqv = input.at("offload_kqv");
  options.abort_callback = abort_compute;
  options.abort_callback_data = &control;
  std::unique_ptr<llama_context, decltype(&llama_free)> context(
      llama_init_from_model(model.get(), options), llama_free);
  if (!context)
    return control.stopped() ? 1 : 3;
  const auto *vocab = llama_model_get_vocab(model.get());
  const auto *chat_template = llama_model_chat_template(model.get(), nullptr);
  if (!chat_template)
    return 5;
  std::vector<std::string> roles, contents;
  for (const auto &message : input.at("messages")) {
    roles.push_back(message.at("role"));
    contents.push_back(message.at("content"));
  }
  std::vector<llama_chat_message> messages;
  for (size_t i = 0; i < roles.size(); ++i)
    messages.push_back({roles[i].c_str(), contents[i].c_str()});
  std::vector<char> prompt(4096);
  int length = llama_chat_apply_template(chat_template, messages.data(),
                                         messages.size(), true, prompt.data(),
                                         static_cast<int>(prompt.size()));
  if (length < 0 || length > 8 * 1024 * 1024)
    return 5;
  if (length > static_cast<int>(prompt.size())) {
    prompt.resize(length);
    length = llama_chat_apply_template(chat_template, messages.data(),
                                       messages.size(), true, prompt.data(),
                                       static_cast<int>(prompt.size()));
  }
  if (length <= 0)
    return 5;
  int count =
      llama_tokenize(vocab, prompt.data(), length, nullptr, 0, true, true);
  if (count >= 0 || count == INT32_MIN)
    return 2;
  std::vector<llama_token> tokens(-count);
  count = llama_tokenize(vocab, prompt.data(), length, tokens.data(),
                         static_cast<int>(tokens.size()), true, true);
  if (count <= 0 || static_cast<uint32_t>(count) >= llama_n_ctx(context.get()))
    return 2;
  output.input = count;
  auto sampler_options = llama_sampler_chain_default_params();
  std::unique_ptr<llama_sampler, decltype(&llama_sampler_free)> sampler(
      llama_sampler_chain_init(sampler_options), llama_sampler_free);
  if (!sampler)
    return 3;
  const auto &parameters = input.at("parameters");
  llama_sampler_chain_add(
      sampler.get(),
      llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), 64,
                                   parameters.at("repetition_penalty"),
                                   parameters.at("frequency_penalty"),
                                   parameters.at("presence_penalty")));
  llama_sampler_chain_add(sampler.get(),
                          llama_sampler_init_top_k(parameters.at("top_k")));
  llama_sampler_chain_add(sampler.get(),
                          llama_sampler_init_top_p(parameters.at("top_p"), 1));
  const float temperature = parameters.at("temperature");
  if (temperature == 0)
    llama_sampler_chain_add(sampler.get(), llama_sampler_init_greedy());
  else {
    llama_sampler_chain_add(sampler.get(),
                            llama_sampler_init_temp(temperature));
    llama_sampler_chain_add(sampler.get(),
                            llama_sampler_init_dist(parameters.at("seed")));
  }
  for (int start = 0; start < count;) {
    if (control.stopped())
      return 1;
    const int size = std::min(count - start, static_cast<int>(options.n_batch));
    auto batch = llama_batch_get_one(tokens.data() + start, size);
    if (llama_decode(context.get(), batch) != 0)
      return control.stopped() ? 1 : 4;
    start += size;
  }
  const int maximum =
      std::min(input.at("max_tokens").get<int>(),
               static_cast<int>(llama_n_ctx(context.get())) - count);
  output.reason = 1;
  for (int index = 0; index < maximum; ++index) {
    if (control.stopped())
      return 1;
    auto token = llama_sampler_sample(sampler.get(), context.get(), -1);
    if (llama_vocab_is_eog(vocab, token)) {
      output.reason = 0;
      break;
    }
    std::vector<char> piece(256);
    int size = llama_token_to_piece(vocab, token, piece.data(),
                                    static_cast<int>(piece.size()), 0, false);
    if (size < 0) {
      piece.resize(-size);
      size = llama_token_to_piece(vocab, token, piece.data(),
                                  static_cast<int>(piece.size()), 0, false);
    }
    if (size < 0 || !control.write(std::string(piece.data(), size)))
      return control.stopped() ? 1 : 4;
    ++output.output;
    if (index + 1 < maximum) {
      auto batch = llama_batch_get_one(&token, 1);
      if (llama_decode(context.get(), batch) != 0)
        return control.stopped() ? 1 : 4;
    }
  }
  return control.stopped() ? 1 : 0;
}
extern "C" int kiyori_infer(const char *request, void *state, KiyoriStop stop,
                            KiyoriEmit emit,
                            KiyoriInferenceResult *result) noexcept {
  if (!request || !stop || !emit || !result)
    return 2;
  try {
    *result = {0, 0, 0};
    const auto input = Json::parse(request);
    Control control{state, stop, emit};
    if (input.at("provider") == "MNN")
      return mnn(input, control, *result);
    if (input.at("provider") == "LLAMA_CPP")
      return llama(input, control, *result);
    return 2;
  } catch (const std::bad_alloc &) {
    return 3;
  } catch (...) {
    return 4;
  }
}
