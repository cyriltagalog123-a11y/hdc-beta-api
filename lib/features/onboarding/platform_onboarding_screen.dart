import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/onboarding/onboarding_flow_ids.dart';
import '../../core/ui/hdc_colors.dart';
import '../../providers/onboarding_provider.dart';
import '../dashboard/dashboard_screen.dart';

class PlatformOnboardingScreen extends StatefulWidget {
  const PlatformOnboardingScreen({super.key});

  @override
  State<PlatformOnboardingScreen> createState() =>
      _PlatformOnboardingScreenState();
}

class _PlatformOnboardingScreenState
    extends State<PlatformOnboardingScreen> {
  final PageController _pageController = PageController();

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      icon: Icons.support_agent,
      title: 'Welcome to HDC',
      description:
          'HelpDesk Connect brings technical support, trusted services, '
          'products, and service history together in one platform.',
    ),
    _OnboardingPageData(
      icon: Icons.manage_search_outlined,
      title: 'Find the right help',
      description:
          'Describe your concern, discover suitable technicians, and '
          'compare the options available to you.',
    ),
    _OnboardingPageData(
      icon: Icons.confirmation_number_outlined,
      title: 'Track every request',
      description:
          'Follow service requests, offers, technician updates, and completed '
          'service records without losing important details.',
    ),
    _OnboardingPageData(
      icon: Icons.hub_outlined,
      title: 'Grow with the platform',
      description:
          'Use HDC as a customer today, then apply as a technician, seller, '
          'or store when you are ready to offer services and products.',
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
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      await context.read<OnboardingProvider>().complete(
        OnboardingFlowIds.platform,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const DashboardScreen(),
        ),
      );
    } on Object {
      if (!mounted) return;

      setState(() {
        _isCompleting = false;
      });

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
      backgroundColor: HDCColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                  right: 16,
                ),
                child: TextButton(
                  onPressed: _isCompleting ? null : _finish,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (pageIndex) {
                  setState(() {
                    _currentPage = pageIndex;
                  });
                },
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: _pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: index == _currentPage ? 26 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? HDCColors.primary
                                : HDCColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _isCompleting ? null : _next,
                        icon: _isCompleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Icon(
                                _isLastPage
                                    ? Icons.rocket_launch_outlined
                                    : Icons.arrow_forward,
                              ),
                        label: Text(
                          _isLastPage ? 'Get Started' : 'Next',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_currentPage + 1} of ${_pages.length} · ${page.title}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: HDCColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 16,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: HDCColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.icon,
                  size: 74,
                  color: HDCColors.primary,
                ),
              ),
              const SizedBox(height: 42),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: HDCColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
