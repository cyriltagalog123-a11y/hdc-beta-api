import '../models/onboarding_state.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingState> load(String userId);

  Future<void> save(
    String userId,
    OnboardingState state,
  );
}
