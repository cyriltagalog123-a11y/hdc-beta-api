import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/hdc_workflow_api_client.dart';
import '../../providers/hdc_community_provider.dart';
import '../../core/ui/hdc_colors.dart';
import '../../core/ui/hdc_flow.dart';

class SuggestionManagementScreen extends StatefulWidget {
  const SuggestionManagementScreen({super.key});

  @override
  State<SuggestionManagementScreen> createState() =>
      _SuggestionManagementScreenState();
}

class _SuggestionManagementScreenState
    extends State<SuggestionManagementScreen> {
  bool _loading = true;
  Object? _error;
  List<Map<String, dynamic>> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = context.read<HdcCommunityProvider>().client;
      if (client == null) {
        throw const HdcWorkflowException(
          code: 'backend_unavailable',
          message: 'HDC suggestion management is unavailable.',
        );
      }
      final response = await client.get('/api/internal/community');
      final raw = response['suggestions'];
      if (!mounted) return;
      setState(() {
        _suggestions = raw is List
            ? List.unmodifiable(
                raw.whereType<Map>().map(
                      (item) => Map<String, dynamic>.from(item),
                    ),
              )
            : const [];
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suggestion Queue')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const HDCFlowHero(
              eyebrow: 'OWNER / APPROVED ADMIN',
              title: 'Review HDC suggestions without editing code.',
              description:
                  'Move suggestions through review, planning, decline, or implementation. Marking a suggestion implemented can earn its author the Helpful Contributor badge. Public credit still depends on the member’s separate consent.',
              icon: Icons.fact_check_outlined,
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              HDCEmptyState(
                icon: Icons.error_outline,
                title: 'Suggestion queue unavailable',
                description: '$_error',
                actions: [OutlinedButton(onPressed: _load, child: const Text('Retry'))],
              )
            else if (_suggestions.isEmpty)
              const HDCEmptyState(
                icon: Icons.lightbulb_outline,
                title: 'No suggestions in the queue',
                description: 'Member suggestions will appear here after submission.',
              )
            else
              for (final item in _suggestions) ...[
                _SuggestionAdminCard(item: item, onSaved: _load),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionAdminCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Future<void> Function() onSaved;

  const _SuggestionAdminCard({required this.item, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    final status = '${item['status'] ?? 'submitted'}';
    return HDCSectionCard(
      title: '${item['title'] ?? 'Suggestion'}',
      subtitle:
          '${item['publicSuggestionId'] ?? ''} • ${'${item['category'] ?? 'other'}'.replaceAll('_', ' ')}',
      trailing: Chip(label: Text(status.toUpperCase())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item['body'] ?? ''}'),
          const SizedBox(height: 10),
          Text(
            item['publicAttributionConsent'] == true
                ? 'Public recognition consent: allowed if HDC later chooses to recognize this suggestion.'
                : 'Public recognition consent: not granted. Keep the member anonymous in public posts.',
            style: const TextStyle(color: HDCColors.textSecondary),
          ),
          if ('${item['staffResponse'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Current staff response',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${item['staffResponse']}'),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.edit_note_outlined),
            label: const Text('Review / Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    var status = '${item['status'] ?? 'submitted'}';
    final response = TextEditingController(text: '${item['staffResponse'] ?? ''}');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${item['publicSuggestionId'] ?? 'Suggestion'}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const {
                    'submitted': 'Submitted',
                    'reviewing': 'Reviewing',
                    'planned': 'Planned',
                    'declined': 'Declined',
                    'implemented': 'Implemented',
                  }.entries.map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  )).toList(),
                  onChanged: (value) => setState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: response,
                  maxLength: 3000,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Response / review note',
                    hintText: 'Explain the decision or next step to the member.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save != true) {
      response.dispose();
      return;
    }
    try {
      final client = context.read<HdcCommunityProvider>().client;
      if (client == null) {
        throw const HdcWorkflowException(
          code: 'backend_unavailable',
          message: 'HDC suggestion management is unavailable.',
        );
      }
      await client.put('/api/internal/community', body: {
        'id': item['id'],
        'status': status,
        'staffResponse': response.text,
      });
      await onSaved();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      response.dispose();
    }
  }
}
