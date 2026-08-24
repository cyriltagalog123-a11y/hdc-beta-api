import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/service_request_draft.dart';
import '../../repositories/master_data_repository.dart';

import 'problem_description_screen.dart';

class ServiceCategoryScreen extends StatefulWidget {
  const ServiceCategoryScreen({super.key});

  @override
  State<ServiceCategoryScreen> createState() =>
      _ServiceCategoryScreenState();
}

class _ServiceCategoryScreenState
    extends State<ServiceCategoryScreen> {
  late Future<List<ServiceCategory>> futureCategories;

  @override
  void initState() {
    super.initState();

    futureCategories =
        MasterDataRepository.instance.getServiceCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose a Service"),
      ),
      body: FutureBuilder<List<ServiceCategory>>(
        future: futureCategories,
        builder: (context, snapshot) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(
              child: Text("No service categories found."),
            );
          }

          final categories = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 14),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(category.icon),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    category.description,
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                  ),
                  onTap: () {
                    final draft =
                        ServiceRequestDraft();

                    draft.category = category;

                    Navigator.push(
                      context,
                      HDCPageRoute(
                        page:
                            ProblemDescriptionScreen(
                          draft: draft,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}