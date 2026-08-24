import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/region.dart';
import '../../providers/region_provider.dart';

class RegionRegistrationScreen extends StatefulWidget {
  final String organizationId;
  final String brandId;

  const RegionRegistrationScreen({
    super.key,
    required this.organizationId,
    required this.brandId,
  });

  @override
  State<RegionRegistrationScreen> createState() =>
      _RegionRegistrationScreenState();
}

class _RegionRegistrationScreenState
    extends State<RegionRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _code = TextEditingController();
  final _description = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final provider = context.read<RegionProvider>();

    await provider.registerRegion(
      Region(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        organizationId: widget.organizationId,
        brandId: widget.brandId,
        name: _name.text.trim(),
        code: _code.text.trim(),
        description: _description.text.trim(),
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
        title: const Text("Register Region"),
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
                  labelText: "Region Name",
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
                controller: _code,
                decoration: const InputDecoration(
                  labelText: "Region Code",
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
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              FilledButton(
                onPressed: _saving ? null : _register,
                child: Text(
                  _saving
                      ? "Registering..."
                      : "Register Region",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}