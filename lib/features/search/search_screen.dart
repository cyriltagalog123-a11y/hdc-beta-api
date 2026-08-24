import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/service_request_draft.dart';
import '../service_requests/create_service_request_screen.dart';

class SearchScreen extends StatelessWidget {
  final ServiceRequestDraft draft;

  const SearchScreen({
    super.key,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Technician'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.engineering_outlined, size: 56),
                    const SizedBox(height: 18),
                    Text(
                      'No live technician listings yet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'The live technician directory is not available yet. '
                      'Post a service request instead; an approved Technician '
                      'account can find it in Technician Marketplace and '
                      'submit a proposal.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          HDCPageRoute<void>(
                            page: const CreateServiceRequestScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Post a Service Request'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
