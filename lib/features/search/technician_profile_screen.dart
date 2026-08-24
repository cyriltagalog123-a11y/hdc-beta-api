import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/service_request_draft.dart';
import '../../models/technician.dart';

import '../authentication/registered_user_gate.dart';
import '../booking/booking_summary_screen.dart';

class TechnicianProfileScreen
    extends StatelessWidget {
  final Technician technician;
  final ServiceRequestDraft draft;

  const TechnicianProfileScreen({
    super.key,
    required this.technician,
    required this.draft,
  });

  Widget infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 10,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget specialtyChip(
    String text,
  ) {
    return Chip(
      avatar: const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 18,
      ),
      label: Text(text),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final initial = technician.name.isNotEmpty
        ? technician.name.substring(0, 1)
        : "?";

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Technician Profile",
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            Center(
              child: CircleAvatar(
                radius: 45,
                backgroundImage:
                    technician.photoUrl != null &&
                            technician
                                .photoUrl!
                                .isNotEmpty
                        ? NetworkImage(
                            technician.photoUrl!,
                          )
                        : null,
                child:
                    technician.photoUrl == null ||
                            technician
                                .photoUrl!
                                .isEmpty
                        ? Text(
                            initial,
                            style:
                                const TextStyle(
                              fontSize: 34,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          )
                        : null,
              ),
            ),

            const SizedBox(height: 18),

            Center(
              child: Text(
                technician.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 5),

            Center(
              child: Text(
                technician.specialty,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    technician.rating
                        .toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            if (technician.verified)
              const Center(
                child: Chip(
                  avatar: Icon(
                    Icons.verified,
                    color: Colors.green,
                  ),
                  label: Text(
                    "Verified Technician",
                  ),
                ),
              ),

            Center(
              child: Chip(
                avatar: Icon(
                  technician.availabilityIcon,
                  color:
                      technician.availabilityColor,
                ),
                label: Text(
                  technician.availabilityText,
                ),
              ),
            ),

            const SizedBox(height: 25),

            Row(
              children: [
                infoCard(
                  icon: Icons.task_alt,
                  title: "Jobs",
                  value:
                      technician.completedJobsText,
                ),
                infoCard(
                  icon: Icons.place,
                  title: "Distance",
                  value: technician.distanceText,
                ),
                infoCard(
                  icon: Icons.timer,
                  title: "Response",
                  value: technician.responseText,
                ),
              ],
            ),

            const SizedBox(height: 30),

            const Text(
              "Skills",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: technician.skills
                  .map(
                    specialtyChip,
                  )
                  .toList(),
            ),

            const SizedBox(height: 30),

            const Text(
              "About Technician",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              technician.about,
            ),

            if (technician.companyName != null &&
                technician
                    .companyName!
                    .isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.business),
                  title: const Text(
                    "Company",
                  ),
                  subtitle: Text(
                    technician.companyName!,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),

            const Text(
              "Recent Customer Reviews",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Card(
              child: ListTile(
                leading: Icon(Icons.rate_review_outlined),
                title: Text('No verified customer reviews yet'),
                subtitle: Text(
                  'Reviews from completed live HDC services will appear here.',
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                icon: const Icon(
                  Icons.calendar_month,
                ),
                label: const Text(
                  "Book Technician",
                ),
                onPressed: technician.available
                    ? () async {
                        if (!await requireRegisteredUser(
                          context,
                          action: 'book a technician',
                        )) {
                          return;
                        }
                        if (!context.mounted) return;

                        Navigator.push(
                          context,
                          HDCPageRoute(
                            page: BookingSummaryScreen(
                              technician: technician,
                              draft: draft,
                            ),
                          ),
                        );
                      }
                    : null,
              ),
            ),

            if (!technician.available) ...[
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  "This technician is currently unavailable.",
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
