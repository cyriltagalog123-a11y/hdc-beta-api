import 'package:flutter/material.dart';

import '../../models/brand.dart';

class BrandPassportScreen extends StatelessWidget {
  final Brand brand;

  const BrandPassportScreen({
    super.key,
    required this.brand,
  });

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 20,
        bottom: 10,
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

  Widget comingSoon(
    IconData icon,
    String title,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: const Text(
          "Coming Soon",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Brand Passport",
        ),
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

                    const Icon(
                      Icons.business,
                      size: 70,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      brand.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      brand.code,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Chip(
                      backgroundColor:
                          brand.active
                              ? Colors.green
                              : Colors.red,
                      label: Text(
                        brand.active
                            ? "ACTIVE"
                            : "INACTIVE",
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            sectionTitle("Brand"),

            infoTile(
              icon: Icons.badge,
              title: "Brand Name",
              value: brand.name,
            ),

            infoTile(
              icon: Icons.description,
              title: "Description",
              value: brand.description,
            ),

            sectionTitle("Operations"),

            comingSoon(
              Icons.map,
              "Regions",
            ),

            comingSoon(
              Icons.store,
              "Stores",
            ),

            comingSoon(
              Icons.people,
              "Employees",
            ),

            comingSoon(
              Icons.inventory,
              "Assets",
            ),

            comingSoon(
              Icons.confirmation_number,
              "Service Requests",
            ),

            sectionTitle("Business Intelligence"),

            comingSoon(
              Icons.analytics,
              "Analytics",
            ),

            comingSoon(
              Icons.smart_toy,
              "Nexus Summary",
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}