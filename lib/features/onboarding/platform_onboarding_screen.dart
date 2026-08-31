import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/onboarding/onboarding_flow_ids.dart';
import '../../core/ui/hdc_brand.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../providers/onboarding_provider.dart';
import '../dashboard/dashboard_screen.dart';

class PlatformOnboardingScreen extends StatefulWidget {
  const PlatformOnboardingScreen({super.key});

  @override
  State<PlatformOnboardingScreen> createState() =>
      _PlatformOnboardingScreenState();
}

class _PlatformOnboardingScreenState extends State<PlatformOnboardingScreen> {
  final PageController _pageController = PageController();

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      eyebrow: 'ONE CONNECTED WORKSPACE',
      icon: Icons.hub_outlined,
      color: HDCColors.accent,
      title: 'Welcome to HDC',
      description:
          'HelpDesk Connect brings technical support, trusted services, '
          'products, and service history together in one platform.',
      detail: 'Start as a guest or member. Your available actions always follow your verified account roles.',
    ),
    _OnboardingPageData(
      eyebrow: 'SMARTER DISCOVERY',
      icon: Icons.manage_search_outlined,
      color: HDCColors.signal,
      title: 'Find the right help',
      description:
          'Describe your concern, discover suitable technicians, and '
          'compare the options available to you.',
      detail: 'Open requests, technician profiles, and offers stay connected to the same service record.',
    ),
    _OnboardingPageData(
      eyebrow: 'AUTHORITATIVE HISTORY',
      icon: Icons.timeline_rounded,
      color: HDCColors.warm,
      title: 'Track every request',
      description:
          'Follow service requests, offers, technician updates, and completed '
          'service records without losing important details.',
      detail: 'Chat, decisions, payments, documents, and disputes remain visible to authorized participants.',
    ),
    _OnboardingPageData(
      eyebrow: 'ONE ACCOUNT • MANY ROLES',
      icon: Icons.account_tree_outlined,
      color: HDCColors.secondary,
      title: 'Grow with the platform',
      description:
          'Use HDC as a customer today, then apply as a technician, seller, '
          'or store when you are ready to offer services and products.',
      detail: 'Each approved role receives its own public profile and workspace without creating another login.',
    ),
  ];

  int _currentPage = 0;
  bool _isCompleting = false;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_isLastPage) {
      await _finish();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      await context.read<OnboardingProvider>().complete(
        OnboardingFlowIds.platform,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'HDC could not save your onboarding progress. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      body: HDCSignalBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Row(
                    children: [
                      const Expanded(
                        child: HDCBrandLockup(compact: true, markSize: 40),
                      ),
                      TextButton.icon(
                        onPressed: _isCompleting ? null : _finish,
                        icon: const Icon(Icons.fast_forward_rounded, size: 18),
                        label: const Text('Skip welcome'),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (pageIndex) {
                    setState(() => _currentPage = pageIndex);
                  },
                  itemBuilder: (context, index) {
                    return _OnboardingPage(
                      data: _pages[index],
                      index: index + 1,
                      total: _pages.length,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: HDCCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 520;
                        final progress = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            _pages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: index == _currentPage ? 28 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: index == _currentPage
                                    ? page.color
                                    : HDCColors.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        );
                        final button = FilledButton.icon(
                          onPressed: _isCompleting ? null : _next,
                          icon: _isCompleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                  ),
                                )
                              : Icon(
                                  _isLastPage
                                      ? Icons.rocket_launch_outlined
                                      : Icons.arrow_forward_rounded,
                                ),
                          label: Text(_isLastPage ? 'Enter HDC' : 'Continue'),
                        );

                        if (compact) {
                          return Column(
                            children: [
                              progress,
                              const SizedBox(height: 14),
                              SizedBox(width: double.infinity, child: button),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            progress,
                            const SizedBox(width: 18),
                            Expanded(
                              child: Text(
                                '${_currentPage + 1} of ${_pages.length} · ${page.title}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            button,
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;
  final int index;
  final int total;

  const _OnboardingPage({
    required this.data,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: HDCCard(
            elevated: true,
            padding: const EdgeInsets.all(0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 680;
                final visual = _OnboardingVisual(
                  data: data,
                  index: index,
                  horizontal: horizontal,
                );
                final copy = _OnboardingCopy(
                  data: data,
                  index: index,
                  total: total,
                );

                if (horizontal) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 310, child: visual),
                        Expanded(child: copy),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 245, child: visual),
                    copy,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  final _OnboardingPageData data;
  final int index;
  final bool horizontal;

  const _OnboardingVisual({
    required this.data,
    required this.index,
    required this.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: horizontal
          ? const BorderRadius.only(
              topLeft: Radius.circular(HDCSpacing.radiusMedium),
              bottomLeft: Radius.circular(HDCSpacing.radiusMedium),
            )
          : const BorderRadius.only(
              topLeft: Radius.circular(HDCSpacing.radiusMedium),
              topRight: Radius.circular(HDCSpacing.radiusMedium),
            ),
      child: HDCSignalBackdrop(
        dark: true,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: data.color.withValues(alpha: 0.72),
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              Align(
                child: Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.color.withValues(alpha: 0.12),
                    border: Border.all(
                      color: data.color.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Icon(data.icon, size: 56, color: data.color),
                ),
              ),
              HDCSignalPill(
                label: data.eyebrow,
                color: data.color,
                light: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingCopy extends StatelessWidget {
  final _OnboardingPageData data;
  final int index;
  final int total;

  const _OnboardingCopy({
    required this.data,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'HDC WELCOME • $index/$total',
            style: TextStyle(
              color: data.color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(data.title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          Text(
            data.description,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: HDCColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: data.color.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.bolt_rounded, color: data.color, size: 20),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    data.detail,
                    style: const TextStyle(
                      color: HDCColors.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
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
}

class _OnboardingPageData {
  final String eyebrow;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String detail;

  const _OnboardingPageData({
    required this.eyebrow,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.detail,
  });
}
