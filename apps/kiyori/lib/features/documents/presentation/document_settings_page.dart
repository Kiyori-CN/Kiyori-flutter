import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// DocumentSettingsContent 在空历史、默认偏好下的展示。
/// 原说明文字照录，仅为说明，不代表此阶段已接入文档能力。
class DocumentSettingsPage extends StatelessWidget {
  const DocumentSettingsPage({super.key});

  Future<void> _choose(
    BuildContext context,
    String title,
    String current,
    List<String> labels,
  ) async {
    await showSettingsSelection(
      context,
      title: title,
      current: current,
      options: [
        for (final label in labels)
          SettingsOption(label, selected: label == current),
      ],
    );
  }

  void _information(BuildContext context, String title, String content) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '文档工作台',
    children: [
      SettingsGroup(
        title: '阅读显示',
        description: '适用于文本和电子书；办公文档保留原版排版',
        children: [
          SettingsRow(
            title: '正文字号',
            description: '调整阅读文字的大小',
            value: '18 sp',
            onTap: () => _choose(context, '正文字号', '18 sp', [
              for (var value = 14; value <= 30; value++) '$value sp',
            ]),
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '行距',
            description: '调整正文行间距离',
            value: '1.65 倍',
            onTap: () => _choose(context, '行距', '1.65 倍', [
              for (final value in [
                '1.2',
                '1.4',
                '1.5',
                '1.65',
                '1.8',
                '2',
                '2.2',
              ])
                '$value 倍',
            ]),
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '正文宽度',
            description: '宽屏限制行长，手机自动适应可用宽度',
            value: '720 dp',
            onTap: () => _choose(context, '正文宽度', '720 dp', [
              for (final value in [480, 600, 720, 840, 1000]) '$value dp',
            ]),
          ),
        ],
      ),
      SettingsGroup(
        title: '文本编辑',
        description: '适用于文字、Markdown 和代码',
        children: [
          SettingsRow(
            title: '编辑字号',
            description: '调整编辑区文字的大小',
            value: '15 sp',
            onTap: () => _choose(context, '编辑字号', '15 sp', [
              for (var value = 12; value <= 28; value++) '$value sp',
            ]),
          ),
          const SettingsDivider(),
          const SettingsRow(
            title: '自动换行',
            description: '长行在窗口边缘折行，不改变文件内容',
            checked: true,
          ),
          const SettingsDivider(),
          const SettingsRow(
            title: '显示行号',
            description: '在编辑区左侧显示行号',
            checked: true,
          ),
          const SettingsDivider(),
          const SettingsRow(
            title: '快捷符号栏',
            description: '键盘上方显示常用代码符号',
            checked: true,
          ),
        ],
      ),
      SettingsGroup(
        title: '记录与隐私',
        description: '记录保存在本机，不自动上传文档',
        children: [
          const SettingsRow(
            title: '清除最近记录',
            description: '仅清除未收藏的记录，不删除原文件',
            value: '0 项',
            enabled: false,
          ),
          const SettingsDivider(),
          SettingsRow(
            title: '草稿与保存',
            description: '查看草稿恢复和副本保存说明',
            value: '无草稿',
            onTap: () => _information(
              context,
              '草稿与保存',
              '在工作台右上角的“已打开”中继续处理文档、恢复或丢弃草稿。关闭记录只能重新读取源文件，不恢复已丢弃修改。卸载应用会移除私有记录。\n\n文本修改需主动保存为副本。办公会话不支持跨进程草稿恢复，退出前请导出需要保留的内容。',
            ),
          ),
        ],
      ),
      SettingsGroup(
        title: '使用说明',
        description: '了解支持范围与内容发送方式',
        children: [
          SettingsRow(
            title: '格式与能力',
            description: '查看预览、编辑、编码和文件大小限制',
            onTap: () => _information(
              context,
              '格式与能力',
              '办公文档\nDOCX、XLSX、PPTX 使用内置办公组件预览原版布局，当前为只读。缺少原字体时分页与换行可能变化。\n\n文本与代码\nUTF-8 文本在 1 MiB 内可编辑、64 MiB 内可阅读；保存默认生成副本。单个文件打开上限为 64 MiB。\n\nPDF 与电子书\nPDF 支持连续页面预览。Markdown 和 EPUB 提供安全阅读，不自动加载外部资源。',
            ),
          ),
          const SettingsDivider(),
          SettingsRow(
            title: 'AI 文档处理',
            description: '选择范围并确认后才发送，不自动上传',
            onTap: () => _information(
              context,
              'AI 文档处理',
              '默认发送当前章节，也可选择选区或全文。发送前会显示实际范围与内容量。\n\n使用已有的模型配置，不自动上传文档，也不把文档中的文字当作工具指令执行。',
            ),
          ),
        ],
      ),
    ],
  );
}
