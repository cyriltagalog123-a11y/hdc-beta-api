import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_state.dart';
import 'onboarding_repository.dart';

class SharedPreferencesOnboardingRepository
    implements OnboardingRepository {
  static const String _keyPrefix = 'hdc.onboarding';

  final SharedPreferencesAsync _preferences;

  SharedPreferencesOnboardingRepository({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<OnboardingState> load(String userId) async {
    final completedFlows =
        await _preferences.getStringList(_storageKey(userId)) ??
        const <String>[];

    return OnboardingState(
      completedFlows: completedFlows.toSet(),
    );
  }

  @override
  Future<void> save(
    String userId,
    OnboardingState state,
  ) async {
    final completedFlows = state.completedFlows.toList()..sort();

    await _preferences.setStringList(
      _storageKey(userId),
      completedFlows,
    );
  }

  String _storageKey(String userId) {
    return '$_keyPrefix.$userId.completed_flows';
  }
}
