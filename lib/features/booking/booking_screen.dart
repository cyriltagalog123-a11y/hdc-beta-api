import 'package:flutter/material.dart';

import '../../models/service_request_draft.dart';
import '../../models/technician.dart';
import '../../repositories/master_data_repository.dart';

import '../authentication/registered_user_gate.dart';
import 'booking_summary_screen.dart';

class BookingScreen extends StatefulWidget {
  final Technician technician;

  const BookingScreen({
    super.key,
    required this.technician,
  });

  @override
  State<BookingScreen> createState() =>
      _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _descriptionController =
      TextEditingController();

  ServiceCategory? _selectedCategory;

  String _urgency = "Normal";

  bool _loadingCategories = true;

  List<ServiceCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories =
        await MasterDataRepository.instance
            .getServiceCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _categories = categories;
      _loadingCategories = false;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!await requireRegisteredUser(
      context,
      action: 'book a technician',
    )) {
      return;
    }
    if (!mounted) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select a service category.",
          ),
        ),
      );

      return;
    }

    final draft = ServiceRequestDraft()
      ..category = _selectedCategory
      ..problemDescription =
          _descriptionController.text.trim()
      ..urgency = _urgency;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingSummaryScreen(
          technician: widget.technician,
          draft: draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Book Service",
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                "Booking with ${widget.technician.name}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.technician.specialty,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 25),

              if (_loadingCategories)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                DropdownButtonFormField<ServiceCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: "Service Category",
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map(
                        (category) =>
                            DropdownMenuItem<
                                ServiceCategory>(
                          value: category,
                          child: Text(
                            category.name,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (value) {
                    if (value == null) {
                      return "Please select a category.";
                    }

                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),

              const SizedBox(height: 20),

              TextFormField(
                controller:
                    _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText:
                      "Problem Description",
                  hintText:
                      "Describe the problem in as much detail as possible.",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return "Problem description is required.";
                  }

                  if (value.trim().length < 10) {
                    return "Please provide a little more detail.";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                initialValue: _urgency,
                decoration: const InputDecoration(
                  labelText: "Urgency",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "Low",
                    child: Text("Low"),
                  ),
                  DropdownMenuItem(
                    value: "Normal",
                    child: Text("Normal"),
                  ),
                  DropdownMenuItem(
                    value: "High",
                    child: Text("High"),
                  ),
                  DropdownMenuItem(
                    value: "Emergency",
                    child: Text("Emergency"),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _urgency = value;
                  });
                },
              ),

              const SizedBox(height: 30),

              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Technician",
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget.technician.name,
                      ),

                      Text(
                        widget
                            .technician.specialty,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget
                            .technician.responseText,
                      ),

                      Text(
                        widget
                            .technician.distanceText,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: FilledButton.icon(
                  onPressed:
                      _loadingCategories
                          ? null
                          : _continue,
                  icon: const Icon(
                    Icons.arrow_forward,
                  ),
                  label: const Text(
                    "Continue",
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}