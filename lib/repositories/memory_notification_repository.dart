import '../models/notification_item.dart';
import 'notification_repository.dart';

class MemoryNotificationRepository
    implements NotificationRepository {

  final List<NotificationItem> _items = [];

  @override
  List<NotificationItem> getNotifications() {

    _items.sort(
      (a, b) =>
          b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return _items;
  }

  @override
  Future<void> add(
    NotificationItem item,
  ) async {

    _items.add(item);
  }

  @override
  Future<void> markRead(
    String id,
  ) async {

    final index =
        _items.indexWhere(
      (n) => n.id == id,
    );

    if (index != -1) {

      _items[index] =
          _items[index].copyWith(
        read: true,
      );
    }
  }

  @override
  Future<void> clear() async {

    _items.clear();
  }
}