import '../models/service_request.dart';

abstract class ServiceRequestRepository {
  Future<void> initialize();

  Future<void> refresh();

  List<ServiceRequest> getAll();

  ServiceRequest? byId(String id);

  Future<void> create(ServiceRequest request);

  Future<void> update(ServiceRequest request);

  Future<void> delete(String id);
}
