import '../models/service_request_draft.dart';
import '../models/technician.dart';

class ServiceDiscoveryRepository {
  ServiceDiscoveryRepository._();

  static final ServiceDiscoveryRepository instance =
      ServiceDiscoveryRepository._();

  Future<List<Technician>> discoverServices(
    ServiceRequestDraft _,
  ) async {
    // Live mode must never manufacture technician accounts or reputation.
    // This stays empty until the public technician-discovery API is connected.
    return const <Technician>[];
  }
}
