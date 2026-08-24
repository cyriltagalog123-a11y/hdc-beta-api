import 'package:flutter/material.dart';

import 'audit_entry.dart';
import 'audit_service.dart';

class AuditProvider
    extends ChangeNotifier {

  final AuditService _service =
      AuditService.instance;

  List<AuditEntry> history(
    String entityId,
  ) {
    return _service.history(
      entityId,
    );
  }

  void log(
    AuditEntry entry,
  ) {
    _service.log(
      entry,
    );

    notifyListeners();
  }

  void clear() {
    _service.clear();

    notifyListeners();
  }
}