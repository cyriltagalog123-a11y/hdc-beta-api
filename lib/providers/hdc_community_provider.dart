import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';

class HdcRatingOpportunity {
  final String transactionKind;
  final String transactionId;
  final String title;
  final String counterpartyName;
  final String status;
  final int version;
  final bool canRate;
  final bool canMarkFulfilled;
  final bool canConfirmComplete;
  final Map<String, dynamic>? rating;

  const HdcRatingOpportunity({
    required this.transactionKind,
    required this.transactionId,
    required this.title,
    required this.counterpartyName,
    required this.status,
    required this.version,
    required this.canRate,
    required this.canMarkFulfilled,
    required this.canConfirmComplete,
    required this.rating,
  });

  factory HdcRatingOpportunity.fromJson(Map<String, dynamic> json) =>
      HdcRatingOpportunity(
        transactionKind: '${json['transactionKind'] ?? ''}',
        transactionId: '${json['transactionId'] ?? ''}',
        title: '${json['title'] ?? ''}',
        counterpartyName: '${json['counterpartyName'] ?? ''}',
        status: '${json['status'] ?? ''}',
        version: (json['version'] as num?)?.toInt() ?? 0,
        canRate: json['canRate'] == true,
        canMarkFulfilled: json['canMarkFulfilled'] == true,
        canConfirmComplete: json['canConfirmComplete'] == true,
        rating: json['rating'] is Map
            ? Map<String, dynamic>.from(json['rating'] as Map)
            : null,
      );
}

class HdcSuggestionItem {
  final String publicSuggestionId;
  final String category;
  final String title;
  final String body;
  final String status;
  final String staffResponse;
  final bool publicAttributionConsent;

  const HdcSuggestionItem({
    required this.publicSuggestionId,
    required this.category,
    required this.title,
    required this.body,
    required this.status,
    required this.staffResponse,
    required this.publicAttributionConsent,
  });

  factory HdcSuggestionItem.fromJson(Map<String, dynamic> json) =>
      HdcSuggestionItem(
        publicSuggestionId: '${json['publicSuggestionId'] ?? ''}',
        category: '${json['category'] ?? ''}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        status: '${json['status'] ?? ''}',
        staffResponse: '${json['staffResponse'] ?? ''}',
        publicAttributionConsent: json['publicAttributionConsent'] == true,
      );
}

class HdcBadgeItem {
  final String key;
  final String name;
  final String description;
  final String category;
  final int evidenceCount;
  final bool visible;

  const HdcBadgeItem({
    required this.key,
    required this.name,
    required this.description,
    required this.category,
    required this.evidenceCount,
    required this.visible,
  });

  factory HdcBadgeItem.fromJson(Map<String, dynamic> json) => HdcBadgeItem(
        key: '${json['key'] ?? ''}',
        name: '${json['name'] ?? ''}',
        description: '${json['description'] ?? ''}',
        category: '${json['category'] ?? ''}',
        evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
        visible: json['visible'] == true,
      );
}

class HdcCommunityProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;
  String? _userId;
  bool isLoading = false;
  String? errorMessage;
  double receivedAverage = 0;
  int receivedCount = 0;
  List<HdcRatingOpportunity> ratingOpportunities = const [];
  List<HdcSuggestionItem> suggestions = const [];
  List<HdcBadgeItem> badges = const [];

  HdcCommunityProvider({required this.client});

  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    receivedAverage = 0;
    receivedCount = 0;
    ratingOpportunities = const [];
    suggestions = const [];
    badges = const [];
    errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    if (_userId == null || client == null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await Future.wait([refreshRatings(notify: false), refreshSuggestions(notify: false), refreshBadges(notify: false)]);
    } on Object catch (error) {
      errorMessage = '$error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRatings({bool notify = true}) async {
    if (_userId == null || client == null) return;
    final data = await client!.get('/api/community?view=ratings');
    final received = data['received'] is Map
        ? Map<String, dynamic>.from(data['received'] as Map)
        : const <String, dynamic>{};
    receivedAverage = (received['average'] as num?)?.toDouble() ?? 0;
    receivedCount = (received['count'] as num?)?.toInt() ?? 0;
    final items = <HdcRatingOpportunity>[];
    for (final key in ['service', 'commerce']) {
      final raw = data[key];
      if (raw is List) {
        for (final item in raw.whereType<Map>()) {
          items.add(HdcRatingOpportunity.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    ratingOpportunities = List.unmodifiable(items);
    if (notify) notifyListeners();
  }

  Future<void> refreshSuggestions({bool notify = true}) async {
    if (_userId == null || client == null) return;
    final data = await client!.get('/api/community?view=suggestions');
    final raw = data['suggestions'];
    suggestions = raw is List
        ? List.unmodifiable(raw.whereType<Map>().map((e) => HdcSuggestionItem.fromJson(Map<String, dynamic>.from(e))))
        : const [];
    if (notify) notifyListeners();
  }

  Future<void> refreshBadges({bool notify = true}) async {
    if (_userId == null || client == null) return;
    final data = await client!.get('/api/community?view=badges');
    final raw = data['badges'];
    badges = raw is List
        ? List.unmodifiable(raw.whereType<Map>().map((e) => HdcBadgeItem.fromJson(Map<String, dynamic>.from(e))))
        : const [];
    if (notify) notifyListeners();
  }

  Future<void> submitRating({
    required String transactionKind,
    required String transactionId,
    required int score,
    String review = '',
  }) async {
    await _post({
      'action': 'submit_rating',
      'transactionKind': transactionKind,
      'transactionId': transactionId,
      'score': score,
      'review': review,
    });
    await refreshRatings();
  }

  Future<void> progressCommerce(HdcRatingOpportunity item) async {
    final action = item.canMarkFulfilled
        ? 'commerce_fulfill'
        : item.canConfirmComplete
        ? 'commerce_complete'
        : null;
    if (action == null) return;
    await _post({
      'action': action,
      'purchaseRequestId': item.transactionId,
      'version': item.version,
    });
    await refreshRatings();
    await refreshBadges();
  }

  Future<void> submitSuggestion({
    required String category,
    required String title,
    required String body,
    required bool publicAttributionConsent,
  }) async {
    await _post({
      'action': 'submit_suggestion',
      'category': category,
      'title': title,
      'body': body,
      'publicAttributionConsent': publicAttributionConsent,
    });
    await refreshSuggestions();
  }

  Future<void> setBadgeVisibility(HdcBadgeItem badge, bool visible) async {
    await _post({
      'action': 'set_badge_visibility',
      'badgeKey': badge.key,
      'visible': visible,
    });
    await refreshBadges();
  }

  Future<void> _post(Map<String, Object?> body) async {
    if (_userId == null || client == null) {
      throw const HdcWorkflowException(
        code: 'authentication_required',
        message: 'Sign in to use HDC community features.',
      );
    }
    await client!.post('/api/community', body: body);
  }
}
