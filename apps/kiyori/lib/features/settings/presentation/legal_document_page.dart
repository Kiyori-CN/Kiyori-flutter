import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'legal_document.dart';

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    required this.document,
    this.onboarding = false,
    this.onBack,
    super.key,
  });
  final bool onboarding;
  final VoidCallback? onBack;
  final LegalDocument document;
  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  bool showContents = false;
  late final sections = List.generate(
    widget.document.sections.length,
    (_) => GlobalKey(),
  );

  @override
  Widget build(BuildContext context) => widget.onboarding
      ? _onboarding(context)
      : SettingsDetailPage(
          title: widget.document.title,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.document.summary,
                    style: TextStyle(
                      fontSize: 14,
                      height: 21 / 14,
                      color: PrimaryColors.of(context).secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '当前协议版本：${LegalDocument.version}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SettingsGroup(
              title: '完整正文',
              description: '当前完整中文正文，可通过目录定位章节，也可长按选择复制。',
              children: [_body(context)],
            ),
          ],
        );

  Widget _body(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => setState(() => showContents = !showContents),
          child: Text(
            showContents ? '收起目录' : '浏览目录 · ${sections.length - 1} 个章节',
          ),
        ),
        if (showContents)
          Wrap(
            spacing: 8,
            children: [
              for (var index = 1; index < sections.length; index++)
                ActionChip(
                  label: Text(
                    widget.document.sections[index].title,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => Scrollable.ensureVisible(
                    sections[index].currentContext!,
                    alignment: .2,
                    duration: const Duration(milliseconds: 250),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < sections.length; index++) ...[
                if (index > 0) const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      key: sections[index],
                      header: true,
                      child: Text(
                        widget.document.sections[index].title,
                        style: TextStyle(
                          fontSize: index == 0 ? 22 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.document.sections[index].body,
                      style: TextStyle(
                        fontSize: 14,
                        height: 26 / 14,
                        color: PrimaryColors.of(context).secondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      color: Theme.of(context).colorScheme.outlineVariant
                          .withValues(alpha: .45),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '以上为当前完整中文正文 · 版本 ${LegalDocument.version}',
          style: TextStyle(
            fontSize: 12,
            color: PrimaryColors.of(context).secondary,
          ),
        ),
      ],
    ),
  );

  Widget _onboarding(BuildContext context) => ColoredBox(
    color: PrimaryColors.of(context).background,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.document.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '协议版本：${LegalDocument.version}',
                        style: TextStyle(
                          fontSize: 11,
                          color: PrimaryColors.of(context).secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 长产品名和大字号会增加页头高度。说明与正文共用滚动区，
          // 保留完整内容和字体比例，避免固定说明挤出正文。
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.document.summary,
                          style: TextStyle(
                            fontSize: 14,
                            height: 20 / 14,
                            color: PrimaryColors.of(context).secondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '完整正文',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '展开目录可定位章节；正文支持滚动与长按复制。',
                          style: TextStyle(
                            fontSize: 12,
                            height: 18 / 12,
                            color: PrimaryColors.of(context).secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  _body(context),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
