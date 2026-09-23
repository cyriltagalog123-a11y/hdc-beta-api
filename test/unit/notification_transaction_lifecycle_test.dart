import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/auth/auth_session_store.dart';
import 'package:hdc_app/providers/hdc_notification_center_provider.dart';
import 'package:hdc_app/providers/hdc_transaction_tools_provider.dart';

class _Call {
  final String method;
  final String path;
  final result = Completer<Map<String, dynamic>>();
  _Call(this.method, this.path);
}

class _Api extends HdcWorkflowApiClient {
  final calls = <_Call>[];
  _Api()
      : super(
          baseUri: Uri.parse('https://example.test'),
          sessionStore: MemoryAuthSessionStore(),
        );
  Future<Map<String, dynamic>> _call(String method, String path) {
    final call = _Call(method, path);
    calls.add(call);
    return call.result.future;
  }

  @override
  Future<Map<String, dynamic>> get(String path) => _call('GET', path);
  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, Object?>? body}) =>
      _call('POST', path);
  @override
  Future<Map<String, dynamic>> put(String path, {required Map<String, Object?> body}) =>
      _call('PUT', path);
}

Map<String, dynamic> _notification(String id, {bool read = false}) => {
      'id': id,
      'title': id,
      'createdAt': '2026-09-22T00:00:00Z',
      if (read) 'readAt': '2026-09-22T01:00:00Z',
    };
Map<String, dynamic> _notifications(String id, {bool read = false, int? total}) => {
      'notifications': [_notification(id, read: read)],
      'unreadCount': total ?? (read ? 0 : 1),
    };
Map<String, dynamic> _toolbox(String id, int paid) => {
      'toolbox': {
        'transactionId': id,
        'confirmedPaidMinor': paid,
        'updatedAt': '2026-09-22T00:00:00Z',
      },
    };

void main() {
  test('notifications load a new login while the old login is still loading', () async {
    final api = _Api();
    final provider = HdcNotificationCenterProvider(client: api)..bindUser('first');
    await pumpEventQueue();
    expect(api.calls, hasLength(1));
    provider.bindUser(null);
    provider.bindUser('second');
    await pumpEventQueue();
    expect(api.calls, hasLength(2));
    api.calls[0].result.complete(_notifications('private-old-account'));
    await pumpEventQueue();
    expect(provider.notifications, isEmpty);
    expect(provider.isLoading, isTrue);
    api.calls[1].result.complete(_notifications('current-account'));
    await pumpEventQueue();
    expect(provider.notifications.single.id, 'current-account');
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });

  for (final all in [false, true]) {
    test('notification ${all ? 'mark all' : 'mark one'} cannot be undone by an older read', () async {
      final api = _Api();
      final provider = HdcNotificationCenterProvider(client: api)..bindUser('member');
      await pumpEventQueue();
      api.calls[0].result.complete(_notifications('notice', total: 105));
      await pumpEventQueue();
      final oldRead = provider.refresh();
      final write = all ? provider.markAllRead() : provider.markRead('notice');
      api.calls[2].result.complete({'notification': _notification('notice', read: true)});
      await write;
      expect(provider.notifications.single.isUnread, isFalse);
      expect(provider.unreadCount, all ? 0 : 104);
      expect(api.calls, hasLength(4));
      api.calls[1].result.complete(_notifications('notice', total: 105));
      await oldRead;
      expect(provider.notifications.single.isUnread, isFalse);
      expect(provider.isLoading, isTrue);
      api.calls[3].result.complete(_notifications('notice', read: true, total: all ? 0 : 104));
      await pumpEventQueue();
      expect(provider.isLoading, isFalse);
      provider.dispose();
    });
  }

  test('notification writes from an old account cannot refresh the new account', () async {
    final api = _Api();
    final provider = HdcNotificationCenterProvider(client: api)..bindUser('first');
    await pumpEventQueue();
    api.calls[0].result.complete(_notifications('first'));
    await pumpEventQueue();
    final write = provider.markAllRead();
    provider.bindUser('second');
    await pumpEventQueue();
    api.calls[2].result.complete(_notifications('second'));
    await pumpEventQueue();
    api.calls[1].result.complete({});
    await write;
    expect(api.calls, hasLength(3));
    expect(provider.notifications.single.id, 'second');
    expect(provider.unreadCount, 1);
    provider.dispose();
  });

  test('notification writes reject mismatched records and ignore disposal', () async {
    final api = _Api();
    final provider = HdcNotificationCenterProvider(client: api)..bindUser('member');
    await pumpEventQueue();
    api.calls[0].result.complete(_notifications('expected'));
    await pumpEventQueue();
    final write = provider.markRead('expected');
    final rejected = expectLater(write, throwsA(isA<HdcWorkflowException>()));
    api.calls[1].result.complete({'notification': _notification('wrong', read: true)});
    await rejected;
    expect(provider.notifications.single.isUnread, isTrue);
    final pending = provider.refresh();
    provider.dispose();
    api.calls[2].result.completeError(StateError('Disposed read'));
    await pending;
    await expectLater(provider.markAllRead(), throwsA(isA<HdcWorkflowException>()));
    expect(api.calls, hasLength(3));
  });

  test('service tools reset saving after account change without accepting the old response', () async {
    final api = _Api();
    final provider = HdcTransactionToolsProvider(client: api)..bindUser('first');
    final old = provider.recordPayment(transactionId: 'old', amountMinor: 100, paymentMethod: 'cash');
    final rejected = expectLater(old, throwsA(isA<StateError>()));
    provider.bindUser('second');
    expect(provider.isSaving, isFalse);
    final current = provider.recordPayment(transactionId: 'new', amountMinor: 200, paymentMethod: 'cash');
    api.calls[0].result.complete(_toolbox('old', 100));
    await rejected;
    expect(provider.forTransaction('old'), isNull);
    expect(provider.isSaving, isTrue);
    api.calls[1].result.complete(_toolbox('new', 200));
    await current;
    expect(provider.forTransaction('new')!.confirmedPaidMinor, 200);
    expect(provider.isSaving, isFalse);
    provider.dispose();
  });

  test('service tools retain the newest read for each transaction and loading stays accurate', () async {
    final api = _Api();
    final provider = HdcTransactionToolsProvider(client: api)..bindUser('member');
    final old = provider.refresh('one');
    final current = provider.refresh('one');
    final other = provider.refresh('two');
    api.calls[1].result.complete(_toolbox('one', 200));
    await current;
    api.calls[0].result.complete(_toolbox('one', 100));
    await old;
    expect(provider.forTransaction('one')!.confirmedPaidMinor, 200);
    expect(provider.isLoading, isTrue);
    api.calls[2].result.complete(_toolbox('two', 300));
    await other;
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });

  test('service tools keep saved payment data when pre-write and mid-write reads finish late', () async {
    final api = _Api();
    final provider = HdcTransactionToolsProvider(client: api)..bindUser('member');
    final before = provider.refresh('one');
    final write = provider.recordPayment(transactionId: 'one', amountMinor: 500, paymentMethod: 'cash');
    final during = provider.refresh('one');
    api.calls[1].result.complete(_toolbox('one', 500));
    await write;
    api.calls[0].result.complete(_toolbox('one', 0));
    api.calls[2].result.complete(_toolbox('one', 0));
    await Future.wait([before, during]);
    expect(provider.forTransaction('one')!.confirmedPaidMinor, 500);
    expect(provider.isLoading, isFalse);
    provider.dispose();
  });

  test('service tool reads reject mismatched transactions and writes after disposal', () async {
    final api = _Api();
    final provider = HdcTransactionToolsProvider(client: api)..bindUser('member');
    final read = provider.refresh('one');
    final rejected = expectLater(read, throwsA(isA<HdcWorkflowException>()));
    api.calls[0].result.complete(_toolbox('wrong', 100));
    await rejected;
    expect(provider.forTransaction('one'), isNull);
    expect(provider.isLoading, isFalse);
    provider.dispose();
    await expectLater(provider.recordPayment(transactionId: 'one', amountMinor: 100, paymentMethod: 'cash'),
        throwsA(isA<HdcWorkflowException>()));
    expect(api.calls, hasLength(1));
  });
}
