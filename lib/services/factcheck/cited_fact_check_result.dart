/// Data types for active (web-grounded) fact-checking.
///
/// These are emitted on `ConversationEngine.citedFactCheckStream` after the
/// primary answer stream finalizes, when `activeFactCheckEnabled` is on and a
/// Tavily API key is configured. See `.planning/orchestration/reports/WS-E-investigation.md`.
library;

/// A single source returned from a web search backend, reduced to the fields
/// required by the verifier LLM and the UI disclosure row.
class CitedSource {
  const CitedSource({
    required this.url,
    required this.title,
    required this.snippet,
    this.score,
  });

  final String url;
  final String title;
  final String snippet;
  final double? score;

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'snippet': snippet,
    if (score != null) 'score': score,
  };
}

/// Verdict returned by the verifier LLM after comparing the primary answer
/// against the web search results.
enum FactCheckVerdict { supported, contradicted, unclear }

FactCheckVerdict factCheckVerdictFromString(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'supported':
      return FactCheckVerdict.supported;
    case 'contradicted':
      return FactCheckVerdict.contradicted;
    default:
      return FactCheckVerdict.unclear;
  }
}

/// Result of an active fact-check pass. Always carries the `sources` the
/// verifier was shown so the UI can render a Sources disclosure even when
/// the verdict is `unclear`.
class CitedFactCheckResult {
  CitedFactCheckResult({
    required this.verdict,
    required this.sources,
    this.correction,
    DateTime? checkedAt,
  }) : checkedAt = checkedAt ?? DateTime.now();

  final FactCheckVerdict verdict;
  final String? correction;
  final List<CitedSource> sources;
  final DateTime checkedAt;

  bool get hasSources => sources.isNotEmpty;
}
