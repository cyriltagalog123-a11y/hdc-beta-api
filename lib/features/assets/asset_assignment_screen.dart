import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset_assignment.dart';
import '../../providers/asset_assignment_provider.dart';

class AssetAssignmentScreen extends StatefulWidget {
  final String assetId;

  const AssetAssignmentScreen({
    super.key,
    required this.assetId,
  });

  @override
  State<AssetAssignmentScreen> createState() =>
      _AssetAssignmentScreenState();
}

class _AssetAssignmentScreenState
    extends State<AssetAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _organization =
      TextEditingController();

  final _brand =
      TextEditingController();

  final _region =
      TextEditingController();

  final _store =
      TextEditingController();

  final _department =
      TextEditingController();

  final _assignedTo =
      TextEditingController();

  @override
  void dispose() {
    _organization.dispose();
    _brand.dispose();
    _region.dispose();
    _store.dispose();
    _department.dispose();
    _assignedTo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.read<AssetAssignmentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Asset"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              TextFormField(
                controller: _organization,
                decoration: const InputDecoration(
                  labelText: "Organization",
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(
                  labelText: "Brand",
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _region,
                decoration: const InputDecoration(
                  labelText: "Region",
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _store,
                decoration: const InputDecoration(
                  labelText: "Store",
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _department,
                decoration: const InputDecoration(
                  labelText: "Department",
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _assignedTo,
                decoration: const InputDecoration(
                  labelText: "Assigned To",
                ),
              ),

              const SizedBox(height: 30),

              FilledButton(
                onPressed: () {

                  final assignment =
                      AssetAssignment(
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),

                    assetId: widget.assetId,

                    organizationId:
                        _organization.text,

                    brandId:
                        _brand.text,

                    regionId:
                        _region.text,

                    storeId:
                        _store.text,

                    departmentId:
                        _department.text,

                    assignedTo:
                        _assignedTo.text,

                    assignedDate:
                        DateTime.now(),

                    status:
                        AssetAssignmentStatus
                            .active,
                  );

                  provider.assign(
                    assignment,
                  );

                  Navigator.pop(context);
                },
                child: const Text(
                  "Assign Asset",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}