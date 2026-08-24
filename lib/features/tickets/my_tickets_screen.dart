import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/ticket.dart';
import '../../providers/ticket_provider.dart';

import 'ticket_details_screen.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<TicketProvider>();

    final List<Ticket> tickets =
        provider.tickets;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Tickets",
        ),
      ),

      body: tickets.isEmpty
          ? const Center(
              child: Text(
                "No tickets yet.",
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.all(16),

              itemCount:
                  tickets.length,

              itemBuilder:
                  (context, index) {
                final ticket =
                    tickets[index];

                return Card(
                  margin:
                      const EdgeInsets.only(
                    bottom: 16,
                  ),

                  child: ListTile(
                    leading:
                        CircleAvatar(
                      backgroundColor:
                          ticket.statusColor,
                      child: Icon(
                        ticket.statusIcon,
                        color:
                            Colors.white,
                      ),
                    ),

                    title: Text(
                      ticket.id,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    subtitle: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          ticket
                              .technician
                              .name,
                        ),

                        Text(
                          ticket
                                  .request
                                  .category
                                  ?.name ??
                              "No Category",
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          ticket.statusLabel,
                          style:
                              TextStyle(
                            color:
                                ticket
                                    .statusColor,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ],
                    ),

                    trailing:
                        const Icon(
                      Icons.chevron_right,
                    ),

                    onTap: () {
                      Navigator.push(
                        context,
                        HDCPageRoute(
                          page:
                              TicketDetailsScreen(
                            ticketId:
                                ticket.id,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}