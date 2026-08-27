import 'package:flutter_test/flutter_test.dart';

import 'package:hdc_app/models/service_transaction.dart';
import 'package:hdc_app/providers/service_transaction_provider.dart';
import 'package:hdc_app/repositories/service_transaction_repository.dart';
import 'package:hdc_app/repositories/transaction_seed_repository.dart';

void main() {
  test('participant filter includes customer and technician workspaces', () {
    final provider = ServiceTransactionProvider(
      repository: _TransactionRepository([
        _transaction(
          id: 'TXN-AS-CUSTOMER',
          customerId: 'jon',
          technicianId: 'tech-a',
        ),
        _transaction(
          id: 'TXN-AS-TECHNICIAN',
          customerId: 'customer-b',
          technicianId: 'jon',
        ),
        _transaction(
          id: 'TXN-UNRELATED',
          customerId: 'customer-c',
          technicianId: 'tech-c',
        ),
      ]),
      seedRepository: _SeedRepository(),
    );

    expect(
      provider.forParticipant('jon').map((transaction) => transaction.id),
      ['TXN-AS-CUSTOMER', 'TXN-AS-TECHNICIAN'],
    );
  });
}

class _TransactionRepository extends Fake
    implements ServiceTransactionRepository {
  final List<ServiceTransaction> values;

  _TransactionRepository(this.values);

  @override
  List<ServiceTransaction> getAll() => values;
}

class _SeedRepository extends Fake implements TransactionSeedRepository {}

ServiceTransaction _transaction({
  required String id,
  required String customerId,
  required String technicianId,
}) {
  final createdAt = DateTime.utc(2026, 8, 27, 10);
  return ServiceTransaction(
    id: id,
    seedId: 'SEED-$id',
    requestId: 'SR-$id',
    proposalId: 'PR-$id',
    customerId: customerId,
    customerName: customerId,
    technicianId: technicianId,
    technicianName: technicianId,
    requestTitle: 'Laptop repair',
    categoryName: 'Computer Repair',
    serviceLocation: 'Cebu City',
    status: ServiceTransactionStatus.confirmed,
    acceptedTerms: AcceptedServiceTerms(
      serviceFee: 1000,
      totalEstimate: 1000,
      earliestArrival: DateTime.utc(2026, 8, 28, 9),
      estimatedDurationMinutes: 120,
      warrantyDays: 30,
      diagnosis: 'Power delivery issue',
      repairApproach: 'Inspect and repair',
      professionalNotes: '',
    ),
    activity: const [],
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
