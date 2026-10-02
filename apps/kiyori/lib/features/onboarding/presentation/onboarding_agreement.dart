part of 'onboarding_page.dart';

class _AgreementPage extends StatelessWidget {
  const _AgreementPage({
    required this.checked,
    required this.accepted,
    required this.termsRead,
    required this.privacyRead,
    required this.reviewing,
    required this.onChanged,
    required this.onTerms,
    required this.onPrivacy,
    required this.onNext,
    required this.onBack,
  });
  final bool checked, accepted, termsRead, privacyRead, reviewing;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTerms, onPrivacy, onNext, onBack;
  @override
  Widget build(BuildContext c) => Column(
    children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Eyebrow('开始前'),
              const SizedBox(height: 8),
              const Text(
                '先把三件事说清楚',
                style: TextStyle(
                  fontSize: 24,
                  height: 32 / 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '请阅读用户协议与隐私政策，确认后继续。以后也可在「设置 → 更多功能」查阅两份文档。',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 21 / 13.5,
                  color: PrimaryColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              _InfoBox(),
              const SizedBox(height: 8),
              _DocCard('Kiyori 用户协议', '使用规则、高影响操作与开源许可', termsRead, onTerms),
              const SizedBox(height: 8),
              _DocCard(
                'Kiyori 隐私政策',
                '数据类型、联网场景、保存期限与删除方式',
                privacyRead,
                onPrivacy,
              ),
              const SizedBox(height: 9),
              InkWell(
                onTap: accepted ? null : () => onChanged(!checked),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: PrimaryColors.divider),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 28,
                        child: Checkbox(
                          value: checked,
                          onChanged: accepted
                              ? null
                              : (v) => onChanged(v ?? false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '我已阅读并同意《用户协议》和《隐私政策》',
                          style: TextStyle(fontSize: 12.5, height: 18 / 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                '协议版本 2026-09-08-r1 · 更新时会再次征求同意',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 15 / 10.5,
                  color: PrimaryColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
      _BottomAction(
        label: accepted ? '已同意，继续查看权限' : '同意并继续',
        onPressed: checked ? onNext : null,
        secondary: reviewing ? '返回设置' : '不同意并退出',
        onSecondary: onBack,
      ),
    ],
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox();
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.fromLTRB(13, 4, 13, 11),
    decoration: BoxDecoration(
      color: Theme.of(c).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Info('数据去向有边界', '浏览网站、调用模型或联网扩展时，相关内容会发送给对应服务；本地保存不等于所有处理都离线。'),
        _Info('授权是独立选择', '同意协议不会开启任何设备权限。你可以暂不授权，用到具体功能时再决定。'),
        _Info('重要操作请核验', 'AI 可能出错，脚本与自动化可能修改文件或设备；第三方服务可能收费，重要数据请先备份。'),
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info(this.title, this.body);
  final String title, body;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          body,
          style: const TextStyle(
            fontSize: 11.5,
            height: 17 / 11.5,
            color: PrimaryColors.secondary,
          ),
        ),
      ],
    ),
  );
}

class _DocCard extends StatelessWidget {
  const _DocCard(this.title, this.desc, this.read, this.onTap);
  final String title, desc;
  final bool read;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: PrimaryColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ToneBadge(
            title == 'Kiyori 用户协议'
                ? Icons.description_outlined
                : Icons.security_outlined,
            title == 'Kiyori 用户协议' ? IconTone.document : IconTone.security,
            size: 34,
            iconSize: 19,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 15 / 11,
                    color: PrimaryColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            read ? '已读 ›' : '未读 ›',
            style: const TextStyle(fontSize: 10.5, color: PrimaryColors.accent),
          ),
        ],
      ),
    ),
  );
}
