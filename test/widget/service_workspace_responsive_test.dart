import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hdc_app/core/ui/hdc_theme.dart';
import 'package:hdc_app/features/transactions/service_transaction_workspace_screen.dart';
import 'package:hdc_app/models/service_transaction.dart';
import 'package:hdc_app/providers/service_transaction_provider.dart';
import 'package:hdc_app/repositories/service_transaction_repository.dart';
import 'package:hdc_app/repositories/transaction_seed_repository.dart';

void main() {
  late ServiceTransaction transaction;
  late ServiceTransactionProvider provider;

  setUp(() {
    transaction = _transaction();
    provider = ServiceTransactionProvider(
      repository: _TransactionRepository(transaction),
      seedRepository: _SeedRepository(),
    );
  });

  Widget workspace({
    String actorId = 'tech-1',
    ServiceTransactionParticipantRole role =
        ServiceTransactionParticipantRole.technician,
  }) {
    return ChangeNotifierProvider<ServiceTransactionProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: HDCTheme.lightTheme,
        home: ServiceTransactionWorkspaceScreen(
          transactionId: transaction.id,
          actorId: actorId,
          role: role,
        ),
      ),
    );
  }

  testWidgets('compact technician workspace keeps the next action reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(workspace());

    expect(find.byKey(const Key('hdc-service-workspace')), findsOneWidget);
    expect(find.byKey(const Key('hdc-workspace-next-action')), findsOneWidget);
    expect(
      find.byKey(const Key('hdc-workspace-primary-action')),
      findsOneWidget,
    );
    expect(find.text('Accepted Service Terms'), findsOneWidget);
    expect(find.text('Workspace Tools'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide workspace separates the record and participant rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(workspace());

    final terms = tester.getTopLeft(
      find.byKey(const Key('hdc-accepted-service-terms')),
    );
    final participants = tester.getTopLeft(
      find.byKey(const Key('hdc-service-participants')),
    );
    expect(participants.dx, greaterThan(terms.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mismatched role reveals no transaction details', (tester) async {
    await tester.pumpWidget(
      workspace(
        actorId: 'customer-1',
        role: ServiceTransactionParticipantRole.technician,
      ),
    );

    expect(
      find.byKey(const Key('hdc-workspace-access-unavailable')),
      findsOneWidget,
    );
    expect(find.text(transaction.requestTitle), findsNothing);
    expect(find.text(transaction.technicianName), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _TransactionRepository extends Fake
    implements ServiceTransactionRepository {
  final ServiceTransaction transaction;

  _TransactionRepository(this.transaction);

  @override
  ServiceTransaction? byId(String id) =>
      id == transaction.id ? transaction : null;

  @override
  List<ServiceTransaction> getAll() => [transaction];
}

class _SeedRepository extends Fake implements TransactionSeedRepository {}

ServiceTransaction _transaction() {
  final createdAt = DateTime.utc(2026, 9, 2, 8);
  return ServiceTransaction(
    id: 'TXN-BUILD24C',
    seedId: 'SEED-BUILD24C',
    requestId: 'SR-BUILD24C',
    proposalId: 'PR-BUILD24C',
    customerId: 'customer-1',
    customerName: 'Customer One',
    technicianId: 'tech-1',
    technicianName: 'Technician One',
    requestTitle: 'Laptop power and display repair',
    categoryName: 'Computer Repair',
    serviceLocation: 'Cebu City',
    status: ServiceTransactionStatus.confirmed,
    acceptedTerms: AcceptedServiceTerms(
      serviceFee: 1200,
      estimatedPartsCost: 500,
      totalEstimate: 1700,
      earliestArrival: DateTime.utc(2026, 9, 3, 9),
      estimatedDurationMinutes: 120,
      warrantyDays: 30,
      diagnosis: 'Possible power delivery fault.',
      repairApproach: 'Inspect power and display circuits.',
      professionalNotes: 'Parts require Customer approval.',
    ),
    activity: [
      ServiceTransactionActivity(
        id: 'ACT-BUILD24C',
        type: ServiceTransactionActivityType.transactionConfirmed,
        message: 'The accepted service workspace was confirmed.',
        createdAt: createdAt,
      ),
    ],
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}
