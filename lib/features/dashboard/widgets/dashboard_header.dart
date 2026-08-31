import 'package:flutter/material.dart';

import '../../../core/greetings/user_greeting_service.dart';
import '../../../core/ui/hdc_brand.dart';
import '../../../core/ui/hdc_colors.dart';
import '../../../core/ui/hdc_spacing.dart';

class DashboardHeader extends StatelessWidget {
  final String displayName;
  final int activeTransactions;
  final int newOffers;
  final bool guestMode;
  final List<String> platformRoleLabels;
  final String? email;
  final String? accountId;

  const DashboardHeader({
    this.displayName = 'Guest',
    this.activeTransactions = 0,
    this.newOffers = 0,
    this.guestMode = false,
    this.platformRoleLabels = const ['Customer'],
    this.email,
    this.accountId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const greetingService = UserGreetingService();
    final greeting = guestMode
        ? 'Welcome to HelpDesk Connect'
        : greetingService.greeting(displayName: displayName);
    final message = guestMode
        ? 'You are browsing in Guest mode. Explore HDC and technician '
              'services freely; create an account or sign in before posting '
              'requests, booking services, or using account features.'
        : greetingService.returningMessage(
            activeTransactions: activeTransactions,
            newOffers: newOffers,
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HDCSpacing.radiusLarge),
        boxShadow: const [
          BoxShadow(
            color: HDCColors.shadowStrong,
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HDCSpacing.radiusLarge),
        child: HDCSignalBackdrop(
          dark: true,
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final showIdentityNode = constraints.maxWidth >= 720;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (compact) ...[
                      const HDCBrandLockup(
                        light: true,
                        compact: true,
                        markSize: 42,
                      ),
                      const SizedBox(height: 16),
                      HDCSignalPill(
                        label: guestMode ? 'GUEST PREVIEW' : 'LIVE WORKSPACE',
                        icon: guestMode
                            ? Icons.visibility_outlined
                            : Icons.bolt_rounded,
                        light: true,
                      ),
                    ] else
                      Row(
                        children: [
                          const Expanded(
                            child: HDCBrandLockup(light: true, markSize: 46),
                          ),
                          HDCSignalPill(
                            label: guestMode
                                ? 'GUEST PREVIEW'
                                : 'LIVE WORKSPACE',
                            icon: guestMode
                                ? Icons.visibility_outlined
                                : Icons.bolt_rounded,
                            light: true,
                          ),
                        ],
                      ),
                    const SizedBox(height: 34),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: TextStyle(
                                  color: HDCColors.textLight,
                                  fontSize: compact ? 27 : 34,
                                  height: 1.12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.75,
                                ),
                              ),
                              const SizedBox(height: 11),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: HDCSpacing.readableMaxWidth,
                                ),
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: HDCColors.textLight.withValues(
                                      alpha: 0.74,
                                    ),
                                    height: 1.55,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (showIdentityNode) ...[
                          const SizedBox(width: 28),
                          _IdentityNode(guestMode: guestMode),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: guestMode
                          ? const [
                              _RoleChip(
                                icon: Icons.visibility_outlined,
                                label: 'Guest Preview',
                              ),
                            ]
                          : [
                              for (final label in platformRoleLabels)
                                _RoleChip(
                                  icon: Icons.badge_outlined,
                                  label: label,
                                ),
                              const _RoleChip(
                                icon: Icons.verified_user_outlined,
                                label: 'HDC Member',
                              ),
                              if (email != null && email!.trim().isNotEmpty)
                                _RoleChip(
                                  icon: Icons.alternate_email,
                                  label: email!.trim(),
                                ),
                              if (accountId != null &&
                                  accountId!.trim().isNotEmpty)
                                _RoleChip(
                                  icon: Icons.fingerprint,
                                  label: 'Account ${_shortId(accountId!)}',
                                ),
                            ],
                    ),
                    if (!guestMode) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _PulseMetric(
                            label: 'ACTIVE SERVICES',
                            value: '$activeTransactions',
                            color: HDCColors.signal,
                          ),
                          _PulseMetric(
                            label: 'OFFERS',
                            value: '$newOffers',
                            color: HDCColors.warm,
                          ),
                          const _PulseMetric(
                            label: 'RECORD SYNC',
                            value: 'ON',
                            color: HDCColors.accent,
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _shortId(String value) {
    final normalized = value.trim();
    if (normalized.length <= 12) return normalized;
    return normalized.substring(0, 12);
  }
}

class _IdentityNode extends StatelessWidget {
  final bool guestMode;

  const _IdentityNode({required this.guestMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HDCColors.accent.withValues(alpha: 0.32)),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HDCColors.textLight.withValues(alpha: 0.09),
          border: Border.all(
            color: HDCColors.textLight.withValues(alpha: 0.16),
          ),
        ),
        child: Icon(
          guestMode ? Icons.visibility_outlined : Icons.person_outline_rounded,
          color: HDCColors.textLight,
          size: 34,
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RoleChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: HDCColors.textLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(HDCSpacing.radiusPill),
        border: Border.all(color: HDCColors.textLight.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: HDCColors.textLight),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: HDCColors.textLight,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PulseMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: HDCColors.textLight.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HDCColors.textLight.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: HDCColors.textLight.withValues(alpha: 0.56),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: HDCColors.textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
