import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 能力标题和用途来自 KiyoriPermissionPresentation / values/strings.xml。
/// 不读取系统状态；未知值必须保持未知，不能由 UI 推断已授权。
enum PermissionAction {
  authorize,
  settings,
  manage,
  accessibility,
  shizuku,
  root,
  none,
}

enum PermissionStatus {
  unchecked,
  granted,
  partial,
  notGranted,
  setup,
  notApplicable,
  onDemand,
}

extension PermissionStatusPresentation on PermissionStatus {
  Color foreground(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return switch (this) {
      PermissionStatus.granted => Color(dark ? 0xFF67D7A5 : 0xFF16734F),
      PermissionStatus.partial => Color(dark ? 0xFFFFB76A : 0xFFA85A12),
      PermissionStatus.setup => Color(dark ? 0xFF8CB5FF : 0xFF2B5FAF),
      PermissionStatus.onDemand => Color(dark ? 0xFF65D3E8 : 0xFF17768B),
      PermissionStatus.unchecked => PrimaryColors.of(context).secondary,
      _ => PrimaryColors.of(context).accent,
    };
  }

  String get label => switch (this) {
    PermissionStatus.unchecked => '未检查',
    PermissionStatus.granted => '已授权',
    PermissionStatus.partial => '部分授权',
    PermissionStatus.notGranted => '未开启',
    PermissionStatus.setup => '需要配置',
    PermissionStatus.notApplicable => '本机无需',
    PermissionStatus.onDemand => '使用时确认',
  };

  // 未接平台时仍可选择预览草稿；不能将此值解释为待授权系统事实。
  bool get previewSelectable =>
      this != PermissionStatus.granted &&
      this != PermissionStatus.notApplicable &&
      this != PermissionStatus.onDemand;
}

class PermissionEntry {
  const PermissionEntry(
    this.id,
    this.title,
    this.description,
    this.icon,
    this.tone,
    this.action,
  );
  final String id, title, description;
  final IconData icon;
  final IconTone tone;
  final PermissionAction action;
}

const permissionEntries = <PermissionEntry>[
  PermissionEntry(
    "notifications",
    "通知",
    "显示 AI 回复、下载、后台任务和服务状态。",
    Icons.notifications,
    IconTone.warning,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "media",
    "视频与音频",
    "读取设备视频与音频供播放或处理；Android 14 可只允许选定视频。照片和其他文件通过系统文件选择器按次选择。",
    Icons.photo_library,
    IconTone.image,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "legacy_storage",
    "旧版外部存储",
    "Android 12 及以下读取公共存储；Android 9 及以下写入公共存储所需的兼容权限。",
    Icons.folder,
    IconTone.folder,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "camera",
    "相机",
    "拍摄附件、网页媒体和视觉输入。",
    Icons.camera_alt,
    IconTone.image,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "microphone",
    "麦克风",
    "语音输入、语音助手、录音和网页音频采集。",
    Icons.mic,
    IconTone.audio,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "location",
    "位置",
    "天气、定位工具与允许的站点。可按系统选项提供粗略位置；需要精确定位的功能会受限。",
    Icons.location_on,
    IconTone.neutral,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "bluetooth",
    "附近设备与蓝牙",
    "扫描并连接你主动使用的蓝牙设备。",
    Icons.bluetooth,
    IconTone.network,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "all_files",
    "所有文件访问",
    "跨目录管理共享存储文件，可能读取、修改或删除内容；不自动获得其他应用私有目录的访问权。",
    Icons.folder_special,
    IconTone.folder,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "install",
    "安装未知来源应用",
    "安装你选择的 APK、内置 Shizuku 或 Kiyori Flutter 无障碍支持。",
    Icons.install_mobile,
    IconTone.neutral,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "battery",
    "忽略电池优化",
    "帮助长任务、下载和语音服务持续运行，可能增加耗电；仍受系统后台限制。",
    Icons.battery_charging_full,
    IconTone.neutral,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "overlay",
    "悬浮窗",
    "在其他应用上方显示语音助手、调试器和悬浮能力。",
    Icons.layers,
    IconTone.neutral,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "assistant",
    "系统默认助手",
    "通过系统助手手势或入口快速唤起 Kiyori Flutter。",
    Icons.smart_toy,
    IconTone.ai,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "write_settings",
    "修改系统设置",
    "允许经你确认的工具修改亮度、旋转等系统设置。",
    Icons.settings_applications,
    IconTone.tools,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "usage",
    "使用情况访问",
    "识别前台应用和使用状态，为自动化提供上下文。",
    Icons.visibility,
    IconTone.neutral,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "installed_apps",
    "读取已安装应用列表",
    "读取设备上已安装应用，用于应用选择、自动化和跨应用工具；Android 由应用可见性策略管理。",
    Icons.apps,
    IconTone.tools,
    PermissionAction.manage,
  ),
  PermissionEntry(
    "phone",
    "拨打电话",
    "工具可直接拨号，可能产生通信费用。不使用拨号自动化时无需开启。",
    Icons.phone,
    IconTone.neutral,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "sms",
    "短信",
    "工具可发送、读取和接收短信，可能涉及验证码、他人信息与通信费用。仅在需要短信自动化时开启。",
    Icons.perm_phone_msg,
    IconTone.reading,
    PermissionAction.authorize,
  ),
  PermissionEntry(
    "notification_listener",
    "通知读取",
    "读取其他应用通知，可能包含消息与验证码。仅在使用通知工具或自动化时开启。",
    Icons.notifications_active,
    IconTone.warning,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "restricted_settings",
    "受限设置帮助",
    "仅在 Android 拦截通知访问等能力时，到该应用的信息页检查“允许受限设置”。无障碍支持组件需在其自己的应用信息页处理。",
    Icons.lock_open,
    IconTone.security,
    PermissionAction.settings,
  ),
  PermissionEntry(
    "accessibility",
    "无障碍 UI 自动化",
    "安装并启用 Kiyori Flutter 无障碍支持，可读取界面、点击、输入及执行手势。仅向可信任务提供此能力。",
    Icons.accessibility_new,
    IconTone.security,
    PermissionAction.accessibility,
  ),
  PermissionEntry(
    "shizuku",
    "Shizuku / ADB",
    "使用由你启动并授权的 Shizuku 服务执行 ADB 级系统操作。",
    Icons.android,
    IconTone.success,
    PermissionAction.shizuku,
  ),
  PermissionEntry(
    "root",
    "Root",
    "请求超级用户访问，可读取和修改受保护的系统与应用数据。",
    Icons.shield,
    IconTone.security,
    PermissionAction.root,
  ),
  PermissionEntry(
    "screen_capture",
    "屏幕捕获",
    "截屏、录屏和视觉分析时，由 Android 针对本次操作确认。",
    Icons.widgets,
    IconTone.network,
    PermissionAction.none,
  ),
];

const permissionGroups = [
  ('日常使用', '通知、影音与输入 · 只开启你会用到的功能', 0, 7),
  ('文件与后台', '跨目录管理、安装与长任务 · 由系统单独确认', 7, 10),
  ('设备协作', '悬浮助手与设备工具 · 普通浏览无需开启', 10, 15),
  ('通信与通知内容', '涉及他人信息、验证码或通信费用 · 请逐项确认用途', 15, 18),
  ('高级自动化', '可操作其他应用或受保护数据 · 仅在理解影响后启用', 18, 23),
];
