import '../models/service_request.dart';
import 'service_request_repository.dart';

class MemoryServiceRequestRepository implements ServiceRequestRepository {
  @override
  Future<void> initialize() async {}

  final List<ServiceRequest> _requests = [];

  @override
  List<ServiceRequest> getAll() {
    final requests = List<ServiceRequest>.from(_requests);
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  }

  @override
  ServiceRequest? byId(String id) {
    try {
      return _requests.firstWhere((request) => request.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<void> create(ServiceRequest request) async {
    _requests.add(request);
  }

  @override
  Future<void> update(ServiceRequest request) async {
    final index = _requests.indexWhere((item) => item.id == request.id);

    if (index == -1) {
      throw StateError('Service request ${request.id} was not found.');
    }

    _requests[index] = request;
  }

  @override
  Future<void> delete(String id) async {
    _requests.removeWhere((request) => request.id == id);
  }
}
