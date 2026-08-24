import 'package:flutter/material.dart';

import '../../models/department.dart';

class DepartmentPassportScreen extends StatelessWidget {
  final Department department;

  const DepartmentPassportScreen({
    super.key,
    required this.department,
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
          "Department Passport",
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
                      Icons.groups,
                      size: 70,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      department.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      department.code,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Chip(
                      backgroundColor:
                          department.active
                              ? Colors.green
                              : Colors.red,
                      label: Text(
                        department.active
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

            sectionTitle("Department"),

            infoTile(
              icon: Icons.groups,
              title: "Department Name",
              value: department.name,
            ),

            infoTile(
              icon: Icons.badge,
              title: "Department Code",
              value: department.code,
            ),

            sectionTitle("Operations"),

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

            comingSoon(
              Icons.assignment,
              "Assigned Work",
            ),

            sectionTitle("Business Intelligence"),

            comingSoon(
              Icons.analytics,
              "Department Analytics",
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