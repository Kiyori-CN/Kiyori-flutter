import 'package:flutter/painting.dart';

const builtinEmotions = [
  'happy',
  'sad',
  'angry',
  'surprised',
  'confused',
  'crying',
  'like_you',
  'miss_you',
  'speechless',
];

class EmojiPresentation {
  const EmojiPresentation(this.id, this.category, this.image);
  final String id, category;
  final ImageProvider image;
}

/// 打包素材的只读目录，不复制到用户目录或建立表情数据库。
class EmojiLibraryPresentation {
  const EmojiLibraryPresentation({
    this.targetName = '',
    this.categories = builtinEmotions,
    this.emojis = const [],
    this.loading = false,
  });
  final String targetName;
  final List<String> categories;
  final List<EmojiPresentation> emojis;
  final bool loading;

  static final bundled = EmojiLibraryPresentation(
    emojis: [
      for (final entry in _extensions.entries)
        for (var index = 0; index < entry.value.length; index++)
          EmojiPresentation(
            '${entry.key}_${index + 1}',
            entry.key,
            AssetImage(
              'assets/emoji/${entry.key}/${entry.key}_${index + 1}.${entry.value[index]}',
            ),
          ),
    ],
  );
  static const _extensions = {
    'happy': ['jpg', 'jpg', 'jpg', 'webp', 'webp'],
    'sad': ['jpg', 'jpg', 'jpg', 'webp', 'gif', 'gif'],
    'angry': ['jpg', 'jpg', 'jpg', 'gif', 'webp', 'gif'],
    'surprised': ['webp', 'webp', 'gif', 'jpg', 'gif'],
    'confused': ['jpg', 'jpg', 'jpg', 'webp', 'png', 'jpg', 'jpg'],
    'crying': ['jpg', 'jpg', 'jpg', 'webp', 'webp', 'png'],
    'like_you': ['jpg', 'jpg', 'jpg', 'jpg', 'webp', 'gif'],
    'miss_you': ['webp', 'webp', 'jpg', 'jpg', 'jpg', 'jpg'],
    'speechless': ['jpg', 'jpg', 'jpg', 'webp', 'jpg', 'jpg'],
  };
}
