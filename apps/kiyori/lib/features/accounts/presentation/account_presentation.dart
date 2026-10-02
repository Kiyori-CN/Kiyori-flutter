/// 账号事实由宿主注入，展示类型不包含凭据或本机存储位置。
class AccountPresentation {
  const AccountPresentation({
    this.githubConnected = false,
    this.githubLogin,
    this.bilibili,
    this.bilibiliLoading = false,
    this.bilibiliBusy = false,
    this.bilibiliError,
  });

  final bool githubConnected;
  final String? githubLogin;
  final BilibiliAccountPresentation? bilibili;
  final bool bilibiliLoading, bilibiliBusy;
  final String? bilibiliError;
}

class BilibiliAccountPresentation {
  const BilibiliAccountPresentation({
    required this.name,
    required this.uid,
    required this.verifiedAtLabel,
    this.valid = true,
    this.level = 0,
    this.vip = false,
  });

  final String name, uid, verifiedAtLabel;
  final bool valid, vip;
  final int level;
}
