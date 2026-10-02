import 'package:kiyori/features/assistant/presentation/history/chat_history_presentation.dart';
import 'package:kiyori/features/assistant/presentation/models/function_model_presentation.dart';
import 'package:kiyori/features/assistant/presentation/usage/usage_presentation.dart';

const snapshot = ChatHistoryPresentation(
  chats: [
    ChatHistoryItem(id: 'a', title: '第一条记录', character: '林', group: '工作'),
    ChatHistoryItem(
      id: 'b',
      title: '第二条记录',
      characterGroupId: 'g',
      group: '生活',
    ),
  ],
  characters: [HistoryIdentity('c', '林')],
  groups: [HistoryIdentity('g', '讨论组')],
  characterStats: [HistoryStatistic('已删除角色', 1, 3)],
  groupStats: [HistoryStatistic('lost', 1, 2)],
  workspaces: [HistoryWorkspace('/preview/workspace', '草稿', '内部存储')],
);

const functionSnapshot = FunctionModelsPresentation(
  configs: [
    ModelConfigPresentation(id: 'default', name: '默认配置', models: ['模型一']),
    ModelConfigPresentation(id: 'multi', name: '多模型配置', models: ['模型二', '模型三']),
  ],
);

const usageFixture = UsagePresentation(
  chats: 12,
  messages: 40,
  input: 800,
  output: 200,
  cached: 80,
  requests: 5,
  costCny: 1.25,
  hasUsdCost: true,
  models: [
    ModelUsagePresentation(
      name: 'Model B',
      input: 200,
      output: 100,
      requests: 2,
      costCny: .5,
      billing: UsageBillingMode.request,
      requestPriceCny: .25,
    ),
    ModelUsagePresentation(
      name: 'Model A',
      input: 600,
      output: 100,
      cached: 80,
      requests: 3,
      costCny: .75,
      inputPriceCny: 1.2,
      cachedPriceCny: .1,
      outputPriceCny: 2.4,
    ),
  ],
);
