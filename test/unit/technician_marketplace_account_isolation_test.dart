import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdc_app/models/service_request.dart';
import 'package:hdc_app/providers/technician_marketplace_provider.dart';

Future<void> _waitUntilLoaded(TechnicianMarketplaceProvider provider) async {
  for (var attempt = 0; attempt < 20 && provider.isLoading; attempt += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(provider.isLoading, isFalse);
}

ServiceRequest _request({
  required String id,
  required String customerId,
  required String location,
  required DateTime createdAt,
  ServiceRequestUrgency urgency = ServiceRequestUrgency.normal,
}) {
  return ServiceRequest(
    id: id,
    customerId: customerId,
    customerName: 'Customer',
    title: 'Laptop repair',
    categoryId: 'laptop-repair',
    categoryName: 'Laptop Repair',
    description: 'Laptop needs diagnostics.',
    location: location,
    preferredDate: createdAt.add(const Duration(days: 1)),
    preferredTime: 'Any time',
    urgency: urgency,
    status: ServiceRequestStatus.open,
    offerCount: 0,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

void main() {
  test('saved marketplace requests stay isolated by account UUID', () async {
    const accountA = '11111111-1111-4111-8111-111111111111';
    const accountB = '22222222-2222-4222-8222-222222222222';
    SharedPreferences.setMockInitialValues({
      'hdc_technician_saved_request_ids_v2.$accountA': <String>['SR-A'],
      'hdc_technician_saved_request_ids_v2.$accountB': <String>['SR-B'],
    });
    final provider = TechnicianMarketplaceProvider();

    provider.bindUser(accountA);
    await _waitUntilLoaded(provider);
    expect(provider.isSaved('SR-A'), isTrue);
    expect(provider.isSaved('SR-B'), isFalse);

    provider.bindUser(accountB);
    expect(provider.savedCount, 0);
    await _waitUntilLoaded(provider);
    expect(provider.isSaved('SR-A'), isFalse);
    expect(provider.isSaved('SR-B'), isTrue);

    await provider.toggleSaved('SR-C');
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList(
        'hdc_technician_saved_request_ids_v2.$accountA',
      ),
      <String>['SR-A'],
    );
    expect(
      preferences.getStringList(
        'hdc_technician_saved_request_ids_v2.$accountB',
      ),
      containsAll(<String>['SR-B', 'SR-C']),
    );
    provider.dispose();
  });

  test('nearby-area ordering prioritizes matching service areas', () {
    final provider = TechnicianMarketplaceProvider();
    final now = DateTime.utc(2026, 8, 25, 10);
    final results = provider.applyFilters(
      <ServiceRequest>[
        _request(
          id: 'SR-MANILA',
          customerId: 'customer-a',
          location: 'Manila City',
          createdAt: now,
          urgency: ServiceRequestUrgency.emergency,
        ),
        _request(
          id: 'SR-CEBU',
          customerId: 'customer-b',
          location: 'Cebu City',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ],
      technicianId: 'technician-a',
      technicianLocation: 'Cebu City',
    );

    expect(results.map((request) => request.id), <String>[
      'SR-CEBU',
      'SR-MANILA',
    ]);
    provider.dispose();
  });

  test('technician opportunity feed excludes the account own requests', () {
    final provider = TechnicianMarketplaceProvider();
    final now = DateTime.utc(2026, 8, 25, 10);
    final results = provider.applyFilters(
      <ServiceRequest>[
        _request(
          id: 'SR-OWN',
          customerId: 'same-account',
          location: 'Cebu City',
          createdAt: now,
        ),
        _request(
          id: 'SR-OTHER',
          customerId: 'another-account',
          location: 'Cebu City',
          createdAt: now,
        ),
      ],
      technicianId: 'same-account',
      technicianLocation: 'Cebu City',
    );

    expect(results.map((request) => request.id), <String>['SR-OTHER']);
    provider.dispose();
  });
}
