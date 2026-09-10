import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/hdc_operations_report.dart';
import '../../providers/hdc_internal_dashboard_provider.dart';

class OperationsReportScreen extends StatefulWidget {
  final String reportKey;
  final String? recordId;

  const OperationsReportScreen({required this.reportKey, this.recordId, super.key});

  @override
  State<OperationsReportScreen> createState() => _OperationsReportScreenState();
}

class _OperationsReportScreenState extends State<OperationsReportScreen> {
  final _search = TextEditingController();
  String? _sessionKey;
  String _scope = 'current';
  String _query = '';
  HdcOperationsReport? _report;
  List<HdcOperationsSection> _sections = const [];
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessionKey != null) {
      return;
    }
    _sessionKey = context.read<HdcInternalDashboardProvider>().reportSessionKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_load());
      }
    });
  }

  Future<void> _load({int offset = 0, HdcOperationsSection? section}) async {
    final provider = context.read<HdcInternalDashboardProvider>();
    if (!provider.hasAccess || provider.reportSessionKey != _sessionKey) {
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (section == null) {
        _report = null;
        _sections = const [];
      }
    });
    try {
      final report = await provider.loadReport(
        report: widget.reportKey,
        scope: _scope,
        query: _query,
        offset: offset,
        id: widget.recordId,
        section: section?.key,
        sectionOffset: section?.nextOffset ?? 0,
      );
      if (!mounted || generation != _generation || provider.reportSessionKey != _sessionKey) {
        return;
      }
      setState(() {
        if (section == null) {
          _report = report;
          _sections = report.sections;
        } else {
          final page = report.sections.single;
          _sections = _sections.map((item) => item.key == page.key ? item.append(page) : item).toList();
        }
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation || provider.reportSessionKey != _sessionKey) {
        return;
      }
      setState(() {
        // A rejected refresh must also remove previously authorized content.
        _report = null;
        _sections = const [];
        _error = error;
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _searchRecords() {
    _query = _search.text.trim();
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HdcInternalDashboardProvider>();
    final allowed = provider.hasAccess && provider.reportSessionKey == _sessionKey;
    final report = allowed ? _report : null;
    final detail = widget.recordId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(report?.title ?? 'Operations report'),
        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed: !allowed || _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !allowed
          ? const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Your account or permissions changed. Return to operations and reopen the report.'),
            ))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (!detail) ...[
                      TextField(
                        controller: _search,
                        maxLength: 180,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchRecords(),
                        decoration: InputDecoration(
                          labelText: 'Search name, title or record ID',
                          suffixIcon: IconButton(
                            tooltip: 'Search reports',
                            onPressed: _loading ? null : _searchRecords,
                            icon: const Icon(Icons.search),
                          ),
                        ),
                      ),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final scope in ['current', 'all'])
                          ChoiceChip(
                            label: Text(scope == 'all' ? 'All records' : 'Snapshot records'),
                            selected: _scope == scope,
                            onSelected: _loading ? null : (_) {
                              _scope = scope;
                              unawaited(_load());
                            },
                          ),
                      ]),
                      const SizedBox(height: 16),
                    ],
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text('Unable to load this report. $_error'),
                      TextButton(onPressed: () => _load(), child: const Text('Try again')),
                    ],
                    if (report != null) ...[
                      Text(report.description),
                      const SizedBox(height: 8),
                      Text('Updated ${operationsValue(report.generatedAt)}'),
                      const SizedBox(height: 16),
                      if (detail)
                        _RecordDetail(record: report.records.single, sections: _sections,
                          loading: _loading, onLoadSection: (section) => _load(section: section))
                      else ...[
                        Text('${report.total} matching records', style: Theme.of(context).textTheme.titleMedium),
                        if (report.records.isEmpty)
                          const Padding(padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No records match this view. Try All records or a different search.')),
                        ...report.records.map((record) => Card(
                          child: ListTile(
                            title: Text(record.title),
                            subtitle: Text('${record.subtitle}\n${operationsLabel(record.status)}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => OperationsReportScreen(reportKey: widget.reportKey, recordId: record.id),
                            )),
                          ),
                        )),
                        Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          OutlinedButton(onPressed: _loading || report.offset == 0 ? null
                            : () => _load(offset: (report.offset - report.limit).clamp(0, report.total).toInt()),
                            child: const Text('Previous')),
                          Text(report.total == 0 ? '0 records'
                            : '${report.offset + 1}–${report.offset + report.records.length} of ${report.total}'),
                          OutlinedButton(onPressed: _loading || !report.hasMore ? null
                            : () => _load(offset: report.offset + report.limit), child: const Text('Next')),
                        ]),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _RecordDetail extends StatelessWidget {
  final HdcOperationsRecord record;
  final List<HdcOperationsSection> sections;
  final bool loading;
  final ValueChanged<HdcOperationsSection> onLoadSection;

  const _RecordDetail({required this.record, required this.sections, required this.loading, required this.onLoadSection});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(record.title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      OperationsRecordFields(fields: {
        'Record ID': record.id, 'Status': operationsLabel(record.status),
        'Created': record.createdAt, 'Updated': record.updatedAt, ...record.data,
      }),
      for (final section in sections) ...[
        const SizedBox(height: 24),
        Text(section.title, style: Theme.of(context).textTheme.titleLarge),
        if (section.items.isEmpty) const Text('No records recorded for this section.'),
        for (final item in section.items) Card(child: Padding(
          padding: const EdgeInsets.all(16), child: OperationsRecordFields(fields: item),
        )),
        if (section.hasMore) TextButton(
          onPressed: loading ? null : () => onLoadSection(section),
          child: const Text('Load more records'),
        ),
      ],
    ],
  );
}

class OperationsRecordFields extends StatelessWidget {
  final Map<String, dynamic> fields;
  const OperationsRecordFields({required this.fields, super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: fields.entries.map((entry) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(operationsLabel(entry.key), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SelectableText(operationsValue(entry.value)),
      ]),
    )).toList(),
  );
}

String operationsLabel(String value) {
  final words = value.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}').replaceAll('_', ' ');
  return words.isEmpty ? '' : '${words[0].toUpperCase()}${words.substring(1)}';
}

String operationsValue(Object? value) {
  if (value == null || value == '' || (value is Iterable && value.isEmpty)) {
    return 'Not recorded';
  }
  if (value is bool) {
    return value ? 'Yes' : 'No';
  }
  if (value is Map) {
    return value.entries.map((e) => '${operationsLabel('${e.key}')}: ${operationsValue(e.value)}').join('\n');
  }
  if (value is List) {
    return value.map(operationsValue).join('\n\n');
  }
  if (value is String && RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(value)) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date != null) {
      final local = date.toString();
      return '${local.substring(0, 16)} (local time)';
    }
  }
  return '$value';
}
