import 'package:kiyori/features/accounts/presentation/account_presentation.dart';

const connectedAccounts = AccountPresentation(
  githubConnected: true,
  githubLogin: 'fixture-user',
  bilibili: BilibiliAccountPresentation(
    name: '测试账号',
    uid: '10001',
    verifiedAtLabel: '2026/10/2 12:00',
    level: 6,
    vip: true,
  ),
);

const expiredAccounts = AccountPresentation(
  githubConnected: true,
  bilibili: BilibiliAccountPresentation(
    name: '失效测试账号',
    uid: '10002',
    verifiedAtLabel: '2026/10/1 12:00',
    valid: false,
  ),
  bilibiliError: '登录已失效，请重新登录',
);
