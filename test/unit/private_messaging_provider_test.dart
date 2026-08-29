import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hdc_app/models/private_conversation.dart';
import 'package:hdc_app/models/service_transaction.dart';
import 'package:hdc_app/providers/private_messaging_provider.dart';
import 'package:hdc_app/repositories/private_conversation_repository.dart';
import 'package:hdc_app/repositories/private_messaging_gateway.dart';
import 'package:hdc_app/repositories/service_transaction_repository.dart';

void main() {
  test('an old account response cannot enter the new account chat cache', () async {
    final gateway = _DelayedMessagingGateway();
    final provider = PrivateMessagingProvider(
      repository: _UnusedConversationRepository(),
      transactionRepository: _TransactionRepository(_transaction),
      gateway: gateway,
    );
    await provider.initialize();
    provider.bindUser('customer-1');

    final accountARequest = provider.ensureConversation(
      transactionId: 'TXN-1',
      actorId: 'customer-1',
    );
    await Future<void>.delayed(Duration.zero);

    provider.bindUser('technician-1');
    gateway.completer.complete(_conversation);

    await expectLater(
      accountARequest,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('account changed'),
        ),
      ),
    );
    expect(provider.forTransaction('TXN-1'), isNull);
    provider.dispose();
  });

  test('remote chat rejects an actor other than the bound account', () async {
    final provider = PrivateMessagingProvider(
      repository: _UnusedConversationRepository(),
      transactionRepository: _TransactionRepository(_transaction),
      gateway: _DelayedMessagingGateway(),
    );
    await provider.initialize();
    provider.bindUser('customer-1');

    await expectLater(
      provider.ensureConversation(
        transactionId: 'TXN-1',
        actorId: 'technician-1',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('currently signed-in'),
        ),
      ),
    );
    provider.dispose();
  });

  test('technician participant can open the accepted-service chat', () async {
    final gateway = _ControlledMessagingGateway();
    final provider = PrivateMessagingProvider(
      repository: _UnusedConversationRepository(),
      transactionRepository: _TransactionRepository(_transaction),
      gateway: gateway,
    );
    await provider.initialize();
    provider.bindUser('technician-1');

    final conversation = await provider.ensureConversation(
      transactionId: 'TXN-1',
      actorId: 'technician-1',
    );

    expect(conversation.id, 'CONV-1');
    expect(provider.forTransaction('TXN-1')?.technicianId, 'technician-1');
    provider.dispose();
  });

  test('a rapid second send cannot create a duplicate message', () async {
    final gateway = _ControlledMessagingGateway();
    final provider = PrivateMessagingProvider(
      repository: _UnusedConversationRepository(),
      transactionRepository: _TransactionRepository(_transaction),
      gateway: gateway,
    );
    await provider.initialize();
    provider.bindUser('customer-1');

    final firstSend = provider.sendMessage(
      transactionId: 'TXN-1',
      senderId: 'customer-1',
      text: 'Please confirm the schedule.',
    );
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      provider.sendMessage(
        transactionId: 'TXN-1',
        senderId: 'customer-1',
        text: 'Please confirm the schedule.',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('still being sent'),
        ),
      ),
    );

    gateway.sendCompleter.complete(_conversationWithMessage);
    await firstSend;
    expect(gateway.sendCalls, 1);
    expect(provider.forTransaction('TXN-1')?.messages, hasLength(1));
    provider.dispose();
  });

  test('a slower refresh cannot replace a newer sent-message snapshot', () async {
    final gateway = _ControlledMessagingGateway();
    final provider = PrivateMessagingProvider(
      repository: _UnusedConversationRepository(),
      transactionRepository: _TransactionRepository(_transaction),
      gateway: gateway,
    );
    await provider.initialize();
    provider.bindUser('customer-1');
    await provider.ensureConversation(
      transactionId: 'TXN-1',
      actorId: 'customer-1',
    );

    final refresh = provider.refreshConversation(
      transactionId: 'TXN-1',
      actorId: 'customer-1',
    );
    await Future<void>.delayed(Duration.zero);

    gateway.sendCompleter.complete(_conversationWithMessage);
    await provider.sendMessage(
      transactionId: 'TXN-1',
      senderId: 'customer-1',
      text: 'Please confirm the schedule.',
    );
    gateway.refreshCompleter.complete(_olderConversation);
    await refresh;

    expect(
      provider.forTransaction('TXN-1')?.messages.single.body,
      'Please confirm the schedule.',
    );
    provider.dispose();
  });

  test('messages longer than the backend limit are rejected locally', () async {
    final gateway = _ControlledMessagingGateway();
    final provider = PrivateMessagingProvider(
      repository: _UnusedConversationRepository(),
      transactionRepository: _TransactionRepository(_transaction),
      gateway: gateway,
    );
    await provider.initialize();
    provider.bindUser('customer-1');

    await expectLater(
      provider.sendMessage(
        transactionId: 'TXN-1',
        senderId: 'customer-1',
        text: List<String>.filled(
          PrivateMessagingProvider.maxMessageLength + 1,
          'x',
        ).join(),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('1 to 4000'),
        ),
      ),
    );
    expect(gateway.sendCalls, 0);
    provider.dispose();
  });
}

class _UnusedConversationRepository extends Fake
    implements PrivateConversationRepository {}

class _TransactionRepository extends Fake
    implements ServiceTransactionRepository {
  final ServiceTransaction transaction;

  _TransactionRepository(this.transaction);

  @override
  Future<void> initialize() async {}

  @override
  ServiceTransaction? byId(String id) => id == transaction.id ? transaction : null;
}

class _DelayedMessagingGateway extends Fake
    implements PrivateMessagingGateway {
  final Completer<PrivateConversation> completer =
      Completer<PrivateConversation>();

  @override
  Future<PrivateConversation> ensureConversation({
    required String transactionId,
  }) {
    return completer.future;
  }
}

class _ControlledMessagingGateway extends Fake
    implements PrivateMessagingGateway {
  final Completer<PrivateConversation> refreshCompleter =
      Completer<PrivateConversation>();
  final Completer<PrivateConversation> sendCompleter =
      Completer<PrivateConversation>();
  int sendCalls = 0;

  @override
  Future<PrivateConversation> ensureConversation({
    required String transactionId,
  }) async {
    return _conversation;
  }

  @override
  Future<PrivateConversation> refreshConversation({
    required String transactionId,
    DateTime? changedSince,
  }) {
    return refreshCompleter.future;
  }

  @override
  Future<PrivateConversation> sendMessage({
    required String transactionId,
    required String clientMessageId,
    required String text,
    required bool acknowledgeLanguageWarning,
  }) {
    sendCalls += 1;
    return sendCompleter.future;
  }
}

final ServiceTransaction _transaction = ServiceTransaction(
  id: 'TXN-1',
  seedId: 'SEED-1',
  requestId: 'SR-1',
  proposalId: 'PR-1',
  customerId: 'customer-1',
  customerName: 'Customer',
  technicianId: 'technician-1',
  technicianName: 'Technician',
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
    diagnosis: 'Power rail issue',
    repairApproach: 'Inspect and repair',
    professionalNotes: '',
  ),
  activity: const [],
  createdAt: DateTime.utc(2026, 8, 27, 10),
  updatedAt: DateTime.utc(2026, 8, 27, 10),
);

final PrivateConversation _conversation = PrivateConversation(
  id: 'CONV-1',
  transactionId: 'TXN-1',
  customerId: 'customer-1',
  technicianId: 'technician-1',
  storage: ConversationStorageSettings(
    mode: ConversationStorageMode.hdcManaged,
    quotaBytes: 5242880,
    externalProviderConnected: false,
    storageChoiceConfirmed: true,
    updatedAt: DateTime.utc(2026, 8, 27, 10),
  ),
  messages: const [],
  createdAt: DateTime.utc(2026, 8, 27, 10),
  updatedAt: DateTime.utc(2026, 8, 27, 10),
);

final PrivateConversation _olderConversation = _conversation.copyWith(
  updatedAt: DateTime.utc(2026, 8, 27, 10, 1),
);

final PrivateConversation _conversationWithMessage = _conversation.copyWith(
  messages: [
    PrivateMessage(
      id: 'MSG-1',
      conversationId: 'CONV-1',
      senderId: 'customer-1',
      body: 'Please confirm the schedule.',
      status: PrivateMessageStatus.sent,
      languageWarningAcknowledged: false,
      createdAt: DateTime.utc(2026, 8, 27, 10, 2),
    ),
  ],
  updatedAt: DateTime.utc(2026, 8, 27, 10, 2),
);
