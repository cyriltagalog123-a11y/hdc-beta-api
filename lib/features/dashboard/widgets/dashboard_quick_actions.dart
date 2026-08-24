import 'package:flutter/material.dart';

import '../../../core/navigation/hdc_page_route.dart';
import '../../../core/ui/hdc_action_card.dart';
import '../../../models/service_request_draft.dart';

import '../../search/search_screen.dart';
import '../../tickets/my_tickets_screen.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    super.key,
  });

  void _openTechnicianSearch(
    BuildContext context,
  ) {
    final draft = ServiceRequestDraft();

    Navigator.push(
      context,
      HDCPageRoute(
        page: SearchScreen(
          draft: draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        HDCActionCard(
          icon: Icons.search,
          title: "Search Technician",
          subtitle: "Find nearby professionals",
          onTap: () {
            _openTechnicianSearch(context);
          },
        ),

        const SizedBox(height: 14),

        HDCActionCard(
          icon: Icons.calendar_month,
          title: "Book a Service",
          subtitle: "Schedule a technician",
          onTap: () {
            _openTechnicianSearch(context);
          },
        ),

        const SizedBox(height: 14),

        HDCActionCard(
          icon: Icons.confirmation_number,
          title: "My Tickets",
          subtitle: "Track service requests",
          onTap: () {
            Navigator.push(
              context,
              HDCPageRoute(
                page:
                    const MyTicketsScreen(),
              ),
            );
          },
        ),

        const SizedBox(height: 14),

        HDCActionCard(
          icon: Icons.groups,
          title: "Community",
          subtitle: "Ask and help others",
          onTap: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  "Community - Coming Soon",
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 14),

        HDCActionCard(
          icon: Icons.smart_toy,
          title: "AI Assistant",
          subtitle: "Instant troubleshooting",
          onTap: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  "AI Assistant - Coming Soon",
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 14),

        HDCActionCard(
          icon: Icons.menu_book,
          title: "Knowledge Base",
          subtitle: "Repair guides and FAQs",
          onTap: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  "Knowledge Base - Coming Soon",
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}