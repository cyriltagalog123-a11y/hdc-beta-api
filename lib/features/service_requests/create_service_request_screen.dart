import 'package:flutter/material.dart';

import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_brand.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../models/service_request.dart';
import '../../models/service_request_draft.dart';
import '../../models/service_request_form_data.dart';
import '../../repositories/master_data_repository.dart';
import '../authentication/registered_user_gate.dart';
import 'review_service_request_screen.dart';

class CreateServiceRequestScreen extends StatefulWidget {
  final ServiceRequest? existingRequest;
  final ServiceRequestDraft? initialDraft;

  const CreateServiceRequestScreen({
    this.existingRequest,
    this.initialDraft,
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
    final initialDraft = widget.initialDraft;
    _titleController = TextEditingController(
      text:
          existing?.title ??
          (initialDraft?.category == null
              ? ''
              : '${initialDraft!.category!.name} service needed'),
    );
    _descriptionController = TextEditingController(
      text: existing?.description ?? initialDraft?.problemDescription ?? '',
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
    if (existing == null && initialDraft != null) {
      _urgency = switch (initialDraft.urgency.trim().toLowerCase()) {
        'flexible' => ServiceRequestUrgency.flexible,
        'urgent' => ServiceRequestUrgency.urgent,
        'emergency' => ServiceRequestUrgency.emergency,
        _ => ServiceRequestUrgency.normal,
      };
    }
    _preferredDate =
        existing?.preferredDate ?? DateTime.now().add(const Duration(days: 1));
    _preferredTime = existing?.preferredTime ?? 'Any time';
    _categoriesFuture = _loadCategories(existing);
  }

  Future<List<ServiceCategory>> _loadCategories(
    ServiceRequest? existing,
  ) async {
    final categories = await MasterDataRepository.instance
        .getServiceCategories();
    if (existing != null) {
      for (final category in categories) {
        if (category.id == existing.categoryId) {
          _category = category;
          break;
        }
      }
    } else if (widget.initialDraft?.category != null) {
      for (final category in categories) {
        if (category.id == widget.initialDraft!.category!.id) {
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _serviceDetailsSection() {
    return HDCSectionCard(
      title: 'Describe the work',
      subtitle: 'Give technicians enough context to assess the request.',
      child: Column(
        children: [
          TextFormField(
            key: const Key('hdc-request-title'),
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Request title',
              hintText: 'Example: Desktop computer will not start',
              prefixIcon: Icon(Icons.title_rounded),
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
          const SizedBox(height: HDCSpacing.md),
          FutureBuilder<List<ServiceCategory>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(HDCSpacing.md),
                  decoration: BoxDecoration(
                    color: HDCColors.danger.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(
                      HDCSpacing.radiusSmall,
                    ),
                    border: Border.all(
                      color: HDCColors.danger.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Text(
                    'Service categories could not be loaded. Return and try again.',
                  ),
                );
              }

              return DropdownButtonFormField<ServiceCategory>(
                key: const Key('hdc-request-category'),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Service category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                isExpanded: true,
                items: snapshot.data!
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value),
                validator: (value) =>
                    value == null ? 'Choose a service category.' : null,
              );
            },
          ),
          const SizedBox(height: HDCSpacing.md),
          TextFormField(
            key: const Key('hdc-request-description'),
            controller: _descriptionController,
            minLines: 5,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Problem or work needed',
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
    );
  }

  Widget _scheduleSection() {
    return HDCSectionCard(
      title: 'Location and schedule',
      subtitle: 'Use a service-area label; do not include private access codes.',
      child: Column(
        children: [
          TextFormField(
            key: const Key('hdc-request-location'),
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
          const SizedBox(height: HDCSpacing.md),
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
                key: const Key('hdc-request-time'),
                initialValue: _preferredTime,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Preferred time',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                items: _timeOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _preferredTime = value);
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
    );
  }

  Widget _prioritySection() {
    return HDCSectionCard(
      title: 'Priority and budget',
      subtitle: 'These details help technicians prepare a suitable offer.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How urgent is this request?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: HDCSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ServiceRequestUrgency.values
                .map(
                  (urgency) => ChoiceChip(
                    label: Text(urgency.label),
                    selected: _urgency == urgency,
                    onSelected: (_) => setState(() => _urgency = urgency),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: HDCSpacing.sm),
          Text(
            _urgency.description,
            style: const TextStyle(color: HDCColors.textSecondary),
          ),
          const SizedBox(height: HDCSpacing.lg),
          TextFormField(
            key: const Key('hdc-request-minimum-budget'),
            controller: _minimumBudgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Minimum budget (optional)',
              prefixText: 'PHP ',
            ),
            validator: _budgetValidator,
          ),
          const SizedBox(height: HDCSpacing.sm),
          TextFormField(
            key: const Key('hdc-request-maximum-budget'),
            controller: _maximumBudgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Maximum budget (optional)',
              prefixText: 'PHP ',
            ),
            validator: _budgetValidator,
          ),
        ],
      ),
    );
  }

  Widget _requestGuidance() {
    return HDCSectionCard(
      title: 'Before you publish',
      child: const Column(
        children: [
          _GuidanceRow(
            icon: Icons.password_rounded,
            text: 'Never include passwords, OTPs, PINs, or payment credentials.',
          ),
          SizedBox(height: 12),
          _GuidanceRow(
            icon: Icons.manage_search_rounded,
            text: 'Eligible technicians can discover the request and send one tracked offer.',
          ),
          SizedBox(height: 12),
          _GuidanceRow(
            icon: Icons.fact_check_outlined,
            text: 'You will review every detail again before anything is published.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existingRequest != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? 'Edit Service Request' : 'Post a Service Request',
        ),
      ),
      body: HDCSignalBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HDCSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: HDCSpacing.contentMaxWidth,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HDCFlowHero(
                        eyebrow: editing
                            ? 'Customer request · edit'
                            : 'Customer request · guided intake',
                        title: editing
                            ? 'Update the request without losing its history.'
                            : 'Describe once. Reach eligible technicians.',
                        description:
                            'HDC keeps the request, offers, acceptance, and later service records connected to one customer-owned reference.',
                        icon: editing
                            ? Icons.edit_note_rounded
                            : Icons.campaign_outlined,
                        tags: const [
                          HDCFlowTag(
                            label: 'Provider-backed',
                            icon: Icons.cloud_done_outlined,
                          ),
                          HDCFlowTag(
                            label: 'Tracked offers',
                            icon: Icons.local_offer_outlined,
                          ),
                          HDCFlowTag(
                            label: 'Customer controlled',
                            icon: Icons.verified_user_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      const HDCFlowProgress(
                        steps: ['Describe', 'Review', 'Publish'],
                        currentStep: 1,
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 960;
                          final mainColumn = Column(
                            children: [
                              _serviceDetailsSection(),
                              const SizedBox(height: HDCSpacing.md),
                              _scheduleSection(),
                            ],
                          );
                          final sideColumn = Column(
                            children: [
                              _prioritySection(),
                              const SizedBox(height: HDCSpacing.md),
                              _requestGuidance(),
                              const SizedBox(height: HDCSpacing.md),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  key: const Key('hdc-request-review'),
                                  onPressed: _continueToReview,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: Text(
                                    editing
                                        ? 'Review Changes'
                                        : 'Review Request',
                                  ),
                                ),
                              ),
                            ],
                          );

                          if (!wide) {
                            return Column(
                              children: [
                                mainColumn,
                                const SizedBox(height: HDCSpacing.md),
                                sideColumn,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: mainColumn),
                              const SizedBox(width: HDCSpacing.md),
                              SizedBox(width: 350, child: sideColumn),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: HDCSpacing.lg),
                    ],
                  ),
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

class _GuidanceRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GuidanceRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: HDCColors.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: HDCColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
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
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }
}
