part of 'onboarding_page.dart';

class _IntroData {
  const _IntroData(
    this.eyebrow,
    this.title,
    this.lede,
    this.note,
    this.cta,
    this.cards,
    this.map,
  );
  final String eyebrow, title, lede, note, cta, map;
  final List<_CardData> cards;
}

class _CardData {
  const _CardData(this.icon, this.tone, this.title, this.lines, {this.badge});
  final IconData icon;
  final IconTone tone;
  final String title, lines;
  final String? badge;
}

const _nav = ['认识 Kiyori', '浏览与媒体', 'AI 协作', '工具与个性化', '协议与隐私', '按需开启权限'];
const _intro = <_IntroData>[
  _IntroData(
    'Kiyori',
    '浏览、协作与创作，从这里开始',
    '用底栏打开浏览器、工具箱与文件管理。在软件首页向左滑，或点击 AI 入口，即可进入右侧的 AI 首页。',
    '向左滑查看下一页，向右滑返回；内容较长时可上下滚动。以后可在「设置 → 更多功能 → 重新查看首次引导」重看。',
    '看看能做什么',
    [
      _CardData(
        Icons.language,
        IconTone.browser,
        '网页浏览器',
        '多窗口搜索与阅读\n底栏第 2 个入口',
      ),
      _CardData(Icons.auto_awesome, IconTone.ai, 'AI 助手', '提问、总结与执行\n首页向左滑进入'),
      _CardData(Icons.apps, IconTone.tools, '工具箱', '音乐、终端与实用工具\n底栏第 3 个入口'),
      _CardData(
        Icons.folder_outlined,
        IconTone.folder,
        '文件管理器',
        '搜索、整理与打开文件\n底栏第 4 个入口',
      ),
    ],
    '底栏五个入口，首页左右滑动切换',
  ),
  _IntroData(
    '内容工作台',
    '发现值得留下的内容',
    '搜索网页、切换窗口，把有用的内容加入书签或下载。网页发现的视频可交给播放器；在工具箱打开音乐，继续收听本地或在线歌曲。',
    '在线音乐的播放与下载取决于音源能力和服务访问条件，可在音乐设置中管理音源。',
    '了解 AI 协作',
    [
      _CardData(
        Icons.shield_outlined,
        IconTone.security,
        '广告拦截',
        '订阅过滤规则\n减少页面干扰',
      ),
      _CardData(
        Icons.download_outlined,
        IconTone.download,
        '文件下载器',
        '管理下载任务\n查看进度与失败原因',
      ),
      _CardData(
        Icons.play_circle_outline,
        IconTone.video,
        '视频播放器',
        '本地与在线视频\n字幕、倍速与悬浮窗',
      ),
      _CardData(
        Icons.audiotrack_outlined,
        IconTone.audio,
        '音乐播放器',
        '本地与在线音乐\n歌词、列表与后台播放',
      ),
    ],
    '浏览器发现内容 · 工具箱打开音乐',
  ),
  _IntroData(
    '你的 AI 助手',
    '从一个问题，到下一步行动',
    '先在「设置 → AI 助手 → 模型与 API」配置可用模型，再结合网页、附件与工作区提问。助手可调用工具执行任务，你可以查看过程并核验结果。',
    '模型能力与服务配置决定可用功能；设备权限和 AI 工具授权分别管理。普通网页浏览无需配置模型。',
    '了解工具与个性化',
    [
      _CardData(
        Icons.tune,
        IconTone.ai,
        '模型配置',
        '配置模型与服务地址\n按服务要求填写密钥',
        badge: '需先配置',
      ),
      _CardData(
        Icons.mic_none,
        IconTone.audio,
        '语音服务',
        '用语音提问\n听回答被朗读',
        badge: '需先配置',
      ),
      _CardData(
        Icons.memory,
        IconTone.memory,
        '记忆与知识',
        '整理记忆、日记与资料\n检索上下文与关联内容',
      ),
      _CardData(
        Icons.business_center_outlined,
        IconTone.tools,
        'AI 工具调用',
        '查看可用工具\n按授权执行操作',
      ),
    ],
    'AI 首页位于软件首页右侧，向左滑进入',
  ),
  _IntroData(
    '属于你的工作台',
    '按需打开，不必一次配齐',
    '在工具箱打开命令终端，在 AI 菜单创建工作流，把重复步骤组织起来。界面定制和数据备份位于设置中，可以按自己的习惯逐项准备。',
    '文件管理可打开文本、电子书、PDF 与 Office 文档；工具箱提供日志查看，设置首页可管理服务账号。',
    '查看协议与隐私',
    [
      _CardData(
        Icons.terminal,
        IconTone.terminal,
        '终端',
        '准备 Ubuntu 环境\n执行命令与脚本',
        badge: '需先配置',
      ),
      _CardData(
        Icons.account_tree_outlined,
        IconTone.automation,
        '工作流',
        '编排重复步骤\n按需重复执行',
      ),
      _CardData(
        Icons.palette_outlined,
        IconTone.appearance,
        '界面定制',
        '主题、字号与布局\n调整首页与底栏',
      ),
      _CardData(
        Icons.backup_outlined,
        IconTone.backup,
        '数据备份',
        '导出与恢复应用数据\n支持导入兼容备份',
      ),
    ],
    '工具箱 · AI 菜单 · 设置',
  ),
];

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.data,
    required this.page,
    required this.onNext,
  });
  final _IntroData data;
  final int page;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
      final showMap =
          constraints.maxWidth - 40 >= 300 &&
          constraints.maxHeight >= 440 &&
          scale < 1.3;
      final twoColumns = constraints.maxWidth - 40 >= 720 && scale < 1.3;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showMap) ...[
            _Map(label: data.map, page: page),
            const SizedBox(height: 16),
          ],
          _Eyebrow(data.eyebrow),
          const SizedBox(height: 8),
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 24,
              height: 32 / 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.lede,
            style: TextStyle(
              fontSize: 13.5,
              height: 21 / 13.5,
              color: PrimaryColors.of(context).secondary,
            ),
          ),
        ],
      );
      final cards = Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            // 与旧 IntrinsicSize.Min 同义：每行取真实文字高度，保持 2×2。
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _FeatureCard(data.cards[row * 2])),
                  const SizedBox(width: 10),
                  Expanded(child: _FeatureCard(data.cards[row * 2 + 1])),
                ],
              ),
            ),
          ],
        ],
      );
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: PageStorageKey('onboarding-intro-$page'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (twoColumns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 24),
                        Expanded(child: cards),
                      ],
                    )
                  else ...[
                    title,
                    const SizedBox(height: 14),
                    cards,
                  ],
                  const SizedBox(height: 11),
                  Text(
                    data.note,
                    style: TextStyle(
                      fontSize: 12,
                      height: 18 / 12,
                      color: PrimaryColors.of(context).secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomAction(label: data.cta, onPressed: onNext),
        ],
      );
    },
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard(this.card);
  final _CardData card;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 122),
    decoration: BoxDecoration(
      color: PrimaryColors.of(context).card,
      border: Border.all(color: PrimaryColors.of(context).divider),
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 2)],
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: card.tone.containerFor(context),
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: card.title == 'AI 助手'
              ? AiSparkleIcon(color: card.tone.iconFor(context), size: 20)
              : Icon(card.icon, color: card.tone.iconFor(context), size: 20),
        ),
        const SizedBox(height: 9),
        Text(
          card.title,
          style: const TextStyle(
            fontSize: 15,
            height: 20 / 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (card.badge != null)
          Container(
            margin: const EdgeInsets.only(top: 5),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              card.badge!,
              style: TextStyle(
                fontSize: 10,
                height: 14 / 10,
                color: PrimaryColors.of(context).accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 5),
        Text(
          card.lines.split('\n').first,
          style: TextStyle(
            fontSize: 12,
            height: 17 / 12,
            color: PrimaryColors.of(context).secondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          card.lines.split('\n').last,
          style: TextStyle(
            fontSize: 12,
            height: 17 / 12,
            color: PrimaryColors.of(context).secondary,
          ),
        ),
      ],
    ),
  );
}

class _Map extends StatelessWidget {
  const _Map({required this.label, required this.page});
  final String label;
  final int page;
  @override
  Widget build(BuildContext context) => Container(
    height: 104,
    width: double.infinity,
    decoration: BoxDecoration(
      color: PrimaryColors.of(context).card,
      border: Border.all(color: PrimaryColors.of(context).divider),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MapPanel(Icons.download_outlined, page <= 1),
            const SizedBox(width: 7),
            _MapPanel(Icons.home_outlined, page == 0, large: true),
            const SizedBox(width: 7),
            _MapPanel(Icons.auto_awesome, page == 0 || page >= 2),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          width: 104,
          height: 15,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: PrimaryColors.of(context).divider),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i == 4 ? 0 : 3),
                    decoration: BoxDecoration(
                      color:
                          (page == 0 ||
                              (page == 1 && (i == 1 || i == 2)) ||
                              (page == 3 && i >= 2))
                          ? PrimaryColors.of(context).accent
                          : PrimaryColors.of(context).divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            height: 12 / 9.5,
            color: PrimaryColors.of(context).secondary,
          ),
        ),
      ],
    ),
  );
}

class _MapPanel extends StatelessWidget {
  const _MapPanel(this.icon, this.active, {this.large = false});
  final IconData icon;
  final bool active, large;
  @override
  Widget build(BuildContext context) => Container(
    width: large ? 104 : 74,
    height: large ? 56 : 50,
    decoration: BoxDecoration(
      color: active
          ? Theme.of(context).colorScheme.primaryContainer
          : PrimaryColors.of(context).card,
      borderRadius: BorderRadius.circular(9),
    ),
    child: CustomPaint(
      foregroundPainter: _PanelOutline(active, PrimaryColors.of(context)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon == Icons.auto_awesome)
            AiSparkleIcon(
              size: 16,
              color: active
                  ? PrimaryColors.of(context).accent
                  : PrimaryColors.of(context).secondary,
            )
          else
            Icon(
              icon,
              size: 16,
              color: active
                  ? PrimaryColors.of(context).accent
                  : PrimaryColors.of(context).secondary,
            ),
          const SizedBox(height: 4),
          Text(
            large ? '软件首页' : (icon == Icons.auto_awesome ? 'AI 助手' : '负一屏'),
            style: TextStyle(
              fontSize: 9,
              height: 11 / 9,
              color: active
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : PrimaryColors.of(context).secondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PanelOutline extends CustomPainter {
  const _PanelOutline(this.active, this.colors);
  final bool active;
  final PrimaryPalette colors;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(9)),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = active ? colors.accent : colors.divider;
    if (active) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 9) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 5).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PanelOutline oldDelegate) =>
      active != oldDelegate.active || colors != oldDelegate.colors;
}
