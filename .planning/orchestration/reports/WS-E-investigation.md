# WS-E Investigation: Active Fact-Checking with Live Web Search

## 1. Existing Pipeline Map

**Trigger point:** `lib/services/conversation_engine.dart:2151` — after the primary answer stream finalizes, `unawaited(_postResponseAnalysis(question, finalResponse))` fires.

**Primary implementation:** `_postResponseAnalysis()` at `conversation_engine.dart:1279-1353`. Merged call to the light LLM model returning `{chips, factCheck}`. On parse failure falls back to `_generateFollowUpChips()` + `_backgroundFactCheck()`.

**Legacy fact-check:** `_backgroundFactCheck()` at `conversation_engine.dart:1244-1275` — closed-book; expects literal `OK` or one-sentence correction. No external grounding, no citations.

**Surface:**
- Controller: `_factCheckAlertController` (broadcast `StreamController<String>`), `conversation_engine.dart:137`
- Public stream: `factCheckAlertStream` at line 169
- Consumer: `home_screen.dart` — gated by `profile.showFactCheck` (lines 891, 1048, 1097, 1447, 2082). Tools row has manual `onFactCheck: _factCheckLastAnswer` at 2087.
- Closed on dispose: `conversation_engine.dart:2866`

**Persistence:** `FactsDao` (`lib/services/database/facts_dao.dart`) exists with a `facts` Drift table — NOT wired to background fact-check; separate longer-lived entity-memory store. Current alerts are ephemeral.

**Today:** Closed-book hallucination check only. No web, no citations.

## 2. Web Search Provider Comparison (2026-04)

| Provider | Cost / 1k | Latency | Citations | Auth | Notes |
|---|---|---|---|---|---|
| **Tavily** | ~$5 (basic) | 400–1200 ms | Native `{title, url, content, score}` | API key | Built for LLM RAG |
| Brave Search | ~$3 | 200–600 ms | SERP only | API key | Cheap; need page fetching |
| Exa | $5–10 | 500–1500 ms | Highlights + full text | API key | Neural search |
| Perplexity Sonar | $5 + tokens | 1–3 s | Inline citations | API key | Overlaps our LLM |
| Bing | $15 | 300–700 ms | SERP only | Azure | Expensive |
| Google CSE | $5 (after 100/day free) | 300–700 ms | SERP | API key + cx | Cumbersome |
| OpenAI built-in | per-call + tokens | 2–5 s | Native tool | OpenAI key | Locks to OpenAI only |
| Anthropic web_search | per-call | 2–5 s | Native | Anthropic key | Locks to Claude only |

## 3. Recommended: **Tavily**

1. **Provider-agnostic** — Helix supports 7+ LLM providers; provider-native tools break feature for ~70% of users.
2. **Designed for RAG** — pre-cleaned content snippets, no scraping.
3. **Cost & latency** fit background window.
4. **Simple auth** — single API key via `FlutterSecureStorage`.
5. **Citation shape** matches need: `url + title + content`.

Fallback: if unreachable, degrade to existing closed-book check (current behavior).

## 4. Architecture

```
Primary answer stream completes
  ↓
_postResponseAnalysis (existing) — chips + closed-book
  ↓
IF activeFactCheckEnabled && apiKey != null:
  _activeFactCheck(question, finalResponse)
    1. Query = finalResponse (single query, YAGNI)
    2. WebSearchProvider.search(query) → List<WebSearchResult>
    3. Light-LLM verify: JSON {verdict, correction, citedIndices}
    4. Build CitedFactCheckResult
    5. Emit on _citedFactCheckController
  ↓
Home screen → "Sources (N)" disclosure under existing fact-check line
```

**Timing:** non-blocking, additive on top of `unawaited(_postResponseAnalysis(...))`. Phone-only UI; no HUD latency impact.

## 5. Settings Flag

Following existing `settings_manager.dart:468` pattern:
- `activeFactCheckEnabled` (bool, default `false`)
- `tavilyApiKey` (String via `FlutterSecureStorage`)
- `activeFactCheckMaxResults` (int, default `3`)

Strictly additive: when disabled or key missing, behavior unchanged.

## 6. Data Model

```dart
class CitedSource {
  final String url;
  final String title;
  final String snippet;
  final double? score;
}

enum FactCheckVerdict { supported, contradicted, unclear }

class CitedFactCheckResult {
  final FactCheckVerdict verdict;
  final String? correction;
  final List<CitedSource> sources;
  final DateTime checkedAt;
}
```

New broadcast: `Stream<CitedFactCheckResult> get citedFactCheckStream`.
Existing `factCheckAlertStream` untouched.

**Persistence: skip Drift in v1** (YAGNI). If needed later, extend `facts` table with nullable `sourcesJson TEXT` column rather than new table.

## 7. File Allowlist

**New:**
- `lib/services/factcheck/web_search_provider.dart`
- `lib/services/factcheck/tavily_search_provider.dart`
- `lib/services/factcheck/cited_fact_check_result.dart`
- `test/services/factcheck/tavily_search_provider_test.dart`
- `test/services/factcheck/active_fact_check_test.dart`

**Modified (must stay within):**
- `lib/services/conversation_engine.dart`
- `lib/services/settings_manager.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/settings_screen.dart` (or actual settings file — confirm)
- `pubspec.yaml` (no new deps expected; `dio` + `flutter_secure_storage` present)

**Out of scope:** any `lib/services/llm/`, `lib/services/database/`, BLE/HUD code.

## 8. Implementation Steps

1. Create DTOs in `cited_fact_check_result.dart`
2. Create abstract `WebSearchProvider`
3. Implement Tavily provider — `POST https://api.tavily.com/search` with `{api_key, query, max_results, include_answer: false}`. Try/catch → empty list on failure
4. Extend `SettingsManager` with flag + key (default off)
5. Add `_activeFactCheck()` to `ConversationEngine`. Gate inside method (testability)
6. Add `_citedFactCheckController` + getter; close in `dispose()` near line 2866
7. Wire call site at line 2151: `unawaited(_activeFactCheck(...))`
8. Home screen: subscribe to `citedFactCheckStream`, render Sources disclosure
9. Settings screen: toggle + API key field
10. Unit tests (provider + pipeline with fakes)
11. Run full gate (`conversation_engine.dart` triggers full gate per CLAUDE.md)

## 9. Sim Test Plan

**Prereq:** dedicated Helix sim, Tavily key set, flag on.

- **T1** Flag off (default): existing behavior unchanged, no `citedFactCheckStream` emission
- **T2** Supported claim: "What year did the iPhone first launch?" → Sources appears with `supported`, ≥1 source
- **T3** Contradiction: forced wrong answer → `contradicted` + correction
- **T4** Missing key with flag on: graceful skip, no crash
- **T5** Network failure (Network Link Conditioner): graceful, primary answer unaffected
- **T6** Latency: HUD render time unchanged (non-blocking verification)
- **T7** Gate: analyze + test + build all pass
- **T8** Unit: every `CitedSource` has valid url/title/trimmed snippet

## Essential Read List for Build Agent

- `lib/services/conversation_engine.dart` (130–170, 1244–1353, 2140–2160, 2860–2870)
- `lib/services/llm/llm_service.dart` + `llm_provider.dart` — `ChatMessage`, `getResponse`, `resolvedLightModel`
- `lib/services/settings_manager.dart` (300–490)
- `lib/screens/home_screen.dart` (880–1100, 2080–2095)
- `lib/services/database/facts_dao.dart` — reference only, do NOT extend in v1
- `CLAUDE.md` — `conversation_engine.dart` triggers full gate
