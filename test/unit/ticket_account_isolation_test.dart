import 'package:flutter_test/flutter_test.dart';

import 'package:hdc_app/models/service_request_draft.dart';
import 'package:hdc_app/models/technician.dart';
import 'package:hdc_app/providers/ticket_provider.dart';

void main() {
  test('local booking tickets stay isolated by full account UUID', () {
    const accountA = '11111111-1111-4111-8111-111111111111';
    const accountB = '22222222-2222-4222-8222-222222222222';
    const technician = Technician(
      id: '33333333-3333-4333-8333-333333333333',
      name: 'Test Technician',
      specialty: 'Computer Repair',
      rating: 0,
      completedJobs: 0,
      distanceKm: 0,
      responseMinutes: 0,
      verified: false,
      available: true,
      about: '',
      skills: <String>[],
    );
    final provider = TicketProvider();

    provider.bindUser(accountA);
    final ticketA = provider.createTicket(
      technician: technician,
      request: ServiceRequestDraft(),
    );
    expect(provider.tickets, hasLength(1));
    expect(ticketA.customerId, accountA);

    provider.bindUser(accountB);
    expect(provider.tickets, isEmpty);
    expect(provider.findTicket(ticketA.id), isNull);
    final ticketB = provider.createTicket(
      technician: technician,
      request: ServiceRequestDraft(),
    );
    expect(ticketB.customerId, accountB);
    expect(ticketB.id, isNot(ticketA.id));

    provider.bindUser(accountA);
    expect(provider.tickets.single.id, ticketA.id);
    expect(provider.findTicket(ticketB.id), isNull);

    provider.clearTickets();
    provider.bindUser(accountB);
    provider.clearTickets();
    provider.dispose();
  });
}
