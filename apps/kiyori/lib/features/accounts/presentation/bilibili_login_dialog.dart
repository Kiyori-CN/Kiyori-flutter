import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 登录方式切换只改变展示。二维码、导入、验证和系统跳转为空动作。
class BilibiliLoginDialog extends StatefulWidget {
  const BilibiliLoginDialog({super.key});
  @override
  State<BilibiliLoginDialog> createState() => _BilibiliLoginDialogState();
}

class _BilibiliLoginDialogState extends State<BilibiliLoginDialog> {
  bool qr = true;
  final cookie = TextEditingController();
  @override
  void dispose() {
    cookie.clear();
    cookie.dispose();
    super.dispose();
  }

  void select(bool next) => setState(() {
    qr = next;
    cookie.clear();
  });
  Widget description(String text) => Text(
    text,
    style: const TextStyle(fontSize: 12, color: PrimaryColors.secondary),
  );
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            const Text('登录哔哩哔哩', style: TextStyle(fontSize: 22)),
            description('登录一次，即可在番剧、资源和默认配置的 AI 工具包中使用。'),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('扫码登录'),
                  selected: qr,
                  onSelected: (_) => select(true),
                ),
                FilterChip(
                  label: const Text('Cookie 登录'),
                  selected: !qr,
                  onSelected: (_) => select(false),
                ),
              ],
            ),
            if (qr) ...[
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '登录二维码',
                    style: TextStyle(color: Color(0xFF444444)),
                  ),
                ),
              ),
              description('使用哔哩哔哩官方客户端扫码并确认；同一手机可点击下方按钮打开确认页。国际版客户端可能不支持。'),
              FilledButton(onPressed: emptyAction, child: const Text('获取二维码')),
              const OutlinedButton(onPressed: null, child: Text('打开哔哩哔哩确认')),
            ] else ...[
              OutlinedButton(
                onPressed: emptyAction,
                child: const Text(
                  '从 Kiyori 浏览器获取并登录',
                  textAlign: TextAlign.center,
                ),
              ),
              description(
                '读取 Kiyori 普通浏览模式下的哔哩哔哩登录信息。无痕模式、其他浏览器与其他应用的 Cookie 不会被读取。',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: emptyAction,
                  child: const Text('打开 Kiyori 浏览器登录'),
                ),
              ),
              description(
                '请在普通模式完成网页登录，再回到此处一键导入。浏览器切换账号后需要重新导入；移除本地账号不会退出网页。',
              ),
              const Divider(),
              TextField(
                controller: cookie,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                inputFormatters: [LengthLimitingTextInputFormatter(16384)],
                decoration: const InputDecoration(
                  labelText: '粘贴 Cookie',
                  helperText: '粘贴完整的 Cookie 请求头，需包含 SESSDATA',
                  helperMaxLines: 3,
                  border: OutlineInputBorder(),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: cookie,
                builder: (context, value, _) => FilledButton(
                  onPressed: value.text.trim().isEmpty ? null : emptyAction,
                  child: const Text('验证并登录'),
                ),
              ),
            ],
            Text(
              qr ? '获取二维码后，使用哔哩哔哩客户端扫码' : 'Cookie 仅在本机加密保存，用于哔哩哔哩账号验证',
              style: const TextStyle(
                fontSize: 14,
                color: PrimaryColors.secondary,
              ),
            ),
            description('凭据仅发送给哔哩哔哩完成验证，不写入日志或备份。'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
