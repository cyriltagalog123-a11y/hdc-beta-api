import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ticket_provider.dart';
import '../../models/ticket.dart';

class TicketDetailsScreen extends StatelessWidget {
  final String ticketId;

  const TicketDetailsScreen({
    super.key,
    required this.ticketId,
  });

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
        top: 20,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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

  Widget timelineItem({
    required IconData icon,
    required Color color,
    required String title,
    required bool completed,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor:
                  completed
                      ? color
                      : Colors.grey.shade300,
              child: Icon(
                icon,
                size: 16,
                color: Colors.white,
              ),
            ),
            Container(
              width: 2,
              height: 45,
              color: Colors.grey.shade300,
            ),
          ],
        ),
        const SizedBox(width: 15),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            title,
            style: TextStyle(
              fontWeight:
                  completed
                      ? FontWeight.bold
                      : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<TicketProvider>();

    final ticket =
        provider.findTicket(ticketId);

    if (ticket == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Ticket Details"),
        ),
        body: const Center(
          child: Text("Ticket not found."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ticket Details"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      ticket.id,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Chip(
                      avatar: Icon(
                        ticket.statusIcon,
                        color: Colors.white,
                      ),
                      backgroundColor:
                          ticket.statusColor,
                      label: Text(
                        ticket.statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            sectionTitle("Technician"),

            infoTile(
              icon: Icons.person,
              title: "Assigned Technician",
              value: ticket.technician.name,
            ),

            infoTile(
              icon: Icons.build,
              title: "Specialty",
              value:
                  ticket.technician.specialty,
            ),

            infoTile(
              icon: Icons.timer,
              title: "Response",
              value:
                  ticket.technician.responseText,
            ),

            sectionTitle("Service"),

            infoTile(
              icon: Icons.category,
              title: "Category",
              value:
                  ticket.request.category?.name ??
                      "",
            ),

            infoTile(
              icon: Icons.description,
              title: "Problem",
              value:
                  ticket.request.problemDescription,
            ),

            infoTile(
              icon: Icons.priority_high,
              title: "Priority",
              value:
                  ticket.request.urgency,
            ),

            sectionTitle("Progress"),

            timelineItem(
              icon: Icons.check,
              color: Colors.green,
              title: "Booking Created",
              completed: true,
            ),

            timelineItem(
              icon: Icons.schedule,
              color: Colors.orange,
              title:
                  "Waiting for Technician",
              completed: true,
            ),

            timelineItem(
              icon: Icons.person,
              color: Colors.blue,
              title:
                  "Technician Accepted",
              completed:
                  ticket.status.index >=
                      TicketStatus
                          .accepted.index,
            ),

            timelineItem(
              icon: Icons.directions_car,
              color: Colors.indigo,
              title:
                  "Technician On The Way",
              completed:
                  ticket.status.index >=
                      TicketStatus
                          .onTheWay.index,
            ),

            timelineItem(
              icon: Icons.location_on,
              color: Colors.teal,
              title:
                  "Technician Arrived",
              completed:
                  ticket.status.index >=
                      TicketStatus
                          .arrived.index,
            ),

            timelineItem(
              icon: Icons.build,
              color: Colors.deepPurple,
              title:
                  "Repair In Progress",
              completed:
                  ticket.status.index >=
                      TicketStatus
                          .inProgress.index,
            ),

            timelineItem(
              icon: Icons.verified,
              color: Colors.green,
              title: "Completed",
              completed:
                  ticket.status ==
                      TicketStatus.completed,
            ),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}