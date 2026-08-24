import '../models/service_transaction.dart';

abstract interface class ServiceTransactionTransitionGateway {
  Future<ServiceTransaction> transition({
    required String transactionId,
    required ServiceTransactionStatus toStatus,
    required String actingUserId,
  });
}
