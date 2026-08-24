import '../models/notification_item.dart';

abstract class NotificationRepository {

  List<NotificationItem> getNotifications();

  Future<void> add(
    NotificationItem item,
  );

  Future<void> markRead(
    String id,
  );

  Future<void> clear();
}