import 'audit_entry.dart';

class AuditService {
  AuditService._();

  static final AuditService instance =
      AuditService._();

  final List<AuditEntry> _entries = [];

  void log(
    AuditEntry entry,
  ) {
    _entries.insert(
      0,
      entry,
    );
  }

  List<AuditEntry> history(
    String entityId,
  ) {
    return _entries.where(
      (entry) =>
          entry.entityId == entityId,
    ).toList();
  }

  void clear() {
    _entries.clear();
  }
}