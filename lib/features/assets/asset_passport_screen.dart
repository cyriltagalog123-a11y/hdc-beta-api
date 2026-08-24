import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/asset_provider.dart';
import '../../models/asset.dart';

class AssetPassportScreen extends StatelessWidget {
  final String assetId;

  const AssetPassportScreen({
    super.key,
    required this.assetId,
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

  @override
  Widget build(BuildContext context) {
    final provider =
        context.watch<AssetProvider>();

    final Asset? asset =
        provider.findAsset(assetId);

    if (asset == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Asset Passport"),
        ),
        body: const Center(
          child: Text("Asset not found."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Asset Passport"),
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
                      Icons.devices,
                      size: 60,
                    ),

                    const SizedBox(height: 10),

                    Text(
                      asset.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      asset.assetTag,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Chip(
                      avatar: Icon(
                        asset.statusIcon,
                        color: Colors.white,
                      ),
                      backgroundColor:
                          asset.statusColor,
                      label: Text(
                        asset.statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            sectionTitle("Asset Information"),

            infoTile(
              icon: Icons.category,
              title: "Category",
              value: asset.category,
            ),

            infoTile(
              icon: Icons.business,
              title: "Brand",
              value: asset.brand,
            ),

            infoTile(
              icon: Icons.memory,
              title: "Model",
              value: asset.model,
            ),

            infoTile(
              icon: Icons.confirmation_number,
              title: "Serial Number",
              value: asset.serialNumber,
            ),

            sectionTitle("Assignment"),

            infoTile(
              icon: Icons.apartment,
              title: "Organization",
              value: asset.organizationId.isEmpty
                  ? "Not Assigned"
                  : asset.organizationId,
            ),

            infoTile(
              icon: Icons.store,
              title: "Store",
              value: asset.storeId.isEmpty
                  ? "Not Assigned"
                  : asset.storeId,
            ),

            sectionTitle("Warranty"),

            infoTile(
              icon: Icons.verified,
              title: "Warranty Expiry",
              value: asset.warrantyExpiry == null
                  ? "Not Available"
                  : asset.warrantyExpiry!
                      .toLocal()
                      .toString()
                      .split(' ')
                      .first,
            ),

            sectionTitle("Coming Soon"),

            Card(
              child: Column(
                children: const [

                  ListTile(
                    leading: Icon(Icons.qr_code),
                    title: Text("QR Code"),
                    subtitle: Text("Coming Soon"),
                  ),

                  Divider(height: 1),

                  ListTile(
                    leading: Icon(Icons.history),
                    title: Text("Service History"),
                    subtitle: Text("Coming Soon"),
                  ),

                  Divider(height: 1),

                  ListTile(
                    leading: Icon(Icons.build),
                    title: Text("Maintenance"),
                    subtitle: Text("Coming Soon"),
                  ),

                  Divider(height: 1),

                  ListTile(
                    leading: Icon(Icons.smart_toy),
                    title: Text("AI Insights"),
                    subtitle: Text("Coming Soon"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}