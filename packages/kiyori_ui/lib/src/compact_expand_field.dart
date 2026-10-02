import 'package:flutter/material.dart';

/// 旧 CompactTextFieldWithExpand 的共享投影；控制器与展开后的草稿归调用方。
class CompactExpandField extends StatelessWidget {
  const CompactExpandField({
    required this.controller,
    required this.onExpand,
    required this.expandLabel,
    this.fieldKey,
    this.expandKey,
    this.label,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onExpand;
  final String expandLabel;
  final Key? fieldKey, expandKey;
  final String? label, hint;
  final int minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Stack(
    // 浮动标签绘制在输入盒上方；不能用定高或 Stack 默认裁切压缩输入。
    clipBehavior: Clip.none,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 32),
        child: TextField(
          key: fieldKey,
          controller: controller,
          style: const TextStyle(fontSize: 12),
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 11),
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ),
      Positioned(
        right: 2,
        top: 2,
        child: IconButton(
          key: expandKey,
          tooltip: expandLabel,
          onPressed: onExpand,
          iconSize: 14,
          color: Theme.of(context).colorScheme.primary,
          icon: const Icon(Icons.open_in_full),
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
      ),
    ],
  );
}
