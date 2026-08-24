import 'dart:async';

import 'package:flutter/material.dart';

import '../models/service_request_draft.dart';
import '../models/technician.dart';
import '../models/ticket.dart';
import '../repositories/booking_repository.dart';

class TicketProvider extends ChangeNotifier {
  final BookingRepository _repository = BookingRepository.instance;

  String? _boundUserId;
  List<Ticket> _tickets = <Ticket>[];
  bool _disposed = false;

  String? get boundUserId => _boundUserId;
  List<Ticket> get tickets => List<Ticket>.unmodifiable(_tickets);

  void bindUser(String? userId) {
    if (_disposed || _boundUserId == userId) return;
    _boundUserId = userId;
    _tickets = userId == null
        ? <Ticket>[]
        : _repository.getAllTickets(userId);
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  void loadTickets() {
    final userId = _boundUserId;
    _tickets = userId == null
        ? <Ticket>[]
        : _repository.getAllTickets(userId);
    notifyListeners();
  }

  Ticket createTicket({
    required Technician technician,
    required ServiceRequestDraft request,
  }) {
    final userId = _boundUserId;
    if (userId == null) {
      throw StateError('A registered HDC account is required to book.');
    }

    final ticket = _repository.createBooking(
      customerId: userId,
      technician: technician,
      request: request,
    );
    loadTickets();
    return ticket;
  }

  Ticket? findTicket(String id) {
    final userId = _boundUserId;
    if (userId == null) return null;
    return _repository.findTicket(
      customerId: userId,
      ticketId: id,
    );
  }

  void updateStatus(String id, TicketStatus status) {
    final userId = _boundUserId;
    if (userId == null) {
      throw StateError('A registered HDC account is required.');
    }
    _repository.updateTicketStatus(
      customerId: userId,
      ticketId: id,
      status: status,
    );
    loadTickets();
  }

  void clearTickets() {
    final userId = _boundUserId;
    if (userId == null) return;
    _repository.clearAll(userId);
    loadTickets();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
