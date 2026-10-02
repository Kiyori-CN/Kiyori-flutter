import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'api_provider_presentation.dart';

Future<ApiProviderPresentation?> showApiProviderDrawer(
  BuildContext context, {
  required String selectedId,
  List<ApiProviderPresentation> providers = builtInApiProviders,
}) => showKiyoriModalDrawer<ApiProviderPresentation>(
  context,
  builder: (context, dismiss) => _ProviderDrawer(
    selectedId: selectedId,
    providers: providers,
    onSelected: (provider) => dismiss(provider),
  ),
);

Future<ModelApiProtocol?> showApiProtocolDrawer(
  BuildContext context, {
  required ApiProviderPresentation provider,
  required ModelApiProtocol selected,
}) => showKiyoriModalDrawer<ModelApiProtocol>(
  context,
  builder: (context, dismiss) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 12),
          child: Text(
            '选择API协议',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: provider.protocols.length,
            itemBuilder: (context, index) {
              final protocol = provider.protocols[index].protocol;
              final checked = protocol == selected;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: checked
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: () => dismiss(protocol),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.protocolLabel(protocol),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: checked
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  protocol.summary,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PrimaryColors.of(context).secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (checked)
                            Icon(
                              Icons.check,
                              color: PrimaryColors.of(context).accent,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  ),
);

class _ProviderDrawer extends StatefulWidget {
  const _ProviderDrawer({
    required this.selectedId,
    required this.providers,
    required this.onSelected,
  });
  final String selectedId;
  final List<ApiProviderPresentation> providers;
  final ValueChanged<ApiProviderPresentation> onSelected;
  @override
  State<_ProviderDrawer> createState() => _ProviderDrawerState();
}

class _ProviderDrawerState extends State<_ProviderDrawer> {
  final search = TextEditingController();
  late List<Object> rows;
  @override
  void initState() {
    super.initState();
    filter();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void filter() {
    final query = search.text.trim().toLowerCase();
    rows = [];
    final matches = widget.providers
        .where(
          (entry) => [
            entry.id,
            entry.name,
            entry.summary,
          ].any((text) => text.toLowerCase().contains(query)),
        )
        .toList();
    for (final section in ['国内供应商', '国际供应商', '本地与自定义', 'ToolPkg Provider']) {
      final entries = matches
          .where((entry) => entry.section == section)
          .toList();
      if (entries.isNotEmpty) rows.addAll([section, ...entries]);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '选择API提供商',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        KiyoriSearchField(
          controller: search,
          hint: '搜索提供商',
          showSearchIcon: true,
          showClear: true,
          onChanged: (_) => setState(filter),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row is String) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Text(
                    row,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PrimaryColors.of(context).accent,
                    ),
                  ),
                );
              }
              final provider = row as ApiProviderPresentation;
              final selected = provider.id == widget.selectedId;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: ValueKey('provider-${provider.id}'),
                    onTap: () => widget.onSelected(provider),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: providerColor(context, provider.id),
                            ),
                            child: Text(
                              provider.name.characters.firstOrNull ?? '?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  provider.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  provider.summary,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: PrimaryColors.of(context).secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check,
                              color: PrimaryColors.of(context).accent,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

Color providerColor(BuildContext context, String id) {
  final colors = Theme.of(context).colorScheme;
  final (color, opacity) = switch (id) {
    'OPENAI' => (colors.primary, 1.0),
    'ANTHROPIC' || 'LMSTUDIO' => (colors.tertiary, 1.0),
    'XAI' => (colors.onSurface, 1.0),
    'GOOGLE' || 'MNN' => (colors.secondary, 1.0),
    'BAIDU' => (colors.primary, .8),
    'ALIYUN' => (colors.tertiary, .8),
    'XUNFEI' => (colors.secondary, .8),
    'ZHIPU' => (colors.primary, .7),
    'BAICHUAN' => (colors.tertiary, .7),
    'MOONSHOT' => (colors.secondary, .7),
    'MIMO' => (colors.secondary, .66),
    'DEEPSEEK' => (colors.primary, .6),
    'MISTRAL' => (colors.tertiary, .65),
    'SILICONFLOW' => (colors.tertiary, .6),
    'IFLOW' => (colors.tertiary, .55),
    'OPENROUTER' => (colors.secondary, .6),
    'FOUR_ROUTER' => (colors.secondary, .56),
    'NOUS_PORTAL' => (colors.secondary, .52),
    'INFINIAI' => (colors.primary, .5),
    'ALIPAY_BAILING' => (colors.tertiary, .45),
    'DOUBAO' => (colors.secondary, .4),
    'NVIDIA' => (colors.primary, .72),
    'OLLAMA' => (colors.primary, .78),
    'OPENAI_LOCAL' => (colors.primary, .82),
    'LLAMA_CPP' => (colors.secondary, .9),
    'PPINFRA' => (colors.primaryContainer, 1.0),
    'NOVITA' => (colors.tertiary, .75),
    'OTHER' => (colors.surfaceContainerHighest, 1.0),
    _ => (colors.primary, 1.0),
  };
  return color.withValues(alpha: opacity);
}
