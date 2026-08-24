import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/service_request.dart';
import '../../models/service_request_form_data.dart';
import '../../repositories/master_data_repository.dart';
import '../authentication/registered_user_gate.dart';
import 'review_service_request_screen.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  final ServiceRequest? existingRequest;

  const CreateServiceRequestScreen({
    this.existingRequest,
    super.key,
  });

  @override
  State<CreateServiceRequestScreen> createState() =>
      _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState
    extends State<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _minimumBudgetController;
  late final TextEditingController _maximumBudgetController;

  late final Future<List<ServiceCategory>> _categoriesFuture;

  ServiceCategory? _category;
  ServiceRequestUrgency _urgency = ServiceRequestUrgency.normal;
  DateTime _preferredDate = DateTime.now().add(const Duration(days: 1));
  String _preferredTime = 'Any time';

  static const _timeOptions = [
    'Any time',
    'Morning (8 AM - 12 PM)',
    'Afternoon (12 PM - 5 PM)',
    'Evening (5 PM - 8 PM)',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRequest;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _locationController = TextEditingController(
      text: existing?.location ?? 'Cebu City',
    );
    _minimumBudgetController = TextEditingController(
      text: existing?.minimumBudget?.toStringAsFixed(0) ?? '',
    );
    _maximumBudgetController = TextEditingController(
      text: existing?.maximumBudget?.toStringAsFixed(0) ?? '',
    );
    _urgency = existing?.urgency ?? ServiceRequestUrgency.normal;
    _preferredDate = existing?.preferredDate ??
        DateTime.now().add(const Duration(days: 1));
    _preferredTime = existing?.preferredTime ?? 'Any time';
    _categoriesFuture = _loadCategories(existing);
  }

  Future<List<ServiceCategory>> _loadCategories(
    ServiceRequest? existing,
  ) async {
    final categories =
        await MasterDataRepository.instance.getServiceCategories();
    if (existing != null) {
      for (final category in categories) {
        if (category.id == existing.categoryId) {
          _category = category;
          break;
        }
      }
    }
    return categories;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _minimumBudgetController.dispose();
    _maximumBudgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _preferredDate.isBefore(firstDate)
          ? firstDate
          : _preferredDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
    );

    if (selected != null && mounted) {
      setState(() {
        _preferredDate = selected;
      });
    }
  }

  Future<void> _continueToReview() async {
    if (!await requireRegisteredUser(
      context,
      action: widget.existingRequest == null
          ? 'post a service request'
          : 'edit a service request',
    )) {
      return;
    }
    if (!mounted) return;

    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final category = _category;
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a service category.')),
      );
      return;
    }

    final minimum = _parseBudget(_minimumBudgetController.text);
    final maximum = _parseBudget(_maximumBudgetController.text);

    if (minimum != null && maximum != null && minimum > maximum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum budget cannot be higher than maximum.'),
        ),
      );
      return;
    }

    final form = ServiceRequestFormData(
      title: _titleController.text,
      category: category,
      description: _descriptionController.text,
      location: _locationController.text,
      preferredDate: _preferredDate,
      preferredTime: _preferredTime,
      urgency: _urgency,
      minimumBudget: minimum,
      maximumBudget: maximum,
    );

    Navigator.of(context).push(
      HDCPageRoute<void>(
        page: ReviewServiceRequestScreen(
          form: form,
          existingRequestId: widget.existingRequest?.id,
        ),
      ),
    );
  }

  double? _parseBudget(String value) {
    final normalized = value.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  String _dateLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRequest == null
              ? 'Post a Service Request'
              : 'Edit Service Request',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FormIntroduction(),
                    const SizedBox(height: 20),
                    _SectionCard(
                      title: 'Service details',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Request title',
                              hintText: 'Example: Desktop computer will not start',
                              prefixIcon: Icon(Icons.title),
                            ),
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.length < 5) {
                                return 'Enter a clear title with at least 5 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<List<ServiceCategory>>(
                            future: _categoriesFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const LinearProgressIndicator();
                              }

                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Text(
                                  'Service categories could not be loaded.',
                                );
                              }

                              return DropdownButtonFormField<ServiceCategory>(
                                initialValue: _category,
                                decoration: const InputDecoration(
                                  labelText: 'Service category',
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: snapshot.data!
                                    .map(
                                      (category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(category.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _category = value;
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Choose a service category.'
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            minLines: 5,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Describe the problem or work needed',
                              hintText:
                                  'Include symptoms, device details, error messages, and anything already tried.',
                              alignLabelWithHint: true,
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.length < 20) {
                                return 'Add at least 20 characters so technicians can understand the request.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: 'Location and schedule',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: 'Service location',
                              hintText: 'City, barangay, or service area',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (value) {
                              if ((value?.trim().length ?? 0) < 3) {
                                return 'Enter the service location.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final horizontal = constraints.maxWidth >= 620;
                              final dateField = _SelectionField(
                                label: 'Preferred date',
                                value: _dateLabel(_preferredDate),
                                icon: Icons.calendar_today_outlined,
                                onTap: _selectDate,
                              );
                              final timeField = DropdownButtonFormField<String>(
                                initialValue: _preferredTime,
                                decoration: const InputDecoration(
                                  labelText: 'Preferred time',
                                  prefixIcon: Icon(Icons.schedule_outlined),
                                ),
                                items: _timeOptions
                                    .map(
                                      (option) => DropdownMenuItem(
                                        value: option,
                                        child: Text(option),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _preferredTime = value;
                                    });
                                  }
                                },
                              );

                              if (horizontal) {
                                return Row(
                                  children: [
                                    Expanded(child: dateField),
                                    const SizedBox(width: 14),
                                    Expanded(child: timeField),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  dateField,
                                  const SizedBox(height: 14),
                                  timeField,
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: 'Urgency and budget',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How urgent is this request?',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: ServiceRequestUrgency.values
                                .map(
                                  (urgency) => ChoiceChip(
                                    label: Text(urgency.label),
                                    selected: _urgency == urgency,
                                    onSelected: (_) {
                                      setState(() {
                                        _urgency = urgency;
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _urgency.description,
                            style: const TextStyle(
                              color: HDCColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final horizontal = constraints.maxWidth >= 520;
                              final minimumField = TextFormField(
                                controller: _minimumBudgetController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Minimum budget (optional)',
                                  prefixText: 'PHP ',
                                ),
                                validator: _budgetValidator,
                              );
                              final maximumField = TextFormField(
                                controller: _maximumBudgetController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Maximum budget (optional)',
                                  prefixText: 'PHP ',
                                ),
                                validator: _budgetValidator,
                              );

                              if (horizontal) {
                                return Row(
                                  children: [
                                    Expanded(child: minimumField),
                                    const SizedBox(width: 14),
                                    Expanded(child: maximumField),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  minimumField,
                                  const SizedBox(height: 14),
                                  maximumField,
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _continueToReview,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                          widget.existingRequest == null
                              ? 'Review Request'
                              : 'Review Changes',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _budgetValidator(String? value) {
    final text = value?.replaceAll(',', '').trim() ?? '';
    if (text.isEmpty) return null;
    final amount = double.tryParse(text);
    if (amount == null || amount < 0) {
      return 'Enter a valid amount.';
    }
    return null;
  }
}

class _FormIntroduction extends StatelessWidget {
  const _FormIntroduction();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: HDCColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined, color: Colors.white, size: 34),
          SizedBox(height: 14),
          Text(
            'Tell technicians what you need',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your request will be published to the HDC service marketplace. '
            'Technicians can review it and send offers in a later sprint.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _SelectionField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(value),
      ),
    );
  }
}
