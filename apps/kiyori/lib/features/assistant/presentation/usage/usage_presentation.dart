enum UsageBillingMode { token, request }

/// 金额已经由领域 owner 折算为 CNY；展示层不承担真实账单计算和定价查询。
class ModelUsagePresentation {
  const ModelUsagePresentation({
    required this.name,
    this.input = 0,
    this.output = 0,
    this.cached = 0,
    this.requests = 0,
    this.costCny = 0,
    this.inputPriceCny = 0,
    this.outputPriceCny = 0,
    this.cachedPriceCny = 0,
    this.requestPriceCny = 0,
    this.billing = UsageBillingMode.token,
  });
  final String name;
  final int input, output, cached, requests;
  final double costCny,
      inputPriceCny,
      outputPriceCny,
      cachedPriceCny,
      requestPriceCny;
  final UsageBillingMode billing;
}

class UsagePresentation {
  const UsagePresentation({
    this.chats = 0,
    this.messages = 0,
    this.input = 0,
    this.output = 0,
    this.cached = 0,
    this.requests = 0,
    this.costCny = 0,
    this.exchangeRate = 7.2,
    this.hasUsdCost = false,
    this.models = const [],
  });
  final int chats, messages, input, output, cached, requests;
  final double costCny, exchangeRate;
  final bool hasUsdCost;
  final List<ModelUsagePresentation> models;
}

String usageMoney(double value) => '¥${value.toStringAsFixed(2)}';
String usageEditablePrice(double value) =>
    value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
