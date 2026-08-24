import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/organization.dart';
import '../../providers/organization_provider.dart';

class OrganizationRegistrationScreen extends StatefulWidget {
  const OrganizationRegistrationScreen({super.key});

  @override
  State<OrganizationRegistrationScreen> createState() =>
      _OrganizationRegistrationScreenState();
}

class _OrganizationRegistrationScreenState
    extends State<OrganizationRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _organizationName =
      TextEditingController();

  final _organizationCode =
      TextEditingController();

  final _ownerName =
      TextEditingController();

  final _email =
      TextEditingController();

  final _phone =
      TextEditingController();

  @override
  void dispose() {
    _organizationName.dispose();
    _organizationCode.dispose();
    _ownerName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        context.read<OrganizationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Register Organization",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              TextFormField(
                controller: _organizationName,
                decoration: const InputDecoration(
                  labelText:
                      "Organization Name",
                ),
                validator: (value) {
                  if (value == null ||
                      value.isEmpty) {
                    return "Required";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _organizationCode,
                decoration: const InputDecoration(
                  labelText:
                      "Organization Code",
                ),
                validator: (value) {
                  if (value == null ||
                      value.isEmpty) {
                    return "Required";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _ownerName,
                decoration: const InputDecoration(
                  labelText:
                      "Owner Name",
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _email,
                decoration: const InputDecoration(
                  labelText: "Email",
                ),
              ),

              const SizedBox(height: 15),

              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: "Phone",
                ),
              ),

              const SizedBox(height: 30),

              FilledButton(
                onPressed: () {

                  if (!_formKey.currentState!
                      .validate()) {
                    return;
                  }

                  final organization =
                      Organization(
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),

                    name:
                        _organizationName.text,

                    code:
                        _organizationCode.text,

                    ownerName:
                        _ownerName.text,

                    email:
                        _email.text,

                    phone:
                        _phone.text,

                    active: true,
                  );

                  provider.registerOrganization(
                    organization,
                  );

                  Navigator.pop(context);
                },
                child: const Text(
                  "Register Organization",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}