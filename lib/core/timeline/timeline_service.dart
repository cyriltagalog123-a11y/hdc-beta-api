import 'timeline_entry.dart';

class TimelineService {
  TimelineService._();

  static final TimelineService instance =
      TimelineService._();

  final List<TimelineEntry> _entries = [];

  List<TimelineEntry> history(
    String entityId,
  ) {
    return _entries
        .where(
          (entry) =>
              entry.entityId == entityId,
        )
        .toList();
  }

  void addEntry(
    TimelineEntry entry,
  ) {
    _entries.insert(
      0,
      entry,
    );
  }

  void clear() {
    _entries.clear();
  }
}