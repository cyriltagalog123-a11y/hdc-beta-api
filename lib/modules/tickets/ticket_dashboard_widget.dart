import 'package:flutter/material.dart';

import '../../core/dashboard/dashboard_widget.dart';

class TicketDashboardWidget {

  static DashboardWidget widget() {

    return DashboardWidget(

      id: "tickets",

      title: "Tickets",

      icon: Icons.confirmation_number,

      builder: (_) {

        return const Center(

          child: Text(

            "Ticket Dashboard\n(Coming Soon)",

            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}