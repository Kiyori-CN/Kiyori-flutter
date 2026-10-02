part of 'onboarding_page.dart';

class _Header extends StatelessWidget {
  const _Header({
    required this.page,
    required this.reviewing,
    required this.onBack,
    this.onSkip,
  });
  final int page;
  final bool reviewing;
  final VoidCallback onBack;
  final VoidCallback? onSkip;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: page == 0 && !reviewing
                    ? null
                    : IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                        tooltip: '返回',
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _nav[page],
                          style: const TextStyle(
                            fontSize: 16,
                            height: 22 / 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${page + 1}/6',
                        style: const TextStyle(
                          fontSize: 13,
                          color: PrimaryColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onSkip != null)
                TextButton(
                  onPressed: onSkip,
                  child: const Text('跳过介绍', style: TextStyle(fontSize: 14)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: Row(
            children: [
              for (var i = 0; i < 6; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i == 5 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: i <= page
                          ? PrimaryColors.accent
                          : PrimaryColors.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext c) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 22),
    child: Row(
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: PrimaryColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            height: 18 / 13,
            color: PrimaryColors.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.label,
    required this.onPressed,
    this.secondary,
    this.onSecondary,
    this.horizontalPadding = 20,
  });
  final String label;
  final VoidCallback? onPressed;
  final String? secondary;
  final VoidCallback? onSecondary;
  final double horizontalPadding;
  @override
  Widget build(BuildContext c) => Container(
    padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x00F6F7F9),
          PrimaryColors.background,
          PrimaryColors.background,
        ],
        stops: [0, .42, 1],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 50),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            backgroundColor: PrimaryColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: PrimaryColors.divider,
            disabledForegroundColor: PrimaryColors.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 22 / 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (secondary != null)
          TextButton(
            onPressed: onSecondary,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: PrimaryColors.secondary,
            ),
            child: Text(secondary!, style: const TextStyle(fontSize: 13.5)),
          ),
      ],
    ),
  );
}
