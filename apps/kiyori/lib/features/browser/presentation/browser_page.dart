import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 原启动恢复流程默认呈现一个 about:blank。这里只投影该外观，
/// 不把占位窗口计数当作 BrowserSession，不创建 WebView 或网络请求。
class BrowserPage extends StatelessWidget {
  const BrowserPage({required this.onBack, super.key});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ShellAction(
                  Icons.arrow_back,
                  '退出浏览器',
                  iconSize: 21,
                  color: const Color(0xFF202124),
                  onTap: onBack,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFF9AA0A6)),
                    ),
                    child: InkWell(
                      onTap: emptyAction,
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        height: 42,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 11),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search,
                                size: 18,
                                color: Color(0xFF5F6368),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'about:blank',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.search,
                                size: 18,
                                color: Color(0xFF5F6368),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const ShellAction(
                  Icons.refresh,
                  '刷新网页',
                  iconSize: 21,
                  color: Color(0xFF202124),
                ),
              ],
            ),
          ),
          const Expanded(
            child: SizedBox.expand(key: Key('browser-blank-page')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              key: const Key('browser-toolbar'),
              children: [
                for (var index = 0; index < 5; index++)
                  Expanded(
                    child: Center(
                      child: Semantics(
                        button: true,
                        excludeSemantics: true,
                        label: [
                          '网页后退',
                          '网页前进',
                          '浏览器主页',
                          '窗口，1',
                          '浏览器菜单',
                        ][index],
                        child: InkWell(
                          onTap: emptyAction,
                          borderRadius: BorderRadius.circular(22),
                          child: SizedBox.square(
                            dimension: 44,
                            child: Center(
                              child: Opacity(
                                opacity: index < 2 ? .38 : 1,
                                child: index == 3
                                    ? Container(
                                        width: 20,
                                        height: 20,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            width: 1.75,
                                            color: const Color(0xFF202124),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            1.75,
                                          ),
                                        ),
                                        child: const Text(
                                          '1',
                                          style: TextStyle(
                                            fontSize: 9,
                                            height: 1,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : CustomPaint(
                                        size: const Size.square(26),
                                        painter: _BrowserGlyph(index),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 直接投影旧 ic_kiyori_browser_bottom_* / ic_kiyori_tool_toolbox 矢量路径。
class _BrowserGlyph extends CustomPainter {
  const _BrowserGlyph(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final path = Path();
    switch (index) {
      case 0:
        path
          ..moveTo(15, 6)
          ..lineTo(9, 12)
          ..lineTo(15, 18);
      case 1:
        path
          ..moveTo(9, 6)
          ..lineTo(15, 12)
          ..lineTo(9, 18);
      case 2:
        path
          ..moveTo(5, 20)
          ..lineTo(19, 20)
          ..arcToPoint(
            const Offset(20, 19),
            radius: const Radius.circular(1),
            clockwise: false,
          )
          ..lineTo(20, 11.5)
          ..lineTo(12, 4)
          ..lineTo(4, 11.5)
          ..lineTo(4, 19)
          ..arcToPoint(
            const Offset(5, 20),
            radius: const Radius.circular(1),
            clockwise: false,
          )
          ..close();
      case 4:
        path
          ..moveTo(4, 8.5)
          ..lineTo(12, 5)
          ..lineTo(20, 8.5)
          ..lineTo(20, 17)
          ..lineTo(12, 20.5)
          ..lineTo(4, 17)
          ..close()
          ..moveTo(4, 8.5)
          ..lineTo(12, 12)
          ..lineTo(20, 8.5)
          ..moveTo(12, 12)
          ..lineTo(12, 20.5);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF202124)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BrowserGlyph oldDelegate) => index != oldDelegate.index;
}
