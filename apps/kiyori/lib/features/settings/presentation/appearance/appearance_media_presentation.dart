import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// 共享资源 owner 已解码的图像。借用句柄，界面不读URI、不解码、不释放owner图像。
class AppearanceImagePresentation {
  const AppearanceImagePresentation(this.id, {this.image});
  final String id;
  final ui.Image? image;
}

class AppearanceBackgroundPresentation {
  const AppearanceBackgroundPresentation({
    this.media,
    this.enabled = false,
    this.video = false,
    this.muted = true,
    this.loop = true,
    this.opacity = .3,
    this.blur = false,
    this.blurRadius = 10,
  });
  final AppearanceImagePresentation? media;
  final bool enabled, video, muted, loop, blur;
  final double opacity, blurRadius;
  bool sameSettings(AppearanceBackgroundPresentation other) =>
      media?.id == other.media?.id &&
      enabled == other.enabled &&
      video == other.video &&
      muted == other.muted &&
      loop == other.loop &&
      opacity == other.opacity &&
      blur == other.blur &&
      blurRadius == other.blurRadius;
}

class AppearanceBubblePresentation {
  const AppearanceBubblePresentation({
    this.media,
    this.enabled = false,
    this.values = const [0, 0, 0, 0, .35, .65, .35, .65, 1, 12, 12],
  });
  final AppearanceImagePresentation? media;
  final bool enabled;
  final List<double> values;
  bool sameSettings(AppearanceBubblePresentation other) =>
      media?.id == other.media?.id &&
      enabled == other.enabled &&
      listEquals(values, other.values);
}

class AppearanceMediaPresentation {
  const AppearanceMediaPresentation({
    this.background = const AppearanceBackgroundPresentation(),
    this.userBubble = const AppearanceBubblePresentation(),
    this.aiBubble = const AppearanceBubblePresentation(),
    this.bubble = false,
    this.tiled = true,
    this.font = const AppearanceFontPresentation(),
    this.userFont = const AppearanceFontPresentation(),
    this.aiFont = const AppearanceFontPresentation(),
    this.avatars = const AppearanceAvatarPresentation(),
  });
  final AppearanceBackgroundPresentation background;
  final AppearanceBubblePresentation userBubble, aiBubble;
  final bool bubble, tiled;
  final AppearanceFontPresentation font, userFont, aiFont;
  final AppearanceAvatarPresentation avatars;
}

/// family只引用宿主已注册的字体，不在设置页加载本机字体路径。
class AppearanceFontPresentation {
  const AppearanceFontPresentation({
    this.enabled = false,
    this.file = false,
    this.systemFont = '默认字体',
    this.fileName,
    this.family,
    this.scale = 1,
  });
  final bool enabled, file;
  final String systemFont;
  final String? fileName, family;
  final double scale;
  bool sameSettings(AppearanceFontPresentation other) =>
      enabled == other.enabled &&
      file == other.file &&
      systemFont == other.systemFont &&
      fileName == other.fileName &&
      scale == other.scale;
}

class AppearanceAvatarPresentation {
  const AppearanceAvatarPresentation({
    this.user,
    this.globalUser,
    this.ai,
    this.name = '',
    this.square = false,
    this.radius = 8,
  });
  final AppearanceImagePresentation? user, globalUser, ai;
  final String name;
  final bool square;
  final int radius;
}
