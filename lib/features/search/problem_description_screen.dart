import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../models/service_request_draft.dart';

import 'search_screen.dart';

class ProblemDescriptionScreen extends StatefulWidget {
  final ServiceRequestDraft draft;

  const ProblemDescriptionScreen({
    super.key,
    required this.draft,
  });

  @override
  State<ProblemDescriptionScreen> createState() =>
      _ProblemDescriptionScreenState();
}

class _ProblemDescriptionScreenState
    extends State<ProblemDescriptionScreen> {
  final TextEditingController _descriptionController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String _urgency = "Normal";

  @override
  void initState() {
    super.initState();

    _descriptionController.text =
        widget.draft.problemDescription;

    _urgency = widget.draft.urgency;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _continueBooking() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    widget.draft.problemDescription =
        _descriptionController.text.trim();

    widget.draft.urgency = _urgency;

    Navigator.push(
      context,
      HDCPageRoute(
        page: SearchScreen(
          draft: widget.draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Describe the Problem",
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                "Tell us what's happening",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "The technician will receive this information before accepting your booking.",
              ),

              const SizedBox(height: 30),

              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: "Problem Description",
                  hintText:
                      "Example:\nMy Epson printer won't print after changing ink.",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final text = value?.trim() ?? "";

                  if (text.isEmpty) {
                    return "Please describe the problem.";
                  }

                  if (text.length < 10) {
                    return "Please provide a little more detail.";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),

              const Text(
                "Urgency",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                initialValue: _urgency,
                decoration: const InputDecoration(
                  labelText: "Select Urgency",
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

              const SizedBox(height: 40),

              SizedBox(
                height: 55,
                child: FilledButton.icon(
                  onPressed: _continueBooking,
                  icon: const Icon(
                    Icons.search,
                  ),
                  label: const Text(
                    "Find Technicians",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}