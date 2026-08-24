import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/asset.dart';
import '../../providers/asset_provider.dart';

class AssetRegistrationScreen extends StatefulWidget {
  const AssetRegistrationScreen({super.key});

  @override
  State<AssetRegistrationScreen> createState() =>
      _AssetRegistrationScreenState();
}

class _AssetRegistrationScreenState
    extends State<AssetRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _category = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _serial = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _brand.dispose();
    _model.dispose();
    _serial.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.read<AssetProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Asset"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: "Asset Name",
                ),
                validator: (v) =>
                    v == null || v.isEmpty
                        ? "Required"
                        : null,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _category,
                decoration: const InputDecoration(
                  labelText: "Category",
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(
                  labelText: "Brand",
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _model,
                decoration: const InputDecoration(
                  labelText: "Model",
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _serial,
                decoration: const InputDecoration(
                  labelText: "Serial Number",
                ),
              ),

              const SizedBox(height: 30),

              FilledButton(
                onPressed: () {

                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  final asset = Asset(

                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),

                    assetTag:
                        "AST-${DateTime.now().millisecondsSinceEpoch}",

                    name: _name.text,

                    category: _category.text,

                    brand: _brand.text,

                    model: _model.text,

                    serialNumber: _serial.text,

                    organizationId: "",

                    storeId: "",

                    purchaseDate: DateTime.now(),
                  );

                  provider.registerAsset(asset);

                  Navigator.pop(context);
                },
                child: const Text(
                  "Register Asset",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}