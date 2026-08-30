import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_exception.dart';
import '../../core/ui/hdc_colors.dart';
import '../../models/legal_document.dart';
import '../../models/privacy_request.dart';
import '../../providers/hdc_auth_provider.dart';
import 'legal_document_screen.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  final _detailsController = TextEditingController();
  HDCPrivacyRequestType _type = HDCPrivacyRequestType.access;
  List<HDCPrivacyRequest>? _requests;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final requests = await context
          .read<HDCAuthProvider>()
          .listPrivacyRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _submit() async {
    final details = _detailsController.text.trim();
    if (details.length < 10 || details.length > 4000) {
      _message('Provide 10 to 4,000 characters of detail.');
      return;
    }
    try {
      final request = await context
          .read<HDCAuthProvider>()
          .submitPrivacyRequest(type: _type, details: details);
      if (!mounted) return;
      _detailsController.clear();
      setState(() {
        _requests = [request, ...?_requests];
        _loadError = null;
      });
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Privacy request recorded'),
          content: Text(
            'Keep reference ${request.publicReference}. HDC Owner or a '
            'Super Admin will review the request in the private queue.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      _message(
        error is HDCAuthException
            ? error.message
            : 'HDC could not record the privacy request. Try again.',
      );
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNotice() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const LegalDocumentScreen(document: HDCLegalDocument.privacy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<HDCAuthProvider>().isBusy;
    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(title: const Text('Privacy Center')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Submit a privacy request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Request access, correction, export, deletion where '
                      'eligible, objection, or report a privacy concern. '
                      'Transaction and dispute evidence may need to be retained '
                      'when law, fraud prevention, or an active claim requires it.',
                      style: TextStyle(height: 1.45),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _openNotice,
                        icon: const Icon(Icons.privacy_tip_outlined),
                        label: const Text('Read the full Privacy Notice'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<HDCPrivacyRequestType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Request type',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final type in HDCPrivacyRequestType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => _type = value ?? _type),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _detailsController,
                      enabled: !busy,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Request details',
                        hintText: 'Describe the data or concern clearly.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: busy ? null : _submit,
                      icon: const Icon(Icons.send_outlined),
                      label: Text(busy ? 'Submitting…' : 'Submit Request'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your request history',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_requests == null && _loadError == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_loadError != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Request history could not be loaded'),
                  subtitle: const Text('Pull down or tap retry.'),
                  trailing: IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if (_requests!.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.inbox_outlined),
                  title: Text('No privacy requests yet'),
                ),
              )
            else
              for (final request in _requests!)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.policy_outlined),
                    title: Text(request.type.label),
                    subtitle: Text(
                      '${request.publicReference}\n'
                      'Status: ${request.status.replaceAll('_', ' ')}'
                      '${request.reviewerNote.isEmpty ? '' : '\n${request.reviewerNote}'}',
                    ),
                    isThreeLine: true,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
