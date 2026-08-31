import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdc_app/core/ui/hdc_app_shell.dart';
import 'package:hdc_app/core/ui/hdc_brand.dart';
import 'package:hdc_app/core/ui/hdc_theme.dart';

void main() {
  Widget shell() {
    return MaterialApp(
      theme: HDCTheme.lightTheme,
      home: HDCAppShell(
        workspaceLabel: 'Public Workspace',
        userLabel: 'HDC Member',
        notificationCount: 3,
        onNotifications: () {},
        onSignOut: () {},
        primaryItems: [
          HDCNavigationItem(
            label: 'Overview',
            icon: Icons.space_dashboard_outlined,
            selected: true,
            onTap: () {},
          ),
          HDCNavigationItem(
            label: 'Active Services',
            icon: Icons.handshake_outlined,
            badgeCount: 1,
            onTap: () {},
          ),
        ],
        secondaryItems: [
          HDCNavigationItem(
            label: 'Notifications',
            icon: Icons.notifications_none_rounded,
            badgeCount: 3,
            onTap: () {},
          ),
        ],
        child: const Center(child: Text('Workspace content')),
      ),
    );
  }

  testWidgets('HDC brand primitives render without remote assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HDCTheme.lightTheme,
        home: const Scaffold(body: Center(child: HDCBrandLockup())),
      ),
    );

    expect(find.byType(HDCBrandMark), findsOneWidget);
    expect(find.text('HELPDESK CONNECT'), findsOneWidget);
    expect(find.text('TECH SUPPORT NETWORK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide workspace exposes persistent navigation', (tester) async {
    tester.view.physicalSize = const Size(1360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shell());

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Active Services'), findsOneWidget);
    expect(find.text('Workspace content'), findsOneWidget);
    expect(find.byTooltip('Open navigation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact workspace opens the same navigation in a drawer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(shell());
    expect(find.byTooltip('Open navigation'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Active Services'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
