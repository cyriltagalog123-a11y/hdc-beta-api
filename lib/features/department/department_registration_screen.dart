import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/department.dart';
import '../../providers/department_provider.dart';

class DepartmentRegistrationScreen extends StatefulWidget {
  final String organizationId;
  final String brandId;
  final String regionId;
  final String storeId;

  const DepartmentRegistrationScreen({
    super.key,
    required this.organizationId,
    required this.brandId,
    required this.regionId,
    required this.storeId,
  });

  @override
  State<DepartmentRegistrationScreen> createState() =>
      _DepartmentRegistrationScreenState();
}

class _DepartmentRegistrationScreenState
    extends State<DepartmentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _code = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final provider = context.read<DepartmentProvider>();

    await provider.registerDepartment(
      Department(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        organizationId: widget.organizationId,
        brandId: widget.brandId,
        regionId: widget.regionId,
        storeId: widget.storeId,
        name: _name.text.trim(),
        code: _code.text.trim(),
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
        title: const Text("Register Department"),
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
                  labelText: "Department Name",
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
                  labelText: "Department Code",
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
                      : "Register Department",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}