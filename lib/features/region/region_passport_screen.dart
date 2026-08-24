import 'package:flutter/material.dart';

import '../../models/region.dart';

class RegionPassportScreen extends StatelessWidget {
  final Region region;

  const RegionPassportScreen({
    super.key,
    required this.region,
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
          "Region Passport",
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
                      Icons.map,
                      size: 70,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      region.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      region.code,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Chip(
                      backgroundColor:
                          region.active
                              ? Colors.green
                              : Colors.red,
                      label: Text(
                        region.active
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

            sectionTitle("Region"),

            infoTile(
              icon: Icons.location_city,
              title: "Region Name",
              value: region.name,
            ),

            infoTile(
              icon: Icons.description,
              title: "Description",
              value: region.description,
            ),

            sectionTitle("Operations"),

            comingSoon(
              Icons.store,
              "Stores",
            ),

            comingSoon(
              Icons.groups,
              "Departments",
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
              "Tickets",
            ),

            sectionTitle("Business Intelligence"),

            comingSoon(
              Icons.analytics,
              "Regional Analytics",
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