import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/hdc_workflow_api_client.dart';
import '../../core/navigation/hdc_page_route.dart';
import '../../core/ui/hdc_brand.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';
import '../../core/ui/hdc_spacing.dart';
import '../../core/ui/hdc_status_badge.dart';
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

  Widget _requestPreview() {
    return HDCSectionCard(
      title: 'Request preview',
      subtitle: 'This is the information eligible technicians will assess.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HDCStatusBadge(
                label: widget.form.category.name,
                icon: widget.form.category.icon,
              ),
              HDCStatusBadge(
                label: widget.form.urgency.label,
                tone: widget.form.urgency == ServiceRequestUrgency.emergency
                    ? HDCStatusTone.danger
                    : widget.form.urgency == ServiceRequestUrgency.urgent
                    ? HDCStatusTone.warning
                    : HDCStatusTone.info,
                icon: Icons.priority_high_rounded,
              ),
              HDCStatusBadge(
                label: widget.existingRequestId == null
                    ? 'Ready to publish'
                    : 'Ready to update',
                tone: HDCStatusTone.success,
                icon: Icons.fact_check_outlined,
              ),
            ],
          ),
          const SizedBox(height: HDCSpacing.lg),
          Text(
            widget.form.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: HDCSpacing.sm),
          Text(widget.form.description, style: const TextStyle(height: 1.6)),
          const SizedBox(height: HDCSpacing.lg),
          const Divider(),
          const SizedBox(height: HDCSpacing.md),
          _ReviewRow(
            icon: Icons.location_on_outlined,
            label: 'Service area',
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
            icon: Icons.payments_outlined,
            label: 'Budget',
            value: _budgetLabel,
          ),
        ],
      ),
    );
  }

  Widget _publicationBoundary() {
    return HDCSectionCard(
      title: 'Visibility and control',
      child: const Column(
        children: [
          _BoundaryRow(
            icon: Icons.engineering_outlined,
            text: 'Only eligible signed-in technicians can discover the request.',
          ),
          SizedBox(height: 13),
          _BoundaryRow(
            icon: Icons.person_off_outlined,
            text: 'Private credentials and internal staff roles are not published with the request.',
          ),
          SizedBox(height: 13),
          _BoundaryRow(
            icon: Icons.edit_note_rounded,
            text: 'You can edit or cancel while the request status permits it.',
          ),
          SizedBox(height: 13),
          _BoundaryRow(
            icon: Icons.receipt_long_outlined,
            text: 'Offers and acceptance stay attached to this tracked request.',
          ),
        ],
      ),
    );
  }

  Widget _actionGroup(bool isSaving) {
    return HDCResponsiveActions(
      breakpoint: 760,
      actions: [
        OutlinedButton.icon(
          key: const Key('hdc-request-edit-details'),
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Details'),
        ),
        FilledButton.icon(
          key: const Key('hdc-request-publish'),
          onPressed: isSaving ? null : () => _publish(context),
          icon: isSaving
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(strokeWidth: 2.3),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<ServiceRequestProvider>().isSaving;
    final editing = widget.existingRequestId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingRequestId == null
              ? 'Review Request'
              : 'Review Changes',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HDCFlowHero(
                      eyebrow: editing
                          ? 'Customer request · update review'
                          : 'Customer request · publish review',
                      title: editing
                          ? 'Confirm the changes before updating the live request.'
                          : 'One last check before the request enters the network.',
                      description:
                          'Review the exact service details, visibility boundary, schedule, and budget before continuing.',
                      icon: Icons.fact_check_outlined,
                      tags: const [
                        HDCFlowTag(
                          label: 'Eligible technicians only',
                          icon: Icons.engineering_outlined,
                        ),
                        HDCFlowTag(
                          label: 'Tracked request',
                          icon: Icons.route_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: HDCSpacing.lg),
                    const HDCFlowProgress(
                      steps: ['Describe', 'Review', 'Publish'],
                      currentStep: 2,
                    ),
                    const SizedBox(height: HDCSpacing.lg),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 940;
                        final preview = _requestPreview();
                        final side = Column(
                          children: [
                            _publicationBoundary(),
                            const SizedBox(height: HDCSpacing.md),
                            _actionGroup(isSaving),
                          ],
                        );
                        if (!wide) {
                          return Column(
                            children: [
                              preview,
                              const SizedBox(height: HDCSpacing.md),
                              side,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: preview),
                            const SizedBox(width: HDCSpacing.md),
                            SizedBox(width: 350, child: side),
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
    );
  }
}

class _BoundaryRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BoundaryRow({required this.icon, required this.text});

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
