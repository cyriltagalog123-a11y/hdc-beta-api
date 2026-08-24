import 'package:flutter/material.dart';

import 'timeline_entry.dart';
import 'timeline_service.dart';

class TimelineProvider
    extends ChangeNotifier {

  final TimelineService _service =
      TimelineService.instance;

  List<TimelineEntry> history(
    String entityId,
  ) {
    return _service.history(
      entityId,
    );
  }

  void add(
    TimelineEntry entry,
  ) {
    _service.addEntry(
      entry,
    );

    notifyListeners();
  }

  void clear() {
    _service.clear();

    notifyListeners();
  }
}