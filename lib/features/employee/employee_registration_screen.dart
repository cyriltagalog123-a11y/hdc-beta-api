import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/employee.dart';
import '../../providers/employee_provider.dart';

class EmployeeRegistrationScreen extends StatefulWidget {
  final String organizationId;
  final String brandId;
  final String regionId;
  final String storeId;
  final String departmentId;

  const EmployeeRegistrationScreen({
    super.key,
    required this.organizationId,
    required this.brandId,
    required this.regionId,
    required this.storeId,
    required this.departmentId,
  });

  @override
  State<EmployeeRegistrationScreen> createState() =>
      _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState
    extends State<EmployeeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _employeeNumber = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _position = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _employeeNumber.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final provider = context.read<EmployeeProvider>();

    await provider.registerEmployee(
      Employee(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        organizationId: widget.organizationId,
        brandId: widget.brandId,
        regionId: widget.regionId,
        storeId: widget.storeId,
        departmentId: widget.departmentId,
        employeeNumber: _employeeNumber.text.trim(),
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        position: _position.text.trim(),
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
        title: const Text("Register Employee"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _employeeNumber,
                decoration: const InputDecoration(
                  labelText: "Employee Number",
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
                controller: _firstName,
                decoration: const InputDecoration(
                  labelText: "First Name",
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
                controller: _lastName,
                decoration: const InputDecoration(
                  labelText: "Last Name",
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
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _position,
                decoration: const InputDecoration(
                  labelText: "Position",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              FilledButton(
                onPressed: _saving ? null : _register,
                child: Text(
                  _saving
                      ? "Registering..."
                      : "Register Employee",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}