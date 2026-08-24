import 'package:flutter/material.dart';

import '../../models/employee.dart';

class EmployeePassportScreen extends StatelessWidget {

  final Employee employee;

  const EmployeePassportScreen({
    super.key,
    required this.employee,
  });

  Widget title(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 20,
        bottom: 10,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget tile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget future(
    IconData icon,
    String label,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
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
        title: const Text("Employee Passport"),
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

                    const CircleAvatar(
                      radius: 40,
                      child: Icon(
                        Icons.person,
                        size: 45,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Text(
                      employee.fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(employee.position),

                    const SizedBox(height: 10),

                    Chip(
                      backgroundColor: employee.active
                          ? Colors.green
                          : Colors.red,
                      label: Text(
                        employee.active
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

            title("Employee Information"),

            tile(
              icon: Icons.badge,
              label: "Employee Number",
              value: employee.employeeNumber,
            ),

            tile(
              icon: Icons.email,
              label: "Email",
              value: employee.email,
            ),

            tile(
              icon: Icons.phone,
              label: "Phone",
              value: employee.phone,
            ),

            title("Operations"),

            future(Icons.inventory, "Assigned Assets"),
            future(Icons.confirmation_number, "Open Tickets"),
            future(Icons.task, "Assigned Tasks"),

            title("Business Intelligence"),

            future(Icons.school, "Training"),
            future(Icons.workspace_premium, "Certifications"),
            future(Icons.analytics, "Performance"),
            future(Icons.smart_toy, "Nexus Summary"),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}