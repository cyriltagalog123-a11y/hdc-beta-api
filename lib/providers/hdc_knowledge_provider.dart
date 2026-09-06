import 'package:flutter/foundation.dart';

import '../core/api/hdc_workflow_api_client.dart';

class HdcKnowledgeArticle {
  final String publicArticleId;
  final String slug;
  final String category;
  final String title;
  final String summary;
  final String body;
  final List<String> steps;
  final List<String> tags;
  final String safetyLevel;
  final String safetyNotice;
  final String escalationText;
  final bool nexusReady;
  final bool isFeatured;
  final int version;
  final DateTime? publishedAt;
  final int helpfulCount;
  final int notHelpfulCount;

  const HdcKnowledgeArticle({
    required this.publicArticleId,
    required this.slug,
    required this.category,
    required this.title,
    required this.summary,
    required this.body,
    required this.steps,
    required this.tags,
    required this.safetyLevel,
    required this.safetyNotice,
    required this.escalationText,
    required this.nexusReady,
    required this.isFeatured,
    required this.version,
    required this.publishedAt,
    required this.helpfulCount,
    required this.notHelpfulCount,
  });

  factory HdcKnowledgeArticle.fromJson(Map<String, dynamic> json) {
    return HdcKnowledgeArticle(
      publicArticleId: '${json['publicArticleId'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      category: '${json['category'] ?? ''}',
      title: '${json['title'] ?? ''}',
      summary: '${json['summary'] ?? ''}',
      body: '${json['body'] ?? ''}',
      steps: _stringList(json['steps']),
      tags: _stringList(json['tags']),
      safetyLevel: '${json['safetyLevel'] ?? 'low'}',
      safetyNotice: '${json['safetyNotice'] ?? ''}',
      escalationText: '${json['escalationText'] ?? ''}',
      nexusReady: json['nexusReady'] == true,
      isFeatured: json['isFeatured'] == true,
      version: (json['version'] as num?)?.toInt() ?? 1,
      publishedAt: _date(json['publishedAt']),
      helpfulCount: (json['helpfulCount'] as num?)?.toInt() ?? 0,
      notHelpfulCount: (json['notHelpfulCount'] as num?)?.toInt() ?? 0,
    );
  }

  HdcKnowledgeArticle withFeedback({
    required int helpfulCount,
    required int notHelpfulCount,
  }) {
    return HdcKnowledgeArticle(
      publicArticleId: publicArticleId,
      slug: slug,
      category: category,
      title: title,
      summary: summary,
      body: body,
      steps: steps,
      tags: tags,
      safetyLevel: safetyLevel,
      safetyNotice: safetyNotice,
      escalationText: escalationText,
      nexusReady: nexusReady,
      isFeatured: isFeatured,
      version: version,
      publishedAt: publishedAt,
      helpfulCount: helpfulCount,
      notHelpfulCount: notHelpfulCount,
    );
  }
}

class HdcKnowledgeProvider extends ChangeNotifier {
  final HdcWorkflowApiClient? client;

  bool isLoading = false;
  String? errorMessage;
  String query = '';
  String? selectedCategory;
  List<HdcKnowledgeArticle> articles = const [];
  Map<String, int> categoryCounts = const {};

  HdcKnowledgeProvider({required this.client});

  Future<void> search({String query = '', String? category}) async {
    if (client == null) {
      errorMessage = 'HDC Knowledge Base services are unavailable.';
      notifyListeners();
      return;
    }
    isLoading = true;
    errorMessage = null;
    this.query = query.trim();
    selectedCategory = category?.trim().isEmpty == true ? null : category;
    notifyListeners();
    try {
      final parameters = <String, String>{
        if (this.query.isNotEmpty) 'q': this.query,
        if (selectedCategory != null) 'category': selectedCategory!,
      };
      final path = Uri(path: '/api/knowledge', queryParameters: parameters).toString();
      final data = await client!.getPublic(path);
      final rawArticles = data['articles'];
      articles = rawArticles is List
          ? List.unmodifiable(
              rawArticles.whereType<Map>().map(
                    (item) => HdcKnowledgeArticle.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  ),
            )
          : const [];
      final rawCounts = data['categoryCounts'];
      categoryCounts = rawCounts is Map
          ? Map.unmodifiable(
              rawCounts.map(
                (key, value) => MapEntry(
                  '$key',
                  value is num ? value.toInt() : 0,
                ),
              ),
            )
          : const {};
    } on Object catch (error) {
      errorMessage = '$error';
      articles = const [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<(HdcKnowledgeArticle, List<HdcKnowledgeArticle>)> loadArticle(
    String slug,
  ) async {
    if (client == null) {
      throw const HdcWorkflowException(
        code: 'knowledge_base_unavailable',
        message: 'HDC Knowledge Base services are unavailable.',
      );
    }
    final path = Uri(
      path: '/api/knowledge',
      queryParameters: {'slug': slug},
    ).toString();
    final data = await client!.getPublic(path);
    final rawArticle = data['article'];
    if (rawArticle is! Map) {
      throw const HdcWorkflowException(
        code: 'knowledge_article_not_found',
        message: 'That HDC guide is no longer available.',
      );
    }
    final article = HdcKnowledgeArticle.fromJson(
      Map<String, dynamic>.from(rawArticle),
    );
    final rawRelated = data['related'];
    final related = rawRelated is List
        ? List.unmodifiable(
            rawRelated.whereType<Map>().map(
                  (item) => HdcKnowledgeArticle.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                ),
          )
        : const <HdcKnowledgeArticle>[];
    return (article, related);
  }

  Future<(int, int)> submitFeedback({
    required HdcKnowledgeArticle article,
    required bool helpful,
    String note = '',
  }) async {
    if (client == null) {
      throw const HdcWorkflowException(
        code: 'knowledge_base_unavailable',
        message: 'HDC Knowledge Base services are unavailable.',
      );
    }
    final data = await client!.post(
      '/api/knowledge',
      body: {
        'publicArticleId': article.publicArticleId,
        'version': article.version,
        'helpful': helpful,
        'note': note,
      },
    );
    return (
      (data['helpfulCount'] as num?)?.toInt() ?? article.helpfulCount,
      (data['notHelpfulCount'] as num?)?.toInt() ?? article.notHelpfulCount,
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable(
    value.map((item) => '$item'.trim()).where((item) => item.isNotEmpty),
  );
}

DateTime? _date(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
