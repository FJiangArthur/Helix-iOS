# Cumulative Session Cost Tracking

**Date:** 2026-04-06
**Status:** Draft
**Spec ID:** D
**Depends on:** Spec A (model_role tagging on LLM calls — smart vs light)

> This spec is mostly additive. The existing `ConversationCostTracker` and the
> `ConversationAiCostEntries` Drift table already do most of the per-call work.
> The new pieces are: per-session totals on the `Conversations` row, a live
> stream for the UI, model_role attribution, and transcription-minute pricing.

---

## Open questions

1. **Live display location.** Recommended: a small pill in the home screen
   recording bar (next to the timer). Alternative: header chip on the active
   conversation card. Decision needed before UI work starts.
2. **Currency.** USD only for v1, or honor a user-selected display currency?
   Recommendation: store USD, format USD in the UI, defer i18n.
3. **Light-model price source.** Spec A allows a different model for the
   "light" role. If the user picks a non-OpenAI model (e.g. DeepSeek), we
   currently have no pricing. Block on light role at v1 to OpenAI-priced
   models, or ship "—" for unknown providers and add prices incrementally?
   Recommendation: ship "—" + log a warning so the cost row is honest.
4. **Transcription minute source of truth.** Where do we get the audio
   duration that OpenAI Realtime billed against — the WebSocket `usage` event,
   or our own mic clock? Recommendation: prefer the server `usage` event when
   present, fall back to local mic seconds.
5. **Mid-session crash recovery.** Do we periodically flush totals to the
   `Conversations` row, or accept that a kill loses the in-memory tally?
   Recommendation: flush on every recordCompleted (cheap, idempotent UPDATE).
6. **Free models and "$0.00".** Show "Free" or "$0.00" for Apple
   On-Device / Apple Cloud transcription? Recommendation: "Free".

---

## 1. Current state audit

### `lib/services/cost/conversation_cost_tracker.dart`

- `ConversationCostTracker` is a plain in-memory list:
  - `final List<ConversationCostEntry> _entries`
  - `recordCompleted({operationType, providerId, modelId, usage, costUsd, …})`
  - `double get totalCostUsd` — folds `entry.costUsd ?? 0`
  - `void reset()` — clears entries
  - **No streams, no listeners, no persistence.** Owned per-instance.
- `ConversationCostEntry` carries `AiOperationType`, `providerId`, `modelId`,
  `LlmUsage`, timestamps, status, and `costUsd?`. **No `modelRole` field.**
- `OpenAiPricingRegistry` is **hardcoded** in this file:
  - `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.4-nano` (input / cached / output per-1M)
  - `gpt-4o-mini-transcribe` (audio input per-1M only)
  - **No prices for** Anthropic, DeepSeek, Qwen, Zhipu, OpenRouter, SiliconFlow,
    OpenAI Realtime per-minute, Apple Cloud, Apple On-Device.
  - `calculateCostUsd` returns `null` for any unknown model — silently drops.

### `lib/services/conversation_engine.dart`

- Owns one `ConversationCostTracker` instance (line 67).
- `reset()` is called when a new session starts (line 236).
- `onTranscriptionUsage(...)` records transcription usage from native
  channel callbacks (line 529). Pricing only computed when
  `providerId == 'openai'`.
- `_recordLlmMetadata(LlmResponseMetadata)` records every LLM completion
  (line 2161). Same OpenAI-only pricing path.
- On `_saveConversation`, the engine inserts every entry into the
  `ConversationAiCostEntries` table tied to the saved `conversationId`
  (line 359). This is **per-call** persistence.
- **The `Conversations` row itself stores no totals** — to render history
  cost we currently must `SUM(costUsd)` over `ConversationAiCostEntries`.

### `lib/services/database/helix_database.dart`

Existing relevant tables:

```dart
class Conversations extends Table {
  TextColumn get id => text()();
  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();
  TextColumn get mode => text()…;
  TextColumn get title => text().nullable()();
  // … no cost columns
}

class ConversationAiCostEntries extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get operationType => text()();   // answer, transcription, …
  TextColumn get providerId => text()();
  TextColumn get modelId => text()();
  IntColumn get inputTokens / outputTokens / cachedInputTokens
           / audioInputTokens / audioOutputTokens => integer()…;
  RealColumn get costUsd => real().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get status => text()…;
  // no modelRole
}
```

### LLM providers (`lib/services/llm/*.dart`)

- All providers return an `LlmResponseMetadata` with `LlmUsage` parsed from the
  provider's `usage` object via `LlmUsage.fromJson` (covers OpenAI,
  OpenAI-compatible, and Anthropic key shapes).
- `LlmResponseMetadata` has `providerId`, `modelId`, `usage`, `operationType?`.
  **It has no `modelRole`** — Spec A introduces this.
- Anthropic stream finishes via `message_delta` events that include
  `usage.output_tokens`; usage is wired through identically to OpenAI.

### Transcription (`ios/Runner/OpenAIRealtimeTranscriber.swift`,
`SpeechStreamRecognizer.swift`)

- OpenAI Realtime: WebSocket receives a `transcription.usage` (or
  `response.usage`) event; AppDelegate forwards to Dart over the
  `eventRealtimeAudio` channel where `onTranscriptionUsage` consumes it.
- Apple Cloud and Apple On-Device: **no usage event, no cost path.** These
  backends never call `onTranscriptionUsage`. They are free, so this is
  semantically correct but should be made explicit (see §5).

---

## 2. Pricing source

**Today:** hardcoded `_pricingByModel` map inside
`conversation_cost_tracker.dart`, OpenAI only.

**Proposed:** keep prices hardcoded in code (not config) but split into a
dedicated `lib/services/cost/pricing_registry.dart` keyed by
`(providerId, modelId)`, returning a unified `ModelPricing` value:

```dart
class ModelPricing {
  final double? inputPerMillionUsd;
  final double? cachedInputPerMillionUsd;
  final double? outputPerMillionUsd;
  final double? audioInputPerMillionUsd;   // OpenAI realtime audio tokens
  final double? audioInputPerMinuteUsd;    // OpenAI Realtime billed per minute
}
```

A single `PricingRegistry.priceFor(providerId, modelId)` resolves to
`ModelPricing?` and handles both LLM token pricing and transcription audio
pricing in one place. `OpenAiPricingRegistry` becomes a thin shim for
back-compat and is deleted in a follow-up.

**Spec A interaction.** Spec A lets the user pick a different model for the
light role. The pricing registry must contain entries for every model the
user can pick in Spec A's two-model selector. For v1 we accept that
non-OpenAI providers (Anthropic / DeepSeek / Qwen / Zhipu / OpenRouter /
SiliconFlow) will return `null` and the UI will render "—" for that segment
of the breakdown. Adding a price is one PR, one map entry.

---

## 3. Data model changes

### Migration: add per-session totals to `Conversations`

```dart
class Conversations extends Table {
  // … existing columns …
  IntColumn get costSmartUsdMicros        => integer().nullable()();
  IntColumn get costLightUsdMicros        => integer().nullable()();
  IntColumn get costTranscriptionUsdMicros => integer().nullable()();
  IntColumn get costTotalUsdMicros        => integer().nullable()();
  // currency assumed USD; reuse currency column convention from cost entries
}
```

- Store costs as integer **micro-USD** (1 USD = 1,000,000) to avoid float
  drift. Display layer divides by 1e6.
- Nullable so historic conversations stay legal without a backfill.
- Drift schema bump: add a numbered migration in `migration_service.dart`
  that runs `ALTER TABLE conversations ADD COLUMN cost_*_usd_micros INTEGER`
  for each new column. Non-destructive. No data loss.
- Optional backfill step (best-effort): for each existing conversation,
  `SELECT SUM(cost_usd) FROM conversation_ai_cost_entries WHERE
  conversation_id = ?` grouped by a derived role (see §4) and write into the
  new columns. Skip rows where totals can't be computed.

### Add `modelRole` to `ConversationAiCostEntries`

```dart
TextColumn get modelRole => text().nullable()();   // 'smart' | 'light' | 'transcription'
```

Nullable for back-compat with rows written before this spec ships.

---

## 4. Recording cost on each LLM call (with `modelRole`)

### Where the data enters today

Every provider (`openai_provider.dart`, `anthropic_provider.dart`,
`openai_compatible_provider.dart`) emits an `LlmResponseMetadata` at the end
of a streamed response. `ConversationEngine._recordLlmMetadata` is the funnel.

### The Spec A coupling

Spec A introduces a per-call concept: which **role** the model is playing —
the "smart" model for primary answers, or the "light" model for cheap
ancillary work (auto-detect, fact-check, segmentation). The role is decided
at call-site, not by the provider.

### Proposed API change

Extend `LlmResponseMetadata` (defined in `lib/services/llm/llm_provider.dart`)
with an optional field, populated by the caller (Spec A's responsibility):

```dart
enum ModelRole { smart, light, transcription }

class LlmResponseMetadata {
  // … existing …
  final ModelRole? modelRole;   // null = unknown, treated as 'smart'
}
```

`ConversationEngine._recordLlmMetadata` then forwards the role to
`ConversationCostTracker.recordCompleted(..., modelRole: …)`. Tracker stores
it on the `ConversationCostEntry` and later attributes the running totals.

Transcription is recorded directly with `ModelRole.transcription` from
`onTranscriptionUsage`.

### Tracker totals API (new)

```dart
class ConversationCostTracker {
  // existing
  Stream<SessionCostSnapshot> get snapshots;   // emits on every recordCompleted
  SessionCostSnapshot get current;
}

class SessionCostSnapshot {
  final double smartUsd;
  final double lightUsd;
  final double transcriptionUsd;
  final double totalUsd;
  final int unpricedCallCount;   // calls where pricing returned null
}
```

The stream is the binding point for the live UI (§5).

---

## 5. Transcription cost

### Today

Only OpenAI batch transcription (`gpt-4o-mini-transcribe`) has a price entry,
and it is priced per audio-input token. Realtime per-minute billing is
**not** modeled. Apple backends report no usage, which is correct but
implicit.

### Proposed

1. **OpenAI Realtime per-minute.** Add a `audioInputPerMinuteUsd` field on
   `ModelPricing`. Native `OpenAIRealtimeTranscriber` already receives
   `usage` events from the WebSocket; extend the bridge to also forward
   `inputAudioSeconds` (and `outputAudioSeconds` if any) to Dart. The Dart
   `onTranscriptionUsage` then computes `(seconds / 60) * pricePerMinute`
   and feeds it into the tracker via the existing `recordCompleted` path,
   wrapping the value in a synthetic `LlmUsage` plus a precomputed
   `costUsd`. (Alternative: thread an explicit `audioSeconds` field through
   `LlmUsage` and let pricing happen centrally — preferred for symmetry.)
2. **Apple Cloud / On-Device.** Record an explicit zero-cost entry with
   `providerId='apple'`, `modelId='cloud' | 'on-device'`,
   `modelRole=transcription`, `costUsd=0.0`. This makes the breakdown honest
   ("Transcription: Free") and means free sessions still appear in the
   tracker stream so the UI updates correctly.
3. **Rates source.** Add to `pricing_registry.dart` next to the LLM prices.
   Cite the OpenAI pricing page URL in a comment alongside the constants;
   no separate config file.

---

## 6. Live UI

### Where

**Recommended:** a compact pill in the recording bar on
`lib/screens/home_screen.dart`, immediately right of the elapsed-time
counter. Updates while the user records. Unobtrusive but always visible
during the action that costs money.

**Rejected alternatives:**
- Header chip on the home screen — too far from the recording context.
- Settings page — invisible during recording, defeats the purpose.

### How

A small `SessionCostBadge` widget subscribes to
`ConversationEngine.instance.costSnapshots` (which the engine exposes by
forwarding `_conversationCostTracker.snapshots`). Rebuilds via
`StreamBuilder<SessionCostSnapshot>`.

### Format

- Show total only on the badge: `$0.0234` (4 decimal places, never rounded
  to zero — users want to see the dial move).
- Long-press / tap opens a small bottom sheet with the per-role breakdown:

  | Role | Model | Cost |
  | --- | --- | --- |
  | Smart | gpt-5.4 | $0.0182 |
  | Light | gpt-5.4-nano | $0.0008 |
  | Transcription | gpt-4o-mini-transcribe | $0.0044 |
  | **Total** | | **$0.0234** |

- For zero totals show "Free" instead of "$0.0000".
- For unpriced calls show "—" with a footnote: "{n} call(s) had no pricing
  data."
- Decision: stick with `$0.0234` rather than `2.3¢`. Cents notation is
  cute but micro-amounts read poorly (`0.234¢`).

---

## 7. History UI

### List cell

In `lib/screens/conversation_history_screen.dart`, append a small trailing
label to each row showing `costTotalUsdMicros` formatted as `$0.0234`.
Hide if the column is null (legacy rows). Free sessions show "Free".

### Detail screen

In `lib/screens/conversation_detail_screen.dart`, add a "Cost" section near
the metadata header. Render the same per-role table as the live bottom
sheet, sourced from the persisted `Conversations` columns. For drill-down,
a "Show calls" disclosure expands the per-call rows from
`ConversationAiCostEntries` filtered by `conversationId` (this view exists
in the table today, just unused).

---

## 8. Edge cases

| Case | Behavior |
| --- | --- |
| App killed mid-session | Per-call rows are inserted only on `_saveConversation`. To survive a kill, also flush running totals to the `Conversations` row on every `recordCompleted` (UPSERT — the conversation row may not exist yet, in which case skip until it does). Accepted loss: in-memory entries between crash and last flush. |
| Provider returns no `usage` | `LlmUsage.hasAnyUsage == false` → tracker skips, total unchanged. Logged at debug. |
| Pricing returns `null` (unknown model) | Entry still recorded with `costUsd = null`, increments `unpricedCallCount`. UI shows "—". |
| Free model (Apple transcription) | Explicit `costUsd = 0.0` row, contributes 0 to total, surfaces as "Free" in the breakdown. |
| `modelRole == null` on legacy rows | Treated as `smart` for aggregation. |
| Cached input tokens | Already handled by `ModelPricing.cachedInputPerMillionUsd`. No change. |
| Anthropic / DeepSeek / etc. | Recorded with `costUsd = null` until prices are added to the registry. Tokens still persisted, so a future migration can backfill cost. |
| Engine `reset()` between sessions | Tracker stream emits a zeroed snapshot so the badge resets to `$0.0000`. |

---

## 9. Testing strategy

### Unit — `test/services/conversation_cost_tracker_test.dart`

- `recordCompleted` with a fake `LlmUsage` for each role accumulates into the
  correct snapshot bucket.
- Pricing-null calls increment `unpricedCallCount` and do not affect the
  total.
- `reset()` emits a zeroed snapshot.
- Apple-zero entries contribute 0 and do not raise `unpricedCallCount`.
- OpenAI Realtime per-minute math: 90 seconds at $0.06/min == $0.09.
- `SessionCostSnapshot` totals equal sum of role buckets within float epsilon.

### Unit — `test/services/cost/pricing_registry_test.dart`

- Round-trip a known OpenAI model returns expected USD.
- Unknown `(provider, model)` returns `null`.

### Drift migration — `test/database/migration_test.dart`

- Apply the new migration to a v(N-1) snapshot DB; assert columns exist and
  existing rows are preserved with `null` cost columns.

### Widget — `test/widgets/session_cost_badge_test.dart`

- Build the badge with a fake `Stream<SessionCostSnapshot>`, push three
  snapshots, assert text updates from `$0.0000` → `$0.0050` → `$0.0234`.
- Free state renders "Free".
- Tap opens the breakdown sheet and renders the per-role table.

### Integration — extend
`test/services/conversation_engine_*` (existing suite)

- After a fake LLM round-trip via the engine's test seam, the tracker
  contains one entry, the snapshot total is non-zero, and on session save
  the `Conversations` row has matching `costTotalUsdMicros`.

### Validation gate

Per `CLAUDE.md`, after editing `conversation_engine.dart` run the full gate:
`bash scripts/run_gate.sh`.

---

## 10. Out of scope

- Multi-currency display.
- Per-user budgets / spending caps / alerts (good follow-on spec).
- Backfilling cost for conversations recorded before the
  `ConversationAiCostEntries` table existed.
- Server-side billing reconciliation against the OpenAI dashboard.
