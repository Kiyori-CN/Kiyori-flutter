import 'package:kiyori_ui/kiyori_ui.dart';

/// 原视频 PlayerModels / KiyoriPlayerSettingsPage 文案与默认选中项。
/// 选择器只返回用户选择，不触碰播放器、文件权限或设置存储。
List<SettingsOption> playerSettingsOptions(String title) => switch (title) {
  '默认视频播放器' => const [
    SettingsOption(
      'Kiyori 内置播放器',
      description: '使用 Kiyori 的 MPV 播放器，支持网页候选、队列和完整播放器控制',
      selected: true,
    ),
    SettingsOption('系统默认播放器', description: '将外部视频交给 Android 上的其他视频播放器处理'),
  ],
  '默认播放倍速' => [
    for (var quarter = 1; quarter <= 12; quarter++)
      SettingsOption(
        '${(quarter / 4).toStringAsFixed(quarter.isEven ? 1 : 2)}x',
        selected: quarter == 4,
      ),
  ],
  '队列播完后' => const [
    SettingsOption('停在结尾', description: '停留在最后一帧并保持播放器'),
    SettingsOption('关闭播放器', description: '关闭当前播放会话', selected: true),
    SettingsOption('循环当前视频', description: '从头重新播放当前视频'),
  ],
  '双击手势' => const [
    SettingsOption('暂停/播放', description: '双击屏幕任意位置暂停或继续播放', selected: true),
    SettingsOption('左退右进', description: '双击左半屏快退，双击右半屏快进'),
  ],
  '双击跳转时长' || '按钮跳转时长' => [
    for (final seconds
        in title == '双击跳转时长'
            ? [5, 10, 15, 20, 30]
            : [5, 10, 15, 20, 30, 45, 60])
      SettingsOption('${seconds}s', selected: seconds == 10),
  ],
  '默认超分模式' => const [
    SettingsOption('关', description: '原始画质，不加载 Anime4K 着色器', selected: true),
    SettingsOption('A', description: '强力重建，使用 Restore 与双阶段 Upscale'),
    SettingsOption('B', description: '柔和重建，使用 Soft Restore 与双阶段 Upscale'),
    SettingsOption('C', description: '降噪处理，使用 Denoise Upscale 与二次放大'),
    SettingsOption('A+', description: '双重强化，在二次放大前再次执行强力重建'),
    SettingsOption('B+', description: '双重柔和，在二次放大前再次执行柔和重建'),
    SettingsOption('C+', description: '降噪强化，在降噪放大后追加重建与二次放大'),
  ],
  '解码方式' => const [
    SettingsOption(
      '软件解码',
      description: '由 FFmpeg 在 CPU 上解码；兼容性基线，不启用 MediaCodec',
      selected: true,
    ),
    SettingsOption(
      'MediaCodec 直通',
      description: '直接使用 Android MediaCodec 硬件帧；适合明确验证过的设备与片源',
    ),
    SettingsOption(
      'MediaCodec Copy',
      description: '使用 MediaCodec 解码后复制为普通视频帧，兼顾硬解与渲染链兼容性',
    ),
  ],
  '渲染预设' => const [
    SettingsOption(
      'Fast',
      description: '低成本 bilinear 缩放，优先缩短首帧时间（推荐）',
      selected: true,
    ),
    SettingsOption('Default', description: 'MPV 默认渲染参数，平衡画质与性能'),
    SettingsOption('High Quality', description: '高质量渲染，使用 ewa_lanczossharp 缩放'),
    SettingsOption('Low Latency', description: '降低探测、缓存和同步延迟，适合直播或低延迟流'),
    SettingsOption('SW Fast', description: '低成本软件缩放参数；解码方式仍由“解码方式”独立决定'),
  ],
  '截图保存位置' || '视频下载位置' => [
    const SettingsOption(
      '跟随文件下载器',
      description: '当前主设置：应用下载目录',
      selected: true,
    ),
    SettingsOption(
      '使用独立目录',
      description: title == '截图保存位置'
          ? '直接将 PNG 写入所选目录，不改变文件下载器主设置'
          : '普通视频由现有内置下载器写入；M3U8 离线包按下载器规则保留在应用目录',
    ),
  ],
  '退出全屏后' => const [
    SettingsOption(
      '返回浏览器悬浮窗',
      description: '浏览器候选返回同一会话悬浮窗；本地视频关闭',
      selected: true,
    ),
    SettingsOption('关闭播放器', description: '退出全屏时关闭当前播放会话'),
  ],
  '切到后台时' => const [
    SettingsOption('暂停播放', description: '进入后台时暂停', selected: true),
    SettingsOption('继续播放', description: '进入后台后保持播放状态'),
  ],
  '在线播放缓存' => const [
    SettingsOption(
      '省流模式',
      description: '减少提前预读，适合流量受限场景；前向 64 MB / 后向 32 MB / 60s',
    ),
    SettingsOption(
      '智能均衡',
      description: '兼顾启动速度、拖动与流量；前向 128 MB / 后向 64 MB / 180s',
      selected: true,
    ),
    SettingsOption(
      '流畅优先',
      description: '扩大前后缓冲，优先弱网抗抖和长视频拖动；前向 256 MB / 后向 128 MB / 300s',
    ),
    SettingsOption(
      '完整缓存',
      description: '符合条件的 HTTP/HTTPS 直链点播会边播边缓存整个文件；占用较多内部存储，关闭播放器或切换视频后释放',
    ),
  ],
  _ => const [],
};
