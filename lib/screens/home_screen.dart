import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import '../models/assistant_profile.dart';
import '../services/conversation_listening_session.dart';
import '../services/conversation_engine.dart';
import '../services/factcheck/cited_fact_check_result.dart';
import '../services/recording_coordinator.dart';
import '../services/glasses_answer_presenter.dart';
import '../services/llm/llm_service.dart';
import '../services/projects/project_rag_service.dart';
import '../services/provider_error_state.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../utils/transcript_timestamps.dart';
import '../widgets/active_project_chip.dart';
import '../widgets/glass_card.dart';
import '../widgets/helix_visuals.dart';
import '../widgets/session_cost_badge.dart';
import '../widgets/home_assistant_modules.dart';
import '../widgets/status_indicator.dart';
import '../app.dart';
import '../ble_manager.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const double _composerDockHeight = 66;

  final _engine = ConversationEngine.instance;
  final _coordinator = RecordingCoordinator.instance;

  ConversationMode _currentMode = ConversationMode.general;
  EngineStatus _status = EngineStatus.idle;
  TranscriptSource _transcriptSource = TranscriptSource.phone;
  String _transcription = '';
  List<TranscriptSegment> _transcriptEntries = const [];
  String _aiResponse = '';
  bool _isRecording = false;
  // WS-B Fix 3: once the live card is shown during a session, latch it on
  // until the user explicitly stops recording. Guards against transient
  // stream glitches (empty snapshot / brief recording=false) that would
  // otherwise flip hasLiveConversation false for one frame and collapse
  // the CONVERSATION HUB to the LOADOUT placeholder.
  bool _liveCardLatched = false;
  RecordingCaptureState _recordingCaptureState = RecordingCaptureState.idle;
  bool _showDetailLink = false;
  Duration _recordingDuration = Duration.zero;
  int _segmentCount = 0;
  bool _manualAnalyzePending = false;

  final List<StreamSubscription> _subscriptions = [];
  final ScrollController _scrollController = ScrollController();

  // Tracks whether the user has manually scrolled away from the bottom while
  // a streaming answer is rendering. While true, _scrollToBottom is a no-op
  // — the user is reading earlier transcript and we will not yank them back.
  // Cleared when the user scrolls back to within 16px of the bottom OR when
  // a new recording session starts. See
  // .planning/todos/pending/2026-04-08-homescreen-scroll-snap-on-long-streaming
  // -answer.md — the previous content-relative 64px tolerance was insufficient
  // because long answers add multiple lines per flush and the "distance from
  // bottom" metric crosses the threshold in either direction between frames.
  bool _userHasScrolledUp = false;
  final TextEditingController _askController = TextEditingController();
  final FocusNode _askFocusNode = FocusNode();
  bool _hasApiKey = false;
  AssistantQuickAskPreset _selectedPreset = AssistantQuickAskPreset.concise;
  ProviderErrorState? _providerError;
  String _assistantProfileId = 'general';
  QuestionDetectionResult? _latestQuestionDetection;
  GlassesAnswerDeliveryState _glassesDeliveryState =
      GlassesAnswerPresenter.instance.currentState;
  String? _listeningError;
  String? _rawListeningError;
  bool _errorDetailExpanded = false;
  List<String> _followUpChips = const [];
  CitedFactCheckResult? _citedFactCheck;
  bool _citedFactCheckExpanded = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _modeSwitchController;
  late Animation<double> _modeSwitchAnimation;

  @override
  void initState() {
    super.initState();

    // Track user-initiated scroll so streaming answers don't yank the user
    // back to the bottom while they're reading earlier transcript.
    _scrollController.addListener(_handleScrollPositionChange);

    _checkApiKey();
    final settings = SettingsManager.instance;
    _selectedPreset = _presetFromId(settings.defaultQuickAskPreset);
    _assistantProfileId = settings.assistantProfileId;
    _engine.autoDetectQuestions = settings.autoDetectQuestions;
    _engine.answerAll = settings.answerAll;
    _recordingCaptureState = _coordinator.currentCaptureState;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _modeSwitchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: 1.0,
    );
    _modeSwitchAnimation = CurvedAnimation(
      parent: _modeSwitchController,
      curve: Curves.easeOutCubic,
    );

    _subscriptions.addAll([
      SettingsManager.instance.onSettingsChanged.listen((_) {
        _checkApiKey();
        _engine.autoDetectQuestions =
            SettingsManager.instance.autoDetectQuestions;
        _engine.answerAll = SettingsManager.instance.answerAll;
        if (mounted) {
          setState(() {
            _assistantProfileId = SettingsManager.instance.assistantProfileId;
            _selectedPreset = _presetFromId(
              SettingsManager.instance.defaultQuickAskPreset,
            );
          });
        }
      }),
      _coordinator.recordingStateStream.listen((recording) {
        if (!mounted) return;
        final wasRecording = _isRecording;
        setState(() {
          _isRecording = recording;
          if (!recording && wasRecording) {
            _showDetailLink = true;
            _liveCardLatched = false;
          }
          if (recording) {
            _resetLiveSessionUiState();
            _liveCardLatched = true;
            // New session: clear any "user scrolled up" lock so the first
            // streaming answer of the session always auto-scrolls.
            _userHasScrolledUp = false;
          }
        });
      }),
      _coordinator.captureStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _recordingCaptureState = state);
      }),
      _coordinator.durationStream.listen((d) {
        if (!mounted) return;
        setState(() => _recordingDuration = d);
      }),
      _engine.transcriptSnapshotStream.listen((snapshot) {
        if (!mounted) return;
        debugPrint(
          '[HomeScreen] transcriptSnapshot: segments=${snapshot.finalizedSegments.length}, '
          'transcript="${snapshot.fullTranscript.length > 60 ? snapshot.fullTranscript.substring(0, 60) : snapshot.fullTranscript}"',
        );
        setState(() {
          _transcription = snapshot.fullTranscript;
          _transcriptEntries = snapshot.finalizedTimelineEntries;
          _transcriptSource = snapshot.source;
          _segmentCount = snapshot.finalizedSegments.length;
        });
      }),
      _engine.aiResponseStream.listen((text) {
        if (!mounted) return;
        setState(() {
          _aiResponse = text;
          if (text.trim().isNotEmpty) {
            _manualAnalyzePending = false;
          }
        });
        _scrollToBottom();
      }),
      _engine.followUpChipsStream.listen((chips) {
        if (!mounted) return;
        setState(() => _followUpChips = chips);
        _scrollToBottom();
      }),
      _engine.citedFactCheckStream.listen((result) {
        if (!mounted) return;
        setState(() {
          _citedFactCheck = result;
          _citedFactCheckExpanded = false;
        });
        _scrollToBottom();
      }),
      _engine.questionDetectionStream.listen((detection) {
        if (!mounted) return;
        setState(() => _latestQuestionDetection = detection);
        _scrollToBottom();
      }),
      _engine.providerErrorStream.listen((error) {
        if (mounted) {
          setState(() {
            _providerError = error;
            if (error != null) {
              _manualAnalyzePending = false;
            }
          });
        }
      }),
      _engine.statusStream.listen((status) {
        if (!mounted) return;
        setState(() {
          _status = status;
          if (status == EngineStatus.idle || status == EngineStatus.listening) {
            _manualAnalyzePending = false;
          }
        });
        if (status == EngineStatus.listening) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      }),
      _engine.modeStream.listen((mode) {
        if (!mounted) return;
        setState(() => _currentMode = mode);
      }),
      _engine.questionDetectedStream.listen((q) {
        // Could show a notification or highlight
      }),
      GlassesAnswerPresenter.instance.stateStream.listen((state) {
        if (!mounted) return;
        setState(() => _glassesDeliveryState = state);
      }),
      ConversationListeningSession.instance.errorStream.listen((error) {
        if (!mounted) return;
        setState(() {
          _rawListeningError = error;
          _listeningError = error == null
              ? null
              : _localizeListeningErrorMessage(error);
          if (error != null) {
            _errorDetailExpanded = false;
            _manualAnalyzePending = false;
          }
        });
      }),
    ]);
  }

  AssistantProfile get _assistantProfile =>
      SettingsManager.instance.resolveAssistantProfile(_assistantProfileId);

  Future<void> _checkApiKey() async {
    final settings = SettingsManager.instance;
    final key = await settings.getApiKey(settings.activeProviderId);
    if (mounted) {
      setState(() => _hasApiKey = key != null && key.isNotEmpty);
    }
  }

  // Distance from `maxScrollExtent` (in px) at which we consider the user to
  // be "at the bottom" again — used to clear the user-scrolled-up lock once
  // they scroll back down. Tighter than the previous 64px gate so a small
  // bounce doesn't accidentally re-arm auto-scroll.
  static const double _atBottomTolerancePx = 16;

  void _handleScrollPositionChange() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final direction = pos.userScrollDirection;
    if (direction == ScrollDirection.reverse) {
      // User is scrolling up (away from the bottom).
      if (!_userHasScrolledUp) _userHasScrolledUp = true;
      return;
    }
    if (_userHasScrolledUp &&
        pos.maxScrollExtent - pos.pixels <= _atBottomTolerancePx) {
      // User scrolled back to the bottom — clear the lock so streaming
      // answers will auto-scroll again.
      _userHasScrolledUp = false;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Intent-relative gate: if the user has manually scrolled up, leave
      // them alone. Content-relative tolerance was insufficient for long
      // streaming answers — see todo file homescreen-scroll-snap-on-long-
      // streaming-answer.md.
      if (_userHasScrolledUp) return;
      final pos = _scrollController.position;
      _scrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _showAssistantSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: HelixTheme.surface,
      ),
    );
  }

  void _navigateToDetail() {
    MainScreen.switchToTab(2); // Live tab
  }

  Future<void> _runResponseToolPrompt(
    String prompt, {
    String? previewText,
  }) async {
    // Diagnostic for response-tools (summarize/rephrase/translate/factcheck)
    // broken todo — if any of the four silently no-ops, capture why.
    if (kDebugMode) {
      debugPrint(
        '[HomeScreen] _runResponseToolPrompt: '
        'recording=$_isRecording promptLen=${prompt.trim().length} '
        'aiResponseLen=${_aiResponse.trim().length}',
      );
    }
    if (prompt.trim().isEmpty) return;
    // Blocking while recording was overly aggressive — user may want to
    // summarize/rephrase/translate/factcheck a prior answer mid-session.
    // Keep the live transcript intact by skipping the preview overwrite.
    final showPreview =
        !_isRecording && previewText != null && previewText.trim().isNotEmpty;

    setState(() {
      _followUpChips = const [];
      _providerError = null;
      if (showPreview) {
        _transcription = previewText.trim();
      }
    });

    await _engine.askQuestion(prompt);
  }

  Future<void> _summarizeLastAnswer() async {
    final answer = _aiResponse.trim();
    if (answer.isEmpty) return;

    final prompt = _isChinese
        ? '请把下面这段回答压缩成 1-3 句要点摘要，保留关键事实：\n$answer'
        : 'Summarize this answer in 1-3 bullet points, preserving the key '
              'facts:\n$answer';
    final preview = _isChinese
        ? '正在总结刚才的回答...'
        : 'Summarizing the latest answer...';
    await _runResponseToolPrompt(prompt, previewText: preview);
  }

  Future<void> _rephraseLastAnswer() async {
    final answer = _aiResponse.trim();
    if (answer.isEmpty) return;

    final prompt = _isChinese
        ? '请把下面这段回答改写成更自然、更适合我直接说出口的表达，保持意思不变：\n$answer'
        : 'Rewrite this answer so I can say it out loud naturally without changing the meaning:\n$answer';
    final preview = _isChinese
        ? '正在改写刚才的回答...'
        : 'Rephrasing the latest answer...';
    await _runResponseToolPrompt(prompt, previewText: preview);
  }

  Future<void> _translateLastAnswer() async {
    final answer = _aiResponse.trim();
    if (answer.isEmpty) return;

    final languageName = switch (_languageCode) {
      'zh' => 'Chinese',
      'ja' => 'Japanese',
      'ko' => 'Korean',
      'es' => 'Spanish',
      'ru' => 'Russian',
      _ => 'Chinese',
    };
    final prompt = _isChinese
        ? '请把下面这段回答翻译成自然、简洁的中文：\n$answer'
        : 'Translate this answer into natural, concise $languageName:\n$answer';
    final preview = _isChinese
        ? '正在翻译刚才的回答...'
        : 'Translating the latest answer...';
    await _runResponseToolPrompt(prompt, previewText: preview);
  }

  Future<void> _factCheckLastAnswer() async {
    final answer = _aiResponse.trim();
    if (answer.isEmpty) return;

    final prompt = _isChinese
        ? '请核实下面这段回答里的关键事实，指出高风险说法，并给出更可靠的版本：\n$answer'
        : 'Fact-check the key claims in this answer, flag any risky statements, and provide a safer corrected version:\n$answer';
    final preview = _isChinese
        ? '正在核实刚才的回答...'
        : 'Fact-checking the latest answer...';
    await _runResponseToolPrompt(prompt, previewText: preview);
  }

  Future<void> _sendCurrentAnswerToGlasses() async {
    final answer = _aiResponse.trim();
    if (answer.isEmpty) return;
    await GlassesAnswerPresenter.instance.present(
      answer,
      source: 'home.response_tools.manual_send',
    );
  }

  Future<void> _pinCurrentAnswer() async {
    final answer = _aiResponse.trim();
    if (answer.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: answer));
    if (!mounted) return;
    _showAssistantSnack(
      _tr(
        en: 'Answer copied to the clipboard.',
        zh: '答案已复制到剪贴板。',
        ja: '回答をクリップボードにコピーしました。',
        ko: '답변을 클립보드에 복사했습니다.',
        es: 'La respuesta se copio al portapapeles.',
        ru: 'Ответ скопирован в буфер обмена.',
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _coordinator.toggleRecording(source: TranscriptSource.phone);
    } else {
      setState(() {
        _resetLiveSessionUiState();
      });

      try {
        await _coordinator.toggleRecording(source: TranscriptSource.phone);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _rawListeningError = error.toString();
          _errorDetailExpanded = false;
          _listeningError = _formatListeningError(error);
        });
      }
    }
  }

  void _resetLiveSessionUiState() {
    _liveCardLatched = false;
    _aiResponse = '';
    _transcription = '';
    _transcriptEntries = const [];
    _latestQuestionDetection = null;
    _providerError = null;
    _glassesDeliveryState = const GlassesAnswerDeliveryState.idle();
    _listeningError = null;
    _rawListeningError = null;
    _errorDetailExpanded = false;
    _followUpChips = const [];
    _showDetailLink = false;
    _recordingDuration = Duration.zero;
    _segmentCount = 0;
    _manualAnalyzePending = false;
  }

  String _formatListeningError(Object error) {
    final text = _extractPlatformMessage(error.toString().trim());
    if (text.isEmpty) {
      return _tr(
        en: 'Speech capture could not start. Check microphone and speech permissions.',
        zh: '语音转写启动失败。请检查麦克风和语音识别权限。',
        ja: '音声入力を開始できませんでした。マイクと音声認識の権限を確認してください。',
        ko: '음성 입력을 시작할 수 없습니다. 마이크 및 음성 인식 권한을 확인하세요.',
        es: 'No se pudo iniciar la captura de voz. Revisa los permisos del micrófono y del reconocimiento de voz.',
        ru: 'Не удалось запустить захват речи. Проверьте разрешения на микрофон и распознавание речи.',
      );
    }

    return _localizeListeningErrorMessage(text);
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _pulseController.dispose();
    _modeSwitchController.dispose();
    _scrollController.removeListener(_handleScrollPositionChange);
    _scrollController.dispose();
    _askFocusNode.dispose();
    _askController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dockBottomPadding = bottomInset > 0 ? bottomInset + 6 : 6.0;
    final scrollBottomPadding = _composerDockHeight + dockBottomPadding + 4;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissQuickAskFocus,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              _buildOverviewCard(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ActiveProjectChip(),
                ),
              ),
              if (!_hasApiKey) ...[
                const SizedBox(height: 8),
                _buildSetupBanner(),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildHomeBody(bottomPadding: scrollBottomPadding),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.only(bottom: dockBottomPadding),
                        child: _buildComposerCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _dismissQuickAskFocus() {
    if (_askFocusNode.hasFocus) {
      _askFocusNode.unfocus();
    }
  }

  Widget _buildOverviewCard() {
    final modeColor = _profileColor(_assistantProfileId);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      opacity: 0.16,
      borderColor: modeColor.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(),
          const SizedBox(height: 8),
          _buildModeSelector(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isChinese ? '控制台' : 'CONTROL DECK',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildOverviewActionButton(
                icon: Icons.tune_rounded,
                label: _isChinese ? '调整' : 'Tune',
                color: modeColor,
                onTap: _openAssistantSetupSheet,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPrimarySessionActions(modeColor),
          if (_aiResponse.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildOverviewReplyStrip(),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewReplyStrip() {
    final preview = _singleLine(_aiResponse, maxLength: 120);

    return Container(
      key: const Key('home-overview-reply-strip'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: HelixTheme.cyan.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _isChinese ? '回复就绪' : 'Reply ready',
              style: TextStyle(
                color: HelixTheme.cyan,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewActionButton({
    Key? key,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withValues(alpha: onTap == null ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: onTap == null ? 0.08 : 0.18),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: color.withValues(alpha: onTap == null ? 0.44 : 0.92),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(
                  alpha: onTap == null ? 0.42 : 0.84,
                ),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimarySessionActions(Color modeColor) {
    return _buildPrimarySessionButton(
      key: const Key('home-qa-button'),
      icon: _manualAnalyzePending
          ? Icons.hourglass_top_rounded
          : Icons.question_answer_rounded,
      title: _isChinese ? '问答' : 'Q&A',
      subtitle: _manualAnalyzePending
          ? (_isChinese
                ? '正在基于最新上下文刷新答案'
                : 'Refreshing the answer from the latest context')
          : (_canAnalyzeCurrentSession
                ? (_isChinese
                      ? '使用当前转录和附近问题生成回答'
                      : 'Use the current transcript and nearby question')
                : (_isChinese ? '开始录音后可用' : 'Start recording to enable')),
      color: _canAnalyzeCurrentSession
          ? modeColor
          : Colors.white.withValues(alpha: 0.28),
      onTap: _canAnalyzeCurrentSession ? _handleAnalyzePressed : null,
    );
  }

  Widget _buildPrimarySessionButton({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: enabled ? 0.22 : 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: enabled ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: color.withValues(alpha: enabled ? 0.94 : 0.46),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: enabled ? 0.92 : 0.54,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: enabled ? 0.68 : 0.42,
                      ),
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final profiles = SettingsManager.instance.assistantProfiles;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: profiles.map((profile) {
        final isSelected = profile.id == _assistantProfileId;
        final color = _profileColor(profile.id);
        return GestureDetector(
          onTap: () => _selectProfileChip(profile),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.32)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              profile.name,
              style: TextStyle(
                color: isSelected
                    ? color
                    : Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _selectProfileChip(AssistantProfile profile) {
    if (profile.id == _assistantProfileId) return;
    _modeSwitchController
      ..reset()
      ..forward();
    _selectAssistantProfile(profile);
  }

  // ignore: unused_element
  void _selectMode(ConversationMode mode) {
    final profiles = SettingsManager.instance.assistantProfiles;
    final match = profiles.firstWhere(
      (p) => p.engineModeName == mode.name,
      orElse: () => profiles.first,
    );
    _selectProfileChip(match);
  }

  bool get _canAnalyzeCurrentSession =>
      _segmentCount > 0 || _transcription.trim().isNotEmpty;

  Future<void> _handleAnalyzePressed() async {
    debugPrint(
      '[HomeScreen] _handleAnalyzePressed called, canAnalyze=$_canAnalyzeCurrentSession, '
      'segmentCount=$_segmentCount, transcription="${_transcription.length > 40 ? _transcription.substring(0, 40) : _transcription}"',
    );
    if (!_canAnalyzeCurrentSession) {
      return;
    }

    setState(() {
      _manualAnalyzePending = true;
      _providerError = null;
      _aiResponse = '';
      _followUpChips = const [];
    });

    try {
      await _engine.forceQuestionAnalysis();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _manualAnalyzePending = false;
        _providerError = ProviderErrorState.fromException(error);
      });
    }
  }

  void _showProfileEditor(AssistantProfile profile, {VoidCallback? onSaved}) {
    final nameController = TextEditingController(text: profile.name);
    final descriptionController = TextEditingController(
      text: profile.description,
    );
    final answerStyleController = TextEditingController(
      text: profile.answerStyle,
    );
    var showSummaryTool = profile.showSummaryTool;
    var showFollowUps = profile.showFollowUps;
    var showFactCheck = profile.showFactCheck;
    var showActionItems = profile.showActionItems;
    var showWebSearch = profile.showWebSearch;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HelixTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Widget buildField(
              String label,
              TextEditingController controller, {
              int maxLines = 1,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    maxLines: maxLines,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: HelixTheme.cyan.withValues(alpha: 0.5),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              );
            }

            Widget buildToggle(
              String title,
              String subtitle,
              bool value,
              ValueChanged<bool> onChanged,
            ) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.48),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    activeTrackColor: HelixTheme.cyan,
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit ${profile.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    buildField('Profile Name', nameController),
                    const SizedBox(height: 12),
                    buildField(
                      'Short Description',
                      descriptionController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    buildField(
                      'Answer Style',
                      answerStyleController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    buildToggle(
                      'Summary Tool',
                      'Show summary actions',
                      showSummaryTool,
                      (v) => setSheetState(() => showSummaryTool = v),
                    ),
                    const SizedBox(height: 8),
                    buildToggle(
                      'Follow-ups',
                      'Keep follow-up chips visible',
                      showFollowUps,
                      (v) => setSheetState(() => showFollowUps = v),
                    ),
                    const SizedBox(height: 8),
                    buildToggle(
                      'Fact Check',
                      'Surface verification actions',
                      showFactCheck,
                      (v) => setSheetState(() => showFactCheck = v),
                    ),
                    const SizedBox(height: 8),
                    buildToggle(
                      'Action Items',
                      'Highlight extracted tasks',
                      showActionItems,
                      (v) => setSheetState(() => showActionItems = v),
                    ),
                    const SizedBox(height: 8),
                    buildToggle(
                      'Web Search',
                      'OpenAI Search for fact-checking',
                      showWebSearch,
                      (v) => setSheetState(() => showWebSearch = v),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final updated = profile.copyWith(
                                name: nameController.text.trim().isEmpty
                                    ? profile.name
                                    : nameController.text.trim(),
                                description:
                                    descriptionController.text.trim().isEmpty
                                    ? profile.description
                                    : descriptionController.text.trim(),
                                answerStyle:
                                    answerStyleController.text.trim().isEmpty
                                    ? profile.answerStyle
                                    : answerStyleController.text.trim(),
                                showSummaryTool: showSummaryTool,
                                showFollowUps: showFollowUps,
                                showFactCheck: showFactCheck,
                                showActionItems: showActionItems,
                                showWebSearch: showWebSearch,
                              );
                              await SettingsManager.instance
                                  .saveAssistantProfile(updated);
                              if (mounted) setState(() {});
                              onSaved?.call();
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HelixTheme.cyan,
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCollapsibleSectionHeader({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: Colors.white.withValues(alpha: 0.42),
          ),
        ],
      ),
    );
  }

  /// Two-option segmented picker for the active fact-check backend.
  /// `setSheetState` is the StatefulBuilder setter so the picker rebuilds
  /// inline when the user taps a chip.
  Widget _buildFactCheckBackendPicker(StateSetter setSheetState) {
    final backend = SettingsManager.instance.activeFactCheckBackend;
    Widget chip(String id, String label) {
      final selected = backend == id;
      return Expanded(
        child: GestureDetector(
          onTap: () async {
            if (backend == id) return;
            await SettingsManager.instance.update((s) {
              s.activeFactCheckBackend = id;
            });
            setSheetState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.30)
                    : Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.70),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          chip(
            'tavily',
            _tr(
              en: 'Tavily',
              zh: 'Tavily',
              ja: 'Tavily',
              ko: 'Tavily',
              es: 'Tavily',
              ru: 'Tavily',
            ),
          ),
          const SizedBox(width: 8),
          chip(
            'openai',
            _tr(
              en: 'OpenAI Web',
              zh: 'OpenAI 网络',
              ja: 'OpenAI Web',
              ko: 'OpenAI 웹',
              es: 'OpenAI Web',
              ru: 'OpenAI Web',
            ),
          ),
        ],
      ),
    );
  }

  void _openAssistantSetupSheet() {
    var sheetProfile = _assistantProfile;
    var sheetPreset = _selectedPreset;
    var sheetAutoShowSummary = SettingsManager.instance.autoShowSummary;
    var sheetAutoShowFollowUps = SettingsManager.instance.autoShowFollowUps;
    var sheetMaxChars = SettingsManager.instance.maxResponseChars;
    var automationExpanded = true;
    var outputToolsExpanded = false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GlassCard(
                  opacity: 0.18,
                  borderColor: _profileColor(
                    _assistantProfileId,
                  ).withValues(alpha: 0.24),
                  padding: const EdgeInsets.all(18),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isChinese ? '助手调优' : 'Assistant Setup',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isChinese
                                        ? '在这里调整档案和默认回答预设。'
                                        : 'Adjust the active profile and default quick-ask preset here.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => Navigator.of(sheetContext).pop(),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        AssistantProfileStrip(
                          profiles: SettingsManager.instance.assistantProfiles,
                          selectedProfileId: _assistantProfileId,
                          onSelected: (profile) {
                            sheetProfile = profile;
                            _selectAssistantProfile(profile);
                            setSheetState(() {});
                          },
                          onEdit: (profile) {
                            _showProfileEditor(
                              profile,
                              onSaved: () {
                                setSheetState(() {});
                              },
                            );
                          },
                          isChinese: _isChinese,
                        ),
                        const SizedBox(height: 14),
                        AssistantPresetStrip(
                          selected: sheetPreset,
                          onSelected: (preset) {
                            sheetPreset = preset;
                            _selectPreset(preset);
                            setSheetState(() {});
                          },
                          isChinese: _isChinese,
                        ),
                        const SizedBox(height: 14),
                        AssistantLoadoutCard(
                          key: const Key('home-setup-preview-card'),
                          profile: sheetProfile,
                          preset: sheetPreset,
                          isChinese: _isChinese,
                          autoShowSummary: sheetAutoShowSummary,
                          autoShowFollowUps: sheetAutoShowFollowUps,
                          backendLabel: _transcriptionBackendLabel(
                            SettingsManager.instance.transcriptionBackend,
                          ),
                          micLabel: _preferredMicLabel(
                            SettingsManager.instance.preferredMicSource,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildCollapsibleSectionHeader(
                          title: _tr(
                            en: 'AUTOMATION',
                            zh: '自动化',
                            ja: 'オートメーション',
                            ko: '자동화',
                            es: 'AUTOMATIZACION',
                            ru: 'АВТОМАТИЗАЦИЯ',
                          ),
                          expanded: automationExpanded,
                          onTap: () => setSheetState(
                            () => automationExpanded = !automationExpanded,
                          ),
                        ),
                        if (automationExpanded) ...[
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-auto-detect-toggle'),
                            title: _tr(
                              en: 'Auto Detect Questions',
                              zh: '自动检测问题',
                              ja: '質問自動検出',
                              ko: '질문 자동 감지',
                              es: 'Detectar preguntas',
                              ru: 'Автообнаружение вопросов',
                            ),
                            description: _tr(
                              en: 'Listen for questions in conversations.',
                              zh: '在对话中监听问题。',
                              ja: '会話内の質問を検出します。',
                              ko: '대화에서 질문을 감지합니다.',
                              es: 'Escucha preguntas en las conversaciones.',
                              ru: 'Слушает вопросы в разговорах.',
                            ),
                            value: SettingsManager.instance.autoDetectQuestions,
                            onTap: () async {
                              final next =
                                  !SettingsManager.instance.autoDetectQuestions;
                              await SettingsManager.instance.update((s) {
                                s.autoDetectQuestions = next;
                              });
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-auto-insights-toggle'),
                            title: _tr(
                              en: 'Auto Insights',
                              zh: '自动洞察',
                              ja: '自動インサイト',
                              ko: '자동 인사이트',
                              es: 'Insights automaticos',
                              ru: 'Автоинсайты',
                            ),
                            description: _tr(
                              en: 'Surfaces conversation overview and insights on your phone.',
                              zh: '在手机上自动展示对话概览和洞察。',
                              ja: 'スマホに会話の概要とインサイトを表示します。',
                              ko: '휴대폰에 대화 개요와 인사이트를 표시합니다.',
                              es: 'Muestra resumen e insights de la conversacion en tu telefono.',
                              ru: 'Показывает обзор разговора и инсайты на телефоне.',
                            ),
                            value: sheetAutoShowSummary,
                            onTap: () async {
                              final nextValue = !sheetAutoShowSummary;
                              setSheetState(
                                () => sheetAutoShowSummary = nextValue,
                              );
                              await SettingsManager.instance.update((settings) {
                                settings.autoShowSummary = nextValue;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key(
                              'home-setup-proactive-followups-toggle',
                            ),
                            title: _tr(
                              en: 'Proactive Follow-ups',
                              zh: '主动追问',
                              ja: 'プロアクティブフォローアップ',
                              ko: '선제적 후속 질문',
                              es: 'Seguimientos proactivos',
                              ru: 'Проактивные вопросы',
                            ),
                            description: _tr(
                              en: 'Suggests follow-up questions to ask the other side.',
                              zh: '自动建议向对方提问的后续问题。',
                              ja: '相手に聞くフォローアップ質問を提案します。',
                              ko: '상대방에게 할 후속 질문을 제안합니다.',
                              es: 'Sugiere preguntas de seguimiento para la otra parte.',
                              ru: 'Предлагает уточняющие вопросы для собеседника.',
                            ),
                            value: sheetAutoShowFollowUps,
                            onTap: () async {
                              final nextValue = !sheetAutoShowFollowUps;
                              setSheetState(
                                () => sheetAutoShowFollowUps = nextValue,
                              );
                              await SettingsManager.instance.update((settings) {
                                settings.autoShowFollowUps = nextValue;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-answer-all-toggle'),
                            title: _tr(
                              en: 'Auto-Answer to Glasses',
                              zh: '自动回答到眼镜',
                              ja: 'メガネへ自動回答',
                              ko: '안경으로 자동 응답',
                              es: 'Respuesta automatica a gafas',
                              ru: 'Автоответ на очки',
                            ),
                            description: _tr(
                              en: 'Auto-answers detected questions and sends to glasses HUD.',
                              zh: '自动回答检测到的问题并发送到眼镜HUD。',
                              ja: '検出した質問に自動回答しメガネHUDに送信します。',
                              ko: '감지된 질문에 자동 응답하고 안경 HUD로 전송합니다.',
                              es: 'Responde automaticamente y envia al HUD de las gafas.',
                              ru: 'Автоматически отвечает на вопросы и отправляет на HUD очков.',
                            ),
                            value: SettingsManager.instance.answerAll,
                            onTap: () async {
                              final next = !SettingsManager.instance.answerAll;
                              await SettingsManager.instance.update((s) {
                                s.answerAll = next;
                                if (next && !s.autoDetectQuestions) {
                                  s.autoDetectQuestions = true;
                                }
                              });
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key(
                              'home-setup-active-factcheck-toggle',
                            ),
                            title: _tr(
                              en: 'Active Fact-Check',
                              zh: '实时事实核查',
                              ja: 'アクティブ事実確認',
                              ko: '실시간 팩트체크',
                              es: 'Verificacion activa',
                              ru: 'Активная проверка',
                            ),
                            description: _tr(
                              en: 'Verify AI answers against live web sources after each response.',
                              zh: '每次回答后根据在线资料验证 AI 答案。',
                              ja: '各回答後にウェブソースで AI の回答を検証します。',
                              ko: '각 응답 후 웹 소스로 AI 답변을 검증합니다.',
                              es: 'Verifica respuestas con fuentes web en vivo.',
                              ru: 'Проверяет ответы AI по живым источникам.',
                            ),
                            value:
                                SettingsManager.instance.activeFactCheckEnabled,
                            onTap: () async {
                              final next = !SettingsManager
                                  .instance
                                  .activeFactCheckEnabled;
                              await SettingsManager.instance.update((s) {
                                s.activeFactCheckEnabled = next;
                              });
                              setSheetState(() {});
                            },
                          ),
                          if (SettingsManager
                              .instance
                              .activeFactCheckEnabled) ...[
                            const SizedBox(height: 8),
                            _buildFactCheckBackendPicker(setSheetState),
                          ],
                        ],
                        const SizedBox(height: 16),
                        _buildCollapsibleSectionHeader(
                          title: _tr(
                            en: 'OUTPUT TOOLS',
                            zh: '输出工具',
                            ja: '出力ツール',
                            ko: '출력 도구',
                            es: 'HERRAMIENTAS DE SALIDA',
                            ru: 'ИНСТРУМЕНТЫ ВЫВОДА',
                          ),
                          expanded: outputToolsExpanded,
                          onTap: () => setSheetState(
                            () => outputToolsExpanded = !outputToolsExpanded,
                          ),
                        ),
                        if (outputToolsExpanded) ...[
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-tool-summary-toggle'),
                            title: _tr(
                              en: 'Summary Tool',
                              zh: '摘要工具',
                              ja: '要約ツール',
                              ko: '요약 도구',
                              es: 'Resumen',
                              ru: 'Сводка',
                            ),
                            description: _tr(
                              en: 'Keep manual summary actions available for this profile.',
                              zh: '为这个档案保留手动摘要能力。',
                              ja: 'このプロフィールで手動要約を使えるようにします。',
                              ko: '이 프로필에서 수동 요약 기능을 유지합니다.',
                              es: 'Mantiene disponible el resumen manual en este perfil.',
                              ru: 'Оставляет ручную сводку доступной для этого профиля.',
                            ),
                            value: sheetProfile.showSummaryTool,
                            onTap: () async {
                              final updated = sheetProfile.copyWith(
                                showSummaryTool: !sheetProfile.showSummaryTool,
                              );
                              setSheetState(() => sheetProfile = updated);
                              await SettingsManager.instance
                                  .saveAssistantProfile(updated);
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-tool-followups-toggle'),
                            title: _tr(
                              en: 'Follow-up Suggestions',
                              zh: '追问建议',
                              ja: 'フォローアップ提案',
                              ko: '후속 질문 제안',
                              es: 'Seguimientos',
                              ru: 'Следующие вопросы',
                            ),
                            description: _tr(
                              en: 'Surface contextual next questions for this profile.',
                              zh: '为这个档案展示上下文追问建议。',
                              ja: 'このプロフィール向けに文脈に沿った次の質問を表示します。',
                              ko: '이 프로필에 맞는 맥락형 후속 질문을 표시합니다.',
                              es: 'Muestra preguntas siguientes según el contexto.',
                              ru: 'Показывает контекстные следующие вопросы для профиля.',
                            ),
                            value: sheetProfile.showFollowUps,
                            onTap: () async {
                              final updated = sheetProfile.copyWith(
                                showFollowUps: !sheetProfile.showFollowUps,
                              );
                              setSheetState(() => sheetProfile = updated);
                              await SettingsManager.instance
                                  .saveAssistantProfile(updated);
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-tool-factcheck-toggle'),
                            title: _tr(
                              en: 'Fact Check',
                              zh: '事实核实',
                              ja: 'ファクトチェック',
                              ko: '사실 확인',
                              es: 'Verificacion',
                              ru: 'Проверка фактов',
                            ),
                            description: _tr(
                              en: 'Expose verification actions when the answer looks risky.',
                              zh: '在回答风险较高时暴露核实动作。',
                              ja: '回答が危うい時に検証アクションを表示します。',
                              ko: '답변이 위험해 보일 때 검증 동작을 노출합니다.',
                              es: 'Muestra acciones de verificacion cuando la respuesta parece riesgosa.',
                              ru: 'Показывает действия проверки, когда ответ выглядит рискованным.',
                            ),
                            value: sheetProfile.showFactCheck,
                            onTap: () async {
                              final updated = sheetProfile.copyWith(
                                showFactCheck: !sheetProfile.showFactCheck,
                              );
                              setSheetState(() => sheetProfile = updated);
                              await SettingsManager.instance
                                  .saveAssistantProfile(updated);
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-tool-websearch-toggle'),
                            title: _tr(
                              en: 'Web Search',
                              zh: '网络搜索',
                              ja: 'ウェブ検索',
                              ko: '웹 검색',
                              es: 'Busqueda web',
                              ru: 'Веб-поиск',
                            ),
                            description: _tr(
                              en: 'Use OpenAI Search API for fact-checking and grounding.',
                              zh: '使用OpenAI搜索API进行事实核查和信息验证。',
                              ja: 'OpenAI検索APIでファクトチェックと情報検証を行います。',
                              ko: 'OpenAI 검색 API로 사실 확인과 정보 검증을 합니다.',
                              es: 'Usa la API de busqueda de OpenAI para verificacion de hechos.',
                              ru: 'Использует OpenAI Search API для проверки фактов.',
                            ),
                            value: sheetProfile.showWebSearch,
                            onTap: () async {
                              final updated = sheetProfile.copyWith(
                                showWebSearch: !sheetProfile.showWebSearch,
                              );
                              setSheetState(() => sheetProfile = updated);
                              await SettingsManager.instance
                                  .saveAssistantProfile(updated);
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key(
                              'home-setup-tool-actionitems-toggle',
                            ),
                            title: _tr(
                              en: 'Action Items',
                              zh: '行动项',
                              ja: 'アクション項目',
                              ko: '실행 항목',
                              es: 'Acciones',
                              ru: 'Пункты действий',
                            ),
                            description: _tr(
                              en: 'Highlight extracted tasks and review signals on Home.',
                              zh: '在主页高亮提取出的任务和复盘信号。',
                              ja: 'ホームで抽出されたタスクとレビュー信号を強調します。',
                              ko: '홈에서 추출된 작업과 리뷰 신호를 강조합니다.',
                              es: 'Resalta tareas extraidas y senales de revision en Inicio.',
                              ru: 'Подсвечивает извлеченные задачи и сигналы обзора на главном экране.',
                            ),
                            value: sheetProfile.showActionItems,
                            onTap: () async {
                              final updated = sheetProfile.copyWith(
                                showActionItems: !sheetProfile.showActionItems,
                              );
                              setSheetState(() => sheetProfile = updated);
                              await SettingsManager.instance
                                  .saveAssistantProfile(updated);
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          _tr(
                            en: 'RESPONSE LENGTH',
                            zh: '回复长度',
                            ja: '応答の長さ',
                            ko: '응답 길이',
                            es: 'LONGITUD DE RESPUESTA',
                            ru: 'ДЛИНА ОТВЕТА',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _tr(
                                        en: 'Max Response Length',
                                        zh: '最大回复长度',
                                        ja: '最大応答長',
                                        ko: '최대 응답 길이',
                                        es: 'Longitud máxima',
                                        ru: 'Макс. длина ответа',
                                      ),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '~$sheetMaxChars characters (soft cap)',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.48,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 140,
                                child: Slider(
                                  value: sheetMaxChars.toDouble(),
                                  min: 50,
                                  max: 500,
                                  divisions: 18,
                                  label: '$sheetMaxChars',
                                  onChanged: (v) {
                                    final val = v.round();
                                    setSheetState(() => sheetMaxChars = val);
                                    SettingsManager.instance.update(
                                      (s) => s.maxResponseChars = val,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _showSystemPromptEditor(sheetProfile);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 20,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _tr(
                                          en: 'Customize Prompt',
                                          zh: '自定义提示词',
                                          ja: 'プロンプトをカスタマイズ',
                                          ko: '프롬프트 커스터마이즈',
                                          es: 'Personalizar Prompt',
                                          ru: 'Настроить промпт',
                                        ),
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.88,
                                          ),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (sheetProfile.systemPrompt != null &&
                                          sheetProfile.systemPrompt!
                                              .trim()
                                              .isNotEmpty)
                                        Text(
                                          sheetProfile.systemPrompt!
                                                      .trim()
                                                      .length >
                                                  40
                                              ? '${sheetProfile.systemPrompt!.trim().substring(0, 40)}...'
                                              : sheetProfile.systemPrompt!
                                                    .trim(),
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.48,
                                            ),
                                            fontSize: 11,
                                          ),
                                        )
                                      else
                                        Text(
                                          _tr(
                                            en: 'Using default prompt',
                                            zh: '使用默认提示词',
                                            ja: 'デフォルトプロンプトを使用',
                                            ko: '기본 프롬프트 사용',
                                            es: 'Usando prompt predeterminado',
                                            ru: 'Используется промпт по умолчанию',
                                          ),
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.38,
                                            ),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.42),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSystemPromptEditor(AssistantProfile profile) {
    final controller = TextEditingController(text: profile.systemPrompt ?? '');
    const maxChars = 2000;

    final isChinese = SettingsManager.instance.language == 'zh';
    final defaultPersona = isChinese
        ? '你是智能眼镜上的对话伙伴，帮助用户进行更好的对话。'
        : 'You are a conversation companion on smart glasses helping the user have better conversations.';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HelixTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(
                        en: 'Custom System Prompt',
                        zh: '自定义系统提示词',
                        ja: 'カスタムシステムプロンプト',
                        ko: '커스텀 시스템 프롬프트',
                        es: 'Prompt de Sistema Personalizado',
                        ru: 'Пользовательский системный промпт',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tr(
                        en: 'Customize how the AI responds. Rules (sentence limit, format) are always enforced.',
                        zh: '自定义AI的回复风格。规则（句数限制、格式）始终生效。',
                        ja: 'AIの応答方法をカスタマイズします。ルール（文数制限、フォーマット）は常に適用されます。',
                        ko: 'AI 응답 방식을 커스터마이즈합니다. 규칙(문장 수 제한, 형식)은 항상 적용됩니다.',
                        es: 'Personaliza cómo responde la IA. Las reglas (límite de oraciones, formato) siempre se aplican.',
                        ru: 'Настройте стиль ответов ИИ. Правила (лимит предложений, формат) всегда применяются.',
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTemplateChip(
                          'Keep it brief',
                          '简短回答',
                          controller,
                          setSheetState,
                        ),
                        _buildTemplateChip(
                          'Explain like I\'m 5',
                          '像跟5岁小孩解释',
                          controller,
                          setSheetState,
                        ),
                        _buildTemplateChip(
                          'Technical detail',
                          '技术细节',
                          controller,
                          setSheetState,
                        ),
                        _buildTemplateChip(
                          'Translate to Spanish',
                          '翻译成西班牙语',
                          controller,
                          setSheetState,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 8,
                      maxLength: maxChars,
                      onChanged: (_) => setSheetState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: defaultPersona,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: HelixTheme.cyan.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (controller.text.trim().isNotEmpty)
                          TextButton(
                            onPressed: () {
                              controller.clear();
                              setSheetState(() {});
                            },
                            child: Text(
                              _tr(
                                en: 'Reset to default',
                                zh: '恢复默认',
                                ja: 'デフォルトに戻す',
                                ko: '기본값으로 재설정',
                                es: 'Restablecer predeterminado',
                                ru: 'Сбросить по умолчанию',
                              ),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.52),
                              ),
                            ),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            final text = controller.text.trim();
                            final updated = text.isEmpty
                                ? profile.copyWith(clearSystemPrompt: true)
                                : profile.copyWith(systemPrompt: text);
                            await SettingsManager.instance.saveAssistantProfile(
                              updated,
                            );
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HelixTheme.cyan,
                          ),
                          child: Text(
                            _tr(
                              en: 'Save',
                              zh: '保存',
                              ja: '保存',
                              ko: '저장',
                              es: 'Guardar',
                              ru: 'Сохранить',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTemplateChip(
    String enLabel,
    String zhLabel,
    TextEditingController controller,
    StateSetter setSheetState,
  ) {
    final label = _isChinese ? zhLabel : enLabel;
    return GestureDetector(
      onTap: () {
        controller.text = _isChinese ? zhLabel : enLabel;
        setSheetState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final isConnected = BleManager.isBothConnected();
    final statusText = _getStatusText();
    final providerName =
        LlmService
            .instance
            .providers[SettingsManager.instance.activeProviderId]
            ?.name ??
        '';

    final micSource = SettingsManager.instance.preferredMicSource;
    final micLabel = micSource == 'phone' ? 'Phone' : 'G1';

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            final next = micSource == 'phone' ? 'glasses' : 'phone';
            SettingsManager.instance.update((s) => s.preferredMicSource = next);
            setState(() {});
          },
          child: StatusIndicator(isActive: isConnected, label: micLabel),
        ),
        if (_hasApiKey && providerName.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: HelixTheme.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              providerName,
              style: TextStyle(
                color: HelixTheme.purple.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getStatusColor().withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSetupBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
      },
      child: GlassCard(
        opacity: 0.08,
        borderColor: HelixTheme.amber.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: HelixTheme.amber.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isChinese
                        ? '连接 OpenAI、Anthropic 或国内模型'
                        : 'Connect OpenAI, Anthropic, or a Chinese provider',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isChinese
                        ? '前往设置添加一个或多个 API key，即可在 Anthropic、DeepSeek、Qwen 或 Zhipu 之间切换。'
                        : 'Add one or more API keys in Settings, then switch between Anthropic, DeepSeek, Qwen, or Zhipu anytime.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: HelixTheme.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _isChinese ? '设置' : 'Settings',
                style: TextStyle(
                  color: HelixTheme.amber.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBody({required double bottomPadding}) {
    return SingleChildScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: FadeTransition(
        opacity: _modeSwitchAnimation,
        child: _buildConversationArea(),
      ),
    );
  }

  Widget _buildLoadoutCard() {
    final settings = SettingsManager.instance;
    return AssistantLoadoutCard(
      key: const Key('home-session-loadout-card'),
      profile: _assistantProfile,
      preset: _selectedPreset,
      isChinese: _isChinese,
      autoShowSummary: settings.autoShowSummary,
      autoShowFollowUps: settings.autoShowFollowUps,
      backendLabel: _transcriptionBackendLabel(settings.transcriptionBackend),
      micLabel: _preferredMicLabel(settings.preferredMicSource),
    );
  }

  Widget _buildConversationArea() {
    final modeColor = _profileColor(_assistantProfileId);
    final showFollowUps =
        _assistantProfile.showFollowUps &&
        SettingsManager.instance.autoShowFollowUps &&
        _followUpChips.isNotEmpty;
    final hasLiveConversation =
        _isRecording ||
        _liveCardLatched ||
        _transcription.isNotEmpty ||
        _aiResponse.isNotEmpty ||
        _latestQuestionDetection != null ||
        (_listeningError?.isNotEmpty ?? false) ||
        _showDetailLink;
    final hasProviderError = _providerError != null;

    return GlassCard(
      opacity: 0.14,
      borderColor: modeColor.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionLabel(
                _isChinese ? '对话中心' : 'CONVERSATION HUB',
                Icons.forum_outlined,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _getStatusColor().withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  _getStatusText().toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasLiveConversation)
            Column(
              children: [
                HelixVisual(
                  type: HelixVisualType.conversation,
                  height: 112,
                  accent: modeColor,
                  compact: true,
                ),
                const SizedBox(height: 8),
                _buildLoadoutCard(),
                const SizedBox(height: 8),
                _buildSuggestionChips(),
              ],
            )
          else ...[
            if (_transcription.isNotEmpty || _isRecording) ...[
              _buildContextRibbon(),
              if (_transcription.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildTranscriptMessageCard(),
              ],
              const SizedBox(height: 8),
            ],
            if ((_listeningError?.isNotEmpty ?? false)) ...[
              _buildListeningErrorCard(),
              if (_latestQuestionDetection != null ||
                  _aiResponse.trim().isNotEmpty ||
                  hasProviderError ||
                  _glassesDeliveryState.status !=
                      GlassesAnswerDeliveryStatus.idle)
                const SizedBox(height: 8),
            ],
            if (hasProviderError) ...[
              _buildProviderErrorCard(),
              if (_latestQuestionDetection != null ||
                  _aiResponse.trim().isNotEmpty ||
                  _glassesDeliveryState.status !=
                      GlassesAnswerDeliveryStatus.idle)
                const SizedBox(height: 8),
            ],
            if (_latestQuestionDetection != null) ...[
              _buildDetectedQuestionCard(),
              const SizedBox(height: 8),
            ],
            if (_aiResponse.trim().isNotEmpty ||
                _status == EngineStatus.thinking ||
                _latestQuestionDetection != null) ...[
              _buildPhoneAnswerCard(),
              StreamBuilder<List<RetrievedChunk>>(
                stream: ConversationEngine.instance.projectCitationsStream,
                initialData: const [],
                builder: (_, snap) {
                  final chunks = snap.data ?? const [];
                  if (chunks.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < chunks.length; i++)
                          ActionChip(
                            label: Text(
                              '[${i + 1}] ${chunks[i].documentFilename}'
                              '${chunks[i].pageStart != null ? ' p.${chunks[i].pageStart}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text(chunks[i].documentFilename),
                                content: SingleChildScrollView(
                                  child: SelectableText(chunks[i].chunkText),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
            if (_aiResponse.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              AssistantResponseActions(
                key: const Key('home-response-tools-card'),
                isChinese: _isChinese,
                allowSummary: _assistantProfile.showSummaryTool,
                allowFactCheck: _assistantProfile.showFactCheck,
                isSummarizing: false,
                onSummarize: _summarizeLastAnswer,
                onRephrase: _rephraseLastAnswer,
                onTranslate: _translateLastAnswer,
                onFactCheck: _factCheckLastAnswer,
                onSendToGlasses: _sendCurrentAnswerToGlasses,
                canSendToGlasses:
                    BleManager.isBothConnected() &&
                    _aiResponse.trim().isNotEmpty,
                followUpCount: showFollowUps ? _followUpChips.length : 0,
                actionItemCount: 0,
                verificationCount: 0,
                onPinResponse: _pinCurrentAnswer,
                onPinFollowUp: null,
                onStarInsight: null,
              ),
            ],
            if (showFollowUps) ...[
              const SizedBox(height: 8),
              _buildFollowUpChipDeck(),
            ],
            if (_assistantProfile.showFactCheck &&
                _citedFactCheck != null &&
                _citedFactCheck!.hasSources) ...[
              const SizedBox(height: 8),
              _buildCitedFactCheckDisclosure(_citedFactCheck!),
            ],
            if (_showDetailLink && !_isRecording) ...[
              const SizedBox(height: 8),
              _buildDetailAnalysisLink(),
            ],
            if (_glassesDeliveryState.status !=
                GlassesAnswerDeliveryStatus.idle) ...[
              const SizedBox(height: 8),
              _buildGlassesDeliveryCard(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCitedFactCheckDisclosure(CitedFactCheckResult result) {
    final Color accent;
    final String label;
    switch (result.verdict) {
      case FactCheckVerdict.supported:
        accent = Colors.greenAccent;
        label = 'Supported';
        break;
      case FactCheckVerdict.contradicted:
        accent = Colors.redAccent;
        label = 'Contradicted';
        break;
      case FactCheckVerdict.unclear:
        accent = Colors.amberAccent;
        label = 'Unclear';
        break;
    }
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(
                () => _citedFactCheckExpanded = !_citedFactCheckExpanded,
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sources (${result.sources.length})',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  Icon(
                    _citedFactCheckExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
            if (result.correction != null && result.correction!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                result.correction!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            if (_citedFactCheckExpanded) ...[
              const SizedBox(height: 8),
              for (final s in result.sources) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.url,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                      if (s.snippet.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.snippet.length > 180
                              ? '${s.snippet.substring(0, 180)}…'
                              : s.snippet,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailAnalysisLink() {
    return Center(
      child: TextButton.icon(
        onPressed: _navigateToDetail,
        icon: Icon(Icons.analytics_rounded, size: 16, color: HelixTheme.cyan),
        label: Text(
          _tr(
            en: 'View detailed analysis \u2192',
            zh: '\u67E5\u770B\u8BE6\u7EC6\u5206\u6790 \u2192',
            ja: '\u8A73\u7D30\u5206\u6790\u3092\u898B\u308B \u2192',
            ko: '\uC0C1\uC138 \uBD84\uC11D \uBCF4\uAE30 \u2192',
            es: 'Ver analisis detallado \u2192',
            ru: '\u041F\u043E\u0434\u0440\u043E\u0431\u043D\u044B\u0439 \u0430\u043D\u0430\u043B\u0438\u0437 \u2192',
          ),
          style: TextStyle(
            color: HelixTheme.cyan,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowUpChipDeck() {
    return GlassCard(
      key: const Key('home-follow-up-chip-deck'),
      opacity: 0.08,
      borderColor: HelixTheme.purple.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(
              en: 'FOLLOW-UP DECK',
              zh: '追问推荐',
              ja: 'フォローアップ候補',
              ko: '후속 질문 제안',
              es: 'PREGUNTAS DE SEGUIMIENTO',
              ru: 'СЛЕДУЮЩИЕ ВОПРОСЫ',
            ),
            style: TextStyle(
              color: HelixTheme.purple,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _followUpChips.map((chip) {
              return GestureDetector(
                onTap: () => _submitFollowUpChip(chip),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: HelixTheme.purple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    chip,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedQuestionCard() {
    final detection = _latestQuestionDetection!;
    return GlassCard(
      opacity: 0.07,
      borderColor: HelixTheme.cyan.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isChinese ? '检测到的问题' : 'DETECTED QUESTION',
            style: TextStyle(
              color: HelixTheme.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detection.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderErrorCard() {
    final errorState = _providerError!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HelixTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HelixTheme.error.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: HelixTheme.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorState.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            errorState.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (errorState.actionLabel != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => MainScreen.switchToTab(3), // Insights tab
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: HelixTheme.error.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  errorState.actionLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListeningErrorCard() {
    final isAudioOnly =
        _recordingCaptureState == RecordingCaptureState.audioOnly;
    final title = isAudioOnly
        ? _tr(
            en: 'AUDIO-ONLY FALLBACK',
            zh: '已切换为仅录音模式',
            ja: '音声のみの録音に切り替え',
            ko: '오디오 전용 녹음으로 전환됨',
            es: 'MODO SOLO AUDIO',
            ru: 'ПЕРЕКЛЮЧЕНО НА ЗАПИСЬ АУДИО',
          )
        : _tr(
            en: 'TRANSCRIPTION FAILED',
            zh: '转写启动失败',
            ja: '文字起こしを开始できません',
            ko: '전사를 시작할 수 없음',
            es: 'NO SE PUDO INICIAR LA TRANSCRIPCIÓN',
            ru: 'НЕ УДАЛОСЬ ЗАПУСТИТЬ РАСШИФРОВКУ',
          );

    final hasRawDetail =
        _rawListeningError != null &&
        _rawListeningError!.trim().isNotEmpty &&
        _rawListeningError!.trim() != _listeningError?.trim();

    return GestureDetector(
      onTap: hasRawDetail
          ? () => setState(() => _errorDetailExpanded = !_errorDetailExpanded)
          : null,
      child: GlassCard(
        opacity: 0.08,
        borderColor: HelixTheme.error.withValues(alpha: 0.22),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: HelixTheme.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (hasRawDetail)
                  Icon(
                    _errorDetailExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (isAudioOnly) ...[
              Text(
                _tr(
                  en: 'Local audio capture is still running and will be saved when you stop.',
                  zh: '本地音频仍在录制，停止后会自动保存。',
                  ja: 'ローカル音声の録音は継続中で、停止時に保存されます。',
                  ko: '로컬 오디오 녹음은 계속되며 중지하면 저장됩니다.',
                  es: 'La grabación de audio local sigue activa y se guardará al detenerla.',
                  ru: 'Локальная запись аудио продолжается и будет сохранена после остановки.',
                ),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              _listeningError!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (hasRawDetail && _errorDetailExpanded) ...[
              Divider(color: Colors.white.withValues(alpha: 0.12), height: 20),
              Text(
                _rawListeningError!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontFamily: 'Courier',
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneAnswerCard() {
    final body = _aiResponse.trim().isNotEmpty
        ? _aiResponse.trim()
        : (_status == EngineStatus.thinking
              ? _tr(
                  en: _latestQuestionDetection == null
                      ? 'Analyzing the latest conversation and extracting the question.'
                      : 'Generating an answer for the detected question.',
                  zh: _latestQuestionDetection == null
                      ? '正在分析刚才的对话并提取问题。'
                      : '正在为检测到的问题生成答案。',
                  ja: _latestQuestionDetection == null
                      ? '直前の会話を解析して質問を抽出しています。'
                      : '検出した質問への回答を生成しています。',
                  ko: _latestQuestionDetection == null
                      ? '방금 대화를 분석해 질문을 추출하고 있습니다.'
                      : '감지된 질문에 대한 답변을 생성하고 있습니다.',
                  es: _latestQuestionDetection == null
                      ? 'Se está analizando la conversación reciente para extraer la pregunta.'
                      : 'Se está generando una respuesta para la pregunta detectada.',
                  ru: _latestQuestionDetection == null
                      ? 'Анализируем последний фрагмент разговора и извлекаем вопрос.'
                      : 'Генерируем ответ на обнаруженный вопрос.',
                )
              : (_latestQuestionDetection != null &&
                        !SettingsManager.instance.answerAll
                    ? _tr(
                        en: 'A question was detected. Auto-answer is off, so no reply is being generated yet.',
                        zh: '已经检测到问题，但自动回答已关闭，因此暂时不会生成回复。',
                        ja: '質問は検出されましたが、自動回答がオフのため、まだ返答は生成されません。',
                        ko: '질문은 감지되었지만 자동 응답이 꺼져 있어 아직 답변을 생성하지 않습니다.',
                        es: 'Se detectó una pregunta, pero la respuesta automática está desactivada, así que todavía no se genera una respuesta.',
                        ru: 'Вопрос обнаружен, но автоответ выключен, поэтому ответ пока не генерируется.',
                      )
                    : _tr(
                        en: 'Active transcription is live. Once a question is detected, the phone answer will appear here first.',
                        zh: '实时转写正在进行。检测到问题后，答案会先出现在这里。',
                        ja: 'ライブ文字起こし中です。質問が検出されると、回答はまずここに表示されます。',
                        ko: '실시간 전사가 진행 중입니다. 질문이 감지되면 답변이 먼저 여기에 표시됩니다.',
                        es: 'La transcripción activa está en curso. Cuando se detecte una pregunta, la respuesta aparecerá primero aquí.',
                        ru: 'Активная расшифровка уже идет. Как только будет обнаружен вопрос, ответ сначала появится здесь.',
                      )));

    return GlassCard(
      opacity: 0.07,
      borderColor: Colors.white.withValues(alpha: 0.14),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(
              en: 'PHONE ANSWER',
              zh: '手机答案',
              ja: 'スマホ回答',
              ko: '휴대폰 답변',
              es: 'RESPUESTA EN EL TELÉFONO',
              ru: 'ОТВЕТ НА ТЕЛЕФОНЕ',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: _aiResponse.trim().isNotEmpty ? 0.96 : 0.74,
              ),
              fontSize: _aiResponse.trim().isNotEmpty ? 14 : 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextRibbon() {
    final isLiveTranscript = _isRecording;
    final glassesConnected = BleManager.isBothConnected();
    final isAudioOnly =
        _recordingCaptureState == RecordingCaptureState.audioOnly;
    final accentColor = isAudioOnly
        ? const Color(0xFFFFB547)
        : isLiveTranscript
        ? const Color(0xFFFF6B6B)
        : HelixTheme.cyan;
    final heading = isAudioOnly
        ? _tr(
            en: 'AUDIO-ONLY RECORDING',
            zh: '仅录音模式',
            ja: '音声のみ録音中',
            ko: '오디오 전용 녹음',
            es: 'GRABACIÓN SOLO DE AUDIO',
            ru: 'ТОЛЬКО ЗАПИСЬ АУДИО',
          )
        : _tr(
            en: 'ACTIVE TRANSCRIPTION',
            zh: '主动转写',
            ja: 'ライブ文字起こし',
            ko: '실시간 전사',
            es: 'TRANSCRIPCIÓN ACTIVA',
            ru: 'АКТИВНАЯ РАСШИФРОВКА',
          );
    final sourceLabel = _transcriptSource == TranscriptSource.glasses
        ? _tr(
            en: 'GLASSES INPUT',
            zh: '眼镜输入',
            ja: 'メガネ入力',
            ko: '안경 입력',
            es: 'ENTRADA DE LAS GAFAS',
            ru: 'ВВОД С ОЧКОВ',
          )
        : _tr(
            en: 'PHONE INPUT',
            zh: '手机输入',
            ja: 'スマホ入力',
            ko: '휴대폰 입력',
            es: 'ENTRADA DEL TELÉFONO',
            ru: 'ВВОД С ТЕЛЕФОНА',
          );

    return GlassCard(
      opacity: 0.08,
      borderColor: accentColor.withValues(alpha: 0.22),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAudioOnly
                ? Icons.graphic_eq_rounded
                : isLiveTranscript
                ? Icons.mic
                : Icons.short_text,
            size: 18,
            color: accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        sourceLabel,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_recordingDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}'
                          '${_segmentCount > 0 ? ' \u00B7 seg $_segmentCount' : ''}',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    if (_isRecording) ...[
                      const SizedBox(width: 6),
                      SessionCostBadge(),
                    ],
                    if (isAudioOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _tr(
                            en: 'SAVING LOCAL WAV',
                            zh: '正在保存本地 WAV',
                            ja: 'ローカル WAV を保存中',
                            ko: '로컬 WAV 저장 중',
                            es: 'GUARDANDO WAV LOCAL',
                            ru: 'СОХРАНЯЕТСЯ ЛОКАЛЬНЫЙ WAV',
                          ),
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    if (glassesConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HelixTheme.cyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _tr(
                            en: 'G1 OUTPUT ONLY',
                            zh: 'G1 仅输出答案',
                            ja: 'G1 は回答のみ表示',
                            ko: 'G1 출력 전용',
                            es: 'G1 SOLO SALIDA',
                            ru: 'G1 ТОЛЬКО ДЛЯ ОТВЕТА',
                          ),
                          style: TextStyle(
                            color: HelixTheme.cyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptMessageCard() {
    final sessionStart = _transcriptEntries.isNotEmpty
        ? _transcriptEntries.first.timestamp
        : DateTime.now();
    final partial = _engine.currentTranscriptSnapshot.partialText.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: HelixTheme.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _transcriptSource == TranscriptSource.glasses
                  ? _tr(
                      en: 'GLASSES INPUT',
                      zh: '眼镜输入',
                      ja: 'メガネ入力',
                      ko: '안경 입력',
                      es: 'ENTRADA DE LAS GAFAS',
                      ru: 'ВВОД С ОЧКОВ',
                    )
                  : _tr(
                      en: 'PHONE INPUT',
                      zh: '手机输入',
                      ja: 'スマホ入力',
                      ko: '휴대폰 입력',
                      es: 'ENTRADA DEL TELÉFONO',
                      ru: 'ВВОД С ТЕЛЕФОНА',
                    ),
              style: TextStyle(
                color: HelixTheme.cyan,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ..._transcriptEntries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      formatTranscriptElapsed(
                        entry.timestamp,
                        sessionStart: sessionStart,
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      _buildHighlightedTranscriptSpan(
                        entry.text,
                        _latestQuestionDetection?.questionExcerpt ?? '',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_transcriptEntries.isEmpty && _transcription.trim().isNotEmpty)
            Text.rich(
              _buildHighlightedTranscriptSpan(
                _transcription,
                _latestQuestionDetection?.questionExcerpt ?? '',
              ),
            ),
          if (partial.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 54,
                    child: Text(
                      'LIVE',
                      style: TextStyle(
                        color: HelixTheme.cyan.withValues(alpha: 0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      partial,
                      style: TextStyle(
                        color: HelixTheme.cyan.withValues(alpha: 0.82),
                        fontSize: 14,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  TextSpan _buildHighlightedTranscriptSpan(String transcript, String excerpt) {
    final baseStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.86),
      fontSize: 14,
      height: 1.4,
    );
    final highlightStyle = baseStyle.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      backgroundColor: HelixTheme.cyan.withValues(alpha: 0.22),
    );

    if (excerpt.isEmpty) {
      return TextSpan(text: transcript, style: baseStyle);
    }

    final start = transcript.indexOf(excerpt);
    if (start < 0) {
      return TextSpan(text: transcript, style: baseStyle);
    }

    final end = start + excerpt.length;
    return TextSpan(
      style: baseStyle,
      children: [
        if (start > 0) TextSpan(text: transcript.substring(0, start)),
        TextSpan(text: transcript.substring(start, end), style: highlightStyle),
        if (end < transcript.length) TextSpan(text: transcript.substring(end)),
      ],
    );
  }

  Widget _buildGlassesDeliveryCard() {
    final state = _glassesDeliveryState;
    final color = switch (state.status) {
      GlassesAnswerDeliveryStatus.failed => HelixTheme.error,
      GlassesAnswerDeliveryStatus.delivered => HelixTheme.cyan,
      GlassesAnswerDeliveryStatus.preparing => Colors.orangeAccent,
      GlassesAnswerDeliveryStatus.delivering => Colors.orangeAccent,
      GlassesAnswerDeliveryStatus.idle => Colors.white,
    };
    final title = switch (state.status) {
      GlassesAnswerDeliveryStatus.preparing => _tr(
        en: 'GLASSES PREPARING',
        zh: '眼镜准备发送',
        ja: 'メガネ送信準備中',
        ko: '안경 전송 준비 중',
        es: 'GAFAS PREPARÁNDOSE',
        ru: 'ОЧКИ ГОТОВЯТСЯ',
      ),
      GlassesAnswerDeliveryStatus.delivering => _tr(
        en: 'GLASSES SCROLLING',
        zh: '眼镜慢速滚动中',
        ja: 'メガネ表示中',
        ko: '안경 표시 중',
        es: 'GAFAS MOSTRANDO',
        ru: 'ОЧКИ ПОКАЗЫВАЮТ',
      ),
      GlassesAnswerDeliveryStatus.delivered => _tr(
        en: 'GLASSES DELIVERED',
        zh: '眼镜发送完成',
        ja: 'メガネ送信完了',
        ko: '안경 전송 완료',
        es: 'GAFAS ENTREGADAS',
        ru: 'ОТПРАВЛЕНО НА ОЧКИ',
      ),
      GlassesAnswerDeliveryStatus.failed => _tr(
        en: 'GLASSES FAILED',
        zh: '眼镜发送失败',
        ja: 'メガネ送信失敗',
        ko: '안경 전송 실패',
        es: 'FALLO EN LAS GAFAS',
        ru: 'СБОЙ ОТПРАВКИ НА ОЧКИ',
      ),
      GlassesAnswerDeliveryStatus.idle => '',
    };
    final body =
        (state.note == null
            ? null
            : _localizeGlassesDeliveryNote(state.note!)) ??
        ((state.totalWindows > 0 &&
                state.status == GlassesAnswerDeliveryStatus.delivering)
            ? _tr(
                en: 'Window ${state.currentWindow}/${state.totalWindows}, advancing one line per second.',
                zh: '窗口 ${state.currentWindow}/${state.totalWindows}，每秒推进一行。',
                ja: '表示ウィンドウ ${state.currentWindow}/${state.totalWindows}。1秒ごとに1行ずつ進みます。',
                ko: '창 ${state.currentWindow}/${state.totalWindows}, 1초마다 한 줄씩 진행됩니다.',
                es: 'Ventana ${state.currentWindow}/${state.totalWindows}; avanza una línea por segundo.',
                ru: 'Окно ${state.currentWindow}/${state.totalWindows}; переход на одну строку в секунду.',
              )
            : _tr(
                en: 'Only the condensed answer is sent to the glasses, not the live transcript.',
                zh: '只向眼镜发送压缩后的答案，不再发送实时转写。',
                ja: 'メガネにはライブ文字起こしではなく、圧縮した回答だけを送信します。',
                ko: '안경에는 실시간 전사가 아니라 압축된 답변만 전송됩니다.',
                es: 'A las gafas solo se envía la respuesta condensada, no la transcripción en vivo.',
                ru: 'На очки отправляется только сжатый ответ, а не живая расшифровка.',
              ));

    return GlassCard(
      opacity: 0.07,
      borderColor: color.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final suggestions = _getSuggestions().take(4).toList();
    return SizedBox(
      key: const Key('home-quick-start-strip'),
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return GestureDetector(
            onTap: () {
              _askController.text = suggestion;
              _submitQuestion();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: HelixTheme.cyan.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                suggestion,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String get _languageCode => SettingsManager.instance.uiLanguage;

  bool get _isChinese => _languageCode == 'zh';

  String _tr({
    required String en,
    required String zh,
    required String ja,
    required String ko,
    required String es,
    required String ru,
  }) {
    switch (_languageCode) {
      case 'zh':
        return zh;
      case 'ja':
        return ja;
      case 'ko':
        return ko;
      case 'es':
        return es;
      case 'ru':
        return ru;
      default:
        return en;
    }
  }

  String _extractPlatformMessage(String text) {
    if (text.startsWith('PlatformException(')) {
      final parts = text.split(', ');
      if (parts.length >= 2) {
        return parts[1].trim();
      }
    }
    return text;
  }

  String _localizeListeningErrorMessage(String message) {
    final normalized = _extractPlatformMessage(message.trim());
    if (normalized.isEmpty) {
      return _tr(
        en: 'Speech capture could not start. Check microphone and speech permissions.',
        zh: '语音转写启动失败。请检查麦克风和语音识别权限。',
        ja: '音声入力を開始できませんでした。マイクと音声認識の権限を確認してください。',
        ko: '음성 입력을 시작할 수 없습니다. 마이크 및 음성 인식 권한을 확인하세요.',
        es: 'No se pudo iniciar la captura de voz. Revisa los permisos del micrófono y del reconocimiento de voz.',
        ru: 'Не удалось запустить захват речи. Проверьте разрешения на микрофон и распознавание речи.',
      );
    }

    switch (normalized) {
      case 'Not authorized to recognize speech':
        return _tr(
          en: 'Speech recognition permission is not granted.',
          zh: '没有语音识别权限。',
          ja: '音声認識の許可がありません。',
          ko: '음성 인식 권한이 없습니다.',
          es: 'No se concedió permiso para el reconocimiento de voz.',
          ru: 'Нет разрешения на распознавание речи.',
        );
      case 'Not permitted to record audio':
        return _tr(
          en: 'Microphone permission is not granted.',
          zh: '没有麦克风权限。',
          ja: 'マイクの許可がありません。',
          ko: '마이크 권한이 없습니다.',
          es: 'No se concedió permiso para usar el micrófono.',
          ru: 'Нет разрешения на использование микрофона.',
        );
      case 'Recognizer is unavailable':
        return _tr(
          en: 'Speech recognition is currently unavailable.',
          zh: '语音识别当前不可用。',
          ja: '音声認識は現在利用できません。',
          ko: '음성 인식을 현재 사용할 수 없습니다.',
          es: 'El reconocimiento de voz no está disponible en este momento.',
          ru: 'Распознавание речи сейчас недоступно.',
        );
      case 'Can\'t initialize speech recognizer':
        return _tr(
          en: 'The speech recognizer could not be initialized.',
          zh: '无法初始化语音识别器。',
          ja: '音声認識エンジンを初期化できませんでした。',
          ko: '음성 인식기를 초기화할 수 없습니다.',
          es: 'No se pudo inicializar el reconocedor de voz.',
          ru: 'Не удалось инициализировать распознаватель речи.',
        );
      case 'Failed to create recognition request':
        return _tr(
          en: 'The speech recognition request could not be created.',
          zh: '无法创建语音识别请求。',
          ja: '音声認識リクエストを作成できませんでした。',
          ko: '음성 인식 요청을 생성할 수 없습니다.',
          es: 'No se pudo crear la solicitud de reconocimiento de voz.',
          ru: 'Не удалось создать запрос на распознавание речи.',
        );
      case 'Speech recognition stream error.':
      case 'Speech recognition stream error':
        return _tr(
          en: 'The live speech stream encountered an error.',
          zh: '实时语音流发生错误。',
          ja: '音声ストリームでエラーが発生しました。',
          ko: '실시간 음성 스트림에서 오류가 발생했습니다.',
          es: 'Se produjo un error en el flujo de voz en vivo.',
          ru: 'В потоке распознавания речи произошла ошибка.',
        );
      case 'Failed to start speech recognition.':
      case 'Failed to start speech recognition':
        return _tr(
          en: 'Speech recognition could not start.',
          zh: '无法启动语音识别。',
          ja: '音声認識を開始できませんでした。',
          ko: '음성 인식을 시작할 수 없습니다.',
          es: 'No se pudo iniciar el reconocimiento de voz.',
          ru: 'Не удалось запустить распознавание речи.',
        );
    }

    if (normalized.startsWith('Error setting up audio session:')) {
      final detail = normalized
          .substring('Error setting up audio session:'.length)
          .trim();
      return _tr(
        en: 'Audio session setup failed${detail.isEmpty ? '' : ': $detail'}',
        zh: '音频会话初始化失败${detail.isEmpty ? '' : '：$detail'}',
        ja: 'オーディオセッションの設定に失敗しました${detail.isEmpty ? '' : '：$detail'}',
        ko: '오디오 세션 설정에 실패했습니다${detail.isEmpty ? '' : ': $detail'}',
        es: 'Falló la configuración de la sesión de audio${detail.isEmpty ? '' : ': $detail'}',
        ru: 'Не удалось настроить аудиосессию${detail.isEmpty ? '' : ': $detail'}',
      );
    }

    if (normalized.startsWith('Failed to start microphone capture:')) {
      final detail = normalized
          .substring('Failed to start microphone capture:'.length)
          .trim();
      return _tr(
        en: 'Microphone capture failed to start${detail.isEmpty ? '' : ': $detail'}',
        zh: '麦克风采集启动失败${detail.isEmpty ? '' : '：$detail'}',
        ja: 'マイク入力を開始できませんでした${detail.isEmpty ? '' : '：$detail'}',
        ko: '마이크 캡처를 시작하지 못했습니다${detail.isEmpty ? '' : ': $detail'}',
        es: 'No se pudo iniciar la captura del micrófono${detail.isEmpty ? '' : ': $detail'}',
        ru: 'Не удалось запустить захват с микрофона${detail.isEmpty ? '' : ': $detail'}',
      );
    }

    if (normalized.startsWith('Speech recognition failed:')) {
      final detail = normalized
          .substring('Speech recognition failed:'.length)
          .trim();
      return _tr(
        en: 'Speech recognition failed${detail.isEmpty ? '' : ': $detail'}',
        zh: '语音识别失败${detail.isEmpty ? '' : '：$detail'}',
        ja: '音声認識に失敗しました${detail.isEmpty ? '' : '：$detail'}',
        ko: '음성 인식에 실패했습니다${detail.isEmpty ? '' : ': $detail'}',
        es: 'Falló el reconocimiento de voz${detail.isEmpty ? '' : ': $detail'}',
        ru: 'Сбой распознавания речи${detail.isEmpty ? '' : ': $detail'}',
      );
    }

    return normalized;
  }

  String _localizeGlassesDeliveryNote(String message) {
    final normalized = message.trim();
    switch (normalized) {
      case 'Glasses are not connected.':
        return _tr(
          en: 'The glasses are not connected.',
          zh: '眼镜尚未连接。',
          ja: 'メガネが接続されていません。',
          ko: '안경이 연결되어 있지 않습니다.',
          es: 'Las gafas no están conectadas.',
          ru: 'Очки не подключены.',
        );
      case 'Nothing to send to the glasses.':
        return _tr(
          en: 'There is nothing to send to the glasses.',
          zh: '没有可发送到眼镜的内容。',
          ja: 'メガネに送る内容がありません。',
          ko: '안경으로 보낼 내용이 없습니다.',
          es: 'No hay nada para enviar a las gafas.',
          ru: 'На очки нечего отправлять.',
        );
      case 'The glasses rejected the answer payload.':
        return _tr(
          en: 'The glasses rejected the answer payload.',
          zh: '眼镜拒绝了答案内容。',
          ja: 'メガネが回答データを受け付けませんでした。',
          ko: '안경이 답변 데이터를 거부했습니다.',
          es: 'Las gafas rechazaron el contenido de la respuesta.',
          ru: 'Очки отклонили данные ответа.',
        );
      case 'Interrupted by a newer answer.':
        return _tr(
          en: 'This delivery was interrupted by a newer answer.',
          zh: '该次发送已被更新的答案中断。',
          ja: '新しい回答が届いたため、この送信は中断されました。',
          ko: '새 답변이 도착해 이번 전송이 중단되었습니다.',
          es: 'Este envío fue interrumpido por una respuesta más reciente.',
          ru: 'Эта отправка была прервана более новым ответом.',
        );
    }

    if (normalized.startsWith('Exception: ')) {
      final detail = normalized.substring('Exception: '.length).trim();
      return _tr(
        en: 'Failed to send the answer to the glasses${detail.isEmpty ? '' : ': $detail'}',
        zh: '发送答案到眼镜失败${detail.isEmpty ? '' : '：$detail'}',
        ja: '回答をメガネに送信できませんでした${detail.isEmpty ? '' : '：$detail'}',
        ko: '답변을 안경으로 보내지 못했습니다${detail.isEmpty ? '' : ': $detail'}',
        es: 'No se pudo enviar la respuesta a las gafas${detail.isEmpty ? '' : ': $detail'}',
        ru: 'Не удалось отправить ответ на очки${detail.isEmpty ? '' : ': $detail'}',
      );
    }

    return normalized;
  }

  List<String> _getSuggestions() {
    if (_isChinese) {
      switch (_currentMode) {
        case ConversationMode.general:
          return [
            '如何开始一段有趣的对话？',
            '给我一个有趣的讨论话题',
            '怎么保持对话不冷场？',
            '推荐一个破冰话题',
            '教我几个闲聊技巧',
          ];
        case ConversationMode.interview:
          return [
            '请做一下自我介绍',
            '你最大的优势是什么？',
            '为什么我们应该录用你？',
            '描述你克服过的一个挑战',
            '你的五年规划是什么？',
          ];
      }
    }
    switch (_currentMode) {
      case ConversationMode.general:
        return [
          'How do I start a good conversation?',
          'Give me an interesting topic to discuss',
          'How to keep a conversation going?',
          'Suggest a fun icebreaker',
          'Help me with small talk tips',
        ];
      case ConversationMode.interview:
        return [
          'Tell me about yourself',
          'What is your greatest strength?',
          'Why should we hire you?',
          'Describe a challenge you overcame',
          'Where do you see yourself in 5 years?',
        ];
    }
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: HelixTheme.cyan.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: HelixTheme.cyan.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildComposerCard() {
    final accentColor =
        _recordingCaptureState == RecordingCaptureState.audioOnly
        ? const Color(0xFFFFB547)
        : _isRecording
        ? const Color(0xFFFF6B6B)
        : _profileColor(_assistantProfileId);

    return GlassCard(
      key: const Key('home-fixed-composer-dock'),
      opacity: 0.18,
      borderRadius: HelixTheme.radiusControl,
      borderColor: accentColor.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(child: _buildQuickAskField()),
          const SizedBox(width: 6),
          _buildRecordButton(),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final isRecordingActive =
            _isRecording && _status == EngineStatus.listening;
        final baseColor =
            _recordingCaptureState == RecordingCaptureState.audioOnly
            ? const Color(0xFFFFB547)
            : _isRecording
            ? const Color(0xFFFF6B6B)
            : HelixTheme.cyan;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                baseColor.withValues(alpha: 0.9),
                Color.lerp(baseColor, HelixTheme.background, 0.38)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(HelixTheme.radiusControl),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: isRecordingActive
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.32),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _status == EngineStatus.thinking ? null : _toggleRecording,
              borderRadius: BorderRadius.circular(14),
              child: Semantics(
                button: true,
                label: _isRecording
                    ? _tr(
                        en: 'Stop recording',
                        zh: '停止录音',
                        ja: '録音を停止',
                        ko: '녹음 중지',
                        es: 'Detener grabación',
                        ru: 'Остановить запись',
                      )
                    : _tr(
                        en: 'Start recording',
                        zh: '开始录音',
                        ja: '録音を開始',
                        ko: '녹음 시작',
                        es: 'Iniciar grabación',
                        ru: 'Начать запись',
                      ),
                child: Center(
                  child: _status == EngineStatus.thinking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _submitQuestion() {
    final text = _askController.text.trim();
    if (kDebugMode) {
      debugPrint(
        '[HomeScreen] _submitQuestion: recording=$_isRecording '
        'textLen=${text.length}',
      );
    }
    if (text.isEmpty) return;
    // The _isRecording guard was overly aggressive — user may want to
    // submit a text query mid-session without stopping recording. Keep
    // the live transcript protected by skipping the overwrite when
    // recording (same pattern as _runResponseToolPrompt).
    _dismissQuickAskFocus();
    _engine.askQuestion(_questionForPreset(text));
    _askController.clear();
    setState(() {
      _aiResponse = '';
      _providerError = null;
      if (!_isRecording) {
        _transcription = text;
      }
      _followUpChips = const [];
    });
  }

  /// Dispatch a follow-up chip directly as if the user had typed + sent it,
  /// without touching the composer text field. Mirrors the desired behavior
  /// from the follow-up-deck-send-broken todo: chip tap should send
  /// immediately, not populate the composer.
  void _submitFollowUpChip(String chipText) {
    final trimmed = chipText.trim();
    if (trimmed.isEmpty) return;
    if (kDebugMode) {
      debugPrint(
        '[HomeScreen] _submitFollowUpChip: recording=$_isRecording '
        'chipLen=${trimmed.length}',
      );
    }
    _dismissQuickAskFocus();
    _engine.askQuestion(_questionForPreset(trimmed));
    setState(() {
      _aiResponse = '';
      _providerError = null;
      if (!_isRecording) {
        _transcription = trimmed;
      }
      _followUpChips = const [];
    });
  }

  String _questionForPreset(String text) {
    switch (_selectedPreset) {
      case AssistantQuickAskPreset.concise:
        return text;
      case AssistantQuickAskPreset.speakForMe:
        return _isChinese
            ? '请把这个问题回答成我可以直接说出口的自然表达：$text'
            : 'Answer this in natural spoken language that I can say directly: $text';
      case AssistantQuickAskPreset.interview:
        return _isChinese
            ? '请给我一个简洁、有说服力、适合面试现场表达的回答：$text'
            : 'Give me a concise, persuasive answer I can use in a live interview: $text';
      case AssistantQuickAskPreset.factCheck:
        return _isChinese
            ? '请核实这个问题里的关键事实，并给出一个简短可靠的回答：$text'
            : 'Fact-check the key claims in this question and answer briefly and reliably: $text';
    }
  }

  Future<void> _selectAssistantProfile(AssistantProfile profile) async {
    setState(() => _assistantProfileId = profile.id);
    await SettingsManager.instance.update((settings) {
      settings.assistantProfileId = profile.id;
    });
    // Sync engine mode from profile
    _engine.setMode(ConversationMode.values.byName(profile.engineModeName));
  }

  void _selectPreset(AssistantQuickAskPreset preset) {
    setState(() => _selectedPreset = preset);
    SettingsManager.instance.update(
      (settings) => settings.defaultQuickAskPreset = _presetIdFor(preset),
    );
  }

  AssistantQuickAskPreset _presetFromId(String id) {
    for (final preset in AssistantQuickAskPreset.values) {
      if (_presetIdFor(preset) == id) {
        return preset;
      }
    }
    return AssistantQuickAskPreset.concise;
  }

  String _presetIdFor(AssistantQuickAskPreset preset) {
    switch (preset) {
      case AssistantQuickAskPreset.concise:
        return 'concise';
      case AssistantQuickAskPreset.speakForMe:
        return 'speakForMe';
      case AssistantQuickAskPreset.interview:
        return 'interview';
      case AssistantQuickAskPreset.factCheck:
        return 'factCheck';
    }
  }

  String _transcriptionBackendLabel(String backend) {
    switch (backend) {
      case 'appleCloud':
        return _isChinese ? '苹果云端' : 'Apple Cloud';
      case 'appleOnDevice':
        return _isChinese ? '苹果本地' : 'Apple On-Device';
      case 'openai':
        final isRealtime = SettingsManager.instance.usesOpenAIRealtimeSession;
        if (isRealtime) {
          return _isChinese ? 'OpenAI 实时' : 'OpenAI Realtime';
        }
        return _isChinese ? 'OpenAI 转写' : 'OpenAI STT';
      default:
        return backend;
    }
  }

  String _preferredMicLabel(String source) {
    switch (source) {
      case 'phone':
        return _isChinese ? '手机麦克风' : 'Phone Mic';
      case 'glasses':
      default:
        return _isChinese ? '眼镜麦克风' : 'Glasses Mic';
    }
  }

  Widget _buildQuickAskField() {
    final inputFill = Color.lerp(
      HelixTheme.surfaceInteractive,
      HelixTheme.surfaceRaised,
      0.28,
    )!.withValues(alpha: 0.82);
    final shellFill = Colors.black.withValues(alpha: 0.18);

    return Container(
      key: const Key('home-composer-input-shell'),
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: shellFill,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _askController,
                focusNode: _askFocusNode,
                enabled: !_isRecording,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: _isRecording ? 0.42 : 1,
                  ),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _isRecording
                      ? _tr(
                          en: 'Listening...',
                          zh: '监听中...',
                          ja: '聞き取り中...',
                          ko: '듣는 중...',
                          es: 'Escuchando...',
                          ru: 'Слушаем...',
                        )
                      : _getAskHint(),
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onTapOutside: (_) => _dismissQuickAskFocus(),
                onSubmitted: (_) {
                  if (!_isRecording) {
                    _submitQuestion();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _isRecording ? null : _submitQuestion,
            child: Container(
              key: const Key('home-composer-send-button'),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    (_isRecording
                            ? Colors.white
                            : Color.lerp(
                                HelixTheme.cyanDeep,
                                HelixTheme.cyan,
                                0.18,
                              )!)
                        .withValues(alpha: _isRecording ? 0.08 : 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_isRecording ? Colors.white : HelixTheme.cyan)
                      .withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                Icons.send_rounded,
                color: (_isRecording ? Colors.white : HelixTheme.cyan)
                    .withValues(alpha: 0.85),
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAskHint() {
    if (_isChinese) {
      switch (_currentMode) {
        case ConversationMode.general:
          return '随便问点什么...';
        case ConversationMode.interview:
          return '练习："请做一下自我介绍..."';
      }
    }
    switch (_currentMode) {
      case ConversationMode.general:
        return 'Ask anything...';
      case ConversationMode.interview:
        return 'Practice: "Tell me about yourself..."';
    }
  }

  String _singleLine(String text, {required int maxLength}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength - 1)}...';
  }

  String _getStatusText() {
    if (_providerError != null) {
      return _tr(
        en: 'Error',
        zh: '错误',
        ja: 'エラー',
        ko: '오류',
        es: 'Error',
        ru: 'Ошибка',
      );
    }
    if (!_hasApiKey) {
      return _tr(
        en: 'Not Ready',
        zh: '未就绪',
        ja: '未準備',
        ko: '준비 안됨',
        es: 'No listo',
        ru: 'Не готово',
      );
    }
    final micSource = SettingsManager.instance.preferredMicSource;
    if (micSource == 'glasses' && !BleManager.isBothConnected()) {
      return _tr(
        en: 'Not Ready',
        zh: '未就绪',
        ja: '未準備',
        ko: '준비 안됨',
        es: 'No listo',
        ru: 'Не готово',
      );
    }
    switch (_status) {
      case EngineStatus.idle:
        return _tr(
          en: 'Ready',
          zh: '就绪',
          ja: '準備完了',
          ko: '준비됨',
          es: 'Listo',
          ru: 'Готово',
        );
      case EngineStatus.listening:
        return _tr(
          en: 'Listening',
          zh: '监听中',
          ja: '聞き取り中',
          ko: '듣는 중',
          es: 'Escuchando',
          ru: 'Слушаем',
        );
      case EngineStatus.thinking:
        return _tr(
          en: 'Thinking',
          zh: '思考中',
          ja: '考え中',
          ko: '생각 중',
          es: 'Pensando',
          ru: 'Думает',
        );
      case EngineStatus.responding:
        return _tr(
          en: 'Responding',
          zh: '回复中',
          ja: '回答中',
          ko: '응답 중',
          es: 'Respondiendo',
          ru: 'Отвечает',
        );
      case EngineStatus.error:
        return _tr(
          en: 'Error',
          zh: '错误',
          ja: 'エラー',
          ko: '오류',
          es: 'Error',
          ru: 'Ошибка',
        );
    }
  }

  Color _getStatusColor() {
    if (_providerError != null) {
      return HelixTheme.error;
    }
    if (!_hasApiKey) {
      return HelixTheme.amber;
    }
    final micSource = SettingsManager.instance.preferredMicSource;
    if (micSource == 'glasses' && !BleManager.isBothConnected()) {
      return HelixTheme.amber;
    }
    switch (_status) {
      case EngineStatus.idle:
        return HelixTheme.statusReady;
      case EngineStatus.listening:
        return HelixTheme.statusListening;
      case EngineStatus.thinking:
        return HelixTheme.statusThinking;
      case EngineStatus.responding:
        return HelixTheme.purple;
      case EngineStatus.error:
        return HelixTheme.error;
    }
  }

  Color _profileColor(String profileId) {
    switch (profileId) {
      case 'general':
      case 'professional':
        return HelixTheme.cyan;
      case 'interview':
      case 'technical':
        return HelixTheme.purple;
      case 'social':
        return HelixTheme.lime;
      default:
        return HelixTheme.cyan;
    }
  }

  // ignore: unused_element
  Color _modeColor(ConversationMode mode) {
    switch (mode) {
      case ConversationMode.general:
        return HelixTheme.cyan;
      case ConversationMode.interview:
        return HelixTheme.purple;
    }
  }

  // ignore: unused_element
  String _modeLabel(ConversationMode mode) {
    if (_isChinese) {
      switch (mode) {
        case ConversationMode.general:
          return '通用';
        case ConversationMode.interview:
          return '面试';
      }
    }

    switch (mode) {
      case ConversationMode.general:
        return 'General';
      case ConversationMode.interview:
        return 'Interview';
    }
  }
}
