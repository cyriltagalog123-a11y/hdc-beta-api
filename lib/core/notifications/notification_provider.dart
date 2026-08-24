import 'package:flutter/material.dart';

import 'event_service.dart';
import 'platform_event.dart';

class NotificationProvider
    extends ChangeNotifier {

  final EventService _service =
      EventService.instance;

  List<PlatformEvent> get events =>
      _service.events;

  void publish(
    PlatformEvent event,
  ) {
    _service.publish(event);

    notifyListeners();
  }

  void clear() {
    _service.clear();

    notifyListeners();
  }
}