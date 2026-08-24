import '../models/service_transaction.dart';

abstract class ServiceTransactionRepository {
  Future<void> initialize();

  List<ServiceTransaction> getAll();

  ServiceTransaction? byId(String id);

  ServiceTransaction? bySeedId(String seedId);

  ServiceTransaction? byRequestId(String requestId);

  List<ServiceTransaction> byCustomerId(String customerId);

  List<ServiceTransaction> byTechnicianId(String technicianId);

  Future<void> create(ServiceTransaction transaction);

  Future<void> update(ServiceTransaction transaction);

  Future<void> delete(String id);
}
