import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/hdc_card.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';

class ContactOwnerScreen extends StatelessWidget {
  static const ownerEmail = 'saicore.holdings@gmail.com';

  const ContactOwnerScreen({super.key});

  Future<void> _copy(
    BuildContext context, {
    required String value,
    required String confirmation,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(confirmation)),
    );
  }

  String get _messageTemplate => '''Subject: HDC Owner Contact — [topic]\n\nName: [your name]\nHDC account email (if relevant): [email]\nHDC reference ID (if any): [request / transaction / dispute ID]\nTopic: [partnership / platform concern / privacy / ownership / other]\n\nSummary:\n[Explain what happened or what you want to discuss.]\n\nRequested outcome:\n[Explain what you are asking the owner to review or consider.]''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Owner')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(HDCSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HDCFlowHero(
                    eyebrow: 'SAICORE / HDC OWNER CONTACT',
                    title: 'A direct channel for matters that need the owner.',
                    description:
                        'Use this page for ownership-level questions, business or partnership discussions, serious platform concerns, privacy matters, or issues that cannot be handled through the normal HDC service workflow.',
                    icon: Icons.account_balance_outlined,
                    tags: [
                      HDCFlowTag(
                        label: 'Direct email',
                        icon: Icons.alternate_email,
                      ),
                      HDCFlowTag(
                        label: 'No account required',
                        icon: Icons.public_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  HDCCard(
                    elevated: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OWNER EMAIL',
                          style: TextStyle(
                            color: HDCColors.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const SelectableText(
                          ownerEmail,
                          style: TextStyle(
                            color: HDCColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'HDC does not send the email for you. Copy this address and use your preferred email service so you keep control of what you send.',
                          style: TextStyle(
                            color: HDCColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _copy(
                                context,
                                value: ownerEmail,
                                confirmation: 'Owner email copied.',
                              ),
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy Email Address'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _copy(
                                context,
                                value: _messageTemplate,
                                confirmation: 'Contact template copied.',
                              ),
                              icon: const Icon(Icons.description_outlined),
                              label: const Text('Copy Email Template'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: HDCSpacing.lg),
                  const _ContactTopics(),
                  const SizedBox(height: HDCSpacing.lg),
                  const _EmailSafetyCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactTopics extends StatelessWidget {
  const _ContactTopics();

  @override
  Widget build(BuildContext context) {
    const topics = [
      (
        Icons.business_center_outlined,
        'Partnerships & business',
        'Sponsorship proposals, business relationships, platform partnerships, or serious commercial discussions.',
      ),
      (
        Icons.gavel_outlined,
        'Ownership, legal & privacy',
        'Ownership-level questions, privacy escalation, formal notices, or matters that require executive review.',
      ),
      (
        Icons.report_problem_outlined,
        'Serious platform concerns',
        'Concerns involving abuse of platform authority, unresolved administrative issues, or risks that should reach the owner directly.',
      ),
      (
        Icons.lightbulb_outline_rounded,
        'Strategic proposals',
        'High-impact ideas, collaboration proposals, or offers that go beyond ordinary product feedback.',
      ),
    ];

    return HDCCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When to contact the owner',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Routine service requests should stay inside HDC so they retain their transaction history and participant protections.',
            style: TextStyle(
              color: HDCColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < topics.length; index += 1) ...[
            _TopicRow(
              icon: topics[index].$1,
              title: topics[index].$2,
              description: topics[index].$3,
            ),
            if (index < topics.length - 1) const Divider(height: 24),
          ],
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _TopicRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: HDCColors.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: HDCColors.secondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: HDCColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmailSafetyCard extends StatelessWidget {
  const _EmailSafetyCard();

  @override
  Widget build(BuildContext context) {
    return HDCCard(
      color: HDCColors.surfaceInteractive,
      borderColor: HDCColors.warning.withValues(alpha: 0.35),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: HDCColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Email safety: never send passwords, one-time codes, secret-question answers, full card or bank credentials, or private keys. When an HDC reference ID is enough to identify a case, use the reference instead of copying sensitive transaction data into email.',
              style: TextStyle(
                color: HDCColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
