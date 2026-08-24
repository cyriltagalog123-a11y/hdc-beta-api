import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/service_transaction.dart';
import 'service_transaction_repository.dart';

class SharedPreferencesServiceTransactionRepository
    implements ServiceTransactionRepository {
  static const _storageKey = 'hdc_service_transactions_v1';

  final List<ServiceTransaction> _transactions = [];
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);

    if (stored != null && stored.trim().isNotEmpty) {
      final decoded = jsonDecode(stored);

      if (decoded is List) {
        _transactions
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
                  (item) => ServiceTransaction.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ),
          );
      }
    }

    _initialized = true;
  }

  @override
  List<ServiceTransaction> getAll() {
    final result = [..._transactions]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<ServiceTransaction>.unmodifiable(result);
  }

  @override
  ServiceTransaction? byId(String id) {
    for (final transaction in _transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  @override
  ServiceTransaction? bySeedId(String seedId) {
    for (final transaction in _transactions) {
      if (transaction.seedId == seedId) return transaction;
    }
    return null;
  }

  @override
  ServiceTransaction? byRequestId(String requestId) {
    for (final transaction in _transactions.reversed) {
      if (transaction.requestId == requestId) return transaction;
    }
    return null;
  }

  @override
  List<ServiceTransaction> byCustomerId(String customerId) {
    return getAll()
        .where((transaction) => transaction.customerId == customerId)
        .toList(growable: false);
  }

  @override
  List<ServiceTransaction> byTechnicianId(String technicianId) {
    return getAll()
        .where((transaction) => transaction.technicianId == technicianId)
        .toList(growable: false);
  }

  @override
  Future<void> create(ServiceTransaction transaction) async {
    if (byId(transaction.id) != null ||
        bySeedId(transaction.seedId) != null ||
        byRequestId(transaction.requestId) != null) {
      throw StateError(
        'A service transaction already exists for this request.',
      );
    }

    _transactions.add(transaction);
    await _persist();
  }

  @override
  Future<void> update(ServiceTransaction transaction) async {
    final index = _transactions.indexWhere(
      (item) => item.id == transaction.id,
    );

    if (index == -1) {
      throw StateError(
        'Service transaction ${transaction.id} was not found.',
      );
    }

    _transactions[index] = transaction;
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    _transactions.removeWhere((transaction) => transaction.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(
        _transactions.map((transaction) => transaction.toJson()).toList(),
      ),
    );

    if (!saved) {
      throw StateError('Service transaction data could not be saved.');
    }
  }
}
