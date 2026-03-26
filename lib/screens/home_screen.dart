import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assistant_profile.dart';
import '../services/conversation_listening_session.dart';
import '../services/conversation_engine.dart';
import '../services/entity_memory.dart';
import '../services/recording_coordinator.dart';
import '../services/glasses_answer_presenter.dart';
import '../services/llm/llm_service.dart';
import '../services/provider_error_state.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/home_assistant_modules.dart';
import '../app.dart';
import '../ble_manager.dart';

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
  String _transcription = '';
  String _aiResponse = '';
  bool _isRecording = false;
  bool _showDetailLink = false;
  Duration _recordingDuration = Duration.zero;
  int _segmentCount = 0;

  final List<StreamSubscription> _subscriptions = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _askController = TextEditingController();
  bool _hasApiKey = false;
  AssistantQuickAskPreset _selectedPreset = AssistantQuickAskPreset.concise;
  ProviderErrorState? _providerError;
  String? _factCheckAlert;
  String _assistantProfileId = 'general';

  QuestionDetectionResult? _latestQuestionDetection;
  GlassesAnswerDeliveryState _glassesDeliveryState =
      GlassesAnswerPresenter.instance.currentState;
  String? _listeningError;
  List<String> _followUpChips = const [];
  String _latestTranslation = '';
  double _sentiment = 0.0;
  EntityInfo? _latestEntity;
  Timer? _transcriptDebounce;
  TranscriptSnapshot? _pendingSnapshot;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _modeSwitchController;
  late Animation<double> _modeSwitchAnimation;

  @override
  void initState() {
    super.initState();

    _checkApiKey();
    final settings = SettingsManager.instance;
    _selectedPreset = _presetFromId(settings.defaultQuickAskPreset);
    _assistantProfileId = settings.assistantProfileId;
    _engine.autoDetectQuestions = settings.autoDetectQuestions;
    _engine.autoAnswerQuestions = settings.autoAnswerQuestions;

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
        _engine.autoAnswerQuestions =
            SettingsManager.instance.autoAnswerQuestions;
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
          }
          if (recording) {
            _showDetailLink = false;
            _recordingDuration = Duration.zero;
            _segmentCount = 0;
          }
        });
      }),
      _coordinator.durationStream.listen((d) {
        if (!mounted) return;
        setState(() => _recordingDuration = d);
      }),
      _engine.transcriptSnapshotStream.listen((snapshot) {
        _pendingSnapshot = snapshot;
        _transcriptDebounce?.cancel();
        _transcriptDebounce = Timer(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          setState(() {
            _transcription = _pendingSnapshot!.fullTranscript;
            _segmentCount = _pendingSnapshot!.finalizedSegments.length;
          });
        });
      }),
      _engine.aiResponseStream.listen((text) {
        if (!mounted) return;
        setState(() {
          _aiResponse = text;
          if (text.isEmpty) _factCheckAlert = null;
        });
        _scrollToBottom();
        // Update Live Activity with AI response (throttle: only every 20 chars)
        if (text.isNotEmpty && text.length % 20 < 3) {
          final q = _latestQuestionDetection?.question ?? '';
          _invokeLiveActivity('updateLiveActivity', {
            'question': q,
            'answer': text.length > 200 ? '${text.substring(0, 200)}...' : text,
            'status': 'answered',
            'duration': _recordingDuration.inSeconds,
          });
        }
      }),
      _engine.followUpChipsStream.listen((chips) {
        if (!mounted) return;
        setState(() => _followUpChips = chips);
        _scrollToBottom();
      }),
      _engine.questionDetectionStream.listen((detection) {
        if (!mounted) return;
        setState(() => _latestQuestionDetection = detection);
        _scrollToBottom();
        // Update Live Activity with detected question
        _invokeLiveActivity('updateLiveActivity', {
          'question': detection.question,
          'answer': '',
          'status': 'thinking',
          'duration': _recordingDuration.inSeconds,
        });
      }),
      _engine.providerErrorStream.listen((error) {
        if (mounted) {
          setState(() => _providerError = error);
        }
      }),
      _engine.statusStream.listen((status) {
        if (!mounted) return;
        setState(() => _status = status);
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
      _engine.factCheckAlertStream.listen((alert) {
        if (mounted) {
          setState(() => _factCheckAlert = alert);
        }
      }),
      GlassesAnswerPresenter.instance.stateStream.listen((state) {
        if (!mounted) return;
        setState(() => _glassesDeliveryState = state);
      }),
      ConversationListeningSession.instance.errorStream.listen((error) {
        if (!mounted) return;
        setState(() {
          _listeningError = error == null
              ? null
              : _localizeListeningErrorMessage(error);
          if (error != null && error.isNotEmpty) {
            _isRecording = false;
          }
        });
      }),
      _engine.translationStream.listen((translation) {
        if (!mounted) return;
        setState(() => _latestTranslation = translation);
        if (translation.isNotEmpty) _scrollToBottom();
      }),
      _engine.sentimentStream.listen((value) {
        if (!mounted) return;
        setState(() => _sentiment = value);
      }),
      _engine.entityStream.listen((entity) {
        if (!mounted) return;
        setState(() => _latestEntity = entity);
        _scrollToBottom();
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
    MainScreen.switchToTab(3);
  }

  Future<void> _runResponseToolPrompt(
    String prompt, {
    String? previewText,
  }) async {
    if (_isRecording || prompt.trim().isEmpty) return;

    setState(() {
      _followUpChips = const [];
      _providerError = null;
      if (previewText != null && previewText.trim().isNotEmpty) {
        _transcription = previewText.trim();
      }
    });

    await _engine.askQuestion(prompt);
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


  static const _liveActivityChannel = MethodChannel('method.evenai');

  Future<void> _invokeLiveActivity(String method, [Map<String, dynamic>? args]) async {
    try {
      await _liveActivityChannel.invokeMethod(method, args);
    } catch (_) {
      // Non-fatal: Live Activity is supplementary UX
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _coordinator.toggleRecording(source: TranscriptSource.phone);
      // End Live Activity when recording stops
      _invokeLiveActivity('stopLiveActivity');
    } else {
      setState(() {
        _aiResponse = '';
        _transcription = '';
        _latestQuestionDetection = null;
        _providerError = null;
        _glassesDeliveryState = const GlassesAnswerDeliveryState.idle();
        _listeningError = null;
        _followUpChips = const [];
        _showDetailLink = false;
        _latestTranslation = '';
        _sentiment = 0.0;
        _latestEntity = null;
        _factCheckAlert = null;
      });

      try {
        await _coordinator.toggleRecording(source: TranscriptSource.phone);
        // Start Live Activity when recording begins
        _invokeLiveActivity('startLiveActivity', {
          'mode': _modeName(_engine.mode),
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _listeningError = _formatListeningError(error);
        });
      }
    }
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

  void _setMode(ConversationMode mode) {
    _engine.setMode(mode);
    _modeSwitchController.forward(from: 0.0);
    setState(() => _currentMode = mode);
  }

  @override
  void dispose() {
    _transcriptDebounce?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _pulseController.dispose();
    _modeSwitchController.dispose();
    _scrollController.dispose();
    _askController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dockBottomPadding = bottomInset > 0 ? bottomInset + 6 : 6.0;
    final scrollBottomPadding = _composerDockHeight + dockBottomPadding + 4;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          children: [
            _buildCompactStatusBar(),
            if (!_hasApiKey) ...[
              const SizedBox(height: 4),
              _buildSetupBanner(),
            ],
            const SizedBox(height: 4),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildChatList(bottomPadding: scrollBottomPadding),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _composerDockHeight + dockBottomPadding + 4,
                    child: _buildRealtimeTranscriptWidget(),
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
    );
  }

  Widget _buildCompactStatusBar() {
    final modeColor = _modeColor(_currentMode);
    final providerName =
        LlmService
            .instance
            .providers[SettingsManager.instance.activeProviderId]
            ?.name ??
        '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // Mode chip (tappable to open mode selector)
          _buildCompactModeChip(),
          const SizedBox(width: 8),
          // Connection status dots
          _buildConnectionDots(),
          const Spacer(),
          // Proactive session stats (compact) when recording in proactive mode
          if (_currentMode == ConversationMode.proactive && _isRecording) ...[
            _buildCompactSessionStats(),
            const SizedBox(width: 8),
          ],
          // Recording indicator (pulsing red dot)
          if (_isRecording) ...[
            _buildRecordingIndicator(),
            const SizedBox(width: 8),
          ],
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _getStatusColor().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getStatusColor().withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Tune button
          GestureDetector(
            onTap: _openAssistantSetupSheet,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: modeColor.withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.tune_rounded, size: 14, color: modeColor.withValues(alpha: 0.8)),
            ),
          ),
          if (_hasApiKey && providerName.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              providerName,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactModeChip() {
    final modeColor = _modeColor(_currentMode);
    return GestureDetector(
      onTap: _showModePickerSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: modeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: modeColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_modeIcon(_currentMode), size: 13, color: modeColor),
            const SizedBox(width: 5),
            Text(
              _modeName(_currentMode),
              style: TextStyle(
                color: modeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.expand_more, size: 12, color: modeColor.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  void _showModePickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassCard(
              opacity: 0.2,
              borderColor: _modeColor(_currentMode).withValues(alpha: 0.24),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 12),
                  Text(
                    _isChinese ? '选择模式' : 'Select Mode',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildModeSelector(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionDots() {
    final isConnected = BleManager.isBothConnected();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? HelixTheme.cyan : Colors.grey,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          isConnected ? 'G1' : (_isChinese ? '手机' : 'Phone'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingIndicator() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B6B),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.5 * (_pulseAnimation.value - 1.0) / 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${_recordingDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactSessionStats() {
    final statsColor = const Color(0xFFFF6B35);
    final wordCount = _transcription.trim().isEmpty
        ? 0
        : _transcription.trim().split(RegExp(r'\s+')).length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$wordCount${_isChinese ? '词' : 'w'}',
          style: TextStyle(
            color: statsColor.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${_segmentCount}seg',
          style: TextStyle(
            color: statsColor.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }




  void _openAssistantSetupSheet() {
    var sheetProfile = _assistantProfile;
    var sheetPreset = _selectedPreset;
    var sheetAutoShowSummary = SettingsManager.instance.autoShowSummary;
    var sheetAutoShowFollowUps = SettingsManager.instance.autoShowFollowUps;

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
                  borderColor: _modeColor(_currentMode).withValues(alpha: 0.24),
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
                        Text(
                          _tr(
                            en: 'TOOLING',
                            zh: '工具配置',
                            ja: 'ツール設定',
                            ko: '도구 설정',
                            es: 'HERRAMIENTAS',
                            ru: 'ИНСТРУМЕНТЫ',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
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
                            await SettingsManager.instance.saveAssistantProfile(
                              updated,
                            );
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
                            await SettingsManager.instance.saveAssistantProfile(
                              updated,
                            );
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
                            await SettingsManager.instance.saveAssistantProfile(
                              updated,
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        AssistantSettingsToggleTile(
                          key: const Key('home-setup-tool-actionitems-toggle'),
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
                            await SettingsManager.instance.saveAssistantProfile(
                              updated,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _tr(
                            en: 'AUTO SURFACES',
                            zh: '自动展示',
                            ja: '自動表示',
                            ko: '자동 표시',
                            es: 'SUPERFICIES AUTOMATICAS',
                            ru: 'АВТОПОКАЗ',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AssistantSettingsToggleTile(
                          key: const Key('home-setup-auto-summary-toggle'),
                          title: _tr(
                            en: 'Auto Insights',
                            zh: '自动洞察',
                            ja: '自動インサイト',
                            ko: '자동 인사이트',
                            es: 'Insights automaticos',
                            ru: 'Автоинсайты',
                          ),
                          description: _tr(
                            en: 'Keep summary and insight surfaces expanded when useful.',
                            zh: '在合适的时候自动展开摘要和洞察区。',
                            ja: '必要なときに要約とインサイトを自動で表示します。',
                            ko: '필요할 때 요약과 인사이트를 자동으로 펼칩니다.',
                            es: 'Mantiene visibles los paneles de resumen e insights cuando son utiles.',
                            ru: 'Автоматически раскрывает сводку и инсайты, когда это полезно.',
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
                          key: const Key('home-setup-auto-followups-toggle'),
                          title: _tr(
                            en: 'Auto Follow-ups',
                            zh: '自动追问',
                            ja: '自動フォローアップ',
                            ko: '자동 후속 질문',
                            es: 'Seguimientos automaticos',
                            ru: 'Автоследующие вопросы',
                          ),
                          description: _tr(
                            en: 'Show the next-question deck as soon as it is ready.',
                            zh: '一旦准备好，就自动展示下一步追问卡片。',
                            ja: '次の質問デッキが準備でき次第すぐ表示します。',
                            ko: '다음 질문 덱이 준비되면 바로 표시합니다.',
                            es: 'Muestra el mazo de siguientes preguntas apenas este listo.',
                            ru: 'Показывает колоду следующих вопросов сразу после готовности.',
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


  Widget _buildSetupBanner() {
    return GestureDetector(
      onTap: () {
        MainScreen.switchToTab(4);
      },
      child: GlassCard(
        opacity: 0.08,
        borderColor: Colors.orange.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Colors.orange.withValues(alpha: 0.8),
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
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _isChinese ? '设置' : 'Settings',
                style: TextStyle(
                  color: Colors.orange.withValues(alpha: 0.9),
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

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ConversationMode.values.map((mode) {
          final isSelected = mode == _currentMode;
          final label = _modeName(mode);
          final icon = _modeIcon(mode);
          final modeColor = _modeColor(mode);
          final chipKey = Key('home-mode-${mode.name}');

          return Semantics(
            button: true,
            label: 'Switch to $label mode',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _setMode(mode),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  key: chipKey,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? modeColor.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? modeColor.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: modeColor.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected
                            ? modeColor
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.66),
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatList({required double bottomPadding}) {
    final turns = _engine.history;
    final hasContent = turns.isNotEmpty ||
        _transcription.isNotEmpty ||
        _aiResponse.isNotEmpty ||
        _latestQuestionDetection != null ||
        (_listeningError?.isNotEmpty ?? false) ||
        _providerError != null;

    if (!hasContent) {
      return _buildEmptyState(bottomPadding: bottomPadding);
    }

    // Build the list of chat items
    final items = <_ChatItem>[];

    // Add history turns as chat bubbles
    for (final turn in turns) {
      items.add(_ChatItem(type: _ChatItemType.bubble, turn: turn));
    }

    // Add live / in-progress items that aren't yet in history
    final lastHistoryIsUser = turns.isNotEmpty && turns.last.role == 'user';
    final lastHistoryIsAssistant = turns.isNotEmpty && turns.last.role == 'assistant';

    // If there's a transcript not yet reflected in history, show it as a user bubble
    if (_transcription.isNotEmpty && !lastHistoryIsUser) {
      items.add(_ChatItem(
        type: _ChatItemType.liveUser,
        content: _transcription,
      ));
    }

    // Live translation bubble (shown after user transcript)
    if (_latestTranslation.isNotEmpty &&
        SettingsManager.instance.translationEnabled) {
      items.add(_ChatItem(
        type: _ChatItemType.translation,
        content: _latestTranslation,
      ));
    }

    // Listening error
    if (_listeningError?.isNotEmpty ?? false) {
      items.add(_ChatItem(type: _ChatItemType.error, content: _listeningError!));
    }

    // Provider error
    if (_providerError != null) {
      items.add(_ChatItem(type: _ChatItemType.providerError));
    }

    // Detected question
    if (_latestQuestionDetection != null) {
      items.add(_ChatItem(
        type: _ChatItemType.detectedQuestion,
        content: _latestQuestionDetection!.question,
      ));
    }

    // AI response (live streaming or final) -- only if not already the last history turn
    if (_aiResponse.trim().isNotEmpty && !lastHistoryIsAssistant) {
      items.add(_ChatItem(
        type: _ChatItemType.liveAssistant,
        content: _aiResponse.trim(),
      ));
    } else if (_status == EngineStatus.thinking && _aiResponse.trim().isEmpty) {
      items.add(_ChatItem(type: _ChatItemType.thinking));
    }

    // Fact check alert
    if (_factCheckAlert != null) {
      items.add(_ChatItem(type: _ChatItemType.factCheck, content: _factCheckAlert!));
    }

    // Response action tools (below AI response)
    if (_aiResponse.trim().isNotEmpty) {
      items.add(_ChatItem(type: _ChatItemType.responseActions));
    }

    // Follow-up chips
    final showFollowUps =
        _assistantProfile.showFollowUps &&
        SettingsManager.instance.autoShowFollowUps &&
        _followUpChips.isNotEmpty;
    if (showFollowUps) {
      items.add(_ChatItem(type: _ChatItemType.followUpChips));
    }

    // Sentiment strip
    if (SettingsManager.instance.sentimentMonitorEnabled) {
      items.add(_ChatItem(type: _ChatItemType.sentimentStrip));
    }

    // Entity memory card
    if (_latestEntity != null && SettingsManager.instance.entityMemoryEnabled) {
      items.add(_ChatItem(type: _ChatItemType.entityCard));
    }

    // Glasses delivery status
    if (_glassesDeliveryState.status != GlassesAnswerDeliveryStatus.idle) {
      items.add(_ChatItem(type: _ChatItemType.glassesDelivery));
    }

    // Detail link
    if (_showDetailLink && !_isRecording) {
      items.add(_ChatItem(type: _ChatItemType.detailLink));
    }

    return FadeTransition(
      opacity: _modeSwitchAnimation,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(left: 4, right: 4, top: 4, bottom: bottomPadding),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildChatItem(item);
        },
      ),
    );
  }

  Widget _buildEmptyState({required double bottomPadding}) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPadding, top: 16),
      child: FadeTransition(
        opacity: _modeSwitchAnimation,
        child: Column(
          children: [
            _buildLoadoutCard(),
            const SizedBox(height: 12),
            _buildSuggestionChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(_ChatItem item) {
    switch (item.type) {
      case _ChatItemType.bubble:
        return _buildChatBubble(item.turn!);
      case _ChatItemType.liveUser:
        return _buildLiveUserBubble(item.content!);
      case _ChatItemType.liveAssistant:
        return _buildAssistantBubble(item.content!);
      case _ChatItemType.thinking:
        return _buildThinkingBubble();
      case _ChatItemType.detectedQuestion:
        return _buildDetectedQuestionBubble(item.content!);
      case _ChatItemType.error:
        return _buildErrorBubble(item.content!);
      case _ChatItemType.providerError:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildProviderErrorCard(),
        );
      case _ChatItemType.factCheck:
        return _buildFactCheckBubble(item.content!);
      case _ChatItemType.translation:
        return _buildTranslationBubble(item.content!);
      case _ChatItemType.responseActions:
        return _buildResponseActionsRow();
      case _ChatItemType.followUpChips:
        return _buildFollowUpChipDeck();
      case _ChatItemType.glassesDelivery:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildGlassesDeliveryCard(),
        );
      case _ChatItemType.detailLink:
        return _buildDetailAnalysisLink();
      case _ChatItemType.sentimentStrip:
        return _buildSentimentStrip();
      case _ChatItemType.entityCard:
        return _buildEntityCard(_latestEntity!);
    }
  }

  Widget _buildChatBubble(ConversationTurn turn) {
    final isUser = turn.role == 'user';
    return _buildBubbleWrapper(
      isUser: isUser,
      child: Text(
        turn.content,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildLiveUserBubble(String text) {
    return _buildBubbleWrapper(
      isUser: true,
      child: Text.rich(
        _buildHighlightedTranscriptSpan(
          text,
          _latestQuestionDetection?.questionExcerpt ?? '',
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(String text) {
    return _buildBubbleWrapper(
      isUser: false,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return _buildBubbleWrapper(
      isUser: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: HelixTheme.cyan.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _tr(
              en: 'Thinking...',
              zh: '思考中...',
              ja: '考え中...',
              ko: '생각 중...',
              es: 'Pensando...',
              ru: 'Думает...',
            ),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedQuestionBubble(String question) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: HelixTheme.cyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HelixTheme.cyan.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.help_outline_rounded, size: 14, color: HelixTheme.cyan.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                question,
                style: TextStyle(
                  color: HelixTheme.cyan.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBubble(String errorText) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: HelixTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HelixTheme.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, size: 14, color: HelixTheme.error),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                errorText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactCheckBubble(String alert) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                alert,
                style: const TextStyle(color: Colors.orange, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => setState(() => _factCheckAlert = null),
              child: Icon(Icons.close, color: Colors.orange.withValues(alpha: 0.5), size: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationBubble(String translation) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 48, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A4E).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6E86FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.translate, color: Color(0xFF6E86FF), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              translation,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseActionsRow() {
    final showFollowUps =
        _assistantProfile.showFollowUps &&
        SettingsManager.instance.autoShowFollowUps &&
        _followUpChips.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: AssistantResponseActions(
        key: const Key('home-response-tools-card'),
        isChinese: _isChinese,
        allowSummary: _assistantProfile.showSummaryTool,
        allowFactCheck: _assistantProfile.showFactCheck,
        isSummarizing: false,
        onSummarize: _navigateToDetail,
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
    );
  }

  Widget _buildBubbleWrapper({
    required bool isUser,
    required Widget child,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? HelixTheme.cyan.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser
                ? HelixTheme.cyan.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildRealtimeTranscriptWidget() {
    if (!_isRecording || _transcription.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HelixTheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HelixTheme.cyan.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Icon(
                Icons.mic,
                color: const Color(0xFFFF6B6B).withValues(
                  alpha: 0.5 + 0.5 * ((_pulseAnimation.value - 1.0) / 0.3).clamp(0.0, 1.0),
                ),
                size: 16,
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _transcription,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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


  Widget _buildSentimentStrip() {
    if (!SettingsManager.instance.sentimentMonitorEnabled) {
      return const SizedBox.shrink();
    }

    final Color color;
    final String label;
    if (_sentiment > 0.3) {
      color = Colors.green;
      label = _isChinese ? '积极' : 'Positive';
    } else if (_sentiment < -0.3) {
      color = Colors.red;
      label = _isChinese ? '消极' : 'Negative';
    } else {
      color = Colors.amber;
      label = _isChinese ? '中性' : 'Neutral';
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ...List.generate(5, (i) {
            final threshold = -0.6 + i * 0.3;
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sentiment >= threshold
                    ? color
                    : color.withValues(alpha: 0.2),
              ),
            );
          }),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityCard(EntityInfo entity) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (entity.title != null || entity.company != null)
                  Text(
                    '${entity.title ?? ''} ${entity.company != null ? '@ ${entity.company}' : ''}'
                        .trim(),
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailAnalysisLink() {
    return Center(
      child: TextButton.icon(
        onPressed: _navigateToDetail,
        icon: Icon(
          Icons.analytics_rounded,
          size: 16,
          color: HelixTheme.cyan,
        ),
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
                onTap: () {
                  _askController.text = chip;
                  _submitQuestion();
                },
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
              onTap: () => MainScreen.switchToTab(4),
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

  String get _languageCode => SettingsManager.instance.language;

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
        case ConversationMode.passive:
          return ['什么是好的领导力？', '用简单的话解释量子计算', '今天的科技趋势是什么？', '机器学习是如何工作的？'];
        case ConversationMode.proactive:
          return ['开始录音然后按分析', '听一段对话后自动总结', '帮我分析谈话要点'];
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
      case ConversationMode.passive:
        return [
          'What makes a great leader?',
          'Explain quantum computing simply',
          'What are today\'s tech trends?',
          'How does machine learning work?',
        ];
      case ConversationMode.proactive:
        return [
          'Start recording then press Analyze',
          'Listen to a conversation and get insights',
          'Analyze the key points of a discussion',
        ];
    }
  }


  Widget _buildComposerCard() {
    final isProactiveRecording =
        _currentMode == ConversationMode.proactive && _isRecording;
    final accentColor = isProactiveRecording
        ? const Color(0xFFFF6B35)
        : _isRecording
            ? const Color(0xFFFF6B6B)
            : _modeColor(_currentMode);

    return GlassCard(
      key: const Key('home-fixed-composer-dock'),
      opacity: 0.18,
      borderRadius: 24,
      borderColor: accentColor.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: isProactiveRecording
                ? _buildProactiveAnalyzeButton()
                : _buildQuickAskField(),
          ),
          const SizedBox(width: 6),
          _buildRecordButton(),
        ],
      ),
    );
  }

  Widget _buildProactiveAnalyzeButton() {
    return GestureDetector(
      onTap: () => _engine.forceQuestionAnalysis(),
      child: Container(
        key: const Key('home-proactive-analyze-button'),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFF8F5E)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bolt, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Analyze',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRecordButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final isRecordingActive =
            _isRecording && _status == EngineStatus.listening;
        final baseColor = _isRecording
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
            borderRadius: BorderRadius.circular(14),
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
    if (_isRecording) return;
    final text = _askController.text.trim();
    if (text.isNotEmpty) {
      _engine.askQuestion(_questionForPreset(text));
      _askController.clear();
      setState(() {
        _aiResponse = '';
        _providerError = null;
        _transcription = text;
        _followUpChips = const [];
      });
    }
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
      case 'whisper':
        return _isChinese ? 'Whisper 转写' : 'Whisper';
      default:
        return backend;
    }
  }

  String _preferredMicLabel(String source) {
    switch (source) {
      case 'glasses':
        return _isChinese ? '眼镜麦克风' : 'Glasses Mic';
      case 'phone':
        return _isChinese ? '手机麦克风' : 'Phone Mic';
      default:
        return _isChinese ? '自动麦克风' : 'Auto Mic';
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
        case ConversationMode.passive:
          return '提个问题...';
        case ConversationMode.proactive:
          return '按分析按钮开始...';
      }
    }
    switch (_currentMode) {
      case ConversationMode.general:
        return 'Ask anything...';
      case ConversationMode.interview:
        return 'Practice: "Tell me about yourself..."';
      case ConversationMode.passive:
        return 'Ask a question...';
      case ConversationMode.proactive:
        return 'Press Analyze to get insights...';
    }
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
    switch (_status) {
      case EngineStatus.idle:
        return Colors.grey;
      case EngineStatus.listening:
        return Colors.green;
      case EngineStatus.thinking:
        return HelixTheme.cyan;
      case EngineStatus.responding:
        return HelixTheme.purple;
      case EngineStatus.error:
        return const Color(0xFFFF6B6B);
    }
  }

  String _modeName(ConversationMode mode) {
    switch (mode) {
      case ConversationMode.general:
        return 'General';
      case ConversationMode.interview:
        return 'Interview';
      case ConversationMode.passive:
        return 'Passive';
      case ConversationMode.proactive:
        return 'Proactive';
    }
  }

  IconData _modeIcon(ConversationMode mode) {
    switch (mode) {
      case ConversationMode.general:
        return Icons.chat_bubble_outline;
      case ConversationMode.interview:
        return Icons.work_outline;
      case ConversationMode.passive:
        return Icons.hearing;
      case ConversationMode.proactive:
        return Icons.psychology_alt;
    }
  }

  Color _modeColor(ConversationMode mode) {
    switch (mode) {
      case ConversationMode.general:
        return HelixTheme.cyan;
      case ConversationMode.interview:
        return HelixTheme.purple;
      case ConversationMode.passive:
        return const Color(0xFF00FF88);
      case ConversationMode.proactive:
        return const Color(0xFFFF6B35);
    }
  }

}

enum _ChatItemType {
  bubble,
  liveUser,
  liveAssistant,
  thinking,
  detectedQuestion,
  error,
  providerError,
  factCheck,
  translation,
  responseActions,
  followUpChips,
  sentimentStrip,
  entityCard,
  glassesDelivery,
  detailLink,
}

class _ChatItem {
  final _ChatItemType type;
  final ConversationTurn? turn;
  final String? content;

  _ChatItem({
    required this.type,
    this.turn,
    this.content,
  });
}
