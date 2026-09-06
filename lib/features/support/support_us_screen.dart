import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import 'contact_owner_screen.dart';

class SupportUsScreen extends StatelessWidget {
  const SupportUsScreen({super.key});

  void _openOwner(BuildContext context) {
    Navigator.of(context).push(
      HDCPageRoute<void>(page: const ContactOwnerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support HDC')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HDCSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HDCFlowHero(
                    eyebrow: 'SUPPORT HDC',
                    title: 'Help HDC become more useful without compromising trust.',
                    description:
                        'Support is not only financial. During beta, the highest-value help is testing real workflows, reporting defects clearly, suggesting useful improvements, sharing HDC with people who actually need technical help, and opening serious partnership conversations.',
                    icon: Icons.volunteer_activism_outlined,
                    tags: [
                      HDCFlowTag(
                        label: 'Beta support',
                        icon: Icons.science_outlined,
                      ),
                      HDCFlowTag(
                        label: 'Trust stays independent',
                        icon: Icons.verified_user_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  const _PrioritySupportGrid(),
                  const SizedBox(height: HDCSpacing.lg),
                  _FundingAndPartnershipCard(onContactOwner: () => _openOwner(context)),
                  const SizedBox(height: HDCSpacing.lg),
                  const _TrustBoundaryCard(),
                  const SizedBox(height: HDCSpacing.lg),
                  const _WhatHelpsMostCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrioritySupportGrid extends StatelessWidget {
  const _PrioritySupportGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      _SupportPath(
        icon: Icons.bug_report_outlined,
        title: 'Test and report defects',
        description:
            'Use HDC like a real customer, technician, seller, or business. Clear reproduction steps, screenshots, affected workflow, and reference IDs are more valuable than vague bug reports.',
        accent: HDCColors.danger,
      ),
      _SupportPath(
        icon: Icons.fact_check_outlined,
        title: 'Challenge the workflow',
        description:
            'Try unusual but legitimate cases: cancellations, disputes, role changes, multiple offers, slow connections, interrupted sessions, and account switching. Good beta testing finds weak assumptions.',
        accent: HDCColors.warning,
      ),
      _SupportPath(
        icon: Icons.campaign_outlined,
        title: 'Share HDC responsibly',
        description:
            'Recommend HDC to people who actually need technology support or to technicians who can give useful beta feedback. Useful testers matter more than raw sign-up numbers.',
        accent: HDCColors.secondary,
      ),
      _SupportPath(
        icon: Icons.lightbulb_outline_rounded,
        title: 'Suggest practical improvements',
        description:
            'Send feature ideas tied to a real problem, user type, or workflow. The strongest suggestions explain what is difficult today and what a better outcome should look like.',
        accent: HDCColors.signal,
      ),
      _SupportPath(
        icon: Icons.menu_book_outlined,
        title: 'Suggest troubleshooting topics',
        description:
            'Tell HDC which devices, errors, software, POS issues, or recurring support problems deserve better guided troubleshooting coverage in future knowledge features.',
        accent: HDCColors.electric,
      ),
      _SupportPath(
        icon: Icons.handshake_outlined,
        title: 'Offer partnership or resources',
        description:
            'Businesses, technical groups, schools, service providers, sponsors, or infrastructure partners can contact the owner directly for serious collaboration discussions.',
        accent: HDCColors.success,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The support HDC needs most right now',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'The beta gets stronger when support produces better evidence, better decisions, and better real-world coverage.',
          style: TextStyle(
            color: HDCColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            final itemWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - ((columns - 1) * 14)) / columns;

            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final item in items)
                  SizedBox(
                    width: itemWidth,
                    child: _SupportPathCard(item: item),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SupportPath {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  const _SupportPath({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });
}

class _SupportPathCard extends StatelessWidget {
  final _SupportPath item;

  const _SupportPathCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: item.accent.withValues(alpha: 0.20)),
            ),
            child: Icon(item.icon, color: item.accent),
          ),
          const SizedBox(height: 16),
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            item.description,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FundingAndPartnershipCard extends StatelessWidget {
  final VoidCallback onContactOwner;

  const _FundingAndPartnershipCard({required this.onContactOwner});

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.primaryDeep,
      borderColor: HDCColors.accent.withValues(alpha: 0.22),
      elevated: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FINANCIAL SUPPORT & PARTNERSHIPS',
                style: TextStyle(
                  color: HDCColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Direct public contributions are not enabled yet.',
                style: TextStyle(
                  color: HDCColors.textLight,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'I am intentionally leaving payment buttons disabled until HDC has an approved payment destination, clear contribution terms, and a public explanation of how support funds the platform. Serious sponsorship, infrastructure, or partnership proposals can already go directly to the owner.',
                style: TextStyle(
                  color: HDCColors.textLight.withValues(alpha: 0.74),
                  height: 1.55,
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onContactOwner,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Contact Owner'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 20), button],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 28),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _TrustBoundaryCard extends StatelessWidget {
  const _TrustBoundaryCard();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'No purchased ratings or review manipulation.',
      'No purchased verification or trust status.',
      'No moderation or dispute exceptions for supporters.',
      'No access to private user, transaction, chat, or internal data.',
      'No guaranteed product decisions in exchange for money or influence.',
    ];

    return HDCCard(
      borderColor: HDCColors.success.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: HDCColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Support must never buy trust',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Anyone may support HDC, but support does not change platform rules, reputation, verification, safety decisions, or access controls.',
            style: TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: HDCColors.success,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      rule,
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        height: 1.4,
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

class _WhatHelpsMostCard extends StatelessWidget {
  const _WhatHelpsMostCard();

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.surfaceInteractive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A useful support report includes',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('What you were trying to do')),
              Chip(label: Text('What actually happened')),
              Chip(label: Text('Steps to reproduce')),
              Chip(label: Text('Device / browser / platform')),
              Chip(label: Text('HDC reference ID when relevant')),
              Chip(label: Text('Screenshot without private data')),
              Chip(label: Text('What you expected instead')),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Do not include passwords, one-time codes, recovery answers, full banking details, private keys, or another user’s confidential data in a support report.',
            style: TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
