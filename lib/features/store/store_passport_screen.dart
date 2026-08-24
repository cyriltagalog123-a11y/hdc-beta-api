import 'package:flutter/material.dart';

import '../../models/store.dart';

class StorePassportScreen extends StatelessWidget {
  final Store store;

  const StorePassportScreen({
    super.key,
    required this.store,
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
          "Store Passport",
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
                      Icons.store,
                      size: 70,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      store.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Store ${store.storeNumber}",
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Chip(
                      backgroundColor:
                          store.active
                              ? Colors.green
                              : Colors.red,
                      label: Text(
                        store.active
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

            sectionTitle("Store"),

            infoTile(
              icon: Icons.store,
              title: "Store Name",
              value: store.name,
            ),

            infoTile(
              icon: Icons.pin_drop,
              title: "Address",
              value: store.address,
            ),

            sectionTitle("Operations"),

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

            comingSoon(
              Icons.shopping_cart,
              "Marketplace",
            ),

            comingSoon(
              Icons.warehouse,
              "Inventory",
            ),

            sectionTitle("Operations Intelligence"),

            comingSoon(
              Icons.analytics,
              "Store Analytics",
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