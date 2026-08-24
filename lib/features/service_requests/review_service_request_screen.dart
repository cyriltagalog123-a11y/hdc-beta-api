import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/hdc_workflow_api_client.dart';
import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/service_request.dart';
import '../../models/service_request_form_data.dart';
import '../../providers/hdc_auth_provider.dart';
import '../../providers/service_request_provider.dart';
import '../authentication/registered_user_gate.dart';
import 'service_request_details_screen.dart';

class ReviewServiceRequestScreen extends StatefulWidget {
  final ServiceRequestFormData form;
  final String? existingRequestId;

  const ReviewServiceRequestScreen({
    required this.form,
    this.existingRequestId,
    super.key,
  });

  @override
  State<ReviewServiceRequestScreen> createState() =>
      _ReviewServiceRequestScreenState();
}

class _ReviewServiceRequestScreenState
    extends State<ReviewServiceRequestScreen> {
  late final String? _newRequestId;

  @override
  void initState() {
    super.initState();
    _newRequestId = widget.existingRequestId == null
        ? ServiceRequestProvider.createRequestId()
        : null;
  }

  Future<void> _publish(BuildContext context) async {
    final provider = context.read<ServiceRequestProvider>();
    final auth = context.read<HDCAuthProvider>();

    if (!await requireRegisteredUser(
      context,
      action: widget.existingRequestId == null
          ? 'publish a service request'
          : 'update a service request',
    )) {
      return;
    }
    if (!context.mounted) return;

    final identity = auth.identity;
    if (identity == null) return;

    try {
      final request = widget.existingRequestId == null
          ? await provider.publish(
              form: widget.form,
              customerId: identity.id,
              customerName: identity.displayName,
              requestId: _newRequestId!,
            )
          : await provider.updateRequest(
              id: widget.existingRequestId!,
              form: widget.form,
            );

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        HDCPageRoute<void>(
          page: ServiceRequestDetailsScreen(
            requestId: request.id,
            justPublished: widget.existingRequestId == null,
          ),
        ),
        (route) => route.isFirst,
      );
    } on Object catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  String _errorMessage(Object error) {
    if (error is HdcWorkflowException) {
      final reference = error.referenceId;
      return reference == null
          ? error.message
          : '${error.message} Reference: $reference';
    }
    return widget.existingRequestId == null
        ? 'The request could not be published. Try again.'
        : 'The request could not be updated. Try again.';
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get _budgetLabel {
    final minimum = widget.form.minimumBudget;
    final maximum = widget.form.maximumBudget;

    if (minimum != null && maximum != null) {
      return 'PHP ${minimum.toStringAsFixed(0)} - '
          '${maximum.toStringAsFixed(0)}';
    }

    if (minimum != null) {
      return 'From PHP ${minimum.toStringAsFixed(0)}';
    }

    if (maximum != null) {
      return 'Up to PHP ${maximum.toStringAsFixed(0)}';
    }

    return 'Open budget';
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<ServiceRequestProvider>().isSaving;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRequestId == null
              ? 'Review Request'
              : 'Review Changes',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: HDCColors.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: HDCColors.secondary.withValues(alpha: 0.20),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          color: HDCColors.secondary,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Check every detail before publishing. Your request '
                            'will be visible to eligible HDC technicians.',
                            style: TextStyle(height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _Badge(label: widget.form.category.name),
                              _Badge(label: widget.form.urgency.label),
                              _Badge(
                                label: widget.existingRequestId == null
                                    ? 'Ready to publish'
                                    : 'Ready to update',
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            widget.form.title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.form.description,
                            style: const TextStyle(height: 1.55),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          _ReviewRow(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: widget.form.location,
                          ),
                          _ReviewRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Preferred date',
                            value: _dateLabel(widget.form.preferredDate),
                          ),
                          _ReviewRow(
                            icon: Icons.schedule_outlined,
                            label: 'Preferred time',
                            value: widget.form.preferredTime,
                          ),
                          _ReviewRow(
                            icon: Icons.priority_high_outlined,
                            label: 'Urgency',
                            value: widget.form.urgency.label,
                          ),
                          _ReviewRow(
                            icon: Icons.payments_outlined,
                            label: 'Budget',
                            value: _budgetLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final horizontal = constraints.maxWidth >= 560;

                      final editButton = OutlinedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Details'),
                      );

                      final publishButton = FilledButton.icon(
                        onPressed: isSaving ? null : () => _publish(context),
                        icon: isSaving
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                ),
                              )
                            : const Icon(Icons.publish_outlined),
                        label: Text(
                          isSaving
                              ? (widget.existingRequestId == null
                                    ? 'Publishing...'
                                    : 'Saving...')
                              : (widget.existingRequestId == null
                                    ? 'Publish Request'
                                    : 'Save Changes'),
                        ),
                      );

                      if (horizontal) {
                        return Row(
                          children: [
                            Expanded(child: editButton),
                            const SizedBox(width: 14),
                            Expanded(child: publishButton),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          publishButton,
                          const SizedBox(height: 12),
                          editButton,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: HDCColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: HDCColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HDCColors.secondary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: HDCColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
