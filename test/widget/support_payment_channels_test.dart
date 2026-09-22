import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdc_app/core/ui/hdc_theme.dart';
import 'package:hdc_app/features/support/support_payment_channels.dart';

void main() {
  testWidgets('both receiving cards are packaged and decode successfully',
      (tester) async {
    await tester.runAsync(() async {
      for (final asset in [
        ('assets/payments/hdc-support-gcash.jpg', 808),
        ('assets/payments/hdc-support-maya.jpg', 1139),
      ]) {
        final data = await rootBundle.load(asset.$1);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ));
        final frame = await codec.getNextFrame();
        expect(frame.image.width, asset.$2);
        expect(frame.image.height, 1536);
        frame.image.dispose();
        codec.dispose();
      }
    });
  });

  for (final width in [320.0, 1024.0]) {
    testWidgets('each wallet opens its own QR at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var ownerOpened = false;
      await tester.pumpWidget(MaterialApp(
        theme: HDCTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SupportPaymentChannelsCard(
              onContactOwner: () => ownerOpened = true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final wallet in [
        ('GCash', 'assets/payments/hdc-support-gcash.jpg', 'CY**L T.'),
        (
          'Maya (PayMaya)',
          'assets/payments/hdc-support-maya.jpg',
          'Cyril Tagalog · mobile ending 1505',
        ),
      ]) {
        final button = find.text('View ${wallet.$1} QR');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('${wallet.$1} support QR'), findsOneWidget);
        expect(find.text('Confirm recipient: ${wallet.$3}'), findsOneWidget);
        final image = tester.widget<Image>(find.descendant(
          of: find.byType(InteractiveViewer),
          matching: find.byType(Image),
        ));
        expect((image.image as AssetImage).assetName, wallet.$2);
        expect(image.fit, BoxFit.contain);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }

      final contact = find.text('Contact Owner');
      await tester.ensureVisible(contact);
      await tester.pumpAndSettle();
      await tester.tap(contact);
      expect(ownerOpened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
