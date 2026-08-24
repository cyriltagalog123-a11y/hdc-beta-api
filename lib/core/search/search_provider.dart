import 'package:flutter/material.dart';

import 'search_result.dart';

class SearchProvider extends ChangeNotifier {
  final List<SearchResult> _results = [];

  List<SearchResult> get results =>
      List.unmodifiable(_results);

  void setResults(
    List<SearchResult> value,
  ) {
    _results
      ..clear()
      ..addAll(value);

    notifyListeners();
  }

  void clear() {
    _results.clear();

    notifyListeners();
  }
}