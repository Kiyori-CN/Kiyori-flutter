import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

Future<void> showFileOpenDefaults(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _OpenDefaults());

class _OpenDefaults extends StatefulWidget {
  const _OpenDefaults();
  @override
  State<_OpenDefaults> createState() => _OpenDefaultsState();
}

class _OpenDefaultsState extends State<_OpenDefaults> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('按格式设置打开方式'),
    content: SizedBox(
      width: 312,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '应用于文件管理、下载和系统交给 Kiyori 的文件。不会改变 Android 对其他应用的默认设置。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextField(
              controller: controller,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: '文件扩展名，例如 mp3',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (!newValue.composing.isCollapsed) return newValue;
                  var text = newValue.text
                      .trim()
                      .replaceFirst(RegExp(r'^\.'), '')
                      .toLowerCase();
                  if (text.length > 20) text = text.substring(0, 20);
                  return TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                  );
                }),
              ],
            ),
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, value, _) => Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed:
                      RegExp(r'^[a-z0-9][a-z0-9_+-]{0,19}$')
                          .hasMatch(value.text)
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) => _FormatChoice(extension: value.text),
                        )
                      : null,
                  child: const Text('设置此格式'),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('尚未自定义：音频用音乐播放器，视频用视频播放器。'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('完成'),
      ),
    ],
  );
}

enum _OpenChoice {
  music('内置音乐播放器', '播放音频，显示封面与歌词', Icons.music_note),
  video('内置视频播放器', '播放视频，支持字幕与画面控制', Icons.movie),
  image('图片查看器', '预览、缩放图片', Icons.image),
  document('文档工作台', '阅读 PDF、EPUB 和 Office 文档', Icons.description),
  text('文本编辑器', '查看和编辑文本、代码', Icons.code),
  browser('内置浏览器', '打开网页文件', Icons.language),
  system('其他应用', '选择手机中支持此文件的应用', Icons.open_in_new),
  choose('每次询问', '每次打开时选择', Icons.open_in_new);

  const _OpenChoice(this.label, this.description, this.icon);
  final String label, description;
  final IconData icon;
}

/// 只计算选择弹窗的默认展示，不用于判断内容、权限或实际打开文件。
_OpenChoice _recommended(String extension) {
  for (final entry in const [
    (
      _OpenChoice.music,
      'mp3 wav ogg oga flac m4a aac opus wma ape aiff aif alac amr m4b ac3 dts dsf dff mid midi',
    ),
    (
      _OpenChoice.video,
      'mp4 avi mkv mov webm m4v 3gp 3g2 mpeg mpg m2ts mts flv wmv vob rm rmvb m3u8 mpd',
    ),
    (_OpenChoice.browser, 'html htm xhtml'),
    (_OpenChoice.document, 'epub pdf docx xlsx pptx'),
    (
      _OpenChoice.text,
      'ts csv tsv markdown sql properties gradle go dart h hpp mjs cjs lrc srt ass vtt js jsx tsx py kt kts java json xml css sh yml yaml toml c cpp rs txt md log ini conf',
    ),
    (_OpenChoice.image, 'jpg jpeg png gif bmp webp heic heif avif svg'),
  ]) {
    if (entry.$2.split(' ').contains(extension)) return entry.$1;
  }
  return _OpenChoice.choose;
}

class _FormatChoice extends StatefulWidget {
  const _FormatChoice({required this.extension});
  final String extension;
  @override
  State<_FormatChoice> createState() => _FormatChoiceState();
}

class _FormatChoiceState extends State<_FormatChoice> {
  late final recommended = _recommended(widget.extension);
  late _OpenChoice? selected = recommended == _OpenChoice.choose
      ? null
      : recommended;
  late final choices = [
    recommended,
    ..._OpenChoice.values.where((choice) => choice != recommended),
  ];
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('默认打开方式'),
    content: SizedBox(
      width: 312,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '文件.${widget.extension}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                '.${widget.extension} 文件',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: PrimaryColors.secondary),
              ),
            ),
            for (final choice in choices)
              Semantics(
                selected: selected == choice,
                inMutuallyExclusiveGroup: true,
                child: Material(
                  color: selected == choice
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(() => selected = choice),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(choice.icon, size: 24),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    choice.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge,
                                  ),
                                  Text(
                                    choice == recommended
                                        ? '推荐 · ${choice.description}'
                                        : choice.description,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: PrimaryColors.secondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ExcludeSemantics(
                            child: Icon(
                              selected == choice
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selected == choice
                                  ? PrimaryColors.accent
                                  : PrimaryColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: selected == null ? null : emptyAction,
        child: const Text('保存'),
      ),
    ],
  );
}
