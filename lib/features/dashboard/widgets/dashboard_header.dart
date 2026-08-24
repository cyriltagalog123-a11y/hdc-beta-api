import 'package:flutter/material.dart';

import '../../../core/greetings/user_greeting_service.dart';
import '../../../core/ui/hdc_colors.dart';

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
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HDCColors.primary,
            HDCColors.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: HDCColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showProfile = constraints.maxWidth >= 620;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.support_agent,
                          color: Colors.white,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'HELPDESK CONNECT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 680,
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          height: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                  ],
                ),
              ),
              if (showProfile) ...[
                const SizedBox(width: 24),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _shortId(String value) {
    final normalized = value.trim();
    if (normalized.length <= 12) return normalized;
    return normalized.substring(0, 12);
  }
}

class _RoleChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RoleChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
