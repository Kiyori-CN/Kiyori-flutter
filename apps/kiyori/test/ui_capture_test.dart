import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_capture.dart';

import 'package:kiyori/app/kiyori_app.dart';

import 'support/fake_runtime.dart' show FakeClient;
import 'support/ui_test_helpers.dart' show reveal;
import 'support/ui_test_helpers.dart' show revealBackup;
import 'support/ui_test_helpers.dart' show revealOnboarding;

// 可选人工视觉证据，字体只在本机加载，不分发系统字体或生成黄金图基线。
void main() {
  const output = String.fromEnvironment('KIYORI_CAPTURE');
  testWidgets(
    'capture supplied screenshot primary surfaces at 360',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: KiyoriApp(connect: () async => FakeClient()),
        ),
      );
      await tester.pumpAndSettle();
      await captureUi(tester, boundary, output, 'screenshot-home-360');
      for (final entry in [
        (1, 'browser'),
        (2, 'toolbox'),
        (3, 'files'),
        (4, 'settings'),
      ]) {
        await tester.tap(find.byKey(Key('nav-${entry.$1}')));
        await tester.pumpAndSettle();
        await captureUi(tester, boundary, output, 'screenshot-${entry.$2}-360');
        if (entry.$1 == 1) {
          await tester.tap(find.bySemanticsLabel('退出浏览器'));
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.byKey(const Key('nav-0')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(600, 0));
      await tester.pumpAndSettle();
      await captureUi(tester, boundary, output, 'screenshot-minus-one-360');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'capture actual Flutter shell for visual review',
    skip: output.isEmpty,
    (tester) async {
      await loadCaptureFonts(tester);
      final boundaryKey = GlobalKey();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> capture(String name, {bool animated = false}) =>
          captureUi(tester, boundaryKey, output, name, animated: animated);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: KiyoriApp(connect: () async => FakeClient()),
        ),
      );
      await tester.runAsync(() async {
        final context = boundaryKey.currentContext!;
        await precacheImage(
          const AssetImage('assets/branding/kiyori-app-icon.png'),
          context,
        );
        for (final name in ['top_search', 'scan', 'top_refresh']) {
          await precacheImage(
            AssetImage('assets/chrome/settings_header_$name.png'),
            context,
          );
        }
        for (final name in [
          'nav_home',
          'nav_globe',
          'nav_apps',
          'nav_folder',
          'tool_settings',
        ]) {
          for (final suffix in [
            '',
            '_selected_fill',
            if (name == 'tool_settings') '_selected_detail',
          ]) {
            await precacheImage(
              AssetImage('assets/navigation/$name$suffix.png'),
              context,
            );
          }
        }
      });
      await capture('home-phone');
      for (final entry in [
        (1, 'browser'),
        (2, 'toolbox'),
        (3, 'files'),
        (4, 'settings'),
      ]) {
        await tester.tap(find.byKey(Key('nav-${entry.$1}')));
        await capture('${entry.$2}-phone');
        if (entry.$1 == 1) {
          await tester.tap(find.bySemanticsLabel('退出浏览器'));
          await tester.pumpAndSettle();
        }
      }
      await tester.tap(find.text('我的账号'));
      await capture('accounts-phone');
      await tester.tap(find.text('登录 GitHub'));
      await capture('github-login-method-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('登录哔哩哔哩'));
      await capture('bilibili-login-qr-phone');
      await tester.tap(find.text('Cookie 登录'));
      await capture('bilibili-login-cookie-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI 助手'));
      await capture('assistant-settings-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('网页浏览器'));
      await capture('browser-settings-phone');
      await reveal(tester, find.text('网页主页'));
      await tester.tap(find.text('网页主页'));
      await capture('browser-home-settings-phone');
      await reveal(tester, find.text('当前网址'));
      await tester.tap(find.text('当前网址'));
      await capture('browser-home-dialog-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('网页文字大小'));
      await tester.tap(find.text('网页文字大小'));
      await capture('browser-text-size-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('文件下载器'));
      await tester.tap(find.text('文件下载器'));
      await capture('download-settings-phone');
      await tester.tap(find.text('默认下载器'));
      await capture('download-engine-drawer-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('文件管理器'));
      await tester.tap(find.text('文件管理器'));
      await capture('file-settings-phone');
      await reveal(tester, find.text('按格式设置默认打开方式'));
      await tester.tap(find.text('按格式设置默认打开方式'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'mp3');
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置此格式'));
      await capture('file-open-format-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('视频播放器'));
      await tester.tap(find.text('视频播放器'));
      await capture('player-settings-phone');
      for (final entry in [
        ('字幕样式', 'subtitle'),
        ('声音处理', 'audio'),
        ('弹幕设置', 'danmaku'),
        ('界面与播放', 'controls'),
      ]) {
        await reveal(tester, find.text(entry.$1));
        await tester.tap(find.text(entry.$1));
        await capture('player-${entry.$2}-phone');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('工具箱设置'));
      await capture('toolbox-settings-phone');
      await reveal(tester, find.text('常用工具'));
      await tester.tap(find.text('常用工具'));
      await capture('toolbox-favorites-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('管理分组'));
      await tester.tap(find.text('管理分组'));
      await capture('toolbox-groups-phone');
      await tester.tap(find.text('批量移动工具'));
      await capture('toolbox-move-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('文档工作台'));
      await tester.tap(find.text('文档工作台'));
      await capture('document-settings-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-4')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('音乐播放器'));
      await tester.tap(find.text('音乐播放器'));
      await capture('music-settings-phone');
      await tester.tap(find.text('在线导入'));
      await capture('music-source-dialog-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('桌面歌词 · LRC'));
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await capture('music-desktop-lyrics-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('广告拦截器'));
      await tester.tap(find.text('广告拦截器'));
      await capture('adblock-overview-phone');
      await reveal(tester, find.text('网址过滤'));
      await tester.tap(find.text('网址过滤'));
      await capture('adblock-network-phone');
      await tester.tap(find.text('新增'));
      await capture('adblock-editor-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('订阅与更新'));
      await tester.tap(find.text('订阅与更新'));
      await reveal(tester, find.text('My AdFilters'));
      await tester.tap(find.text('My AdFilters'));
      await capture('adblock-subscriptions-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('更多功能'));
      await reveal(tester, find.text('数据备份'));
      await tester.tap(find.text('数据备份'));
      await capture('data-settings-menu-phone');
      await tester.tap(find.text('数据备份与恢复'));
      await capture('backup-overview-phone', animated: true);
      await revealBackup(
        tester,
        find.byKey(const ValueKey('backup-export-聊天记录')),
      );
      await tester.tap(find.byKey(const ValueKey('backup-export-聊天记录')));
      await capture('backup-chat-selection-phone', animated: true);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      await revealBackup(tester, find.text('每日自动备份'));
      await capture('backup-database-phone', animated: true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('界面定制'));
      await tester.tap(find.text('界面定制'));
      await capture('appearance-menu-phone');
      await tester.tap(find.text('全局显示'));
      await capture('global-display-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('布局调整'));
      await capture('layout-adjustment-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('语言'));
      await capture('language-settings-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('主题与外观'));
      await capture('appearance-theme-phone');
      for (final entry in [
        ('背景', 'background'),
        ('聊天', 'chat'),
        ('输入栏', 'input'),
        ('AI 界面', 'interface'),
      ]) {
        final label = find.text(entry.$1).first;
        await Scrollable.ensureVisible(tester.element(label));
        await tester.pumpAndSettle();
        await tester.tap(label);
        await capture('appearance-${entry.$2}-phone');
      }
      await Scrollable.ensureVisible(tester.element(find.text('历史记录图标颜色')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('历史记录图标颜色'));
      await capture('appearance-color-picker-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('更多功能'));
      await tester.tap(find.text('更多功能'));
      await capture('more-settings-phone');
      await reveal(tester, find.text('重新查看首次引导'));
      await tester.tap(find.text('重新查看首次引导'));
      await capture('onboarding-1-phone');
      for (final entry in [
        ('看看能做什么', 'onboarding-2-phone'),
        ('了解 AI 协作', 'onboarding-3-phone'),
        ('了解工具与个性化', 'onboarding-4-phone'),
        ('查看协议与隐私', 'onboarding-5-phone'),
      ]) {
        await tester.tap(find.text(entry.$1));
        await capture(entry.$2);
      }
      await revealOnboarding(tester, find.text('Kiyori Flutter 用户协议'));
      await tester.tap(find.text('Kiyori Flutter 用户协议'));
      await capture('onboarding-legal-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await revealOnboarding(tester, find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同意并继续'));
      await capture('onboarding-6-phone');
      await tester.tap(find.text('完成介绍，返回设置'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ListView).hitTestable().last,
        const Offset(0, 900),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('权限管理'));
      await capture('permissions-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('开源协议'));
      await tester.tap(find.text('开源协议'));
      await capture('open-source-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('用户协议'));
      await tester.tap(find.text('用户协议'));
      await capture('legal-agreement-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ListView).hitTestable().last,
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('存储与路径'));
      await capture('storage-paths-phone');
      await reveal(tester, find.text('Android 默认产物目录'));
      await tester.tap(find.text('Android 默认产物目录'));
      await capture('artifact-storage-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('网络代理'));
      await tester.tap(find.text('网络代理'));
      await capture('network-proxy-phone');
      await reveal(tester, find.text('订阅管理'));
      await tester.tap(find.text('订阅管理'));
      await capture('network-subscriptions-phone');
      await tester.tap(find.text('添加订阅地址'));
      await capture('network-subscription-editor-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('规则管理'));
      await tester.tap(find.text('规则管理'));
      await capture('network-rules-phone');
      await tester.tap(find.text('添加自定义规则'));
      await capture('network-rule-editor-phone');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-0')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(330, 0));
      await capture('minus-one-phone');
      await tester.tap(find.bySemanticsLabel('关闭负一屏'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-330, 0));
      await capture('chat-phone');
      await tester.dragFrom(const Offset(180, 350), const Offset(330, 0));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1280, 800);
      await capture('home-desktop');
      expect(tester.takeException(), isNull);
    },
  );
}
