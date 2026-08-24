import 'package:flutter/material.dart';

import '../../models/organization.dart';

class OrganizationPassportScreen extends StatelessWidget {
  final Organization organization;

  const OrganizationPassportScreen({
    super.key,
    required this.organization,
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
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
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

  Widget comingSoonTile(
    IconData icon,
    String title,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: const Text("Coming Soon"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Organization Passport",
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
                      Icons.apartment,
                      size: 70,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      organization.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      organization.code,
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Chip(
                      backgroundColor:
                          organization.active
                              ? Colors.green
                              : Colors.red,
                      label: Text(
                        organization.active
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

            sectionTitle("Organization"),

            infoTile(
              icon: Icons.person,
              title: "Owner",
              value: organization.ownerName,
            ),

            infoTile(
              icon: Icons.email,
              title: "Email",
              value: organization.email,
            ),

            infoTile(
              icon: Icons.phone,
              title: "Phone",
              value: organization.phone,
            ),

            sectionTitle("Business"),

            comingSoonTile(
              Icons.business,
              "Brands",
            ),

            comingSoonTile(
              Icons.map,
              "Regions",
            ),

            comingSoonTile(
              Icons.store,
              "Stores",
            ),

            comingSoonTile(
              Icons.groups,
              "Employees",
            ),

            comingSoonTile(
              Icons.inventory,
              "Assets",
            ),

            sectionTitle("Enterprise"),

            comingSoonTile(
              Icons.bar_chart,
              "Analytics",
            ),

            comingSoonTile(
              Icons.workspace_premium,
              "Subscription",
            ),

            comingSoonTile(
              Icons.smart_toy,
              "Nexus AI",
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}