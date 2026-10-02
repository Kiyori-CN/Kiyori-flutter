import 'package:kiyori/features/music/presentation/music_settings_presentation.dart';

const onlineMusicSource = MusicSourcePresentation(
  id: 'online',
  name: '在线测试音源',
  version: '1.2',
  author: '测试作者',
  description: '用于本机UI验证的目录快照，不执行脚本。',
  url: 'https://example.invalid/music-source.js',
  capabilities: ['网易云 · 128k / 320k', 'QQ 音乐 · flac'],
  importedLabel: '2026/10/3 01:00',
  updatedLabel: '2026/10/3 01:30',
  fingerprint:
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
);
const localMusicSource = MusicSourcePresentation(id: 'local', name: '本地测试音源');
const musicFixture = MusicSettingsPresentation(
  sources: MusicSourcesPresentation(
    items: [onlineMusicSource, localMusicSource],
    activeId: 'online',
  ),
  backup: MusicBackupPresentation(playlistCount: 2, canUndo: true),
  searchCount: 3,
  historyCount: 7,
);
const musicBackupPreview = MusicBackupPreview(
  id: 'preview-1',
  format: 'LX JSON',
  trackCount: 30,
  conflicts: 1,
  omittedLocalTracks: 2,
  lists: [
    MusicBackupListPresentation('我的收藏', 20),
    MusicBackupListPresentation('夜间列表', 10),
  ],
);
