import 'package:flutter/material.dart';

enum WakeRecognitionMode {
  stt('STT（识别文本）'),
  personal('个人化模板（录三遍）');

  const WakeRecognitionMode(this.label);
  final String label;
}

enum WakeAttachmentType {
  screen('屏幕', '截图 + OCR', '屏幕关键词', Icons.screenshot_monitor),
  notifications('通知', '附加当前通知', '通知关键词', Icons.notifications),
  location('位置', '附加当前定位', '位置关键词', Icons.location_on),
  time('时间', '附加当前时间', '时间关键词', Icons.schedule);

  const WakeAttachmentType(
    this.title,
    this.description,
    this.keywordLabel,
    this.icon,
  );
  final String title, description, keywordLabel;
  final IconData icon;
}

class WakeAttachmentPresentation {
  const WakeAttachmentPresentation({
    required this.id,
    required this.type,
    this.enabled = true,
    this.keywords = '',
  });
  final String id, keywords;
  final WakeAttachmentType type;
  final bool enabled;
}

class WakeEnrollmentPresentation {
  const WakeEnrollmentPresentation({
    this.recordingStep = 0,
    this.completedSteps = const {},
    this.error,
  });
  final int recordingStep;
  final Set<int> completedSteps;
  final String? error;
}

/// 唤醒权限、模板和后台状态是快照事实，编辑不能启动监听或伪造录音完成。
class WakeupPresentation {
  const WakeupPresentation({
    this.mode = WakeRecognitionMode.stt,
    this.listening = false,
    this.phrase = '小欧',
    this.regex = false,
    this.timeout = 5,
    this.greeting = true,
    this.greetingText = '我在',
    this.createChat = false,
    this.group = '全局助手',
    this.attach = true,
    this.templateCount = 0,
    this.enrollment = const WakeEnrollmentPresentation(),
    this.attachments = const [
      WakeAttachmentPresentation(
        id: 'screen_ocr',
        type: WakeAttachmentType.screen,
        keywords: '屏幕',
      ),
      WakeAttachmentPresentation(
        id: 'notifications',
        type: WakeAttachmentType.notifications,
        keywords: '通知',
      ),
      WakeAttachmentPresentation(
        id: 'location',
        type: WakeAttachmentType.location,
        keywords: '哪个地方',
      ),
      WakeAttachmentPresentation(
        id: 'time',
        type: WakeAttachmentType.time,
        keywords: '时间|几点',
      ),
    ],
  });
  final WakeRecognitionMode mode;
  final bool listening, regex, greeting, createChat, attach;
  final String phrase, greetingText, group;
  final int timeout, templateCount;
  final WakeEnrollmentPresentation enrollment;
  final List<WakeAttachmentPresentation> attachments;
}
