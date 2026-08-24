import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hdc_app/providers/technician_marketplace_provider.dart';

Future<void> _waitUntilLoaded(TechnicianMarketplaceProvider provider) async {
  for (var attempt = 0; attempt < 20 && provider.isLoading; attempt += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(provider.isLoading, isFalse);
}

void main() {
  test('saved marketplace requests stay isolated by account UUID', () async {
    const accountA = '11111111-1111-4111-8111-111111111111';
    const accountB = '22222222-2222-4222-8222-222222222222';
    SharedPreferences.setMockInitialValues({
      'hdc_technician_saved_request_ids_v2.$accountA': <String>['SR-A'],
      'hdc_technician_saved_request_ids_v2.$accountB': <String>['SR-B'],
    });
    final provider = TechnicianMarketplaceProvider();

    provider.bindUser(accountA);
    await _waitUntilLoaded(provider);
    expect(provider.isSaved('SR-A'), isTrue);
    expect(provider.isSaved('SR-B'), isFalse);

    provider.bindUser(accountB);
    expect(provider.savedCount, 0);
    await _waitUntilLoaded(provider);
    expect(provider.isSaved('SR-A'), isFalse);
    expect(provider.isSaved('SR-B'), isTrue);

    await provider.toggleSaved('SR-C');
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList(
        'hdc_technician_saved_request_ids_v2.$accountA',
      ),
      <String>['SR-A'],
    );
    expect(
      preferences.getStringList(
        'hdc_technician_saved_request_ids_v2.$accountB',
      ),
      containsAll(<String>['SR-B', 'SR-C']),
    );
    provider.dispose();
  });
}
