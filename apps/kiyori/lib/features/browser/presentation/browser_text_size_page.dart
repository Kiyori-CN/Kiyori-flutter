import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

class BrowserTextSizePage extends StatefulWidget {
  const BrowserTextSizePage({super.key});
  @override
  State<BrowserTextSizePage> createState() => _BrowserTextSizePageState();
}

class _BrowserTextSizePageState extends State<BrowserTextSizePage> {
  double percent = 100;
  @override
  Widget build(BuildContext context) {
    final value = (percent / 5).round() * 5;
    final scale = value / 100;
    return SettingsDetailPage(
      title: '网页文字大小',
      children: [
        SettingsGroup(
          title: '实时预览',
          description: '示例只展示比例变化；实际网页由同一 WebView 文字缩放设置控制',
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
              decoration: BoxDecoration(
                color: PrimaryColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    '生活不只眼前的苟且',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18 * scale, height: 27 / 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '还有诗和远方的田野',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18 * scale, height: 27 / 18),
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: '文字比例',
          description: '范围 50%–200%，每次调整 5%；默认值为 100%',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                children: [
                  Text(
                    value == 100 ? '默认 · 100%' : '$value%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: '减小网页文字',
                        constraints: const BoxConstraints.tightFor(
                          width: 42,
                          height: 42,
                        ),
                        onPressed: value > 50
                            ? () => setState(
                                () => percent = (value - 5).toDouble(),
                              )
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Slider(
                          value: percent,
                          min: 50,
                          max: 200,
                          divisions: 30,
                          onChanged: (next) => setState(() => percent = next),
                        ),
                      ),
                      IconButton(
                        tooltip: '增大网页文字',
                        constraints: const BoxConstraints.tightFor(
                          width: 42,
                          height: 42,
                        ),
                        onPressed: value < 200
                            ? () => setState(
                                () => percent = (value + 5).toDouble(),
                              )
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: value == 100
                        ? null
                        : () => setState(() => percent = 100),
                    child: const Text('恢复默认'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
