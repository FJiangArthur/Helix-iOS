import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assistant_profile.dart';
import '../services/conversation_engine.dart';
import '../services/evenai.dart';
import '../services/llm/llm_service.dart';
import '../services/provider_error_state.dart';
import '../services/settings_manager.dart';
import '../services/text_service.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glow_button.dart';
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
  final _engine = ConversationEngine.instance;

  ConversationMode _currentMode = ConversationMode.general;
  EngineStatus _status = EngineStatus.idle;
  String _transcription = '';
  String _aiResponse = '';
  bool _isRecording = false;

  final List<StreamSubscription> _subscriptions = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _askController = TextEditingController();
  bool _hasApiKey = false;
  AssistantQuickAskPreset _selectedPreset = AssistantQuickAskPreset.concise;
  ProviderErrorState? _providerError;
  String _assistantProfileId = 'general';

  // Conversation intelligence state
  ProactiveSuggestion? _proactiveSuggestion;
  CoachingPrompt? _coachingPrompt;
  List<String> _smartFollowUps = [];
  bool _isSummarizing = false;
  String? _summaryText;
  String? _pinnedResponse;
  String? _pinnedFollowUp;
  final Set<String> _starredInsightItems = <String>{};

  // Phone mic recording state
  bool _isPhoneMicRecording = false;
  StreamSubscription? _speechSubscription;
  Completer<void>? _phoneSpeechFinalizationCompleter;
  String _lastFinalizedPhoneTranscription = '';
  static const _eventSpeechRecognize = 'eventSpeechRecognize';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _typingController;

  late AnimationController _modeSwitchController;
  late Animation<double> _modeSwitchAnimation;

  @override
  void initState() {
    super.initState();

    _checkApiKey();
    final settings = SettingsManager.instance;
    _selectedPreset = _presetFromId(settings.defaultQuickAskPreset);
    _assistantProfileId = settings.assistantProfileId;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
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
      _engine.transcriptionStream.listen((text) {
        setState(() => _transcription = text);
      }),
      _engine.aiResponseStream.listen((text) {
        setState(() => _aiResponse = text);
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
        // Typing indicator animation
        if (status == EngineStatus.thinking ||
            status == EngineStatus.responding) {
          _typingController.repeat();
        } else {
          _typingController.stop();
          _typingController.reset();
        }
      }),
      _engine.modeStream.listen((mode) {
        setState(() => _currentMode = mode);
      }),
      _engine.questionDetectedStream.listen((q) {
        // Could show a notification or highlight
      }),
      _engine.proactiveSuggestionStream.listen((suggestion) {
        if (mounted) {
          setState(() => _proactiveSuggestion = suggestion);
          _scrollToBottom();
        }
      }),
      _engine.coachingStream.listen((coaching) {
        if (mounted) {
          setState(() => _coachingPrompt = coaching);
          _scrollToBottom();
        }
      }),
      _engine.followUpChipsStream.listen((chips) {
        if (mounted) {
          setState(() => _smartFollowUps = chips);
          _scrollToBottom();
        }
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    _aiResponse = '';
    _transcription = '';
    _proactiveSuggestion = null;
    _coachingPrompt = null;
    _smartFollowUps = [];
    _summaryText = null;
    _lastFinalizedPhoneTranscription = '';
    _phoneSpeechFinalizationCompleter = Completer<void>();

    final glassesConnected = BleManager.isBothConnected();

    if (glassesConnected) {
      // Glasses connected: use existing EvenAI flow
      EvenAI.get.toStartEvenAIByOS();
    } else {
      // Standalone phone mic mode: start native speech recognition directly
      _isPhoneMicRecording = true;
      _engine.start();

      // Subscribe to the native speech recognition event channel
      _speechSubscription?.cancel();
      _speechSubscription = const EventChannel(_eventSpeechRecognize)
          .receiveBroadcastStream(_eventSpeechRecognize)
          .listen(
            (event) {
              final payload = Map<String, dynamic>.from(event as Map);
              final txt = (payload['script'] as String? ?? '').trim();
              final isFinal = payload['isFinal'] == true;
              if (txt.isNotEmpty) {
                _engine.onTranscriptionUpdate(txt);
              }
              if (isFinal) {
                _finalizePhoneTranscription(
                  txt.isNotEmpty ? txt : _transcription,
                );
              }
            },
            onError: (error) {
              debugPrint('Speech recognition error: $error');
              _completePhoneSpeechFinalization();
            },
          );

      // Start the native SpeechStreamRecognizer via platform channel
      final langCode = _mapLanguageCode(SettingsManager.instance.language);
      await BleManager.invokeMethod('startEvenAI', {
        'language': langCode,
        'source': 'microphone',
      });
    }

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    final glassesConnected = BleManager.isBothConnected();

    if (glassesConnected && !_isPhoneMicRecording) {
      // Glasses mode: use existing EvenAI flow
      await EvenAI.get.stopEvenAIByOS();
    } else {
      // Standalone phone mic mode: stop native speech recognition
      await BleManager.invokeMethod('stopEvenAI');
      await _waitForPhoneSpeechFinalization();
      _speechSubscription?.cancel();
      _speechSubscription = null;

      _engine.stop();
      _isPhoneMicRecording = false;
    }

    setState(() => _isRecording = false);
  }

  void _setMode(ConversationMode mode) {
    _engine.setMode(mode);
    _modeSwitchController.forward(from: 0.0);
    setState(() => _currentMode = mode);
  }

  @override
  void dispose() {
    _completePhoneSpeechFinalization();
    _speechSubscription?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _pulseController.dispose();
    _typingController.dispose();
    _modeSwitchController.dispose();
    _scrollController.dispose();
    _askController.dispose();
    super.dispose();
  }

  void _finalizePhoneTranscription(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty || normalized == _lastFinalizedPhoneTranscription) {
      _completePhoneSpeechFinalization();
      return;
    }

    _lastFinalizedPhoneTranscription = normalized;
    _engine.onTranscriptionFinalized(normalized);
    _completePhoneSpeechFinalization();
  }

  Future<void> _waitForPhoneSpeechFinalization() async {
    final waiter = _phoneSpeechFinalizationCompleter;
    if (waiter == null || waiter.isCompleted) {
      return;
    }

    try {
      await waiter.future.timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      _completePhoneSpeechFinalization();
    }
  }

  void _completePhoneSpeechFinalization() {
    final waiter = _phoneSpeechFinalizationCompleter;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            _buildOverviewCard(),
            if (!_hasApiKey) ...[
              const SizedBox(height: 10),
              _buildSetupBanner(),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildHomeBody()),
            const SizedBox(height: 12),
            _buildComposerCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final modeColor = _modeColor(_currentMode);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      opacity: 0.14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  modeColor.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: modeColor.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: modeColor.withValues(alpha: 0.16),
                        border: Border.all(
                          color: modeColor.withValues(alpha: 0.26),
                        ),
                      ),
                      child: Icon(
                        _modeIcon(_currentMode),
                        color: modeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI COCKPIT',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getModeDescription(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        _modeName(_currentMode).toUpperCase(),
                        style: TextStyle(
                          color: modeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _getModeHint(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AssistantProfileStrip(
            profiles: SettingsManager.instance.assistantProfiles,
            selectedProfileId: _assistantProfileId,
            onSelected: _selectAssistantProfile,
            isChinese: _isChinese,
          ),
          const SizedBox(height: 12),
          _buildModeSelector(),
          const SizedBox(height: 12),
          AssistantPresetStrip(
            selected: _selectedPreset,
            onSelected: (preset) {
              setState(() => _selectedPreset = preset);
              SettingsManager.instance.update(
                (settings) =>
                    settings.defaultQuickAskPreset = _presetIdFor(preset),
              );
            },
            isChinese: _isChinese,
          ),
        ],
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
        // Navigate to Settings tab (index 3)
        MainScreen.switchToTab(3);
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
                    _isChinese ? '连接 AI 提供商' : 'Connect an AI provider',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isChinese
                        ? '前往设置添加 API key 以启用回复。'
                        : 'Add your API key in Settings to enable responses.',
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
      child: Row(
        children: ConversationMode.values.map((mode) {
          final isSelected = mode == _currentMode;
          final label = _modeName(mode);
          final icon = _modeIcon(mode);
          final modeColor = _modeColor(mode);

          return Expanded(
            child: GestureDetector(
              onTap: () => _setMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? modeColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? modeColor.withValues(alpha: 0.3)
                        : Colors.transparent,
                    width: 1,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? modeColor.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: isSelected
                            ? modeColor
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? modeColor
                            : Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: FadeTransition(
        opacity: _modeSwitchAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_transcription.isNotEmpty || _isRecording) ...[
              _buildContextRibbon(),
              const SizedBox(height: 12),
            ],
            _buildConversationArea(),
            const SizedBox(height: 12),
            _buildAssistantTray(),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantCard() {
    final modeColor = _modeColor(_currentMode);

    return GlassCard(
      opacity: 0.1,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: modeColor.withValues(alpha: 0.12),
                  border: Border.all(color: modeColor.withValues(alpha: 0.2)),
                ),
                child: Icon(
                  _modeIcon(_currentMode),
                  size: 24,
                  color: modeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isChinese ? '准备开始' : 'Ready to Start',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getModeDescription(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _getModeHint(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _buildSuggestionChips(),
        ],
      ),
    );
  }

  Widget _buildConversationArea() {
    final insights = AssistantInsightSnapshot.fromConversation(
      transcription: _transcription,
      aiResponse: _aiResponse,
      history: _engine.history,
      isChinese: _isChinese,
    );

    final hasLiveConversation =
        _isRecording || _transcription.isNotEmpty || _aiResponse.isNotEmpty;
    final hasProviderError = _providerError != null;

    return GlassCard(
      opacity: 0.12,
      borderColor: HelixTheme.cyan.withValues(alpha: 0.16),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionLabel(
                _isChinese ? '主画布' : 'LIVE CANVAS',
                Icons.auto_awesome,
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
          const SizedBox(height: 14),
          if (!hasLiveConversation)
            _buildAssistantCard()
          else ...[
            if (hasProviderError)
              _buildProviderErrorCard()
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_status == EngineStatus.thinking)
                      _buildThinkingIndicator(),
                    if (_status == EngineStatus.thinking && _aiResponse.isEmpty)
                      _buildThinkingCard()
                    else
                      Text(
                        _aiResponse.isNotEmpty
                            ? _aiResponse
                            : (_isRecording
                                  ? (_isChinese
                                        ? '正在监听并等待内容...'
                                        : 'Listening and waiting for content...')
                                  : (_isChinese
                                        ? '输入问题以开始。'
                                        : 'Ask a question to start.')),
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: _aiResponse.isNotEmpty ? 0.95 : 0.64,
                          ),
                          fontSize: _aiResponse.isNotEmpty ? 16 : 15,
                          height: 1.65,
                        ),
                      ),
                    if (_status == EngineStatus.responding) ...[
                      const SizedBox(height: 10),
                      _buildStreamingCursor(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AssistantResponseActions(
                isChinese: _isChinese,
                allowSummary: _assistantProfile.showSummaryTool,
                allowFactCheck: _assistantProfile.showFactCheck,
                isSummarizing: _isSummarizing,
                onSummarize: _generateSummary,
                onRephrase: _rephraseAnswer,
                onTranslate: _translateAnswer,
                onFactCheck: _factCheckAnswer,
                onSendToGlasses: _sendAnswerToGlasses,
                onPinResponse: _aiResponse.trim().isEmpty
                    ? null
                    : _pinCurrentResponse,
                onPinFollowUp: _smartFollowUps.isEmpty
                    ? null
                    : () => setState(
                        () => _pinnedFollowUp = _smartFollowUps.first,
                      ),
                onStarInsight: insights == null
                    ? null
                    : () => _togglePrimaryInsight(insights),
                canSendToGlasses: BleManager.get().isConnected,
                followUpCount: _smartFollowUps.length,
                actionItemCount: insights?.actionItems.length ?? 0,
                verificationCount: insights?.verificationCandidates.length ?? 0,
              ),
            ],
          ],
          if (insights != null && !hasProviderError) ...[
            const SizedBox(height: 12),
            AssistantInsightsCard(snapshot: insights, isChinese: _isChinese),
            const SizedBox(height: 10),
            _buildInsightMemoryActions(insights),
          ],
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
              onTap: () => MainScreen.switchToTab(3),
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

  Widget _buildContextRibbon() {
    final isLiveTranscript = _isRecording;
    final accentColor = isLiveTranscript
        ? const Color(0xFFFF6B6B)
        : HelixTheme.cyan;

    return GlassCard(
      opacity: 0.08,
      borderColor: accentColor.withValues(alpha: 0.22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  isLiveTranscript
                      ? (_isChinese ? '实时转写' : 'LIVE TRANSCRIPT')
                      : (_isChinese ? '当前问题' : 'ACTIVE PROMPT'),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _transcription,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantTray() {
    final hasCompletedAnswer =
        _aiResponse.isNotEmpty &&
        (_status == EngineStatus.listening || _status == EngineStatus.idle);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(
          _isChinese ? '助手工具托盘' : 'ASSISTANT TRAY',
          Icons.dashboard_customize_outlined,
        ),
        const SizedBox(height: 8),
        if (!(_proactiveSuggestion != null ||
            _coachingPrompt != null ||
            _summaryText != null ||
            _smartFollowUps.isNotEmpty ||
            hasCompletedAnswer ||
            _engine.history.isNotEmpty))
          _buildProactiveTip(),
        if (_hasPinnedMemory) _buildPinnedMemoryCard(),
        if (_coachingPrompt != null) _buildCoachingCard(),
        if (_assistantProfile.showFollowUps &&
            _smartFollowUps.isNotEmpty &&
            hasCompletedAnswer)
          _buildSmartFollowUpChips(),
        if (_assistantProfile.showFollowUps &&
            SettingsManager.instance.autoShowFollowUps &&
            _smartFollowUps.isEmpty &&
            hasCompletedAnswer)
          _buildFollowUpSuggestions(),
        if (_proactiveSuggestion != null) _buildProactiveSuggestionCard(),
        if (_summaryText != null) _buildSummaryCard(),
        if (_assistantProfile.showSummaryTool &&
            SettingsManager.instance.autoShowSummary &&
            _engine.history.length >= 2 &&
            hasCompletedAnswer)
          _buildSummaryButton(),
        if (_engine.history.isNotEmpty && !_isRecording) _buildHistorySection(),
      ],
    );
  }

  Widget _buildProactiveTip() {
    final tip = _getProactiveTip();
    return GlassCard(
      opacity: 0.06,
      borderColor: HelixTheme.purple.withValues(alpha: 0.15),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: HelixTheme.purple.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String title, String body}) _getProactiveTip() {
    // Rotate tips based on time
    final tipIndex = DateTime.now().minute ~/ 5;
    final tips = _getTips();
    return tips[tipIndex % tips.length];
  }

  List<({String title, String body})> _getTips() {
    switch (_currentMode) {
      case ConversationMode.general:
        return [
          (
            title: 'Active Listening',
            body:
                'Repeat back key points to show engagement. "So what you\'re saying is..." builds instant rapport.',
          ),
          (
            title: 'The 2-Second Rule',
            body:
                'Pause 2 seconds before responding. It makes you seem thoughtful and gives better answers.',
          ),
          (
            title: 'Open-Ended Questions',
            body:
                'Ask "What was that like?" instead of "Did you like it?" to keep conversations flowing.',
          ),
          (
            title: 'Mirror & Match',
            body:
                'Subtly match the other person\'s energy and pace. It creates natural connection.',
          ),
          (
            title: 'Name Drop',
            body:
                'Use someone\'s name naturally in conversation. It makes them feel valued and remembered.',
          ),
          (
            title: 'Story Bridge',
            body:
                'Connect topics with "That reminds me of..." to keep conversations interesting and personal.',
          ),
        ];
      case ConversationMode.interview:
        return [
          (
            title: 'STAR Method',
            body:
                'Structure answers: Situation, Task, Action, Result. Interviewers love organized responses.',
          ),
          (
            title: 'Quantify Everything',
            body:
                '"Increased efficiency by 40%" beats "made things better". Numbers are memorable.',
          ),
          (
            title: 'Ask Smart Questions',
            body:
                'Ask about team culture or current challenges. It shows genuine interest and preparation.',
          ),
          (
            title: 'Weakness Flip',
            body:
                'Frame weaknesses as growth areas: "I used to struggle with X, so I developed Y."',
          ),
          (
            title: 'Close Strong',
            body:
                'End with: "Based on our conversation, I\'m excited about X because I can bring Y."',
          ),
          (
            title: 'Pause Before Answers',
            body:
                'A brief pause shows you\'re thinking carefully, not reciting memorized answers.',
          ),
        ];
      case ConversationMode.passive:
        return [
          (
            title: 'Listen First',
            body:
                'In passive mode, Even Companion monitors the conversation and only surfaces genuinely useful information.',
          ),
          (
            title: 'Fact Check Mode',
            body:
                'When someone states a fact, Even Companion can verify it and provide the correct information.',
          ),
          (
            title: 'Context Enrichment',
            body:
                'Even Companion adds relevant context and background when topics come up naturally.',
          ),
        ];
    }
  }

  Widget _buildSuggestionChips() {
    final suggestions = _getSuggestions();
    return GlassCard(
      opacity: 0.08,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('QUICK START', Icons.bolt),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) {
              return GestureDetector(
                onTap: () {
                  _askController.text = s;
                  _submitQuestion();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: HelixTheme.cyan.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: HelixTheme.cyan.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      color: HelixTheme.cyan.withValues(alpha: 0.7),
                      fontSize: 13,
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

  bool get _isChinese => SettingsManager.instance.language == 'zh';

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

  Widget _buildFollowUpSuggestions() {
    final followUps = _getFollowUps();
    if (followUps.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('FOLLOW UP', Icons.reply),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: followUps.map((text) {
              return GestureDetector(
                onTap: () {
                  _askController.text = text;
                  _submitQuestion();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: HelixTheme.purple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: HelixTheme.purple.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: HelixTheme.purple.withValues(alpha: 0.7),
                      fontSize: 12,
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

  List<String> _getFollowUps() {
    switch (_currentMode) {
      case ConversationMode.general:
        return ['Tell me more', 'Give me an example', 'How can I use this?'];
      case ConversationMode.interview:
        return [
          'How do I phrase that better?',
          'Give me a stronger example',
          'What metrics should I mention?',
        ];
      case ConversationMode.passive:
        return ['Elaborate on that', 'Is that accurate?'];
    }
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypingDots(),
          const SizedBox(width: 8),
          Text(
            'Thinking...',
            style: TextStyle(
              color: HelixTheme.cyan.withValues(alpha: 0.6),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingCursor() {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, child) {
        final opacity = (_typingController.value * 2).clamp(0.0, 1.0);
        final blink = opacity > 0.5 ? 1.0 : 0.3;
        return Container(
          width: 2,
          height: 16,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: HelixTheme.cyan.withValues(alpha: blink),
            borderRadius: BorderRadius.circular(1),
            boxShadow: [
              BoxShadow(
                color: HelixTheme.cyan.withValues(alpha: blink * 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThinkingCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GlassCard(
        opacity: 0.08,
        borderColor: HelixTheme.cyan.withValues(alpha: 0.2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypingDots(),
            const SizedBox(width: 12),
            Text(
              'Generating response...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDots() {
    return AnimatedBuilder(
      animation: _typingController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_typingController.value - delay).clamp(0.0, 1.0);
            final bounce = (progress < 0.5) ? progress * 2 : 2 - progress * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -4 * bounce),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HelixTheme.cyan.withValues(
                      alpha: 0.4 + 0.6 * bounce,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Conversation Intelligence Widgets
  // ---------------------------------------------------------------------------

  /// Proactive suggestion card shown when silence is detected
  Widget _buildProactiveSuggestionCard() {
    final suggestion = _proactiveSuggestion!;
    IconData icon;
    Color accentColor;
    switch (suggestion.type) {
      case SuggestionType.topicChange:
        icon = Icons.swap_horiz;
        accentColor = const Color(0xFFFF9F43);
        break;
      case SuggestionType.followUp:
        icon = Icons.reply;
        accentColor = HelixTheme.cyan;
        break;
      case SuggestionType.insight:
        icon = Icons.lightbulb_outline;
        accentColor = HelixTheme.purple;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () {
          _askController.text = suggestion.text;
          _submitQuestion();
          setState(() => _proactiveSuggestion = null);
        },
        child: GlassCard(
          opacity: 0.08,
          borderColor: accentColor.withValues(alpha: 0.25),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    suggestion.typeLabel.toUpperCase(),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _proactiveSuggestion = null),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                suggestion.text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isChinese ? '点击使用这个建议' : 'Tap to use this suggestion',
                style: TextStyle(
                  color: accentColor.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// STAR coaching card for behavioral interview questions
  Widget _buildCoachingCard() {
    final coaching = _coachingPrompt!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        opacity: 0.1,
        borderColor: HelixTheme.purple.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HelixTheme.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    coaching.framework,
                    style: const TextStyle(
                      color: HelixTheme.purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isChinese ? '行为面试教练' : 'Behavioral Interview Coach',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _coachingPrompt = null),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              coaching.prompt,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...coaching.steps.map((step) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HelixTheme.purple.withValues(alpha: 0.6),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (coaching.questionContext.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        coaching.questionContext,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Smart follow-up chips generated by the LLM based on conversation context
  Widget _buildSmartFollowUpChips() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(
            _isChinese ? '智能追问' : 'SMART FOLLOW-UPS',
            Icons.auto_awesome,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _smartFollowUps.map((text) {
              return GestureDetector(
                onTap: () {
                  _askController.text = text;
                  _submitQuestion();
                  setState(() => _smartFollowUps = []);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        HelixTheme.cyan.withValues(alpha: 0.08),
                        HelixTheme.purple.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: HelixTheme.cyan.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: HelixTheme.cyan.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _pinnedFollowUp = text),
                        child: Icon(
                          Icons.push_pin_outlined,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.42),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Summary button to generate a conversation summary
  Widget _buildSummaryButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: _isSummarizing ? null : _generateSummary,
        child: GlassCard(
          opacity: 0.06,
          borderColor: HelixTheme.cyan.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSummarizing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HelixTheme.cyan.withValues(alpha: 0.6),
                  ),
                )
              else
                Icon(
                  Icons.summarize,
                  size: 16,
                  color: HelixTheme.cyan.withValues(alpha: 0.6),
                ),
              const SizedBox(width: 8),
              Text(
                _isSummarizing
                    ? (_isChinese ? '正在生成摘要...' : 'Generating summary...')
                    : (_isChinese ? '生成对话摘要' : 'Summarize Conversation'),
                style: TextStyle(
                  color: HelixTheme.cyan.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Summary card displaying the generated conversation summary
  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        opacity: 0.08,
        borderColor: HelixTheme.cyan.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.summarize,
                  size: 14,
                  color: HelixTheme.cyan.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  _isChinese ? '对话摘要' : 'CONVERSATION SUMMARY',
                  style: TextStyle(
                    color: HelixTheme.cyan.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _pinnedResponse = _summaryText),
                  child: Icon(
                    Icons.push_pin_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.42),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _summaryText = null),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _summaryText!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate conversation summary via the engine
  Future<void> _generateSummary() async {
    setState(() {
      _isSummarizing = true;
      _summaryText = null;
    });

    final summary = await _engine.getSummary();

    if (mounted) {
      setState(() {
        _isSummarizing = false;
        _summaryText =
            summary ?? (_isChinese ? '无法生成摘要。' : 'Could not generate summary.');
      });
      _scrollToBottom();
    }
  }

  Widget _buildHistorySection() {
    final turns = _engine.history;
    if (turns.length <= 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildSectionLabel('HISTORY', Icons.history),
        const SizedBox(height: 8),
        ...turns.take(turns.length - 2).map((turn) {
          final isUser = turn.role == 'user';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GlassCard(
              opacity: 0.05,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isUser ? Icons.person : Icons.auto_awesome,
                    size: 14,
                    color: isUser
                        ? Colors.white.withValues(alpha: 0.4)
                        : HelixTheme.cyan.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      turn.content,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildComposerCard() {
    return GlassCard(
      opacity: 0.14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _isChinese ? '输入与控制' : 'Input Dock',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                _isRecording
                    ? (_isChinese ? '监听中' : 'Listening')
                    : (_isChinese ? '待命' : 'Standby'),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isRecording) ...[
            _buildQuickAskField(),
            const SizedBox(height: 12),
          ],
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
        return Container(
          decoration: isRecordingActive
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withValues(
                        alpha:
                            0.15 + 0.25 * (_pulseAnimation.value - 1.0) / 0.3,
                      ),
                      blurRadius: 20 + 12 * (_pulseAnimation.value - 1.0) / 0.3,
                      spreadRadius: 4 * (_pulseAnimation.value - 1.0) / 0.3,
                    ),
                  ],
                )
              : null,
          child: GlowButton(
            label: _isRecording ? 'Stop' : 'Listen',
            icon: _isRecording ? Icons.stop : Icons.mic,
            color: _isRecording ? const Color(0xFFFF6B6B) : HelixTheme.cyan,
            onPressed: _toggleRecording,
            isLoading: _status == EngineStatus.thinking,
          ),
        );
      },
    );
  }

  void _submitQuestion() {
    final text = _askController.text.trim();
    if (text.isNotEmpty) {
      _engine.askQuestion(_questionForPreset(text));
      _askController.clear();
      setState(() {
        _aiResponse = '';
        _providerError = null;
        _transcription = text;
        _smartFollowUps = [];
        _proactiveSuggestion = null;
        _coachingPrompt = null;
        _summaryText = null;
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

  void _rephraseAnswer() {
    if (_aiResponse.trim().isEmpty) return;
    final prompt = _isChinese
        ? '把下面这段回答改写成更自然、更像我本人会说的话，保持简洁：\n$_aiResponse'
        : 'Rephrase this answer into natural spoken language I can say directly. Keep it concise:\n$_aiResponse';
    _submitAssistantPrompt(
      prompt,
      label: _isChinese ? '改写当前回答' : 'Rephrase the current answer',
    );
  }

  void _translateAnswer() {
    if (_aiResponse.trim().isEmpty) return;
    final prompt = _isChinese
        ? '请把下面的回答翻译成自然英文，适合口语表达：\n$_aiResponse'
        : 'Translate this answer into natural Chinese that sounds good spoken aloud:\n$_aiResponse';
    _submitAssistantPrompt(
      prompt,
      label: _isChinese ? '翻译当前回答' : 'Translate the current answer',
    );
  }

  void _factCheckAnswer() {
    if (_aiResponse.trim().isEmpty) return;
    final prompt = _isChinese
        ? '请核实下面回答里的事实，指出可能不确定的部分，并给出更可靠的版本：\n$_aiResponse'
        : 'Fact-check the response below, flag uncertain claims, and give me a tighter corrected version:\n$_aiResponse';
    _submitAssistantPrompt(
      prompt,
      label: _isChinese ? '核实当前回答' : 'Fact-check the current answer',
    );
  }

  Future<void> _sendAnswerToGlasses() async {
    if (_aiResponse.trim().isEmpty) return;
    if (!BleManager.get().isConnected) {
      _showHomeSnackBar(_isChinese ? '请先连接眼镜。' : 'Connect the glasses first.');
      return;
    }

    await TextService.get.startSendText(
      _aiResponse.trim(),
      source: 'home.answer',
    );
    _showHomeSnackBar(
      _isChinese ? '回答已发送到眼镜。' : 'Response sent to the glasses.',
    );
  }

  Widget _buildInsightMemoryActions(AssistantInsightSnapshot snapshot) {
    final primaryInsight = snapshot.actionItems.isNotEmpty
        ? snapshot.actionItems.first
        : snapshot.verificationCandidates.isNotEmpty
        ? snapshot.verificationCandidates.first
        : snapshot.topics.isNotEmpty
        ? snapshot.topics.first
        : snapshot.summary;
    if (primaryInsight.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final isStarred = _starredInsightItems.contains(primaryInsight);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildMemoryActionChip(
          icon: isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
          label: _isChinese ? '收藏主洞察' : 'Star Primary Insight',
          onTap: () {
            setState(() {
              if (isStarred) {
                _starredInsightItems.remove(primaryInsight);
              } else {
                _starredInsightItems.add(primaryInsight);
              }
            });
          },
        ),
        if (snapshot.actionItems.isNotEmpty)
          _buildMemoryActionChip(
            icon: Icons.push_pin_outlined,
            label: _isChinese ? '固定行动项' : 'Pin Action Item',
            onTap: () {
              setState(() => _pinnedFollowUp = snapshot.actionItems.first);
            },
          ),
      ],
    );
  }

  Widget _buildMemoryActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: HelixTheme.purple.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasPinnedMemory =>
      (_pinnedResponse != null && _pinnedResponse!.trim().isNotEmpty) ||
      (_pinnedFollowUp != null && _pinnedFollowUp!.trim().isNotEmpty) ||
      _starredInsightItems.isNotEmpty;

  Widget _buildPinnedMemoryCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        opacity: 0.07,
        borderColor: HelixTheme.purple.withValues(alpha: 0.18),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel(
              _isChinese ? '当前记忆' : 'SESSION MEMORY',
              Icons.push_pin_outlined,
            ),
            if (_pinnedResponse != null) ...[
              const SizedBox(height: 10),
              _buildMemoryRow(
                _isChinese ? 'Pinned response' : 'Pinned response',
                _pinnedResponse!,
                () => setState(() => _pinnedResponse = null),
              ),
            ],
            if (_pinnedFollowUp != null) ...[
              const SizedBox(height: 10),
              _buildMemoryRow(
                _isChinese ? 'Pinned follow-up' : 'Pinned follow-up',
                _pinnedFollowUp!,
                () => setState(() => _pinnedFollowUp = null),
              ),
            ],
            if (_starredInsightItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _isChinese ? 'Starred insights' : 'Starred insights',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _starredInsightItems.map((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryRow(String label, String value, VoidCallback onClear) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onClear,
          child: Icon(
            Icons.close_rounded,
            size: 16,
            color: Colors.white.withValues(alpha: 0.34),
          ),
        ),
      ],
    );
  }

  void _pinCurrentResponse() {
    if (_aiResponse.trim().isEmpty) return;
    setState(() => _pinnedResponse = _aiResponse.trim());
  }

  void _togglePrimaryInsight(AssistantInsightSnapshot snapshot) {
    final primaryInsight = snapshot.actionItems.isNotEmpty
        ? snapshot.actionItems.first
        : snapshot.verificationCandidates.isNotEmpty
        ? snapshot.verificationCandidates.first
        : snapshot.topics.isNotEmpty
        ? snapshot.topics.first
        : snapshot.summary;
    if (primaryInsight.trim().isEmpty) return;
    setState(() {
      if (_starredInsightItems.contains(primaryInsight)) {
        _starredInsightItems.remove(primaryInsight);
      } else {
        _starredInsightItems.add(primaryInsight);
      }
    });
  }

  Future<void> _selectAssistantProfile(AssistantProfile profile) async {
    setState(() => _assistantProfileId = profile.id);
    await SettingsManager.instance.update((settings) {
      settings.assistantProfileId = profile.id;
    });
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

  void _showHomeSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _submitAssistantPrompt(String prompt, {required String label}) {
    _engine.askQuestion(prompt);
    setState(() {
      _aiResponse = '';
      _providerError = null;
      _transcription = label;
      _smartFollowUps = [];
      _proactiveSuggestion = null;
      _coachingPrompt = null;
      _summaryText = null;
    });
  }

  Widget _buildQuickAskField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HelixTheme.cyan.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 18,
              color: HelixTheme.cyan.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _askController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _getAskHint(),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onSubmitted: (_) => _submitQuestion(),
            ),
          ),
          GestureDetector(
            onTap: _submitQuestion,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: HelixTheme.cyan.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.send_rounded,
                color: HelixTheme.cyan.withValues(alpha: 0.85),
                size: 20,
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

  String _getStatusText() {
    if (_providerError != null) {
      return _isChinese ? '错误' : 'Error';
    }
    switch (_status) {
      case EngineStatus.idle:
        return 'Ready';
      case EngineStatus.listening:
        return 'Listening';
      case EngineStatus.thinking:
        return 'Thinking';
      case EngineStatus.responding:
        return 'Responding';
      case EngineStatus.error:
        return 'Error';
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

  String _getModeDescription() {
    if (_isChinese) {
      switch (_currentMode) {
        case ConversationMode.general:
          return '对话助手';
        case ConversationMode.interview:
          return '面试教练';
        case ConversationMode.passive:
          return '被动聆听';
      }
    }
    switch (_currentMode) {
      case ConversationMode.general:
        return 'Conversation Assistant';
      case ConversationMode.interview:
        return 'Interview Coach';
      case ConversationMode.passive:
        return 'Passive Listener';
    }
  }

  String _mapLanguageCode(String lang) {
    switch (lang) {
      case 'zh':
        return 'CN';
      case 'ja':
        return 'JP';
      case 'ko':
        return 'KR';
      case 'es':
        return 'ES';
      case 'ru':
        return 'RU';
      default:
        return 'EN';
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
