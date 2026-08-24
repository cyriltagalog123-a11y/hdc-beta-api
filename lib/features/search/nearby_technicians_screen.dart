import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/service_request_draft.dart';
import '../../models/technician.dart';
import '../../repositories/service_discovery_repository.dart';

import 'technician_profile_screen.dart';

class NearbyTechniciansScreen extends StatefulWidget {
  final ServiceRequestDraft draft;

  const NearbyTechniciansScreen({
    super.key,
    required this.draft,
  });

  @override
  State<NearbyTechniciansScreen> createState() =>
      _NearbyTechniciansScreenState();
}

class _NearbyTechniciansScreenState
    extends State<NearbyTechniciansScreen> {
  late Future<List<Technician>> technicians;

  @override
  void initState() {
    super.initState();

    technicians = ServiceDiscoveryRepository.instance
        .discoverServices(widget.draft);
  }

  Widget infoChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Colors.blue,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget technicianCard(
    Technician tech,
  ) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Text(
                    tech.name.substring(0, 1),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        tech.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        tech.specialty,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (tech.verified)
                        const Row(
                          children: [
                            Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Verified Technician",
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                infoChip(
                  Icons.place,
                  tech.distanceText,
                ),
                infoChip(
                  Icons.star,
                  tech.rating.toString(),
                ),
                infoChip(
                  Icons.task_alt,
                  tech.completedJobsText,
                ),
                infoChip(
                  Icons.timer,
                  tech.responseText,
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color:
                    tech.availabilityColor.withValues(
                  alpha: .12,
                ),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    tech.availabilityIcon,
                    color: tech.availabilityColor,
                  ),

                  const SizedBox(width: 8),

                  Text(
                    tech.availabilityText,
                    style: TextStyle(
                      color: tech.availabilityColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    HDCPageRoute(
                      page: TechnicianProfileScreen(
                        technician: tech,
                        draft: widget.draft,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "View Profile",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Nearby Technicians",
        ),
      ),
      body: FutureBuilder<List<Technician>>(
        future: technicians,
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "No technicians available.",
              ),
            );
          }

          final techs = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: const EdgeInsets.only(
                  bottom: 20,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Looking Near You",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        widget.draft.category?.name ??
                            "",
                      ),

                      Text(
                        "Priority: ${widget.draft.urgency}",
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget
                            .draft.problemDescription,
                      ),
                    ],
                  ),
                ),
              ),

              ...techs.map(
                technicianCard,
              ),
            ],
          );
        },
      ),
    );
  }
}