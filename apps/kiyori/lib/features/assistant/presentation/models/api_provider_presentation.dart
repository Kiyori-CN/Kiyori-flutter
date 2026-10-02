/// 旧 ApiProviderConfigCollect / ModelApiProviderPresentation 的展示目录。
/// 仅供 UI 草稿、名称与协议选择使用；不是当前可用服务声明，不创建网络客户端。
enum ModelApiProtocol {
  chat('OpenAI Chat Completions', '兼容 Chat Completions 的请求协议'),
  responses('OpenAI Responses API', '兼容 Responses API 的请求协议'),
  messages('Anthropic Messages API', '兼容 Anthropic Messages 的请求协议'),
  native('供应商原生协议', '由供应商专用适配器处理');

  const ModelApiProtocol(this.label, this.summary);
  final String label, summary;
}

class ProviderProtocolPresentation {
  const ProviderProtocolPresentation(
    this.protocol,
    this.model,
    this.endpoint, {
    this.endpoints = const [],
  });
  final ModelApiProtocol protocol;
  final String model, endpoint;
  final List<(String, String)> endpoints;
}

class ApiProviderPresentation {
  const ApiProviderPresentation(
    this.id,
    this.name,
    this.section,
    this.defaultProtocol,
    this.protocols,
  );
  final String id, name, section;
  final ModelApiProtocol defaultProtocol;
  final List<ProviderProtocolPresentation> protocols;
  String protocolLabel(ModelApiProtocol protocol) =>
      protocol != ModelApiProtocol.native
      ? protocol.label
      : switch (id) {
          'GOOGLE' => 'Gemini 原生 API',
          'MNN' => 'MNN 端侧推理',
          'LLAMA_CPP' => 'llama.cpp 端侧推理',
          _ => protocol.label,
        };
  String get summary =>
      protocols.map((entry) => protocolLabel(entry.protocol)).join(' · ');
}

const builtInApiProviders = <ApiProviderPresentation>[
  ApiProviderPresentation(
    'DEEPSEEK',
    '深度求索（DeepSeek 系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'deepseek-v4-flash',
        'https://api.deepseek.com/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        'deepseek-v4-flash',
        'https://api.deepseek.com/v1/responses',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        'deepseek-v4-flash',
        'https://api.deepseek.com/anthropic/v1/messages',
      ),
    ],
  ),
  ApiProviderPresentation(
    'ALIYUN',
    '阿里云百炼（Qwen 通义千问系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'qwen-max',
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        'qwen-max',
        'https://dashscope.aliyuncs.com/compatible-mode/v1/responses',
      ),
    ],
  ),
  ApiProviderPresentation(
    'BAIDU',
    '百度智能云（ERNIE 文心系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'ernie-bot-4',
        'https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'XUNFEI',
    '讯飞星火（Spark 系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'spark3.5',
        'https://spark-api-open.xf-yun.com/v2/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'ZHIPU',
    '智谱 AI（GLM 系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'glm-4.5',
        'https://open.bigmodel.cn/api/paas/v4/chat/completions',
        endpoints: [
          (
            'https://open.bigmodel.cn/api/paas/v4/chat/completions',
            'CN standard',
          ),
          (
            'https://open.bigmodel.cn/api/coding/paas/v4/chat/completions',
            'CN coding',
          ),
          (
            'https://api.z.ai/api/paas/v4/chat/completions',
            'International standard',
          ),
          (
            'https://api.z.ai/api/coding/paas/v4/chat/completions',
            'International coding',
          ),
        ],
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        'glm-4.5',
        'https://open.bigmodel.cn/api/anthropic/v1/messages',
      ),
    ],
  ),
  ApiProviderPresentation(
    'BAICHUAN',
    '百川智能（Baichuan 系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'baichuan4',
        'https://api.baichuan-ai.com/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'MOONSHOT',
    '月之暗面（Kimi / Moonshot 系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'moonshot-v1-128k',
        'https://api.moonshot.cn/v1/chat/completions',
        endpoints: [
          (
            'https://api.moonshot.cn/v1/chat/completions',
            'China (moonshot.cn)',
          ),
          (
            'https://api.moonshot.ai/v1/chat/completions',
            'International (moonshot.ai)',
          ),
          (
            'https://api.kimi.com/coding/v1/chat/completions',
            'Kimi Code (api.kimi.com)',
          ),
        ],
      ),
    ],
  ),
  ApiProviderPresentation(
    'MIMO',
    '小米 MiMo（MiMo 系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'mimo-v2.5-pro',
        'https://api.xiaomimimo.com/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        'mimo-v2.5-pro',
        'https://api.xiaomimimo.com/v1/responses',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        'mimo-v2.5-pro',
        'https://api.xiaomimimo.com/anthropic/v1/messages',
      ),
    ],
  ),
  ApiProviderPresentation(
    'SILICONFLOW',
    '硅基流动（多模型）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'yi-1.5-34b',
        'https://api.siliconflow.cn/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        'yi-1.5-34b',
        'https://api.siliconflow.cn/v1/messages',
      ),
    ],
  ),
  ApiProviderPresentation(
    'IFLOW',
    'iFlow（多模型）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'TBStars2-200B-A13B',
        'https://apis.iflow.cn/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'INFINIAI',
    '无问芯穹（Infini-AI 系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'infini-mini',
        'https://cloud.infini-ai.com/maas/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        'infini-mini',
        'https://cloud.infini-ai.com/maas/v1/messages',
      ),
    ],
  ),
  ApiProviderPresentation(
    'ALIPAY_BAILING',
    '支付宝百灵（Ling 系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'Ling-1T',
        'https://api.tbox.cn/api/llm/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'DOUBAO',
    '火山方舟（豆包系列）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'Doubao-pro-4k',
        'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
        endpoints: [
          (
            'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
            'CN standard',
          ),
          (
            'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions',
            'CN coding',
          ),
        ],
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        'Doubao-pro-4k',
        'https://ark.cn-beijing.volces.com/api/v3/responses',
      ),
    ],
  ),
  ApiProviderPresentation(
    'PPINFRA',
    '派欧云 PPIO（多模型）',
    '国内供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'gpt-4o-mini',
        'https://api.ppinfra.com/openai/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'OPENAI',
    'OpenAI（GPT 系列）',
    '国际供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'gpt-4o',
        'https://api.openai.com/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        'gpt-4o',
        'https://api.openai.com/v1/responses',
      ),
    ],
  ),
  ApiProviderPresentation(
    'ANTHROPIC',
    'Anthropic（Claude 系列）',
    '国际供应商',
    ModelApiProtocol.messages,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        'claude-3-opus-20240229',
        'https://api.anthropic.com/v1/messages',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'claude-3-opus-20240229',
        'https://api.anthropic.com/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'GOOGLE',
    'Google（Gemini 系列）',
    '国际供应商',
    ModelApiProtocol.native,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.native,
        'gemini-2.0-flash',
        'https://generativelanguage.googleapis.com/v1beta/models',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'gemini-2.0-flash',
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'XAI',
    'xAI（Grok 系列）',
    '国际供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'grok-4.6',
        'https://api.x.ai/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        'grok-4.6',
        'https://api.x.ai/v1/responses',
      ),
    ],
  ),
  ApiProviderPresentation(
    'MISTRAL',
    'Mistral AI（Mistral / Codestral 系列）',
    '国际供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'codestral-latest',
        'https://codestral.mistral.ai/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'OPENROUTER',
    'OpenRouter（多模型聚合）',
    '国际供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'google/gemini-pro',
        'https://openrouter.ai/api/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        'google/gemini-pro',
        'https://openrouter.ai/api/v1/responses',
      ),
    ],
  ),
  ApiProviderPresentation(
    'FOUR_ROUTER',
    '4Router（多模型聚合）',
    '国际供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'gpt-5.4-mini',
        'https://4router.net/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'NOUS_PORTAL',
    'Nous Research（Hermes 系列）',
    '国际供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        '',
        'https://inference-api.nousresearch.com/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'NVIDIA',
    'NVIDIA NIM（Nemotron / 多模型）',
    '国际供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'nvidia/nemotron-3-nano-30b-a3b',
        'https://integrate.api.nvidia.com/v1/chat/completions',
      ),
    ],
  ),
  ApiProviderPresentation(
    'NOVITA',
    'Novita AI（多模型）',
    '国际供应商',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'moonshotai/kimi-k2.5',
        'https://api.novita.ai/openai/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        'moonshotai/kimi-k2.5',
        'https://api.novita.ai/anthropic/v1/messages',
      ),
    ],
  ),
  ApiProviderPresentation(
    'LMSTUDIO',
    'LM Studio（本地模型服务）',
    '本地与自定义',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        'meta-llama-3.1-8b-instruct',
        'http://localhost:1234/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        'meta-llama-3.1-8b-instruct',
        'http://localhost:1234/v1/responses',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        'meta-llama-3.1-8b-instruct',
        'http://localhost:1234/v1/messages',
      ),
    ],
  ),
  ApiProviderPresentation(
    'OLLAMA',
    'Ollama（本地模型服务）',
    '本地与自定义',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        '',
        'http://localhost:11434/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        '',
        'http://localhost:11434/v1/responses',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.messages,
        '',
        'http://localhost:11434/v1/messages',
      ),
    ],
  ),
  ApiProviderPresentation(
    'OPENAI_LOCAL',
    'OpenAI 兼容本地服务',
    '本地与自定义',
    ModelApiProtocol.chat,
    [
      ProviderProtocolPresentation(
        ModelApiProtocol.chat,
        '',
        'http://localhost:8000/v1/chat/completions',
      ),
      ProviderProtocolPresentation(
        ModelApiProtocol.responses,
        '',
        'http://localhost:8000/v1/responses',
      ),
    ],
  ),
  ApiProviderPresentation(
    'MNN',
    'MNN（端侧本地推理）',
    '本地与自定义',
    ModelApiProtocol.native,
    [ProviderProtocolPresentation(ModelApiProtocol.native, '', '')],
  ),
  ApiProviderPresentation(
    'LLAMA_CPP',
    'llama.cpp（端侧本地推理）',
    '本地与自定义',
    ModelApiProtocol.native,
    [ProviderProtocolPresentation(ModelApiProtocol.native, '', '')],
  ),
  ApiProviderPresentation('OTHER', '自定义 API', '本地与自定义', ModelApiProtocol.chat, [
    ProviderProtocolPresentation(ModelApiProtocol.chat, '', ''),
    ProviderProtocolPresentation(ModelApiProtocol.responses, '', ''),
    ProviderProtocolPresentation(ModelApiProtocol.messages, '', ''),
  ]),
];
