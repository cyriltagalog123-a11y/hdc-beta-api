import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/hdc_notification.dart';
import '../../providers/hdc_notification_center_provider.dart';

class NotificationDetailScreen extends StatefulWidget {
  final HdcNotification notification;

  const NotificationDetailScreen({
    required this.notification,
    super.key,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.notification.isUnread) return;
      context
          .read<HdcNotificationCenterProvider>()
          .markRead(widget.notification.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final priorityColor = switch (notification.priority) {
      'critical' => HDCColors.danger,
      'high' => HDCColors.warning,
      _ => HDCColors.secondary,
    };

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Notification'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.mark_email_read_outlined,
                            color: priorityColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    avatar: Icon(
                                      Icons.flag_outlined,
                                      size: 17,
                                      color: priorityColor,
                                    ),
                                    label: Text(
                                      notification.priority.toUpperCase(),
                                    ),
                                  ),
                                  Chip(
                                    avatar: const Icon(
                                      Icons.schedule_outlined,
                                      size: 17,
                                    ),
                                    label: Text(_when(notification.createdAt)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 36),
                    SelectableText(
                      notification.message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.65,
                          ),
                    ),
                    if (_safeReferences(notification.metadata).isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'References',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: HDCColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry
                                in _safeReferences(notification.metadata).entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(
                                  '${_label(entry.key)}: ${entry.value}',
                                  style: const TextStyle(
                                    color: HDCColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: HDCColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Event: ${notification.eventType.replaceAll('_', ' ')}',
                            style: const TextStyle(
                              color: HDCColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, String> _safeReferences(Map<String, Object?> metadata) {
    const allowed = {
      'transactionId',
      'requestId',
      'purchaseRequestId',
      'publicSuggestionId',
      'publicMemberId',
      'proposalId',
      'disputeId',
      'receiptId',
      'documentId',
    };
    final result = <String, String>{};
    for (final entry in metadata.entries) {
      if (!allowed.contains(entry.key)) continue;
      final value = '${entry.value ?? ''}'.trim();
      if (value.isNotEmpty) result[entry.key] = value;
    }
    return result;
  }

  String _label(String key) {
    final spaced = key.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _when(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final meridiem = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.month}/${local.day}/${local.year} • $hour:$minute $meridiem';
  }
}
