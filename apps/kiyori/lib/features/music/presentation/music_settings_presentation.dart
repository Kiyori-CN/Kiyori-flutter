/// 音乐资料与操作结果的只读展示契约；不包含脚本正文，不创建播放器或文件存储。
class MusicSettingsPresentation {
  const MusicSettingsPresentation({
    this.loaded = true,
    this.writable = true,
    this.importing = false,
    this.restoringLists = false,
    this.error,
    this.sources = const MusicSourcesPresentation(),
    this.backup = const MusicBackupPresentation(),
    this.searchCount = 0,
    this.historyCount = 0,
    this.playingAudio = false,
    this.hasMedia = false,
    this.resolving = false,
    this.speed = 1,
    this.preferences = const MusicPreferencePresentation(),
    this.desktopLyrics = const MusicDesktopLyricPresentation(),
    this.committingSource = false,
  });
  final bool loaded, writable, importing, restoringLists;
  final String? error;
  final MusicSourcesPresentation sources;
  final MusicBackupPresentation backup;
  final int searchCount, historyCount;
  final bool playingAudio, hasMedia, resolving;
  final double speed;
  final bool committingSource;
  final MusicPreferencePresentation preferences;
  final MusicDesktopLyricPresentation desktopLyrics;
  bool get canEdit =>
      loaded && writable && !restoringLists && !committingSource;
  bool get editable => canEdit && !importing;
}

/// 旧偏好默认值的类型化投影，UI不保存键值或处理偏好迁移。
class MusicPreferencePresentation {
  const MusicPreferencePresentation({
    this.tags = true,
    this.alias = false,
    this.lyricFile = false,
    this.romanized = false,
    this.embedded = true,
    this.cover = true,
    this.autoMatch = true,
    this.spin = true,
    this.translation = true,
    this.seek = true,
    this.keepAwake = true,
    this.clickPlayList = false,
    this.listCover = true,
    this.listSource = true,
    this.listAlbum = true,
    this.listDuration = true,
    this.searchHistory = true,
    this.localPlatform = '网易云',
    this.downloadQuality = '高品质 · 320k',
    this.playQuality = '高品质 · 320k',
    this.fileName = '歌名 - 歌手',
    this.repeat = '顺序播放',
    this.volume = 100,
    this.lyricSize = 18,
    this.lyricOffset = 0,
    this.lyricAlign = '居中',
    this.directoryName,
    this.directoryDescription,
    this.directoryError,
  });
  final bool tags,
      alias,
      lyricFile,
      romanized,
      embedded,
      cover,
      autoMatch,
      spin,
      translation,
      seek,
      keepAwake,
      clickPlayList,
      listCover,
      listSource,
      listAlbum,
      listDuration,
      searchHistory;
  final String localPlatform,
      downloadQuality,
      playQuality,
      fileName,
      repeat,
      lyricAlign;
  final double volume, lyricSize, lyricOffset;
  final String? directoryName, directoryDescription, directoryError;
}

class MusicDesktopLyricPresentation {
  const MusicDesktopLyricPresentation({
    this.enabled = false,
    this.locked = false,
    this.bold = false,
    this.shadow = true,
    this.translation = true,
    this.size = 18,
    this.font = '无衬线',
    this.color = 0xffffffff,
    this.opacity = 100,
    this.backgroundOpacity = 40,
    this.width = 90,
    this.x = 50,
    this.y = 15,
    this.align = '居中',
    this.maxLines = 2,
  });
  final bool enabled, locked, bold, shadow, translation;
  final double size, opacity, backgroundOpacity, width, x, y;
  final String font, align;
  final int color, maxLines;
}

class MusicSourcesPresentation {
  const MusicSourcesPresentation({
    this.items = const [],
    this.activeId,
    this.working = false,
    this.error,
  });
  final List<MusicSourcePresentation> items;
  final String? activeId, error;
  final bool working;
  MusicSourcePresentation? get active =>
      items.where((s) => s.id == activeId).firstOrNull;
}

class MusicSourcePresentation {
  const MusicSourcePresentation({
    required this.id,
    required this.name,
    this.version = '',
    this.author = '',
    this.description = '',
    this.url = '',
    this.capabilities = const [],
    this.importedLabel,
    this.updatedLabel,
    this.fingerprint = '',
  });
  final String id, name, version, author, description, url, fingerprint;
  final String? importedLabel, updatedLabel;

  /// 已由领域解析并格式化的平台与音质；UI不解析/执行LX脚本。
  final List<String> capabilities;
  String get summary => [
    if (version.isNotEmpty) '版本 $version',
    if (author.isNotEmpty) author,
    url.isEmpty ? '本地脚本' : '在线脚本',
  ].join(' · ');
}

class MusicBackupPresentation {
  const MusicBackupPresentation({
    this.playlistCount = 0,
    this.canUndo = false,
    this.busy = false,
    this.exportPending = false,
    this.message,
    this.preview,
  });
  final int playlistCount;
  final bool canUndo, busy, exportPending;
  final String? message;
  final MusicBackupPreview? preview;
}

class MusicBackupPreview {
  const MusicBackupPreview({
    required this.id,
    required this.format,
    required this.trackCount,
    required this.conflicts,
    this.omittedLocalTracks = 0,
    this.lists = const [],
  });

  /// 一次解析结果的身份，取消后相同ID不重新打开，新的文件选择使用新ID。
  final String id, format;
  final int trackCount, conflicts, omittedLocalTracks;
  final List<MusicBackupListPresentation> lists;
}

class MusicBackupListPresentation {
  const MusicBackupListPresentation(this.name, this.trackCount);
  final String name;
  final int trackCount;
}
