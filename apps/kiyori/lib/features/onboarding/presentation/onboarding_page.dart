import 'package:flutter/material.dart';
import 'package:kiyori_ui/kiyori_ui.dart';

import '../../settings/presentation/legal_document.dart';
import '../../settings/presentation/legal_document_page.dart';
import '../../settings/presentation/permission_presentation.dart';

part 'onboarding_components.dart';
part 'onboarding_introduction.dart';
part 'onboarding_agreement.dart';
part 'onboarding_permissions.dart';

/// 首次引导的 UI 投影。它只保存本次页面中的勾选和阅读状态，不写首启、协议或
/// 系统授权事实；实际能力由后续宿主注入。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    this.reviewing = false,
    this.agreementAccepted = false,
    this.statuses = const {},
    this.onFinish = emptyAction,
    this.onExit = emptyAction,
    super.key,
  });
  final bool reviewing;
  final bool agreementAccepted;
  final Map<String, PermissionStatus> statuses;
  final VoidCallback onFinish, onExit;
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pages = PageController();
  int _page = 0;
  late bool _agreement = widget.agreementAccepted;
  bool _termsRead = false;
  bool _privacyRead = false;
  final Set<String> _selected = <String>{};
  final Set<int> _expanded = <int>{};
  late bool _acceptedPreview = widget.agreementAccepted;
  bool _navigating = false;
  LegalDocument? _document;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _go(int page) async {
    if (_navigating ||
        _pages.position.isScrollingNotifier.value ||
        page < 0 ||
        page > 5 ||
        (page == 5 && !_acceptedPreview)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _navigating = true;
    await _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _navigating = false;
  }

  void _openDocument(LegalDocument document) {
    setState(() {
      _document = document;
      if (document == LegalDocument.agreement) _termsRead = true;
      if (document == LegalDocument.privacy) _privacyRead = true;
    });
  }

  void _back() {
    if (_document != null) {
      setState(() => _document = null);
      return;
    }
    if (_page == 0) {
      if (widget.reviewing) Navigator.of(context).pop();
      return;
    }
    _go(_page - 1);
  }

  void _finish() {
    if (widget.reviewing) {
      Navigator.of(context).pop();
    } else {
      widget.onFinish();
    }
  }

  void _decline() {
    if (widget.reviewing) {
      Navigator.of(context).pop();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('不同意就无法使用 Kiyori Flutter'),
        content: const Text('你可以先阅读两份文档，再决定是否同意。仍要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('再看看'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              widget.onExit();
            },
            child: const Text('退出应用'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.reviewing && _page == 0 && _document == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: Scaffold(
      backgroundColor: PrimaryColors.of(context).background,
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: PrimaryColors.of(context).text,
            letterSpacing: 0,
          ),
          child: Stack(
            children: [
              Offstage(
                offstage: _document != null,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      children: [
                        _Header(
                          page: _page,
                          reviewing: widget.reviewing,
                          onBack: _back,
                          onSkip: _page < 4 ? () => _go(4) : null,
                        ),
                        Expanded(
                          child: PageView(
                            controller: _pages,
                            onPageChanged: (value) =>
                                setState(() => _page = value),
                            children: [
                              _IntroPage(
                                data: _intro[0],
                                page: 0,
                                onNext: () => _go(1),
                              ),
                              _IntroPage(
                                data: _intro[1],
                                page: 1,
                                onNext: () => _go(2),
                              ),
                              _IntroPage(
                                data: _intro[2],
                                page: 2,
                                onNext: () => _go(3),
                              ),
                              _IntroPage(
                                data: _intro[3],
                                page: 3,
                                onNext: () => _go(4),
                              ),
                              _AgreementPage(
                                checked: _agreement,
                                accepted: widget.agreementAccepted,
                                termsRead:
                                    _termsRead || widget.agreementAccepted,
                                privacyRead:
                                    _privacyRead || widget.agreementAccepted,
                                reviewing: widget.reviewing,
                                onChanged: (value) =>
                                    setState(() => _agreement = value),
                                onTerms: () =>
                                    _openDocument(LegalDocument.agreement),
                                onPrivacy: () =>
                                    _openDocument(LegalDocument.privacy),
                                onNext: () {
                                  setState(() => _acceptedPreview = true);
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) _go(5);
                                  });
                                },
                                onBack: _decline,
                              ),
                              if (_acceptedPreview)
                                _PermissionsPage(
                                  statuses: widget.statuses,
                                  selected: _selected,
                                  expanded: _expanded,
                                  reviewing: widget.reviewing,
                                  onToggle: (id) => setState(
                                    () => _selected.contains(id)
                                        ? _selected.remove(id)
                                        : _selected.add(id),
                                  ),
                                  onSelect: (ids) => setState(() {
                                    _selected.clear();
                                    _selected.addAll(ids);
                                  }),
                                  onExpand: (index) => setState(
                                    () => _expanded.contains(index)
                                        ? _expanded.remove(index)
                                        : _expanded.add(index),
                                  ),
                                  onFinish: _finish,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_document != null)
                LegalDocumentPage(
                  key: ValueKey(_document),
                  document: _document!,
                  onboarding: true,
                  onBack: _back,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
