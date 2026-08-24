import '../../models/ticket.dart';

class TicketMemoryDataSource {
  TicketMemoryDataSource._();

  static final TicketMemoryDataSource instance =
      TicketMemoryDataSource._();

  final List<Ticket> _tickets = [];

  List<Ticket> getAllTickets() {
    return List.unmodifiable(_tickets);
  }

  void addTicket(Ticket ticket) {
    _tickets.add(ticket);
  }

  Ticket? findTicket(String ticketId) {
    try {
      return _tickets.firstWhere(
        (ticket) => ticket.id == ticketId,
      );
    } catch (_) {
      return null;
    }
  }

  void updateTicket(Ticket updatedTicket) {
    final index = _tickets.indexWhere(
      (ticket) => ticket.id == updatedTicket.id,
    );

    if (index == -1) return;

    _tickets[index] = updatedTicket;
  }

  void removeTicket(String ticketId) {
    _tickets.removeWhere((ticket) => ticket.id == ticketId);
  }

  void clear() {
    _tickets.clear();
  }
}
