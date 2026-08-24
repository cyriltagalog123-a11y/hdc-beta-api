import '../models/transaction_seed.dart';

abstract class TransactionSeedRepository {
  Future<void> initialize();

  List<TransactionSeed> getAll();

  TransactionSeed? byId(String id);

  TransactionSeed? byRequestId(String requestId);

  Future<void> create(TransactionSeed seed);

  Future<void> update(TransactionSeed seed);

  Future<void> delete(String id);
}
