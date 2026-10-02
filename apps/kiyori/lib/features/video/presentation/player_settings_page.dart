import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import 'player_settings_options.dart';
import 'player_experience_page.dart';

/// 原视频播放器设置的默认展示；业务设置写入保持空操作。
class PlayerSettingsPage extends StatelessWidget {
  const PlayerSettingsPage({required this.onOpenDetail, super.key});
  final ValueChanged<PlayerExperienceSection> onOpenDetail;
  static const toggles = <String, bool>{
    '记忆播放倍速': false,
    '自动播放下一集': true,
    '长按加速': false,
    '精确进度定位': false,
    '显示章节进度条': true,
    '进度条缩略图预览': false,
    '记忆超分模式': false,
    'GPU Next 渲染': false,
    'Vulkan 渲染上下文': false,
    '跟随重力自动旋转': false,
  };

  static const rootGroups =
      <
        ({
          String title,
          String description,
          List<
            ({
              String title,
              String description,
              String? value,
              bool toggle,
              bool enabled,
            })
          >
          rows,
        })
      >[
        (
          title: '播放与连播',
          description: '控制新视频的播放速度，以及真实播放队列到达结尾后的行为',
          rows: [
            (
              title: '默认视频播放器',
              description: '选择打开外部视频文件时使用 Kiyori 内置播放器或系统默认播放器',
              value: 'Kiyori 内置播放器',
              toggle: false,
              enabled: true,
            ),
            (
              title: '默认播放倍速',
              description: '未开启倍速记忆时，新视频从此倍速开始',
              value: '1.0x',
              toggle: false,
              enabled: true,
            ),
            (
              title: '记忆播放倍速',
              description: '保存播放器中最后一次实际选择的倍速',
              value: null,
              toggle: true,
              enabled: true,
            ),
            (
              title: '自动播放下一集',
              description: '当前视频自然结束后播放队列中的下一项',
              value: null,
              toggle: true,
              enabled: true,
            ),
            (
              title: '队列播完后',
              description: '最后一项播放结束时停留、关闭播放器或循环当前项',
              value: '关闭播放器',
              toggle: false,
              enabled: true,
            ),
          ],
        ),
        (
          title: '手势与进度',
          description: '调整双击、跳转精度、章节信息和拖动预览',
          rows: [
            (
              title: '双击手势',
              description: '双击任意位置暂停/播放，或按左右半屏快退/快进',
              value: '暂停/播放',
              toggle: false,
              enabled: true,
            ),
            (
              title: '双击跳转时长',
              description: '仅在左右双击快退/快进模式下使用',
              value: '10s',
              toggle: false,
              enabled: false,
            ),
            (
              title: '长按加速',
              description: '按当前速度分段临时提升到 1x、2x 或 3x，松手恢复按下前速度',
              value: null,
              toggle: true,
              enabled: true,
            ),
            (
              title: '按钮跳转时长',
              description: '播放器快退和快进按钮每次跳转的秒数',
              value: '10s',
              toggle: false,
              enabled: true,
            ),
            (
              title: '精确进度定位',
              description: '定位到更准确的画面；在线流和长视频可能需要更多解码时间',
              value: null,
              toggle: true,
              enabled: true,
            ),
            (
              title: '显示章节进度条',
              description: '在进度条绘制章节节点，并显示当前章节名称',
              value: null,
              toggle: true,
              enabled: true,
            ),
            (
              title: '进度条缩略图预览',
              description: '本地视频直接提取；完整缓存完成的在线直链从同一 MPV 缓存快速提取',
              value: null,
              toggle: true,
              enabled: true,
            ),
          ],
        ),
        (
          title: '画面与超分',
          description: 'Anime4K 可实时切换；渲染内核选项在下次创建播放器时完整生效',
          rows: [
            (
              title: '记忆超分模式',
              description: '新视频自动使用设定的 Anime4K 默认模式',
              value: null,
              toggle: true,
              enabled: true,
            ),
            (
              title: '默认超分模式',
              description: '选择关、A、B、C、A+、B+ 或 C+ Anime4K 着色器组合',
              value: '关',
              toggle: false,
              enabled: false,
            ),
            (
              title: '解码方式',
              description: '明确选择软件解码、MediaCodec 直通或 MediaCodec Copy；不会自动切换',
              value: '软件解码',
              toggle: false,
              enabled: true,
            ),
            (
              title: '渲染预设',
              description: '只切换 MPV 缩放、画质或低延迟 profile，不改变解码方式',
              value: 'Fast',
              toggle: false,
              enabled: true,
            ),
            (
              title: 'GPU Next 渲染',
              description: '下次创建播放器内核时使用 gpu-next 视频输出',
              value: null,
              toggle: true,
              enabled: true,
            ),
            (
              title: 'Vulkan 渲染上下文',
              description: '下次创建播放器内核时使用 Android Vulkan context',
              value: null,
              toggle: true,
              enabled: true,
            ),
          ],
        ),
        (
          title: '保存与下载',
          description: '默认跟随文件下载器，也可以为播放器分别指定独立目录',
          rows: [
            (
              title: '截图保存位置',
              description: '保存右侧截图按钮生成的 PNG 图片',
              value: '跟随文件下载器',
              toggle: false,
              enabled: true,
            ),
            (
              title: '视频下载位置',
              description: '保存右侧下载按钮获取的在线视频',
              value: '跟随文件下载器',
              toggle: false,
              enabled: true,
            ),
          ],
        ),
        (
          title: '窗口与在线',
          description: '协调屏幕方向、全屏退出、后台播放和在线播放缓存',
          rows: [
            (
              title: '跟随重力自动旋转',
              description: '根据设备方向自动切换横屏或竖屏；开启后停用手动旋转按钮',
              value: null,
              toggle: true,
              enabled: true,
            ),
            (
              title: '退出全屏后',
              description: '浏览器视频可返回同一会话悬浮窗，本地视频会关闭',
              value: '返回浏览器悬浮窗',
              toggle: false,
              enabled: true,
            ),
            (
              title: '切到后台时',
              description: '决定全屏播放器进入后台时暂停还是继续播放',
              value: '暂停播放',
              toggle: false,
              enabled: true,
            ),
            (
              title: '在线播放缓存',
              description: '选择省流、均衡、流畅优先或完整缓存策略；新视频生效',
              value: '智能均衡',
              toggle: false,
              enabled: true,
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) => SettingsDetailPage(
    title: '视频播放器',
    children: [
      SettingsGroup(
        title: '播放体验',
        description: '与播放面板实时同步的显示与声音偏好',
        children: [
          _nav(PlayerExperienceSection.subtitle, '大小、位置、颜色、样式覆盖与语言优先'),
          const SettingsDivider(),
          _nav(PlayerExperienceSection.audio, '输出声道、响度均衡与音量增强'),
          const SettingsDivider(),
          _nav(PlayerExperienceSection.danmaku, '显示区域、类型、去重与屏蔽词'),
          const SettingsDivider(),
          _nav(PlayerExperienceSection.controls, '状态信息、控制栏隐藏与片头片尾'),
        ],
      ),
      for (final group in rootGroups)
        SettingsGroup(
          title: group.title,
          description: group.description,
          children: [
            for (var i = 0; i < group.rows.length; i++) ...[
              if (i > 0) const SettingsDivider(),
              _row(context, group.rows[i]),
            ],
          ],
        ),
    ],
  );

  Widget _nav(PlayerExperienceSection target, String description) =>
      SettingsRow(
        title: target.title,
        description: description,
        onTap: () => onOpenDetail(target),
      );

  Widget _row(
    BuildContext context,
    ({
      String title,
      String description,
      String? value,
      bool toggle,
      bool enabled,
    })
    row,
  ) => SettingsRow(
    title: row.title,
    description: row.description,
    value: row.toggle ? null : row.value,
    checked: row.toggle ? (toggles[row.title] ?? false) : null,
    enabled: row.enabled,
    onTap: () async {
      if (!row.toggle) {
        await showSettingsSelection(
          context,
          title: row.title,
          current: row.value!,
          options: playerSettingsOptions(row.title),
        );
      }
    },
  );
}
