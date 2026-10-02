import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

/// 仅投影登录宿主状态；OAuth、浏览器会话和凭据归后续共享 owner。
class GitHubLoginPresentation {
  const GitHubLoginPresentation({
    this.loading = false,
    this.completing = false,
    this.launchingExternal = false,
    this.error,
  });
  final bool loading, completing, launchingExternal;
  final String? error;
}

/// 同一模态内由方式选择切换全屏容器，关闭直接返回原账号页。
class GitHubLoginDialog extends StatefulWidget {
  const GitHubLoginDialog({
    this.snapshot = const GitHubLoginPresentation(),
    super.key,
  });
  final GitHubLoginPresentation snapshot;

  @override
  State<GitHubLoginDialog> createState() => _GitHubLoginDialogState();
}

class _GitHubLoginDialogState extends State<GitHubLoginDialog> {
  bool embedded = false;
  final messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void didUpdateWidget(covariant GitHubLoginDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.error != widget.snapshot.error) reportError();
  }

  void reportError() {
    final message = widget.snapshot.error;
    if (!embedded || message == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.snapshot.error != message) return;
      messenger.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void openEmbedded() {
    setState(() => embedded = true);
    reportError();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.snapshot;
    if (!embedded) {
      return AlertDialog(
        title: const Text('登录 GitHub'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('请选择 GitHub 登录方式。内嵌模式适合无法调起外部浏览器的设备，外部浏览器模式兼容性更好。'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: openEmbedded,
              icon: const Icon(Icons.language),
              label: const Text('使用内嵌页面登录'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.launchingExternal ? null : emptyAction,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('使用外部浏览器登录'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      );
    }
    return PopScope(
      canPop: !state.completing,
      child: Dialog.fullscreen(
        child: ScaffoldMessenger(
          key: messenger,
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 64,
              title: const Text(
                '登录 GitHub',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              leading: IconButton(
                tooltip: '关闭',
                onPressed: state.completing
                    ? null
                    : () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 21),
              ),
              actions: [
                IconButton(
                  tooltip: '刷新',
                  onPressed: state.completing ? null : emptyAction,
                  icon: const Icon(Icons.refresh, size: 21),
                ),
              ],
            ),
            // 浏览器尚未接入，不构造第二 WebView，也不渲染虚假网页。
            body: Column(
              children: [
                if (state.loading || state.completing)
                  const LinearProgressIndicator(),
                const Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
