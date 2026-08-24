import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import '../repositories/notification_repository.dart';

class NotificationProvider
    extends ChangeNotifier {

  final NotificationRepository repository;

  NotificationProvider({
    required this.repository,
  });

  List<NotificationItem> get notifications =>
      repository.getNotifications();

  Future<void> notify(
    NotificationItem item,
  ) async {

    await repository.add(item);

    notifyListeners();
  }

  Future<void> read(
    String id,
  ) async {

    await repository.markRead(id);

    notifyListeners();
  }

  Future<void> clear() async {

    await repository.clear();

    notifyListeners();
  }
}