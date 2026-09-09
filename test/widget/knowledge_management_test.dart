import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hdc_app/core/api/hdc_workflow_api_client.dart';
import 'package:hdc_app/core/ui/hdc_theme.dart';
import 'package:hdc_app/features/knowledge_base/knowledge_editor_screen.dart';
import 'package:hdc_app/features/knowledge_base/knowledge_management_screen.dart';
import 'package:hdc_app/providers/hdc_community_provider.dart';

class _Client extends Fake implements HdcWorkflowApiClient {
  final writes = <Map<String, Object?>>[];
  final methods = <String>[];
  final reads = <String>[];
  Future<Map<String, dynamic>> Function(String)? onGet;
  Future<Map<String, dynamic>> Function()? onWrite;
  List<Map<String, dynamic>> articles = [_article()];
  bool canPublish = true;

  @override
  Future<Map<String, dynamic>> get(String path) async {
    reads.add(path);
    if (onGet != null) return onGet!(path);
    return {'articles': articles, 'canPublish': canPublish, 'hasMore': false};
  }

  Future<Map<String, dynamic>> _write(
    String method,
    Map<String, Object?> body,
  ) async {
    methods.add(method);
    writes.add(body);
    if (onWrite != null) return onWrite!();
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
  }) => _write('POST', body!);
  @override
  Future<Map<String, dynamic>> put(
    String path, {
    required Map<String, Object?> body,
  }) => _write('PUT', body);
  @override
  Future<Map<String, dynamic>> delete(String path) =>
      _write('DELETE', {'path': path});
}

Map<String, dynamic> _article({
  String id = 'guide-one',
  String status = 'published',
}) => {
  'id': id,
  'publicArticleId': 'KB-$id',
  'slug': id,
  'title': 'Printer connection guide $id',
  'category': 'printers_peripherals',
  'summary': 'Find and fix a missing USB printer connection.',
  'body': 'Use this guide when a USB printer does not appear on your computer.',
  'steps': ['Check the USB cable.', 'Select the correct printer.'],
  'tags': ['printer', 'usb'],
  'safetyLevel': 'low',
  'safetyNotice': '',
  'escalationText': '',
  'nexusReady': true,
  'isFeatured': true,
  'status': status,
  'version': 7,
  'publishedVersion': status == 'draft' ? null : 5,
  'everPublished': status != 'draft',
  'publicVisible': status != 'draft' && status != 'archived',
};

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  // ensureVisible can jump the scroll position without laying out a frame.
  await tester.pump();
  await tester.tap(finder);
  // Dialogs can sit above an indeterminate progress bar while actions are locked.
  // Advance navigation without waiting for a network request to settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  if (find.byType(LinearProgressIndicator).evaluate().isEmpty) {
    await tester.pumpAndSettle();
  }
}

Future<void> _fill(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

Finder _step(int number) => find.ancestor(
  of: find.text('Step $number instructions'),
  matching: find.byType(TextFormField),
);

Future<void> _editor(
  WidgetTester tester,
  _Client client, {
  Map<String, dynamic>? article,
  bool canPublish = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: HDCTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<String>(
              MaterialPageRoute<String>(
                builder: (_) => KnowledgeEditorScreen(
                  client: client,
                  article: article,
                  canPublish: canPublish,
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, find.text('Open editor'));
}

Future<void> _library(WidgetTester tester, _Client client) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => HdcCommunityProvider(client: client),
      child: MaterialApp(
        theme: HDCTheme.lightTheme,
        home: const KnowledgeManagementScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);
  testWidgets(
    'creates a draft with ordered steps and a preview that makes no writes',
    (tester) async {
      final client = _Client();
      await _editor(tester, client);
      await _fill(
        tester,
        find.byKey(const ValueKey('guide-title')),
        'Fix a missing printer',
      );
      await _fill(
        tester,
        find.byKey(const ValueKey('guide-summary')),
        'Find a USB printer safely.',
      );
      await _fill(
        tester,
        find.byKey(const ValueKey('guide-body')),
        'Use these checks when the printer is missing from your computer.',
      );
      await _fill(tester, _step(1), 'Check the cable.');
      await _tap(tester, find.text('Add step (1/20)'));
      await _fill(tester, _step(2), 'Check the power.');
      await _tap(tester, find.byTooltip('Move step 2 up'));
      await _tap(tester, find.byTooltip('Remove step 1'));
      await _tap(tester, find.text('Undo'));
      await _tap(tester, find.text('Preview'));
      expect(
        find.text('UNSAVED PREVIEW · only you can see this'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText && widget.data == 'Check the power.',
        ),
        findsOneWidget,
      );
      expect(client.writes, isEmpty);
      await _tap(tester, find.byType(BackButton));
      expect(find.text('Publish…'), findsNothing);
      await _tap(tester, find.text('Save draft'));
      expect(client.methods, ['POST']);
      expect(client.writes.single['steps'], [
        'Check the power.',
        'Check the cable.',
      ]);
      expect(client.writes.single['status'], 'draft');
      expect(client.writes.single.containsKey('expectedVersion'), isFalse);
      expect(find.text('Open editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'published edits keep the version guard and remain drafts until published',
    (tester) async {
      final client = _Client();
      await _editor(tester, client, article: _article(), canPublish: true);
      await _fill(
        tester,
        find.byKey(const ValueKey('guide-title')),
        'Updated printer connection guide',
      );
      await _tap(tester, find.text('Save draft'));
      expect(client.methods, ['PUT']);
      expect(client.writes.single['expectedVersion'], 7);
      expect(client.writes.single['slug'], 'guide-one');
      expect(client.writes.single['status'], 'draft');
    },
  );

  testWidgets(
    'publication requires confirmation and blocks duplicate requests',
    (tester) async {
      final client = _Client();
      final save = Completer<Map<String, dynamic>>();
      client.onWrite = () => save.future;
      await _editor(tester, client, article: _article(), canPublish: true);
      await _tap(tester, find.text('Publish…'));
      expect(client.writes, isEmpty);
      await _tap(tester, find.text('Cancel'));
      expect(client.writes, isEmpty);
      await _tap(tester, find.text('Publish…'));
      await tester.tap(find.text('Publish guide'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(client.writes, hasLength(1));
      expect(client.writes.single['status'], 'published');
      final draftButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save draft'),
      );
      expect(draftButton.onPressed, isNull);
      save.complete({});
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
    },
  );

  testWidgets(
    'failed saves preserve input and back navigation asks before discarding',
    (tester) async {
      final client = _Client()
        ..onWrite = () async => throw const HdcWorkflowException(
          code: 'knowledge_version_conflict',
          message: 'This guide changed. Refresh before saving.',
          statusCode: 409,
        );
      await _editor(tester, client, article: _article());
      await _fill(
        tester,
        find.byKey(const ValueKey('guide-title')),
        'Keep my unsaved title',
      );
      await _tap(tester, find.text('Send for review'));
      expect(find.textContaining('Your edits are still here.'), findsOneWidget);
      expect(find.text('Keep my unsaved title'), findsOneWidget);
      expect(client.writes.single['status'], 'review');
      await _tap(tester, find.byType(BackButton));
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await _tap(tester, find.text('Keep editing'));
      expect(find.text('Keep my unsaved title'), findsOneWidget);
      await _tap(tester, find.byType(BackButton));
      await _tap(tester, find.text('Discard changes'));
      expect(find.text('Open editor'), findsOneWidget);
    },
  );

  testWidgets('invalid or duplicate steps prevent a save', (tester) async {
    final client = _Client();
    await _editor(tester, client, article: _article());
    await _fill(tester, _step(2), 'Check the USB cable.');
    await _tap(tester, find.text('Save draft'));
    expect(client.writes, isEmpty);
    expect(
      find.text('Combine duplicate steps or make each step distinct.'),
      findsNWidgets(2),
    );
  });

  testWidgets(
    'moving a published guide retains its content and saves review status',
    (tester) async {
      final client = _Client()..canPublish = false;
      await _library(tester, client);
      await _tap(tester, find.text('Move'));
      expect(
        find.textContaining('public category changes only'),
        findsOneWidget,
      );
      final destination = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await _tap(tester, destination);
      await _tap(tester, find.text('PC & Laptop').last);
      await _tap(tester, find.text('Save move'));
      final payload = client.writes.single;
      expect(payload['category'], 'pc_laptop');
      expect(payload['status'], 'review');
      expect(payload['expectedVersion'], 7);
      expect(payload['steps'], _article()['steps']);
      expect(payload['body'], _article()['body']);
      expect(payload.containsKey('publishedVersion'), isFalse);
    },
  );

  testWidgets(
    'archive is confirmed, and published guides never expose delete',
    (tester) async {
      final client = _Client();
      await _library(tester, client);
      await _tap(tester, find.text('More ⋮'));
      expect(find.text('Delete draft'), findsNothing);
      await _tap(tester, find.text('Archive guide'));
      expect(client.writes, isEmpty);
      await _tap(tester, find.text('Cancel'));
      expect(client.writes, isEmpty);
      await _tap(tester, find.text('More ⋮'));
      await _tap(tester, find.text('Archive guide'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Archive guide'));
      expect(client.writes.single['status'], 'archived');
      expect(client.writes.single['expectedVersion'], 7);
    },
  );

  testWidgets(
    'restore explains public visibility and keeps working changes in review',
    (tester) async {
      final client = _Client()..articles = [_article(status: 'archived')];
      await _library(tester, client);
      expect(find.text('Edit guide'), findsNothing);
      await _tap(tester, find.text('Restore guide'));
      expect(find.textContaining('last published version'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilledButton, 'Restore guide'));
      expect(client.writes.single['status'], 'review');
    },
  );

  testWidgets('only never-published drafts offer permanent deletion', (
    tester,
  ) async {
    final client = _Client()
      ..articles = [_article(status: 'draft')]
      ..canPublish = false;
    await _library(tester, client);
    await _tap(tester, find.text('More ⋮'));
    expect(find.text('Archive guide'), findsNothing);
    await _tap(tester, find.text('Delete draft'));
    expect(client.writes, isEmpty);
    await _tap(tester, find.widgetWithText(FilledButton, 'Delete draft'));
    expect(client.methods, ['DELETE']);
  });

  testWidgets(
    'search ignores stale results and pagination uses the returned offset',
    (tester) async {
      final client = _Client();
      final oldSearch = Completer<Map<String, dynamic>>();
      client.onGet = (path) async {
        final params = Uri.parse(path).queryParameters;
        if (params['q'] == 'old') return oldSearch.future;
        return {
          'canPublish': true,
          'articles': [
            _article(id: params['offset'] == '50' ? 'second' : 'new'),
          ],
          'hasMore': params['offset'] != '50',
          'nextOffset': 50,
        };
      };
      await _library(tester, client);
      final search = find.byType(TextField).first;
      await _fill(tester, search, 'old');
      await tester.pump(const Duration(milliseconds: 400));
      await _fill(tester, search, 'new');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      oldSearch.complete({
        'articles': [_article(id: 'old')],
        'canPublish': false,
      });
      await tester.pumpAndSettle();
      expect(find.text('Printer connection guide old'), findsNothing);
      expect(find.text('Printer connection guide new'), findsOneWidget);
      await _tap(tester, find.text('Load more guides'));
      expect(
        Uri.parse(client.reads.last).queryParameters,
        containsPair('offset', '50'),
      );
      expect(
        Uri.parse(client.reads.last).queryParameters,
        containsPair('q', 'new'),
      );
      expect(find.text('Printer connection guide second'), findsOneWidget);
      expect(find.text('Load more guides'), findsNothing);
    },
  );

  for (final width in [320.0, 1280.0]) {
    testWidgets('management and editor fit a $width px viewport', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = _Client();
      await _library(tester, client);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Edit guide'));
      await tester.ensureVisible(_step(2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Preview'));
      expect(tester.takeException(), isNull);
    });
  }
}
