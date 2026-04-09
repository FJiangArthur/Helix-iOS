/// Abstraction over the web-search backend used by active fact-checking.
///
/// Implementations MUST NOT throw — network or auth failures should resolve
/// to an empty list and be logged via `appLogger.d`. This keeps active
/// fact-checking strictly additive on top of the primary answer pipeline.
library;

class WebSearchResult {
  const WebSearchResult({
    required this.url,
    required this.title,
    required this.snippet,
    this.score,
  });

  final String url;
  final String title;
  final String snippet;
  final double? score;
}

abstract class WebSearchProvider {
  Future<List<WebSearchResult>> search(String query, {int maxResults = 3});
}
