/// Roles a model can play in the conversation pipeline.
///
/// `smart` is the primary answer-generating model, `light` is the cheap
/// ancillary model (e.g. question detection, fact-check, segmentation), and
/// `transcription` is any speech-to-text path. Spec A is responsible for
/// tagging LLM call sites with the right role; legacy `null` is treated as
/// `smart` by the cost tracker.
enum ModelRole { smart, light, transcription }

/// Immutable snapshot of cumulative session cost broken down by role.
///
/// Stored in USD as `double` for in-memory math; persisted to the database
/// as integer micro-USD (1 USD = 1_000_000) to avoid float drift.
class SessionCostSnapshot {
  const SessionCostSnapshot({
    this.smartUsd = 0,
    this.lightUsd = 0,
    this.transcriptionUsd = 0,
    this.unpricedCallCount = 0,
  });

  final double smartUsd;
  final double lightUsd;
  final double transcriptionUsd;
  final int unpricedCallCount;

  double get totalUsd => smartUsd + lightUsd + transcriptionUsd;

  static const SessionCostSnapshot zero = SessionCostSnapshot();
}
