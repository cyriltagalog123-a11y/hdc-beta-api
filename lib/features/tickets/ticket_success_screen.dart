import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/ticket.dart';

import 'my_tickets_screen.dart';

class TicketSuccessScreen extends StatelessWidget {
  final Ticket ticket;

  const TicketSuccessScreen({
    super.key,
    required this.ticket,
  });

  Widget infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Booking Confirmed"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(

          children: [

            const SizedBox(height: 15),

            const CircleAvatar(
              radius: 45,
              backgroundColor: Colors.green,
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: 55,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Booking Confirmed!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Your service request has been created successfully.",
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            infoTile(
              icon: Icons.confirmation_number,
              title: "Ticket Number",
              value: ticket.id,
            ),

            infoTile(
              icon: Icons.person,
              title: "Technician",
              value: ticket.technician.name,
            ),

            infoTile(
              icon: ticket.statusIcon,
              title: "Status",
              value: ticket.statusLabel,
            ),

            infoTile(
              icon: Icons.timer,
              title: "Estimated Response",
              value: ticket.technician.responseText,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                icon: const Icon(Icons.track_changes),
                label: const Text("Track Ticket"),
                onPressed: () {

                  Navigator.pushReplacement(
                    context,
                    HDCPageRoute(
                      page: const MyTicketsScreen(),
                    ),
                  );

                },
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text("Return Home"),
                onPressed: () {

                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  );

                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}