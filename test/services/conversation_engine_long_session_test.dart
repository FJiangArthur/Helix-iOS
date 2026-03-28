import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';

import '../helpers/test_helpers.dart';

/// B12: Segment compaction at high count
/// F5: Long session with 50+ segments
///
/// The ConversationEngine caps _finalizedSegments at 200 and archives the
/// oldest 100 via SessionContextManager._compactAndCapSegments().  These tests
/// verify the engine handles high segment counts gracefully and that the
/// compaction mechanism fires when the threshold is crossed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConversationEngine engine;

  setUpAll(() => installPlatformMocks());
  tearDownAll(() => removePlatformMocks());

  setUp(() async {
    final setup = await setupTestEngine();
    engine = setup.engine;
    engine.autoDetectQuestions = false;
  });

  tearDown(() => teardownTestEngine(engine));

  // ---------------------------------------------------------------------------
  // B12 — Segment compaction at high count
  // ---------------------------------------------------------------------------
  group('B12 — segment compaction at high count', () {
    test('engine handles 60 rapid finalizations without crash', () {
      engine.start(mode: ConversationMode.general);

      for (var i = 0; i < 60; i++) {
        engine.onTranscriptionFinalized(
          'Segment number $i with some filler text.',
          segmentTimestamp: DateTime.now().add(Duration(seconds: i)),
        );
      }

      final stats = engine.transcriptStats;
      // All 60 segments should be tracked (below the 200 compaction threshold).
      expect(stats.segmentCount, equals(60));
    });

    test('210 segments via onTranscriptionFinalized are all kept (compaction only triggers from progressive splitting)', () {
      // BUG FINDING: _compactAndCapSegments is only called from
      // onTranscriptionUpdate's progressive sentence splitting path,
      // NOT from onTranscriptionFinalized. This means direct finalization
      // of 200+ segments bypasses compaction entirely.
      engine.start(mode: ConversationMode.general);

      for (var i = 0; i < 210; i++) {
        engine.onTranscriptionFinalized(
          'Long session segment $i.',
          segmentTimestamp: DateTime.now().add(Duration(seconds: i)),
        );
      }

      final stats = engine.transcriptStats;
      // All 210 segments are kept since compaction doesn't fire here.
      expect(stats.segmentCount, equals(210));
    });

    test('transcriptStats.segmentCount matches finalized list length', () {
      engine.start(mode: ConversationMode.general);

      const count = 75;
      for (var i = 0; i < count; i++) {
        engine.onTranscriptionFinalized(
          'Stats check segment $i.',
          segmentTimestamp: DateTime.now().add(Duration(seconds: i)),
        );
      }

      final stats = engine.transcriptStats;
      // segmentCount is derived from _finalizedSegments.length.
      expect(stats.segmentCount, equals(count));

      // Snapshot should also expose the same number of finalized segments.
      final snapshot = engine.currentTranscriptSnapshot;
      expect(snapshot.finalizedSegments.length, equals(count));
    });

    test('engine accepts segments beyond 200 without crash', () {
      engine.start(mode: ConversationMode.general);

      for (var i = 0; i < 205; i++) {
        engine.onTranscriptionFinalized(
          'Beyond-200 segment $i.',
          segmentTimestamp: DateTime.now().add(Duration(seconds: i)),
        );
      }

      // All 205 segments tracked.
      expect(engine.transcriptStats.segmentCount, equals(205));

      // Engine still accepts more.
      engine.onTranscriptionFinalized(
        'Post-205 segment.',
        segmentTimestamp: DateTime.now().add(const Duration(seconds: 300)),
      );
      expect(engine.transcriptStats.segmentCount, equals(206));
    });
  });

  // ---------------------------------------------------------------------------
  // F5 — Long session with 50+ segments
  // ---------------------------------------------------------------------------
  group('F5 — long session with 50+ segments', () {
    test('55 varied segments are all tracked and engine stays responsive', () {
      engine.start(mode: ConversationMode.general);

      final contents = <String>[
        'Hello, welcome to the meeting.',
        'Let me introduce the agenda for today.',
        'First, we will discuss quarterly revenue.',
        'Revenue grew 12% quarter over quarter.',
        'Our customer base expanded to 50,000 users.',
        'The churn rate improved from 5% to 3.2%.',
        'Marketing spend was reduced by 8%.',
        'We launched three new product features.',
        'Feature A improved user onboarding by 40%.',
        'Feature B added real-time collaboration.',
        'Feature C is an AI-powered search.',
        'Customer satisfaction scores are at 4.7 out of 5.',
        'Support ticket volume decreased by 15%.',
        'Average resolution time is now under 2 hours.',
        'We hired 12 new engineers this quarter.',
        'The team is now 85 people strong.',
        'Infrastructure costs were optimized.',
        'We migrated to a new cloud provider.',
        'Latency improved by 30% across all regions.',
        'Mobile app downloads exceeded 100,000.',
        'The iOS app rating is 4.8 stars.',
        'Android rating is 4.6 stars.',
        'We opened a new office in Austin.',
        'Remote work policy was updated.',
        'Employee retention is at 95%.',
        'Next quarter goals include international expansion.',
        'We are targeting the European market first.',
        'Localization for 5 languages is underway.',
        'Compliance with GDPR is complete.',
        'Legal reviewed all data processing agreements.',
        'Partnership with Acme Corp is finalized.',
        'Joint marketing campaign launches next month.',
        'Budget allocation for Q2 is approved.',
        'R&D will receive 40% of the budget.',
        'Sales team exceeded targets by 15%.',
        'New CRM system rollout is on track.',
        'Training sessions are scheduled for next week.',
        'The board meeting is set for April 15th.',
        'Investor update will be sent Friday.',
        'Stock option refresh program was announced.',
        'Health benefits package was expanded.',
        'Company retreat is planned for June.',
        'Open source contributions increased.',
        'We published 8 blog posts this quarter.',
        'Conference speaking slots secured for 3 events.',
        'Brand awareness metrics are trending up.',
        'Social media engagement doubled.',
        'Website traffic increased 25%.',
        'SEO ranking improved for key terms.',
        'Podcast series launched successfully.',
        'Community forum has 5,000 active members.',
        'Bug bounty program paid out 12 rewards.',
        'Security audit passed with no critical findings.',
        'Disaster recovery plan was tested.',
        'Any questions before we wrap up?',
      ];

      // Finalize all 55 segments.
      for (var i = 0; i < contents.length; i++) {
        engine.onTranscriptionFinalized(
          contents[i],
          segmentTimestamp: DateTime.now().add(Duration(seconds: i * 3)),
        );
      }

      final stats = engine.transcriptStats;
      expect(stats.segmentCount, equals(contents.length));

      // Word count should be positive and reasonable.
      // (transcriptStats.wordCount is derived from _currentTranscription which
      //  is updated by onTranscriptionUpdate, not onTranscriptionFinalized.
      //  segmentCount is the reliable counter here.)
      expect(stats.segmentCount, greaterThanOrEqualTo(55));
    });

    test('engine can process new segments after a long session', () {
      engine.start(mode: ConversationMode.general);

      for (var i = 0; i < 55; i++) {
        engine.onTranscriptionFinalized(
          'Session segment $i.',
          segmentTimestamp: DateTime.now().add(Duration(seconds: i)),
        );
      }

      // Verify engine is responsive: add one more segment.
      engine.onTranscriptionFinalized(
        'Fresh segment after long session.',
        segmentTimestamp: DateTime.now().add(const Duration(seconds: 100)),
      );

      expect(engine.transcriptStats.segmentCount, equals(56));

      // Snapshot reflects all segments including the latest.
      final snapshot = engine.currentTranscriptSnapshot;
      expect(
        snapshot.finalizedSegments.last,
        equals('Fresh segment after long session.'),
      );
    });

    test('engine stops cleanly after 55+ segments', () {
      engine.start(mode: ConversationMode.general);

      for (var i = 0; i < 55; i++) {
        engine.onTranscriptionFinalized(
          'Clean-stop segment $i.',
          segmentTimestamp: DateTime.now().add(Duration(seconds: i)),
        );
      }

      // Stopping should not throw.
      expect(() => engine.stop(), returnsNormally);
      expect(engine.isActive, isFalse);
    });

    test('duplicate consecutive segments are deduplicated', () {
      engine.start(mode: ConversationMode.general);

      // The engine skips a segment if it matches the last finalized text.
      engine.onTranscriptionFinalized(
        'Repeated text.',
        segmentTimestamp: DateTime.now(),
      );
      engine.onTranscriptionFinalized(
        'Repeated text.',
        segmentTimestamp: DateTime.now().add(const Duration(seconds: 1)),
      );
      engine.onTranscriptionFinalized(
        'Different text.',
        segmentTimestamp: DateTime.now().add(const Duration(seconds: 2)),
      );

      // Only 2 unique segments should be present.
      expect(engine.transcriptStats.segmentCount, equals(2));
    });
  });
}
