import 'search_result.dart';

class GlobalSearchService {
  GlobalSearchService._();

  static final GlobalSearchService instance =
      GlobalSearchService._();

  final List<SearchResult> _index = [];

  void register(
    SearchResult result,
  ) {
    _index.add(result);
  }

  List<SearchResult> search(
    String keyword,
  ) {
    final query = keyword.toLowerCase();

    return _index.where((item) {
      return item.title
              .toLowerCase()
              .contains(query) ||
          item.subtitle
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  void clear() {
    _index.clear();
  }
}