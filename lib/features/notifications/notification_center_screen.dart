import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/hdc_notification.dart';
import '../../providers/hdc_notification_center_provider.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HdcNotificationCenterProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HdcNotificationCenterProvider>();
    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: provider.unreadCount == 0
                ? null
                : () => provider.markAllRead(),
            child: const Text('Mark all read'),
          ),
          IconButton(
            tooltip: 'Refresh notifications',
            onPressed: provider.isLoading ? null : provider.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: provider.isLoading && provider.notifications.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.notifications.isEmpty
              ? _EmptyNotifications(error: provider.lastError)
              : RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: provider.notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _NotificationCard(
                      notification: provider.notifications[index],
                      onRead: provider.markRead,
                    ),
                  ),
                ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final HdcNotification notification;
  final Future<void> Function(String id) onRead;

  const _NotificationCard({required this.notification, required this.onRead});

  @override
  Widget build(BuildContext context) {
    final color = switch (notification.priority) {
      'critical' => HDCColors.danger,
      'high' => HDCColors.warning,
      _ => HDCColors.secondary,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: notification.isUnread ? () => onRead(notification.id) : null,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.notifications_outlined, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isUnread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (notification.isUnread)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _when(notification.createdAt),
                      style: const TextStyle(
                        color: HDCColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _when(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyNotifications extends StatelessWidget {
  final Object? error;

  const _EmptyNotifications({this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none,
              size: 58,
              color: HDCColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              error == null ? 'No notifications yet' : 'Could not load notifications',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
