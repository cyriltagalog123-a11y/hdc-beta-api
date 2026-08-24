import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/transaction_seed.dart';
import 'transaction_seed_repository.dart';

class SharedPreferencesTransactionSeedRepository
    implements TransactionSeedRepository {
  static const _storageKey = 'hdc_transaction_seeds_v1';

  final List<TransactionSeed> _seeds = [];
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_storageKey);

    if (stored != null && stored.trim().isNotEmpty) {
      final decoded = jsonDecode(stored);
      if (decoded is List) {
        _seeds
          ..clear()
          ..addAll(
            decoded.whereType<Map>().map(
                  (item) => TransactionSeed.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ),
          );
      }
    }

    _initialized = true;
  }

  @override
  List<TransactionSeed> getAll() =>
      List<TransactionSeed>.unmodifiable(_seeds);

  @override
  TransactionSeed? byId(String id) {
    for (final seed in _seeds) {
      if (seed.id == id) return seed;
    }
    return null;
  }

  @override
  TransactionSeed? byRequestId(String requestId) {
    for (final seed in _seeds.reversed) {
      if (seed.requestId == requestId) return seed;
    }
    return null;
  }

  @override
  Future<void> create(TransactionSeed seed) async {
    if (byId(seed.id) != null || byRequestId(seed.requestId) != null) {
      throw StateError('A transaction handoff already exists for this request.');
    }
    _seeds.add(seed);
    await _persist();
  }

  @override
  Future<void> update(TransactionSeed seed) async {
    final index = _seeds.indexWhere((item) => item.id == seed.id);
    if (index == -1) {
      throw StateError('Transaction handoff ${seed.id} was not found.');
    }
    _seeds[index] = seed;
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    _seeds.removeWhere((seed) => seed.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _storageKey,
      jsonEncode(_seeds.map((seed) => seed.toJson()).toList()),
    );
    if (!saved) {
      throw StateError('Transaction handoff data could not be saved locally.');
    }
  }
}
