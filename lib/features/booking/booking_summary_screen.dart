import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/service_request_draft.dart';
import '../../models/technician.dart';

import '../../providers/ticket_provider.dart';

import '../authentication/registered_user_gate.dart';
import '../tickets/ticket_success_screen.dart';

class BookingSummaryScreen extends StatelessWidget {
  final Technician technician;
  final ServiceRequestDraft draft;

  const BookingSummaryScreen({
    super.key,
    required this.technician,
    required this.draft,
  });

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
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
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking Summary"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Review Your Booking",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            sectionTitle("Technician"),

            infoTile(
              icon: Icons.person,
              title: technician.name,
              value: technician.specialty,
            ),

            infoTile(
              icon: Icons.star,
              title: "Rating",
              value: technician.rating.toString(),
            ),

            infoTile(
              icon: Icons.verified,
              title: "Status",
              value: technician.verified
                  ? "Verified Technician"
                  : "Not Verified",
            ),

            const SizedBox(height: 25),

            sectionTitle("Service Request"),

            infoTile(
              icon: Icons.build,
              title: "Category",
              value: draft.category?.name ?? "",
            ),

            infoTile(
              icon: Icons.description,
              title: "Problem",
              value: draft.problemDescription,
            ),

            infoTile(
              icon: Icons.priority_high,
              title: "Priority",
              value: draft.urgency,
            ),

            const SizedBox(height: 25),

            sectionTitle("Estimated Response"),

            infoTile(
              icon: Icons.timer,
              title: "Technician Response",
              value: technician.responseText,
            ),

            infoTile(
              icon: Icons.place,
              title: "Distance",
              value: technician.distanceText,
            ),

            infoTile(
              icon: Icons.attach_money,
              title: "Estimated Cost",
              value: "To be confirmed after inspection",
            ),

            infoTile(
              icon: Icons.schedule,
              title: "Preferred Schedule",
              value: "ASAP",
            ),

            const SizedBox(height: 25),

            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "By confirming this booking, you understand that the technician may inspect the equipment before providing the final quotation.",
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(

                icon: const Icon(Icons.check_circle),

                label: const Text(
                  "Confirm Booking",
                ),

                onPressed: () async {
                  if (!await requireRegisteredUser(
                    context,
                    action: 'confirm a booking',
                  )) {
                    return;
                  }
                  if (!context.mounted) return;

                  final ticket = context.read<TicketProvider>().createTicket(
                    technician: technician,
                    request: draft,
                  );

                  Navigator.pushReplacement(
                    context,
                    HDCPageRoute(
                      page: TicketSuccessScreen(
                        ticket: ticket,
                      ),
                    ),
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
