import 'platform_event.dart';

class EventService {
  EventService._();

  static final EventService instance =
      EventService._();

  final List<PlatformEvent> _events = [];

  List<PlatformEvent> get events =>
      List.unmodifiable(_events);

  void publish(
    PlatformEvent event,
  ) {
    _events.insert(0, event);
  }

  void clear() {
    _events.clear();
  }
}