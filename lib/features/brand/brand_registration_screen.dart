import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/brand.dart';
import '../../providers/brand_provider.dart';

class BrandRegistrationScreen extends StatefulWidget {
  final String organizationId;

  const BrandRegistrationScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<BrandRegistrationScreen> createState() =>
      _BrandRegistrationScreenState();
}

class _BrandRegistrationScreenState
    extends State<BrandRegistrationScreen> {

  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _code = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final provider =
        context.read<BrandProvider>();

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Register Brand",
        ),
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
                  labelText: "Brand Name",
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
                controller: _code,
                decoration: const InputDecoration(
                  labelText: "Brand Code",
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
                controller: _description,
                decoration: const InputDecoration(
                  labelText: "Description",
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 30),

              FilledButton(

                onPressed: () {

                  if (!_formKey.currentState!
                      .validate()) {
                    return;
                  }

                  provider.registerBrand(

                    Brand(

                      id: DateTime.now()
                          .millisecondsSinceEpoch
                          .toString(),

                      organizationId:
                          widget.organizationId,

                      name: _name.text,

                      code: _code.text,

                      description:
                          _description.text,

                      active: true,
                    ),
                  );

                  Navigator.pop(context);
                },

                child: const Text(
                  "Register Brand",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}