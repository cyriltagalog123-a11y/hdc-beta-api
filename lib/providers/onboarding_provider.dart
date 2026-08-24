import 'package:flutter/foundation.dart';

import '../models/onboarding_state.dart';
import '../repositories/onboarding_repository.dart';

class OnboardingProvider extends ChangeNotifier {
  final OnboardingRepository repository;

  OnboardingProvider({
    required this.repository,
  });

  OnboardingState _state = const OnboardingState();
  String? _userId;
  bool _isLoading = false;
  Object? _error;

  OnboardingState get state => _state;
  String? get userId => _userId;
  bool get isLoading => _isLoading;
  Object? get error => _error;
  bool get isReady => _userId != null && !_isLoading && _error == null;

  bool hasCompleted(String flowId) {
    return _state.hasCompleted(flowId);
  }

  Future<void> loadForUser(String userId) async {
    if (_userId == userId && isReady) {
      return;
    }

    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _state = await repository.load(userId);
    } on Object catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> complete(String flowId) async {
    final currentUserId = _userId;

    if (currentUserId == null) {
      throw StateError(
        'Onboarding must be loaded for a user before completing a flow.',
      );
    }

    final previousState = _state;
    _state = _state.complete(flowId);
    _error = null;
    notifyListeners();

    try {
      await repository.save(currentUserId, _state);
    } on Object catch (error) {
      _state = previousState;
      _error = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reset(String flowId) async {
    final currentUserId = _userId;

    if (currentUserId == null) {
      throw StateError(
        'Onboarding must be loaded for a user before resetting a flow.',
      );
    }

    final previousState = _state;
    _state = _state.reset(flowId);
    _error = null;
    notifyListeners();

    try {
      await repository.save(currentUserId, _state);
    } on Object catch (error) {
      _state = previousState;
      _error = error;
      notifyListeners();
      rethrow;
    }
  }
}
