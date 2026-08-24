import 'package:flutter/material.dart';

import 'service_request_draft.dart';
import 'technician.dart';

enum TicketStatus {
  pending,
  accepted,
  onTheWay,
  arrived,
  inProgress,
  completed,
  cancelled,
}

class Ticket {
  final String id;

  final String customerId;

  final Technician technician;

  final ServiceRequestDraft request;

  final DateTime createdAt;

  final TicketStatus status;

  const Ticket({
    required this.id,
    required this.customerId,
    required this.technician,
    required this.request,
    required this.createdAt,
    required this.status,
  });

  String get statusLabel {
    switch (status) {
      case TicketStatus.pending:
        return "Pending";

      case TicketStatus.accepted:
        return "Accepted";

      case TicketStatus.onTheWay:
        return "On The Way";

      case TicketStatus.arrived:
        return "Arrived";

      case TicketStatus.inProgress:
        return "In Progress";

      case TicketStatus.completed:
        return "Completed";

      case TicketStatus.cancelled:
        return "Cancelled";
    }
  }

  Color get statusColor {
    switch (status) {
      case TicketStatus.pending:
        return Colors.orange;

      case TicketStatus.accepted:
        return Colors.blue;

      case TicketStatus.onTheWay:
        return Colors.indigo;

      case TicketStatus.arrived:
        return Colors.teal;

      case TicketStatus.inProgress:
        return Colors.deepPurple;

      case TicketStatus.completed:
        return Colors.green;

      case TicketStatus.cancelled:
        return Colors.red;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case TicketStatus.pending:
        return Icons.schedule;

      case TicketStatus.accepted:
        return Icons.check_circle;

      case TicketStatus.onTheWay:
        return Icons.directions_car;

      case TicketStatus.arrived:
        return Icons.location_on;

      case TicketStatus.inProgress:
        return Icons.build;

      case TicketStatus.completed:
        return Icons.verified;

      case TicketStatus.cancelled:
        return Icons.cancel;
    }
  }
}
