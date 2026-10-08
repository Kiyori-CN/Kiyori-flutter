import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 已取得的挑战与可选解码图像；不包含凭据，不在build生成或下载二维码。
class BilibiliQrPresentation {
  const BilibiliQrPresentation({this.image});
  final ImageProvider? image;
}

/// 登录方式切换只改变展示。二维码、导入、验证和系统跳转为空动作。
class BilibiliLoginDialog extends StatefulWidget {
  const BilibiliLoginDialog({
    this.accountName,
    this.busy = false,
    this.message,
    this.error = false,
    this.qrCode,
    super.key,
  });
  final String? accountName, message;
  final bool busy, error;
  final BilibiliQrPresentation? qrCode;
  @override
  State<BilibiliLoginDialog> createState() => _BilibiliLoginDialogState();
}

class _BilibiliLoginDialogState extends State<BilibiliLoginDialog> {
  bool qr = true;
  late BilibiliQrPresentation? qrCode = widget.qrCode;
  final cookie = TextEditingController();
  @override
  void didUpdateWidget(covariant BilibiliLoginDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qrCode != widget.qrCode) qrCode = widget.qrCode;
  }

  @override
  void dispose() {
    cookie.clear();
    cookie.dispose();
    super.dispose();
  }

  void select(bool next) => setState(() {
    qrCode = null;
    qr = next;
    cookie.clear();
  });
  Widget description(String text) => Text(
    text,
    style: TextStyle(fontSize: 12, color: PrimaryColors.of(context).secondary),
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
            description(
              widget.accountName == null
                  ? '登录一次，即可在番剧、资源和默认配置的 AI 工具包中使用。'
                  : '当前账号：${widget.accountName}。验证成功后切换；失败时保留原账号。',
            ),
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
                  child: switch (qrCode?.image) {
                    final image? => Image(
                      image: image,
                      width: 220,
                      height: 220,
                      semanticLabel: '哔哩哔哩登录二维码',
                      filterQuality: FilterQuality.none,
                    ),
                    null => const Text(
                      '登录二维码',
                      style: TextStyle(color: Color(0xFF444444)),
                    ),
                  },
                ),
              ),
              description('使用哔哩哔哩官方客户端扫码并确认；同一手机可点击下方按钮打开确认页。国际版客户端可能不支持。'),
              FilledButton(
                onPressed: !widget.busy || qrCode != null ? emptyAction : null,
                child: Text(qrCode == null ? '获取二维码' : '刷新二维码'),
              ),
              OutlinedButton(
                onPressed: qrCode == null ? null : emptyAction,
                child: const Text('打开哔哩哔哩确认', textAlign: TextAlign.center),
              ),
            ] else ...[
              OutlinedButton(
                onPressed: widget.busy ? null : cookie.clear,
                child: const Text(
                  '从 Kiyori Flutter 浏览器获取并登录',
                  textAlign: TextAlign.center,
                ),
              ),
              description(
                '读取 Kiyori Flutter 普通浏览模式下的哔哩哔哩登录信息。无痕模式、其他浏览器与其他应用的 Cookie 不会被读取。',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: widget.busy ? null : emptyAction,
                  child: const Text('打开 Kiyori Flutter 浏览器登录'),
                ),
              ),
              description(
                '请在普通模式完成网页登录，再回到此处一键导入。浏览器切换账号后需要重新导入；移除本地账号不会退出网页。',
              ),
              const Divider(),
              TextField(
                controller: cookie,
                enabled: !widget.busy,
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
                  onPressed: value.text.trim().isEmpty || widget.busy
                      ? null
                      : emptyAction,
                  child: const Text('验证并登录'),
                ),
              ),
            ],
            if (widget.busy) const LinearProgressIndicator(),
            Text(
              widget.message ??
                  (qr ? '获取二维码后，使用哔哩哔哩客户端扫码' : 'Cookie 仅在本机加密保存，用于哔哩哔哩账号验证'),
              style: TextStyle(
                fontSize: 14,
                color: widget.error
                    ? Theme.of(context).colorScheme.error
                    : PrimaryColors.of(context).secondary,
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
