import '../../models/platform_event.dart';

typedef EventListener =
    void Function(PlatformEvent event);

class EventBus {

  final List<EventListener> _listeners = [];

  void subscribe(
    EventListener listener,
  ) {

    _listeners.add(listener);
  }

  void unsubscribe(
    EventListener listener,
  ) {

    _listeners.remove(listener);
  }

  void publish(
    PlatformEvent event,
  ) {

    for (final listener in _listeners) {
      listener(event);
    }
  }
}