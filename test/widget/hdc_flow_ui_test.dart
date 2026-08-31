import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdc_app/core/ui/hdc_flow.dart';
import 'package:hdc_app/core/ui/hdc_status_badge.dart';
import 'package:hdc_app/core/ui/hdc_theme.dart';

void main() {
  Widget flowSurface() {
    return MaterialApp(
      theme: HDCTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HDCFlowHero(
                eyebrow: 'Customer request',
                title: 'Describe the service you need',
                description:
                    'Keep each request, offer, and accepted service connected.',
                icon: Icons.campaign_outlined,
                tags: const [
                  HDCFlowTag(
                    label: 'Tracked offers',
                    icon: Icons.local_offer_outlined,
                  ),
                ],
                action: FilledButton(
                  onPressed: () {},
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 16),
              const HDCFlowProgress(
                steps: ['Describe', 'Review', 'Publish'],
                currentStep: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget actionSurface() {
    return MaterialApp(
      theme: HDCTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: HDCResponsiveActions(
            actions: [
              OutlinedButton(
                key: const Key('secondary-action'),
                onPressed: () {},
                child: const Text('Edit Details'),
              ),
              FilledButton(
                key: const Key('primary-action'),
                onPressed: () {},
                child: const Text('Publish Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('guided flow renders without compact-screen overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(flowSurface());

    expect(find.text('Describe the service you need'), findsOneWidget);
    expect(find.text('1. Describe'), findsOneWidget);
    expect(find.text('2. Review'), findsOneWidget);
    expect(find.text('3. Publish'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actions stack on compact screens', (tester) async {
    tester.view.physicalSize = const Size(430, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(actionSurface());

    final secondary = tester.getCenter(find.byKey(const Key('secondary-action')));
    final primary = tester.getCenter(find.byKey(const Key('primary-action')));
    expect(primary.dy, greaterThan(secondary.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('section status stacks safely at narrow widths', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: HDCTheme.lightTheme,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(12),
            child: HDCSectionCard(
              title: 'Request information',
              subtitle: 'Published details used for every technician offer.',
              trailing: HDCStatusBadge(
                label: 'Receiving Offers',
                tone: HDCStatusTone.warning,
              ),
              child: Text('Request details'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Receiving Offers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actions share a row on wide screens', (tester) async {
    tester.view.physicalSize = const Size(1000, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(actionSurface());

    final secondary = tester.getCenter(find.byKey(const Key('secondary-action')));
    final primary = tester.getCenter(find.byKey(const Key('primary-action')));
    expect(primary.dx, greaterThan(secondary.dx));
    expect(primary.dy, closeTo(secondary.dy, 1));
    expect(tester.takeException(), isNull);
  });
}
