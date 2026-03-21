// ABOUTME: Detail Analysis screen that replaces the Record tab.
// ABOUTME: Shows real-time transcript + Q&A during recording,
// ABOUTME: and post-conversation analysis (summary, topics, action items) after.

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/conversation_engine.dart';
import '../services/recording_coordinator.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/home_assistant_modules.dart';

class DetailAnalysisScreen extends StatefulWidget {
  const DetailAnalysisScreen({super.key});

  @override
  State<DetailAnalysisScreen> createState() => _DetailAnalysisScreenState();
}

class _DetailAnalysisScreenState extends State<DetailAnalysisScreen> {
  final _engine = ConversationEngine.instance;
  final _coordinator = RecordingCoordinator.instance;
  final ScrollController _scrollController = ScrollController();
  final List<StreamSubscription> _subs = [];

  bool _isRecording = false;
  Duration _duration = Duration.zero;
  String _transcription = '';
  String _aiResponse = '';
  final List<_QAEntry> _qaEntries = [];
  AssistantInsightSnapshot? _postAnalysis;
  int _wordCount = 0;
  int _segmentCount = 0;
  List<String> _segments = [];
  CoachingPrompt? _activeCoaching;

  @override
  void initState() {
    super.initState();

    _isRecording = _coordinator.isRecording.value;

    _subs.addAll([
      _coordinator.recordingStateStream.listen((recording) {
        if (!mounted) return;
        final wasPreviouslyRecording = _isRecording;
        setState(() => _isRecording = recording);

        if (!recording && wasPreviouslyRecording) {
          // Recording just stopped — build post-conversation analysis.
          _buildPostAnalysis();
        }

        if (recording) {
          // New recording started — clear previous state.
          setState(() {
            _transcription = '';
            _aiResponse = '';
            _qaEntries.clear();
            _postAnalysis = null;
            _wordCount = 0;
            _segmentCount = 0;
            _segments = [];
            _duration = Duration.zero;
            _activeCoaching = null;
          });
        }
      }),
      _coordinator.durationStream.listen((d) {
        if (!mounted) return;
        setState(() => _duration = d);
      }),
      _engine.transcriptSnapshotStream.listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _transcription = snapshot.fullTranscript;
          _segments = snapshot.finalizedSegments;
          _segmentCount = _segments.length;
          _wordCount = _transcription
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .length;
        });
        _scrollToBottom();
      }),
      _engine.aiResponseStream.listen((text) {
        if (!mounted) return;
        setState(() {
          _aiResponse = text;
          if (_qaEntries.isNotEmpty && text.trim().isNotEmpty) {
            _qaEntries.last = _qaEntries.last.copyWith(answer: text);
          }
        });
        _scrollToBottom();
      }),
      _engine.questionDetectionStream.listen((detection) {
        if (!mounted) return;
        setState(() {
          // Update or add Q&A entry.
          final existing = _qaEntries.indexWhere(
            (e) => e.question == detection.question,
          );
          if (existing == -1) {
            _qaEntries.add(_QAEntry(
              question: detection.question,
              questionExcerpt: detection.questionExcerpt,
              timestamp: detection.timestamp,
              answer: '',
            ));
          }
        });
        _scrollToBottom();
      }),
    ]);

    // Display STAR coaching when behavioral questions are detected in interview mode.
    _subs.add(
      _engine.coachingStream.listen((coaching) {
        if (!mounted) return;
        setState(() => _activeCoaching = coaching);
        _scrollToBottom();
      }),
    );

    // Upgrade local heuristic analysis with LLM-powered analysis when available.
    _subs.add(
      _engine.postConversationAnalysisStream.listen((result) {
        if (!mounted || result == null) return;
        final llmSnapshot = AssistantInsightSnapshot.fromLlmResponse(result);
        if (llmSnapshot != null && llmSnapshot.hasContent) {
          setState(() => _postAnalysis = llmSnapshot);
        }
      }),
    );
  }

  void _buildPostAnalysis() {
    final isChinese = SettingsManager.instance.language == 'zh';
    final snapshot = AssistantInsightSnapshot.fromConversation(
      transcription: _transcription,
      aiResponse: _aiResponse,
      history: _engine.history,
      isChinese: isChinese,
    );
    if (snapshot != null && snapshot.hasContent) {
      setState(() => _postAnalysis = snapshot);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleRecording() async {
    await _coordinator.toggleRecording(source: TranscriptSource.phone);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool get _isChinese => SettingsManager.instance.language == 'zh';

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              if (_isRecording) _buildRecordingIndicator(),
              const SizedBox(height: 8),
              Expanded(
                child: _isRecording
                    ? _buildActiveConversation()
                    : _buildPostConversation(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ── Recording indicator ────────────────────────────────────────

  Widget _buildRecordingIndicator() {
    return GlassCard(
      opacity: 0.14,
      borderColor: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isChinese ? '录音中' : 'Recording',
            style: const TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            _formatDuration(_duration),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // ── Active conversation view ───────────────────────────────────

  Widget _buildActiveConversation() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_transcription.isNotEmpty) _buildTranscriptCard(),
                if (_activeCoaching != null) ...[
                  const SizedBox(height: 10),
                  _buildCoachingCard(_activeCoaching!),
                ],
                if (_qaEntries.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._qaEntries.map(_buildQACard),
                ],
              ],
            ),
          ),
        ),
        _buildStatsBar(),
      ],
    );
  }

  Widget _buildTranscriptCard() {
    final partial = _engine.currentTranscriptSnapshot.partialText;
    return GlassCard(
      opacity: 0.1,
      borderColor: HelixTheme.cyan.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _isChinese ? '实时转录' : 'LIVE TRANSCRIPT',
                style: TextStyle(
                  color: HelixTheme.cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              if (_isRecording && _segmentCount > 0)
                Text(
                  _isChinese
                      ? '段落 $_segmentCount'
                      : 'seg $_segmentCount',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Show finalized segments with visual separation
          ..._segments.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            );
          }),
          // Show live partial transcription with different styling
          if (partial.isNotEmpty)
            Text(
              partial,
              style: TextStyle(
                color: HelixTheme.cyan.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQACard(_QAEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GlassCard(
        opacity: 0.08,
        borderColor: HelixTheme.purple.withValues(alpha: 0.22),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: HelixTheme.purple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.question,
                    style: TextStyle(
                      color: HelixTheme.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            // Excerpt context
            if (entry.questionExcerpt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  entry.questionExcerpt,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            // AI answer
            if (entry.answer.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                entry.answer,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
            // Timestamp
            const SizedBox(height: 8),
            Text(
              _formatTime(entry.timestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachingCard(CoachingPrompt coaching) {
    return GlassCard(
      opacity: 0.12,
      borderColor: HelixTheme.lime.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, size: 16, color: HelixTheme.lime),
              const SizedBox(width: 8),
              Text(
                '${coaching.framework} FRAMEWORK',
                style: TextStyle(
                  color: HelixTheme.lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            coaching.prompt,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          ...coaching.steps.map((step) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u2022 ',
                  style: TextStyle(
                    color: HelixTheme.lime,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Text(
                    step,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
          if (coaching.questionContext.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: HelixTheme.lime.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                coaching.questionContext,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: GlassCard(
        opacity: 0.1,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              Icons.timer_outlined,
              _formatDuration(_duration),
              _isChinese ? '时长' : 'Duration',
            ),
            _buildStatDivider(),
            _buildStatItem(
              Icons.text_fields_rounded,
              '$_wordCount',
              _isChinese ? '字数' : 'Words',
            ),
            _buildStatDivider(),
            Builder(builder: (_) {
              final stats = _engine.transcriptStats;
              return _buildStatItem(
                Icons.speed_rounded,
                stats.wordsPerMinute > 0
                    ? '${stats.wordsPerMinute.toInt()}'
                    : '--',
                'WPM',
              );
            }),
            _buildStatDivider(),
            _buildStatItem(
              Icons.segment_rounded,
              '$_segmentCount',
              _isChinese ? '段落' : 'Segments',
            ),
            _buildStatDivider(),
            _buildStatItem(
              Icons.help_outline_rounded,
              '${_qaEntries.length}',
              _isChinese ? '问题' : 'Questions',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: HelixTheme.cyan.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  // ── Post-conversation view ─────────────────────────────────────

  Widget _buildPostConversation() {
    final hasContent = _transcription.isNotEmpty ||
        _qaEntries.isNotEmpty ||
        _postAnalysis != null;

    if (!hasContent) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_postAnalysis != null) ...[
            _buildPostAnalysisCard(_postAnalysis!),
            const SizedBox(height: 10),
          ],
          if (_qaEntries.isNotEmpty) ...[
            _buildSectionHeader(
              _isChinese ? '问答记录' : 'Q&A HISTORY',
              Icons.quiz_outlined,
            ),
            const SizedBox(height: 8),
            ..._qaEntries.map(_buildQACard),
            const SizedBox(height: 10),
          ],
          if (_transcription.isNotEmpty) ...[
            _buildSectionHeader(
              _isChinese ? '完整转录' : 'FULL TRANSCRIPT',
              Icons.description_outlined,
            ),
            const SizedBox(height: 8),
            _buildTranscriptCard(),
          ],
          if (_coordinator.lastAudioFilePath != null) ...[
            const SizedBox(height: 10),
            _buildAudioFileCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_rounded,
            size: 64,
            color: HelixTheme.cyan.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isChinese ? '尚无对话分析' : 'No analysis yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isChinese
                ? '点击下方麦克风开始录音'
                : 'Tap the mic button to start recording',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: HelixTheme.cyan.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: HelixTheme.cyan.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildPostAnalysisCard(AssistantInsightSnapshot analysis) {
    return GlassCard(
      opacity: 0.12,
      borderColor: HelixTheme.purple.withValues(alpha: 0.25),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: 18,
                color: HelixTheme.purple,
              ),
              const SizedBox(width: 8),
              Text(
                _isChinese ? '对话分析' : 'CONVERSATION ANALYSIS',
                style: TextStyle(
                  color: HelixTheme.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          // Summary
          if (analysis.summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              analysis.summary,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],

          // Topics
          if (analysis.topics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _isChinese ? '话题' : 'TOPICS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: analysis.topics.map((topic) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: HelixTheme.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: HelixTheme.purple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    topic,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Action items
          if (analysis.actionItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _isChinese ? '行动项' : 'ACTION ITEMS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            ...analysis.actionItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: TextStyle(
                      color: HelixTheme.cyan,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],

          // Sentiment
          if (analysis.sentiment.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  _isChinese ? '情感倾向' : 'Sentiment',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _sentimentColor(analysis.sentiment)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    analysis.sentiment,
                    style: TextStyle(
                      color: _sentimentColor(analysis.sentiment),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioFileCard() {
    final path = _coordinator.lastAudioFilePath;
    if (path == null) return const SizedBox.shrink();

    final fileName = path.split('/').last;

    return GlassCard(
      opacity: 0.08,
      borderColor: Colors.white.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            Icons.audio_file_rounded,
            size: 20,
            color: HelixTheme.cyan.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isChinese ? '音频文件' : 'Audio File',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────

  bool _isSimulating = false;

  Widget _buildFab() {
    final color = _isRecording || _isSimulating
        ? const Color(0xFFFF6B6B)
        : HelixTheme.cyan;

    return GestureDetector(
      onLongPress: _isRecording ? null : _startSimulation,
      child: FloatingActionButton(
        onPressed: _isSimulating ? null : _toggleRecording,
        backgroundColor: color,
        child: Icon(
          _isRecording
              ? Icons.stop_rounded
              : _isSimulating
                  ? Icons.hourglass_top_rounded
                  : Icons.mic_rounded,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _startSimulation() async {
    if (_isSimulating || _isRecording) return;
    setState(() {
      _isSimulating = true;
      _transcription = '';
      _aiResponse = '';
      _qaEntries.clear();
      _postAnalysis = null;
      _wordCount = 0;
      _segmentCount = 0;
      _segments = [];
    });

    _engine.start(source: TranscriptSource.phone);
    setState(() => _isRecording = true);

    // Start a duration timer for the simulation
    final startTime = DateTime.now();
    final durationTimer = Stream.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now().difference(startTime),
    ).listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    await _engine.simulateTranscription();

    durationTimer.cancel();
    _engine.stop();

    if (mounted) {
      setState(() {
        _isSimulating = false;
        _isRecording = false;
      });
      _buildPostAnalysis();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color _sentimentColor(String sentiment) {
    final lower = sentiment.toLowerCase();
    if (lower.contains('positive') || lower.contains('smooth') ||
        lower.contains('\u79EF\u6781') || lower.contains('\u987A\u7545')) {
      return Colors.green;
    }
    if (lower.contains('cautious') || lower.contains('risk') ||
        lower.contains('\u8C28\u614E') || lower.contains('\u98CE\u9669')) {
      return Colors.orange;
    }
    return HelixTheme.cyan;
  }
}

// ── Internal data class ──────────────────────────────────────────

class _QAEntry {
  final String question;
  final String questionExcerpt;
  final DateTime timestamp;
  final String answer;

  const _QAEntry({
    required this.question,
    required this.questionExcerpt,
    required this.timestamp,
    required this.answer,
  });

  _QAEntry copyWith({String? answer}) {
    return _QAEntry(
      question: question,
      questionExcerpt: questionExcerpt,
      timestamp: timestamp,
      answer: answer ?? this.answer,
    );
  }
}
