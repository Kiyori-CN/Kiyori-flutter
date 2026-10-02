import 'package:flutter/material.dart';
import 'package:kiyori/features/toolbox/presentation/toolbox_settings_presentation.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

const toolboxDocument = ToolboxToolPresentation('doc', (
  '文档工作台',
  Icons.description_outlined,
  IconTone.document,
), keywords: 'PDF 阅读');
const toolboxTerminal = ToolboxToolPresentation('terminal', (
  '命令终端',
  Icons.terminal,
  IconTone.terminal,
), keywords: 'Linux Ubuntu');
const toolboxCustom = ToolboxGroupPresentation('custom:learn', '学习', [
  toolboxDocument,
]);
const toolboxOther = ToolboxGroupPresentation('DEVELOPMENT', '开发调试', [
  toolboxTerminal,
]);
const toolboxFixture = ToolboxSettingsPresentation(
  groups: [toolboxCustom, toolboxOther],
  favorites: [toolboxDocument],
  hasCustomColors: true,
);
