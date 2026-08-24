import '../data/datasources/ticket_memory_datasource.dart';

import '../models/service_request_draft.dart';
import '../models/technician.dart';
import '../models/ticket.dart';

import '../services/ticket_generator.dart';

class BookingRepository {
  BookingRepository._();

  static final BookingRepository instance =
      BookingRepository._();

  final TicketMemoryDataSource _dataSource =
      TicketMemoryDataSource.instance;

  Ticket createBooking({
    required String customerId,
    required Technician technician,
    required ServiceRequestDraft request,
  }) {
    final ticket = Ticket(
      id: TicketGenerator.generateTicketId(),
      customerId: customerId,
      technician: technician,
      request: request,
      createdAt: DateTime.now(),
      status: TicketStatus.pending,
    );

    _dataSource.addTicket(ticket);

    return ticket;
  }

  List<Ticket> getAllTickets(String customerId) {
    return _dataSource
        .getAllTickets()
        .where((ticket) => ticket.customerId == customerId)
        .toList(growable: false);
  }

  Ticket? findTicket({
    required String customerId,
    required String ticketId,
  }) {
    final ticket = _dataSource.findTicket(ticketId);
    return ticket?.customerId == customerId ? ticket : null;
  }

  void updateTicketStatus({
    required String customerId,
    required String ticketId,
    required TicketStatus status,
  }) {
    final oldTicket = findTicket(
      customerId: customerId,
      ticketId: ticketId,
    );

    if (oldTicket == null) return;

    final updatedTicket = Ticket(
      id: oldTicket.id,
      customerId: oldTicket.customerId,
      technician: oldTicket.technician,
      request: oldTicket.request,
      createdAt: oldTicket.createdAt,
      status: status,
    );

    _dataSource.updateTicket(updatedTicket);
  }

  void clearAll(String customerId) {
    final ticketIds = getAllTickets(customerId)
        .map((ticket) => ticket.id)
        .toList(growable: false);
    for (final ticketId in ticketIds) {
      _dataSource.removeTicket(ticketId);
    }
  }
}
