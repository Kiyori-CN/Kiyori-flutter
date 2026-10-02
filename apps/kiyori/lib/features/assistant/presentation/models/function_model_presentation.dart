enum AssistantFunction {
  chat('对话功能', '主要的对话功能，用于与用户进行日常对话交互'),
  summary('上下文总结', '压缩上下文，生成聊天摘要'),
  titleGeneration('AI总结标题', '根据用户第一条消息自动生成简短、准确的对话标题'),
  memory('记忆更新', '处理记忆并存放到记忆库'),
  ui(
    'UI控制器',
    '用于UI界面的自动遍历与操作，对应的 UI 控制器模型仅在用户明确要求使用“智能体”控制时才会启用，例如可选择 autoglm 等专用模型。',
  ),
  translation('翻译功能', '提供多语言翻译功能，支持文本内容的语言转换。建议使用支持多语言的模型。'),
  grep('Grep检索', '用于grep_context的检索规划与结果筛选（多轮grep_code）'),
  planner('群组规划', '用于在群组中动态决定本轮发言顺序与跳过策略，支持多轮讨论'),
  image(
    '图像识别',
    '用于图像内容识别和分析，调用read_file工具读取图片时支持intent参数进行深度理解。建议使用支持视觉的多模态模型。',
  ),
  audio(
    '音频识别',
    '用于音频内容识别和分析，调用read_file工具读取音频时可使用intent参数进行深度理解（如转写/总结/识别说话内容）。建议使用支持音频输入或高质量转写的模型。',
  ),
  video(
    '视频识别',
    '用于视频内容识别和分析，调用read_file工具读取视频时可使用intent参数进行深度理解（如抽帧理解/场景描述/对话总结）。建议使用支持视频/图像输入的多模态模型。',
  );

  const AssistantFunction(this.title, this.description);
  final String title, description;
}

/// 模型配置摘要由未来配置 owner 注入，不包含密钥或客户端。
class ModelConfigPresentation {
  const ModelConfigPresentation({
    required this.id,
    required this.name,
    this.models = const [],
    this.image,
    this.audio,
    this.video,
  });
  final String id, name;
  final List<String> models;
  final bool? image, audio, video;
}

class FunctionModelSelection {
  const FunctionModelSelection(this.configId, [this.modelIndex = 0]);
  final String configId;
  final int modelIndex;
}

enum FunctionModelLoadState { ready, loading, failed }

enum FunctionTestOutcome { passed, unverified, failed }

class FunctionTestPresentation {
  const FunctionTestPresentation(this.outcome, this.message);
  final FunctionTestOutcome outcome;
  final String message;
}

class FunctionModelsPresentation {
  const FunctionModelsPresentation({
    this.configs = const [],
    this.selections = const {},
    this.results = const {},
    this.loading = FunctionModelLoadState.ready,
  });
  final List<ModelConfigPresentation> configs;
  final Map<AssistantFunction, FunctionModelSelection> selections;
  final Map<AssistantFunction, FunctionTestPresentation> results;
  final FunctionModelLoadState loading;
}
