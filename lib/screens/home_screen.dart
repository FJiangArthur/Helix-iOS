import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assistant_profile.dart';
import '../services/conversation_listening_session.dart';
import '../services/evenai.dart';
import '../services/conversation_engine.dart';
import '../services/glasses_answer_presenter.dart';
import '../services/llm/llm_service.dart';
import '../services/provider_error_state.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/home_assistant_modules.dart';
import '../widgets/status_indicator.dart';
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

  ConversationMode _currentMode = ConversationMode.general;
  EngineStatus _status = EngineStatus.idle;
  TranscriptSource _transcriptSource = TranscriptSource.phone;
  String _transcription = '';
  String _aiResponse = '';
  bool _isRecording = false;
  bool _isSummarizing = false;

  final List<StreamSubscription> _subscriptions = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _askController = TextEditingController();
  bool _hasApiKey = false;
  AssistantQuickAskPreset _selectedPreset = AssistantQuickAskPreset.concise;
  ProviderErrorState? _providerError;
  String _assistantProfileId = 'general';
  bool _isOverviewExpanded = false;

  QuestionDetectionResult? _latestQuestionDetection;
  GlassesAnswerDeliveryState _glassesDeliveryState =
      GlassesAnswerPresenter.instance.currentState;
  String? _listeningError;
  String? _conversationSummary;
  List<String> _followUpChips = const [];
  AssistantInsightSnapshot? _insightSnapshot;

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
            _insightSnapshot = _buildInsightSnapshot();
          });
        }
      }),
      _engine.transcriptSnapshotStream.listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _transcription = snapshot.fullTranscript;
          _transcriptSource = snapshot.source;
          _insightSnapshot = _buildInsightSnapshot(
            transcription: snapshot.fullTranscript,
          );
        });
      }),
      _engine.aiResponseStream.listen((text) {
        if (!mounted) return;
        setState(() {
          _aiResponse = text;
          _insightSnapshot = _buildInsightSnapshot(aiResponse: text);
        });
        _scrollToBottom();
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
      }),
      _engine.providerErrorStream.listen((error) {
        if (mounted) {
          setState(() => _providerError = error);
        }
      }),
      _engine.statusStream.listen((status) {
        setState(() => _status = status);
        if (status == EngineStatus.listening) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      }),
      _engine.modeStream.listen((mode) {
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
          _listeningError = error == null
              ? null
              : _localizeListeningErrorMessage(error);
          if (error != null && error.isNotEmpty) {
            _isRecording = false;
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

  AssistantInsightSnapshot? _buildInsightSnapshot({
    String? transcription,
    String? aiResponse,
  }) {
    return AssistantInsightSnapshot.fromConversation(
      transcription: transcription ?? _transcription,
      aiResponse: aiResponse ?? _aiResponse,
      history: _engine.history,
      isChinese: _isChinese,
    );
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

  Future<void> _summarizeConversation() async {
    if (_isRecording || _isSummarizing) return;
    setState(() => _isSummarizing = true);

    final summary = await _engine.getSummary();
    if (!mounted) return;

    setState(() {
      _isSummarizing = false;
      _conversationSummary = summary?.trim().isEmpty ?? true
          ? null
          : summary!.trim();
    });

    if ((_conversationSummary ?? '').isEmpty) {
      _showAssistantSnack(
        _tr(
          en: 'No conversation summary is available yet.',
          zh: '当前还没有可用的对话摘要。',
          ja: 'まだ利用できる会話要約はありません。',
          ko: '아직 사용할 수 있는 대화 요약이 없습니다.',
          es: 'Todavia no hay un resumen de la conversacion disponible.',
          ru: 'Пока нет доступного резюме разговора.',
        ),
      );
      return;
    }

    _scrollToBottom();
  }

  Future<void> _runResponseToolPrompt(
    String prompt, {
    String? previewText,
  }) async {
    if (_isRecording || prompt.trim().isEmpty) return;

    setState(() {
      _conversationSummary = null;
      _followUpChips = const [];
      _providerError = null;
      _isOverviewExpanded = false;
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

  void _pinFollowUpPrompt() {
    final prompt = _insightSnapshot?.focusPrompt.trim() ?? '';
    if (prompt.isEmpty) return;

    _askController
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    _showAssistantSnack(
      _tr(
        en: 'Follow-up loaded into the composer.',
        zh: '追问已放入输入框。',
        ja: 'フォローアップを入力欄に入れました。',
        ko: '후속 질문을 입력창에 넣었습니다.',
        es: 'La pregunta de seguimiento se cargo en el compositor.',
        ru: 'Следующий вопрос загружен в поле ввода.',
      ),
    );
  }

  Future<void> _starCurrentInsight() async {
    final insight = _insightSnapshot;
    if (insight == null || !insight.hasContent) return;

    final payload = [
      if (insight.summary.isNotEmpty) insight.summary,
      if (insight.recommendedNextMove.isNotEmpty) insight.recommendedNextMove,
    ].join('\n');
    if (payload.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    _showAssistantSnack(
      _tr(
        en: 'Insight copied to the clipboard.',
        zh: '洞察已复制到剪贴板。',
        ja: '洞察をクリップボードにコピーしました。',
        ko: '인사이트를 클립보드에 복사했습니다.',
        es: 'La idea se copio al portapapeles.',
        ru: 'Инсайт скопирован в буфер обмена.',
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _aiResponse = '';
      _transcription = '';
      _latestQuestionDetection = null;
      _providerError = null;
      _glassesDeliveryState = const GlassesAnswerDeliveryState.idle();
      _listeningError = null;
      _isOverviewExpanded = false;
      _conversationSummary = null;
      _followUpChips = const [];
      _insightSnapshot = null;
    });

    final settings = SettingsManager.instance;
    final useGlasses = switch (settings.preferredMicSource) {
      'glasses' => BleManager.isBothConnected(),
      'phone' => false,
      _ => BleManager.isBothConnected(), // 'auto'
    };

    try {
      if (useGlasses) {
        await EvenAI.get.toStartEvenAIByOS();
      } else {
        await ConversationListeningSession.instance.startSession(
          source: TranscriptSource.phone,
        );
      }

      if (!mounted) return;
      setState(() {
        _isRecording = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _listeningError = _formatListeningError(error);
      });
    }
  }

  Future<void> _stopRecording() async {
    if (EvenAI.isRunning) {
      await EvenAI.get.stopEvenAIByOS();
    } else {
      await ConversationListeningSession.instance.stopSession();
    }

    setState(() => _isRecording = false);
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            _buildOverviewCard(),
            if (!_hasApiKey) ...[
              const SizedBox(height: 10),
              _buildSetupBanner(),
            ],
            const SizedBox(height: 10),
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
    );
  }

  Widget _buildOverviewCard() {
    final modeColor = _modeColor(_currentMode);
    final profile = _assistantProfile;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      opacity: 0.16,
      borderColor: modeColor.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(),
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
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isChinese ? '对话中心' : 'Conversation Hub',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildOverviewActionButton(
                icon: _isOverviewExpanded
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                label: _isOverviewExpanded
                    ? (_isChinese ? '折叠' : 'Collapse')
                    : (_isChinese ? '展开' : 'Expand'),
                color: Colors.white,
                onTap: () {
                  setState(() => _isOverviewExpanded = !_isOverviewExpanded);
                },
              ),
              const SizedBox(width: 8),
              _buildOverviewActionButton(
                icon: Icons.tune_rounded,
                label: _isChinese ? '调整' : 'Tune',
                color: modeColor,
                onTap: _openAssistantSetupSheet,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildOverviewMetaChip(
                icon: _modeIcon(_currentMode),
                value: _modeName(_currentMode),
                accent: modeColor,
              ),
              _buildOverviewMetaChip(
                icon: Icons.badge_outlined,
                value: profile.name,
                accent: HelixTheme.purple,
              ),
              _buildOverviewMetaChip(
                icon: Icons.bolt_rounded,
                value: _selectedPreset.label(_isChinese),
                accent: HelixTheme.cyan,
              ),
            ],
          ),
          if (_aiResponse.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildOverviewReplyStrip(),
          ],
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: _isOverviewExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildModeSelector(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMetaChip({
    required IconData icon,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accent.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.92)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildStatusBar() {
    final isConnected = BleManager.isBothConnected();
    final statusText = _getStatusText();
    final providerName =
        LlmService
            .instance
            .providers[SettingsManager.instance.activeProviderId]
            ?.name ??
        '';

    return Row(
      children: [
        StatusIndicator(
          isActive: isConnected,
          label: isConnected ? 'G1' : 'Phone',
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

  Widget _buildHomeBody({required double bottomPadding}) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: FadeTransition(
        opacity: _modeSwitchAnimation,
        child: _buildConversationArea(),
      ),
    );
  }

  Widget _buildAssistantCard() {
    final modeColor = _modeColor(_currentMode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            modeColor.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: modeColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: modeColor.withValues(alpha: 0.12),
              border: Border.all(color: modeColor.withValues(alpha: 0.2)),
            ),
            child: Icon(_modeIcon(_currentMode), size: 18, color: modeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getModeHint(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
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

  Widget _buildConversationArea() {
    final modeColor = _modeColor(_currentMode);
    final insightSnapshot = _insightSnapshot;
    final visibleInsightSnapshot =
        SettingsManager.instance.autoShowSummary &&
            insightSnapshot != null &&
            insightSnapshot.hasContent
        ? insightSnapshot
        : null;
    final showFollowUps =
        _assistantProfile.showFollowUps &&
        SettingsManager.instance.autoShowFollowUps &&
        _followUpChips.isNotEmpty;
    final showInsights = visibleInsightSnapshot != null;
    final hasLiveConversation =
        _isRecording ||
        _transcription.isNotEmpty ||
        _aiResponse.isNotEmpty ||
        _latestQuestionDetection != null ||
        (_listeningError?.isNotEmpty ?? false);
    final hasProviderError = _providerError != null;

    return GlassCard(
      opacity: 0.14,
      borderColor: modeColor.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 10),
          if (!hasLiveConversation)
            Column(
              children: [
                _buildAssistantCard(),
                const SizedBox(height: 10),
                _buildLoadoutCard(),
                const SizedBox(height: 10),
                _buildSuggestionChips(),
              ],
            )
          else ...[
            if (_transcription.isNotEmpty || _isRecording) ...[
              _buildContextRibbon(),
              const SizedBox(height: 10),
            ],
            if ((_listeningError?.isNotEmpty ?? false)) ...[
              _buildListeningErrorCard(),
              if (_latestQuestionDetection != null ||
                  _aiResponse.trim().isNotEmpty ||
                  hasProviderError ||
                  _glassesDeliveryState.status !=
                      GlassesAnswerDeliveryStatus.idle)
                const SizedBox(height: 10),
            ],
            if (hasProviderError) ...[
              _buildProviderErrorCard(),
              if (_latestQuestionDetection != null ||
                  _aiResponse.trim().isNotEmpty ||
                  _glassesDeliveryState.status !=
                      GlassesAnswerDeliveryStatus.idle)
                const SizedBox(height: 10),
            ],
            if (_latestQuestionDetection != null) ...[
              _buildDetectedQuestionCard(),
              const SizedBox(height: 10),
            ],
            if (_aiResponse.trim().isNotEmpty ||
                _status == EngineStatus.thinking ||
                _latestQuestionDetection != null) ...[
              _buildPhoneAnswerCard(),
            ],
            if (_aiResponse.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              AssistantResponseActions(
                key: const Key('home-response-tools-card'),
                isChinese: _isChinese,
                allowSummary: _assistantProfile.showSummaryTool,
                allowFactCheck: _assistantProfile.showFactCheck,
                isSummarizing: _isSummarizing,
                onSummarize: _summarizeConversation,
                onRephrase: _rephraseLastAnswer,
                onTranslate: _translateLastAnswer,
                onFactCheck: _factCheckLastAnswer,
                onSendToGlasses: _sendCurrentAnswerToGlasses,
                canSendToGlasses:
                    BleManager.isBothConnected() &&
                    _aiResponse.trim().isNotEmpty,
                followUpCount: showFollowUps ? _followUpChips.length : 0,
                actionItemCount: _assistantProfile.showActionItems
                    ? (insightSnapshot?.actionItems.length ?? 0)
                    : 0,
                verificationCount:
                    insightSnapshot?.verificationCandidates.length ?? 0,
                onPinResponse: _pinCurrentAnswer,
                onPinFollowUp: insightSnapshot == null || !showFollowUps
                    ? null
                    : _pinFollowUpPrompt,
                onStarInsight: insightSnapshot == null || !showInsights
                    ? null
                    : _starCurrentInsight,
              ),
            ],
            if ((_conversationSummary ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildConversationSummaryCard(),
            ],
            if (showFollowUps) ...[
              const SizedBox(height: 10),
              _buildFollowUpChipDeck(),
            ],
            if (visibleInsightSnapshot != null) ...[
              const SizedBox(height: 10),
              AssistantInsightsCard(
                key: const Key('home-insights-card'),
                snapshot: visibleInsightSnapshot,
                isChinese: _isChinese,
              ),
            ],
            if (_glassesDeliveryState.status !=
                GlassesAnswerDeliveryStatus.idle) ...[
              const SizedBox(height: 10),
              _buildGlassesDeliveryCard(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildConversationSummaryCard() {
    final summary = _conversationSummary?.trim() ?? '';
    if (summary.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      key: const Key('home-conversation-summary-card'),
      opacity: 0.08,
      borderColor: HelixTheme.purple.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(
              en: 'CONVERSATION SUMMARY',
              zh: '对话摘要',
              ja: '会話サマリー',
              ko: '대화 요약',
              es: 'RESUMEN DE LA CONVERSACION',
              ru: 'СВОДКА РАЗГОВОРА',
            ),
            style: TextStyle(
              color: HelixTheme.purple,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
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

  Widget _buildListeningErrorCard() {
    return GlassCard(
      opacity: 0.08,
      borderColor: HelixTheme.error.withValues(alpha: 0.22),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(
              en: 'TRANSCRIPTION FAILED',
              zh: '转写启动失败',
              ja: '文字起こしを開始できません',
              ko: '전사를 시작할 수 없음',
              es: 'NO SE PUDO INICIAR LA TRANSCRIPCIÓN',
              ru: 'НЕ УДАЛОСЬ ЗАПУСТИТЬ РАСШИФРОВКУ',
            ),
            style: TextStyle(
              color: HelixTheme.error,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _listeningError!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
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
                        !SettingsManager.instance.autoAnswerQuestions
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
    final accentColor = isLiveTranscript
        ? const Color(0xFFFF6B6B)
        : HelixTheme.cyan;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isLiveTranscript ? Icons.mic : Icons.short_text,
            size: 18,
            color: accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr(
                    en: 'ACTIVE TRANSCRIPTION',
                    zh: '主动转写',
                    ja: 'ライブ文字起こし',
                    ko: '실시간 전사',
                    es: 'TRANSCRIPCIÓN ACTIVA',
                    ru: 'АКТИВНАЯ РАСШИФРОВКА',
                  ),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _tr(
                    en: glassesConnected
                        ? 'Live speech stays on the phone. G1 only shows generated answers after a question is detected.'
                        : 'Live speech streams to the phone first, then GPT filters for questions.',
                    zh: glassesConnected
                        ? '实时语音只显示在手机上。检测到问题后，G1 只显示生成的答案。'
                        : '实时语音优先显示在手机上，再由 GPT 过滤问题。',
                    ja: glassesConnected
                        ? 'ライブ音声はスマホのみに表示されます。質問が検出されると、G1 には生成された回答だけが表示されます。'
                        : 'ライブ音声はまずスマホに表示され、その後 GPT が質問を抽出します。',
                    ko: glassesConnected
                        ? '실시간 음성은 휴대폰에만 표시됩니다. 질문이 감지되면 G1에는 생성된 답변만 표시됩니다.'
                        : '실시간 음성은 먼저 휴대폰으로 전달되고, 그다음 GPT가 질문을 골라냅니다.',
                    es: glassesConnected
                        ? 'La voz en vivo se queda en el teléfono. El G1 solo muestra respuestas generadas cuando se detecta una pregunta.'
                        : 'La voz en vivo se muestra primero en el teléfono y luego GPT filtra las preguntas.',
                    ru: glassesConnected
                        ? 'Живая речь остается только на телефоне. G1 показывает только сгенерированные ответы после обнаружения вопроса.'
                        : 'Живая речь сначала поступает на телефон, а затем GPT отфильтровывает вопросы.',
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 11,
                    height: 1.3,
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
                const SizedBox(height: 6),
                _buildTranscriptText(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptText() {
    final transcript = _transcription.isNotEmpty
        ? _transcription
        : _tr(
            en: 'Active transcription is engaged. Speak and the transcript will appear here immediately.',
            zh: '正在主动转写。你说话后，文字会直接显示在这里。',
            ja: 'ライブ文字起こし中です。話し始めると、ここにすぐ文字が表示されます。',
            ko: '실시간 전사가 활성化되었습니다. 말하면 내용이 바로 여기에 표시됩니다.',
            es: 'La transcripción activa está activada. Habla y el texto aparecerá aquí de inmediato.',
            ru: 'Активная расшифровка включена. Говорите, и текст сразу появится здесь.',
          );
    final excerpt = _latestQuestionDetection?.questionExcerpt ?? '';

    return Text.rich(
      _buildHighlightedTranscriptSpan(transcript, excerpt),
      maxLines: 12,
      overflow: TextOverflow.fade,
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
    final accentColor = _isRecording
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
        _isOverviewExpanded = false;
        _aiResponse = '';
        _providerError = null;
        _transcription = text;
        _conversationSummary = null;
        _followUpChips = const [];
        _insightSnapshot = _buildInsightSnapshot(
          transcription: text,
          aiResponse: '',
        );
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
      case 'openaiRealtime':
        return _isChinese ? 'OpenAI 实时' : 'OpenAI Live AI';
      case 'appleCloud':
        return _isChinese ? '苹果云端' : 'Apple Cloud';
      case 'appleOnDevice':
        return _isChinese ? '苹果本地' : 'Apple On-Device';
      case 'openai':
        return _isChinese ? 'OpenAI 转写' : 'OpenAI STT';
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
      }
    }
    switch (_currentMode) {
      case ConversationMode.general:
        return 'Ask anything...';
      case ConversationMode.interview:
        return 'Practice: "Tell me about yourself..."';
      case ConversationMode.passive:
        return 'Ask a question...';
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
    }
  }

  String _getModeHint() {
    if (_isChinese) {
      switch (_currentMode) {
        case ConversationMode.general:
          return '点击聆听或在下方输入问题';
        case ConversationMode.interview:
          return '用STAR方法辅导面试问题';
        case ConversationMode.passive:
          return '自动检测问题并建议回答';
      }
    }
    switch (_currentMode) {
      case ConversationMode.general:
        return 'Tap Listen or type a question below';
      case ConversationMode.interview:
        return 'Get STAR method coaching for interview questions';
      case ConversationMode.passive:
        return 'Auto-detects questions and suggests answers';
    }
  }
}
