import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/store.dart';
import '../../providers/store_provider.dart';

class StoreRegistrationScreen extends StatefulWidget {
  final String organizationId;
  final String brandId;
  final String regionId;

  const StoreRegistrationScreen({
    super.key,
    required this.organizationId,
    required this.brandId,
    required this.regionId,
  });

  @override
  State<StoreRegistrationScreen> createState() =>
      _StoreRegistrationScreenState();
}

class _StoreRegistrationScreenState
    extends State<StoreRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _storeNumber = TextEditingController();
  final _address = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _storeNumber.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final provider = context.read<StoreProvider>();

    await provider.registerStore(
      Store(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        organizationId: widget.organizationId,
        brandId: widget.brandId,
        regionId: widget.regionId,
        name: _name.text.trim(),
        storeNumber: _storeNumber.text.trim(),
        address: _address.text.trim(),
        active: true,
      ),
    );

    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register Store"),
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
                  labelText: "Store Name",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _storeNumber,
                decoration: const InputDecoration(
                  labelText: "Store Number",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _address,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Store Address",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Required";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              FilledButton(
                onPressed: _saving ? null : _register,
                child: Text(
                  _saving
                      ? "Registering..."
                      : "Register Store",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}