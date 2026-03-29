import 'dart:async';

import 'package:flutter/material.dart';

import '../services/llm/llm_provider.dart';
import '../services/llm/llm_service.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import '../widgets/glass_card.dart';

const _automaticModelSelection = '__provider_default__';
const _providerDisplayOrder = [
  'openai',
  'anthropic',
  'deepseek',
  'qwen',
  'zhipu',
  'siliconflow',
];

class _ProviderPresentation {
  final Color accent;
  final String cluster;
  final String description;
  final IconData icon;
  final String protocol;
  final String region;

  const _ProviderPresentation({
    required this.accent,
    required this.cluster,
    required this.description,
    required this.icon,
    required this.protocol,
    required this.region,
  });
}

class _TranscriptionPresentation {
  final Color accent;
  final IconData icon;
  final String label;
  final String subtitle;

  const _TranscriptionPresentation({
    required this.accent,
    required this.icon,
    required this.label,
    required this.subtitle,
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsManager.instance;
  final _llmService = LlmService.instance;
  Map<String, bool> _configuredProviders = {};
  final Map<String, List<String>> _queriedModelsByProvider = {};
  StreamSubscription? _settingsSub;
  bool _isLoadingModels = false;
  String? _modelQueryError;
  bool _isProviderExpanded = false;
  bool _isTranscriptionExpanded = false;

  // Connection test state
  bool _isTestingConnection = false;
  bool?
  _connectionTestResult; // null = not tested, true = success, false = failure
  String? _connectionTestError;

  @override
  void initState() {
    super.initState();
    _loadProviderStatus();
    _settingsSub = _settings.onSettingsChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadProviderStatus() async {
    _configuredProviders = await _settings.getConfiguredProviders();
    await _loadModelsForActiveProvider();
    if (mounted) setState(() {});
  }

  Future<void> _loadModelsForActiveProvider({bool refresh = false}) async {
    final providerId = _settings.activeProviderId;
    final provider = _llmService.providers[providerId];
    if (provider == null) {
      return;
    }

    if (_configuredProviders[providerId] != true) {
      _queriedModelsByProvider[providerId] = provider.availableModels;
      _modelQueryError = null;
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingModels = true;
        _modelQueryError = null;
      });
    }

    try {
      final models = await _llmService.queryAvailableModels(
        providerId,
        refresh: refresh,
      );
      _queriedModelsByProvider[providerId] = models;
    } catch (e) {
      _modelQueryError = 'Could not query models right now.';
      _queriedModelsByProvider[providerId] = provider.availableModels;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingModels = false;
        });
      }
    }
  }

  Future<void> _setActiveModel(String? model) async {
    final normalized = model?.trim();
    final nextModel = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;

    await _settings.update((s) => s.activeModel = nextModel);
    _llmService.setActiveProvider(_settings.activeProviderId, model: nextModel);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setActiveProvider(String providerId) async {
    await _settings.update((s) {
      s.activeProviderId = providerId;
      s.activeModel = null;
    });
    try {
      _llmService.setActiveProvider(providerId, model: null);
    } catch (_) {}
    await _loadModelsForActiveProvider();
    if (mounted) {
      setState(() {
        _connectionTestResult = null;
        _connectionTestError = null;
      });
    }
  }

  List<MapEntry<String, LlmProvider>> _orderedProviderEntries() {
    final providers = _llmService.providers;
    final ordered = <MapEntry<String, LlmProvider>>[];

    for (final id in _providerDisplayOrder) {
      final provider = providers[id];
      if (provider != null) {
        ordered.add(MapEntry(id, provider));
      }
    }

    for (final entry in providers.entries) {
      final alreadyIncluded = ordered.any((item) => item.key == entry.key);
      if (!alreadyIncluded) {
        ordered.add(MapEntry(entry.key, entry.value));
      }
    }

    return ordered;
  }

  _ProviderPresentation _providerPresentation(String providerId) {
    switch (providerId) {
      case 'anthropic':
        return const _ProviderPresentation(
          accent: Color(0xFFD59B5B),
          cluster: 'Frontier Providers',
          description:
              'Anthropic models tuned for dependable reasoning, writing, and instruction following.',
          icon: Icons.psychology_alt_rounded,
          protocol: 'Native Messages API',
          region: 'Anthropic',
        );
      case 'deepseek':
        return const _ProviderPresentation(
          accent: Color(0xFF4DB8FF),
          cluster: 'Chinese Providers',
          description:
              'DeepSeek chat and reasoning models with a strong value profile and familiar API shape.',
          icon: Icons.auto_graph_rounded,
          protocol: 'OpenAI-compatible',
          region: 'DeepSeek',
        );
      case 'qwen':
        return const _ProviderPresentation(
          accent: Color(0xFF57C785),
          cluster: 'Chinese Providers',
          description:
              'Alibaba Qwen models for bilingual assistants, enterprise routing, and broad China coverage.',
          icon: Icons.language_rounded,
          protocol: 'DashScope compatible',
          region: 'Alibaba Cloud',
        );
      case 'zhipu':
        return const _ProviderPresentation(
          accent: Color(0xFF7C83FF),
          cluster: 'Chinese Providers',
          description:
              'GLM models from Zhipu AI with a lightweight flash tier and China-hosted deployment path.',
          icon: Icons.hub_rounded,
          protocol: 'OpenAI-compatible',
          region: 'Zhipu AI',
        );
      case 'siliconflow':
        return const _ProviderPresentation(
          accent: Color(0xFFFF8C42),
          cluster: 'Chinese Providers',
          description:
              'Model aggregator with free open-source models (Qwen, DeepSeek, GLM) and paid premium tiers.',
          icon: Icons.layers_rounded,
          protocol: 'OpenAI-compatible',
          region: 'SiliconFlow',
        );
      case 'openai':
      default:
        return const _ProviderPresentation(
          accent: HelixTheme.cyan,
          cluster: 'Frontier Providers',
          description:
              'GPT chat and realtime models for general-purpose use, voice features, and broad model coverage.',
          icon: Icons.bolt_rounded,
          protocol: 'Realtime + Chat',
          region: 'OpenAI',
        );
    }
  }

  _TranscriptionPresentation _transcriptionPresentation(String backendId) {
    switch (backendId) {
      case 'appleCloud':
        return const _TranscriptionPresentation(
          accent: HelixTheme.purple,
          icon: Icons.cloud_rounded,
          label: 'Apple Cloud',
          subtitle: 'Server-side speech recognition',
        );
      case 'appleOnDevice':
        return const _TranscriptionPresentation(
          accent: HelixTheme.lime,
          icon: Icons.phone_iphone_rounded,
          label: 'On-Device',
          subtitle: 'Offline speech recognition',
        );
      case 'whisper':
        return const _TranscriptionPresentation(
          accent: HelixTheme.amber,
          icon: Icons.graphic_eq_rounded,
          label: 'Whisper',
          subtitle: 'Batch processing with diarization',
        );
      case 'openai':
      default:
        return const _TranscriptionPresentation(
          accent: HelixTheme.cyan,
          icon: Icons.bolt_rounded,
          label: 'OpenAI',
          subtitle: 'Transcription & realtime modes',
        );
    }
  }

  Future<void> _showCustomModelDialog() async {
    final controller = TextEditingController(text: _settings.activeModel ?? '');
    final provider =
        _llmService.providers[_settings.activeProviderId]?.name ??
        _settings.activeProviderId;
    final accent = _providerPresentation(_settings.activeProviderId).accent;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HelixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Custom $provider model',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter a model ID',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent.withValues(alpha: 0.42)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _setActiveModel(controller.text);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: Text(
              'Save',
              style: TextStyle(color: accent.withValues(alpha: 0.92)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRealtimePromptDialog() async {
    final controller = TextEditingController(
      text: _settings.openAIRealtimePrompt ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HelixTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Realtime prompt',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 6,
          maxLines: 12,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText:
                'Optional override for the realtime assistant prompt. Leave blank to use the generated conversation prompt.',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: HelixTheme.cyan.withValues(alpha: 0.42),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _settings.update((s) => s.openAIRealtimePrompt = null);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Use Default'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final value = controller.text.trim();
              await _settings.update(
                (s) => s.openAIRealtimePrompt = value.isEmpty ? null : value,
              );
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: Text(
              'Save',
              style: TextStyle(color: HelixTheme.cyan.withValues(alpha: 0.92)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Settings', '设置')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(tr('AI Provider', 'AI 服务商'), Icons.psychology, [
              _buildProviderSelector(),
              const SizedBox(height: 12),
              _buildApiKeyTile(),
              const SizedBox(height: 12),
              _buildModelSelector(),
              const SizedBox(height: 12),
              _buildModelTierSelectors(),
              const SizedBox(height: 12),
              _buildTemperatureSlider(),
            ]),
            const SizedBox(height: 20),
            _buildSection(tr('Conversation', '对话'), Icons.chat, [
              _buildToggle(
                tr('Auto-detect Questions', '自动检测问题'),
                tr('Listen for questions in conversations', '在对话中监听问题'),
                _settings.autoDetectQuestions,
                (v) => _settings.update((s) => s.autoDetectQuestions = v),
              ),
              const SizedBox(height: 8),
              _buildToggle(
                tr('Auto-answer', '自动回答'),
                tr('Answer detected questions automatically', '自动回答检测到的问题'),
                _settings.autoAnswerQuestions,
                (v) => _settings.update((s) => s.autoAnswerQuestions = v),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection(tr('Transcription', '语音转写'), Icons.record_voice_over, [
              _buildTranscriptionBackendSelector(),
              const SizedBox(height: 12),
              if (_settings.transcriptionBackend == 'openai')
                ListTile(
                  title: const Text('OpenAI Session'),
                  subtitle: Text(
                    _openAISessionModeLabel(_settings.openAISessionMode),
                  ),
                  trailing: DropdownButton<String>(
                    value: _settings.openAISessionMode,
                    dropdownColor: const Color(0xFF1A1F35),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'transcription',
                        child: Text('Transcription'),
                      ),
                      DropdownMenuItem(
                        value: 'realtime',
                        child: Text('Realtime'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _settings.update((s) => s.openAISessionMode = value);
                      }
                    },
                  ),
                ),
              if (_settings.transcriptionBackend == 'openai')
                ListTile(
                  title: const Text('Model'),
                  trailing: DropdownButton<String>(
                    value: _settings.transcriptionModel,
                    dropdownColor: const Color(0xFF1A1F35),
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'gpt-4o-mini-transcribe',
                        child: Text('gpt-4o-mini-transcribe'),
                      ),
                      DropdownMenuItem(
                        value: 'gpt-4o-transcribe',
                        child: Text('gpt-4o-transcribe'),
                      ),
                      DropdownMenuItem(
                        value: 'whisper-1',
                        child: Text('whisper-1'),
                      ),
                      DropdownMenuItem(
                        value: 'gpt-4o-mini-realtime',
                        child: Text('gpt-4o-mini-realtime'),
                      ),
                      DropdownMenuItem(
                        value: 'gpt-4o-realtime',
                        child: Text('gpt-4o-realtime'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _settings.update((s) => s.transcriptionModel = value);
                      }
                    },
                  ),
                ),
              if (_settings.transcriptionBackend == 'openai' &&
                  _settings.openAISessionMode == 'realtime')
                ListTile(
                  title: const Text('Realtime Prompt'),
                  subtitle: Text(
                    _settings.openAIRealtimePrompt?.trim().isNotEmpty == true
                        ? _settings.openAIRealtimePrompt!.trim()
                        : 'Use generated conversation prompt',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton(
                    onPressed: _showRealtimePromptDialog,
                    child: const Text('Edit'),
                  ),
                ),
              if (_settings.transcriptionBackend == 'whisper' ||
                  _settings.transcriptionBackend == 'appleCloud' ||
                  _settings.transcriptionBackend == 'appleOnDevice')
                _buildToggle(
                  tr('Speaker Diarization', '说话人分离'),
                  tr('Identify different speakers in conversations (experimental)', '识别对话中的不同说话人（实验性）'),
                  _settings.enableDiarization,
                  (v) => _settings.update((s) => s.enableDiarization = v),
                ),
              if (_settings.transcriptionBackend == 'whisper')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    title: const Text('Chunk Duration'),
                    subtitle: Text('${_settings.whisperChunkDurationSec}s audio segments'),
                    trailing: DropdownButton<int>(
                      value: _settings.whisperChunkDurationSec,
                      dropdownColor: const Color(0xFF1A1F35),
                      underline: const SizedBox.shrink(),
                      items: [3, 5, 10]
                          .map((v) => DropdownMenuItem(value: v, child: Text('${v}s')))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _settings.update((s) => s.whisperChunkDurationSec = value);
                        }
                      },
                    ),
                  ),
                ),


            ]),
            const SizedBox(height: 20),
            _buildSection(tr('AI Tools', 'AI 工具'), Icons.build_circle_outlined, [
              _buildToggle(
                tr('Web Search', '网络搜索'),
                tr('Allow AI to search the web for fact-checking', '允许 AI 搜索网络进行事实核查'),
                _settings.webSearchEnabled,
                (v) => _settings.update((s) => s.webSearchEnabled = v),
              ),
              const SizedBox(height: 8),
              _buildToggle(
                tr('Voice Responses', '语音回复'),
                tr('AI speaks answers through phone speaker', 'AI 通过手机扬声器朗读答案'),
                _settings.voiceResponseEnabled,
                (v) => _settings.update((s) => s.voiceResponseEnabled = v),
              ),
              if (_settings.voiceResponseEnabled) ...[
                const SizedBox(height: 8),
                _buildVoiceSelector(),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSection(tr('Features', '功能'), Icons.auto_awesome, [
              _buildToggle(
                tr('Sentiment Monitor', '情感监测'),
                tr('Analyze conversation tone in real time', '实时分析对话语气'),
                _settings.sentimentMonitorEnabled,
                (v) => _settings.update((s) => s.sentimentMonitorEnabled = v),
              ),
              const SizedBox(height: 8),
              _buildToggle(
                tr('Entity Memory', '实体记忆'),
                tr('Detect and remember people and companies mentioned', '检测并记住提到的人物和公司'),
                _settings.entityMemoryEnabled,
                (v) => _settings.update((s) => s.entityMemoryEnabled = v),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection(tr('All-Day Mode', '全天模式'), Icons.hearing, [
              _buildToggle(
                tr('All-Day Listening', '全天监听'),
                tr('Always-on phone mic with on-device transcription', '始终开启手机麦克风并使用设备端转写'),
                _settings.allDayModeEnabled,
                (v) => _settings.update((s) => s.allDayModeEnabled = v),
              ),
              if (_settings.allDayModeEnabled) ...[
                const SizedBox(height: 12),
                _buildAnalysisBackendSelector(),
                const SizedBox(height: 8),
                _buildToggle(
                  tr('Auto-Update Profile', '自动更新档案'),
                  tr('Let AI learn your preferences and contacts over time', '让 AI 随时间学习你的偏好和联系人'),
                  _settings.profileAutoUpdateEnabled,
                  (v) => _settings.update(
                      (s) => s.profileAutoUpdateEnabled = v),
                ),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSection(tr('Translation', '翻译'), Icons.translate, [
              _buildToggle(
                tr('Live Translation', '实时翻译'),
                tr('Translate foreign-language speech in real time', '实时翻译外语语音'),
                _settings.translationEnabled,
                (v) => _settings.update((s) => s.translationEnabled = v),
              ),
              if (_settings.translationEnabled) ...[
                const SizedBox(height: 12),
                _buildTranslationTargetSelector(),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSection(
                tr('Internationalization', '国际化'), Icons.translate, [
              _buildUiLanguageSelector(),
            ]),
            const SizedBox(height: 20),
            _buildSection(tr('About', '关于'), Icons.info_outline, [
              _buildInfoTile(tr('Version', '版本'), '1.0.0'),
              _buildInfoTile(tr('Build', '构建'), '1'),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: HelixTheme.cyan.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: HelixTheme.cyan.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsibleCardSelector({
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget selectedCard,
    required List<Widget> allCards,
    String? helperText,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isExpanded
            ? [
                ...allCards,
                if (helperText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    helperText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ]
            : [
                selectedCard,
              ],
      ),
    );
  }

  Widget _buildProviderSelector() {
    final providerEntries = _orderedProviderEntries();
    final activeId = _settings.activeProviderId;

    return _buildCollapsibleCardSelector(
      isExpanded: _isProviderExpanded,
      onToggle: () => setState(() => _isProviderExpanded = true),
      selectedCard: _buildProviderCard(activeId, showChevron: true),
      allCards: providerEntries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildProviderCard(entry.key),
            ),
          )
          .toList(),
      helperText:
          'Each provider keeps its own API key. Anthropic uses its native API, while DeepSeek, Qwen, and Zhipu follow OpenAI-style request formats.',
    );
  }


  Widget _buildProviderCard(String providerId, {bool showChevron = false}) {
    final provider = _llmService.providers[providerId];
    if (provider == null) return const SizedBox.shrink();

    final presentation = _providerPresentation(providerId);
    final isActive = providerId == _settings.activeProviderId;
    final isConfigured = _configuredProviders[providerId] ?? false;

    return GestureDetector(
      onTap: showChevron
          ? () => setState(() => _isProviderExpanded = !_isProviderExpanded)
          : () {
              setState(() => _isProviderExpanded = false);
              _setActiveProvider(providerId);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? presentation.accent.withValues(alpha: 0.11)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? presentation.accent.withValues(alpha: 0.38)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: presentation.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                presentation.icon,
                color: presentation.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildProviderTag(
                    label: provider.defaultModel,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            if (isConfigured)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.check_circle,
                  size: 15,
                  color: Colors.green.withValues(alpha: 0.8),
                ),
              ),
            Icon(
              isActive ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isActive
                  ? presentation.accent
                  : Colors.white.withValues(alpha: 0.28),
              size: 20,
            ),
            if (showChevron && isActive)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  _isProviderExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderTag({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == Colors.white
              ? Colors.white.withValues(alpha: 0.74)
              : color.withValues(alpha: 0.92),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTranscriptionBackendCard(String backendId,
      {bool showChevron = false}) {
    final presentation = _transcriptionPresentation(backendId);
    final isActive = backendId == _settings.transcriptionBackend;

    return GestureDetector(
      onTap: showChevron
          ? () => setState(
              () => _isTranscriptionExpanded = !_isTranscriptionExpanded)
          : () {
              setState(() => _isTranscriptionExpanded = false);
              _settings.update((s) {
                s.transcriptionBackend = backendId;
                if (backendId != 'openai') {
                  s.openAISessionMode = 'transcription';
                }
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? presentation.accent.withValues(alpha: 0.11)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? presentation.accent.withValues(alpha: 0.38)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: presentation.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                presentation.icon,
                color: presentation.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildProviderTag(
                    label: presentation.subtitle,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            Icon(
              isActive ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isActive
                  ? presentation.accent
                  : Colors.white.withValues(alpha: 0.28),
              size: 20,
            ),
            if (showChevron && isActive)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  _isTranscriptionExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptionBackendSelector() {
    const backends = ['openai', 'appleCloud', 'appleOnDevice', 'whisper'];
    final activeBackend = _settings.transcriptionBackend;

    return _buildCollapsibleCardSelector(
      isExpanded: _isTranscriptionExpanded,
      onToggle: () => setState(() => _isTranscriptionExpanded = true),
      selectedCard:
          _buildTranscriptionBackendCard(activeBackend, showChevron: true),
      allCards: backends
          .map(
            (id) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTranscriptionBackendCard(id),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSelectionChip({
    required String label,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? HelixTheme.cyan.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? HelixTheme.cyan.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisBackendSelector() {
    const backends = [
      ('cloud', 'Cloud LLM', 'Uses your configured API provider'),
      ('llama', 'On-Device LLM', 'Offline via llama.cpp (coming soon)'),
      ('foundation', 'Apple AI', 'Foundation Models, iPhone 16 Pro+'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analysis Backend',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: backends.map((b) {
            final isSelected = _settings.analysisBackend == b.$1;
            return _buildSelectionChip(
              label: b.$2,
              subtitle: b.$3,
              isSelected: isSelected,
              onTap: () =>
                  _settings.update((s) => s.analysisBackend = b.$1),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUiLanguageSelector() {
    const languages = [
      ('en', 'English', '🇺🇸'),
      ('zh', '中文', '🇨🇳'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('UI Language', '界面语言'),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: languages.map((lang) {
            final (code, label, flag) = lang;
            final isSelected = code == _settings.uiLanguage;

            return GestureDetector(
              onTap: () async {
                if (code == _settings.uiLanguage) return;
                await _settings.update((s) => s.uiLanguage = code);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? HelixTheme.cyan.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? HelixTheme.cyan.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? HelixTheme.cyan
                            : Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTranslationTargetSelector() {
    const languages = [
      ('en', 'English'),
      ('zh', 'Chinese'),
      ('ja', 'Japanese'),
      ('ko', 'Korean'),
      ('es', 'Spanish'),
      ('fr', 'French'),
      ('de', 'German'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Translate To',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: languages.map((lang) {
            final (code, label) = lang;
            final isSelected = code == _settings.translationTargetLanguage;

            return GestureDetector(
              onTap: () async {
                await _settings.update(
                  (s) => s.translationTargetLanguage = code,
                );
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6E86FF).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6E86FF).withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF6E86FF)
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _testCurrentConnection() async {
    final providerId = _settings.activeProviderId;
    final apiKey = await _settings.getApiKey(providerId);
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _connectionTestResult = false;
        _connectionTestError = 'No API key configured';
      });
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = null;
      _connectionTestError = null;
    });

    try {
      final result = await _llmService.testConnection(providerId, apiKey);
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _connectionTestResult = result;
          _connectionTestError = result ? null : 'Connection failed';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _connectionTestResult = false;
          _connectionTestError = e.toString();
        });
      }
    }
  }

  Widget _buildApiKeyTile() {
    final providerId = _settings.activeProviderId;
    final presentation = _providerPresentation(providerId);
    final isConfigured = _configuredProviders[providerId] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connection',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showApiKeyDialog(providerId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.key,
                        size: 16,
                        color: presentation.accent.withValues(alpha: 0.78),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConfigured
                                  ? 'API key configured'
                                  : 'Set API key',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${presentation.region} • ${presentation.protocol}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.44),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isConfigured)
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green.withValues(alpha: 0.78),
                        )
                      else
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: Colors.orange.withValues(alpha: 0.82),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (isConfigured) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isTestingConnection ? null : _testCurrentConnection,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _connectionTestResult == true
                        ? Colors.green.withValues(alpha: 0.1)
                        : _connectionTestResult == false
                        ? Colors.red.withValues(alpha: 0.1)
                        : presentation.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _connectionTestResult == true
                          ? Colors.green.withValues(alpha: 0.3)
                          : _connectionTestResult == false
                          ? Colors.red.withValues(alpha: 0.3)
                          : presentation.accent.withValues(alpha: 0.24),
                    ),
                  ),
                  child: _isTestingConnection
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: presentation.accent.withValues(alpha: 0.75),
                          ),
                        )
                      : _connectionTestResult == true
                      ? const Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green,
                        )
                      : _connectionTestResult == false
                      ? const Icon(Icons.cancel, size: 16, color: Colors.red)
                      : Icon(
                          Icons.wifi_tethering,
                          size: 16,
                          color: presentation.accent.withValues(alpha: 0.86),
                        ),
                ),
              ),
            ],
          ],
        ),
        // Test result feedback
        if (_connectionTestResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(
                  _connectionTestResult!
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  size: 13,
                  color: _connectionTestResult!
                      ? Colors.green.withValues(alpha: 0.7)
                      : Colors.red.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _connectionTestResult!
                        ? 'Connection successful'
                        : _connectionTestError ?? 'Connection failed',
                    style: TextStyle(
                      color: _connectionTestResult!
                          ? Colors.green.withValues(alpha: 0.7)
                          : Colors.red.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildModelSelector() {
    final provider = _llmService.providers[_settings.activeProviderId];
    if (provider == null) return const SizedBox.shrink();

    final accent = _providerPresentation(_settings.activeProviderId).accent;
    final models =
        _queriedModelsByProvider[_settings.activeProviderId] ??
        provider.availableModels;
    final currentModel = _settings.activeModel ?? provider.defaultModel;
    final isUsingProviderDefault =
        _settings.activeModel == null || _settings.activeModel!.trim().isEmpty;
    final canRefreshModels =
        (_configuredProviders[_settings.activeProviderId] ?? false) &&
        !_isLoadingModels;
    final selectedValue = isUsingProviderDefault
        ? _automaticModelSelection
        : currentModel;

    final dropdownItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: _automaticModelSelection,
        child: Text('Automatic (${provider.defaultModel})'),
      ),
      ...models.map(
        (model) => DropdownMenuItem<String>(
          value: model,
          child: Text(model, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    if (!isUsingProviderDefault && !models.contains(currentModel)) {
      dropdownItems.add(
        DropdownMenuItem<String>(
          value: currentModel,
          child: Text('Custom: $currentModel', overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Model Catalog',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${models.length} options',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              isExpanded: true,
              dropdownColor: HelixTheme.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              iconEnabledColor: accent.withValues(alpha: 0.9),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              items: dropdownItems,
              onChanged: (value) async {
                if (value == null) return;
                if (value == _automaticModelSelection) {
                  await _setActiveModel(null);
                  return;
                }
                await _setActiveModel(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: canRefreshModels
                  ? () => _loadModelsForActiveProvider(refresh: true)
                  : null,
              icon: _isLoadingModels
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent.withValues(alpha: 0.75),
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: accent.withValues(alpha: 0.9),
                    ),
              label: Text(
                _isLoadingModels ? 'Loading' : 'Query Models',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent.withValues(alpha: 0.22)),
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _showCustomModelDialog,
              icon: Icon(
                Icons.edit_rounded,
                size: 14,
                color: accent.withValues(alpha: 0.9),
              ),
              label: Text(
                'Custom',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent.withValues(alpha: 0.22)),
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        if (_modelQueryError != null) ...[
          const SizedBox(height: 6),
          Text(
            _modelQueryError!,
            style: TextStyle(
              color: Colors.orange.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelTierSelectors() {
    final provider = _llmService.providers[_settings.activeProviderId];
    if (provider == null) return const SizedBox.shrink();

    final models =
        _queriedModelsByProvider[_settings.activeProviderId] ??
        provider.availableModels;
    final accent = _providerPresentation(_settings.activeProviderId).accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Model Tiers',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Use a fast model for detection and a smart model for answers',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        _buildTierDropdown(
          label: 'Light Model',
          subtitle: 'detection, analysis',
          value: _settings.lightModel,
          models: models,
          accent: accent,
          providerDefault: provider.defaultModel,
          onChanged: (v) => _settings.update((s) => s.lightModel = v),
        ),
        const SizedBox(height: 8),
        _buildTierDropdown(
          label: 'Smart Model',
          subtitle: 'responses, Q&A',
          value: _settings.smartModel,
          models: models,
          accent: accent,
          providerDefault: provider.defaultModel,
          onChanged: (v) => _settings.update((s) => s.smartModel = v),
        ),
      ],
    );
  }

  Widget _buildTierDropdown({
    required String label,
    required String subtitle,
    required String? value,
    required List<String> models,
    required Color accent,
    required String providerDefault,
    required ValueChanged<String?> onChanged,
  }) {
    final isAutomatic = value == null || value.trim().isEmpty;
    final selectedValue = isAutomatic ? _automaticModelSelection : value;

    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: _automaticModelSelection,
        child: Text('Automatic ($providerDefault)'),
      ),
      ...models.map(
        (m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
      ),
    ];

    if (!isAutomatic && !models.contains(value)) {
      items.add(DropdownMenuItem(value: value, child: Text('Custom: $value')));
    }

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12, fontWeight: FontWeight.w500,
              )),
              Text(subtitle, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 10,
              )),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.15)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedValue,
                isExpanded: true,
                dropdownColor: HelixTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
                iconEnabledColor: accent.withValues(alpha: 0.7),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
                onChanged: (v) {
                  onChanged(v == _automaticModelSelection ? null : v);
                  setState(() {});
                },
                items: items,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemperatureSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Temperature',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _settings.temperature.toStringAsFixed(1),
              style: TextStyle(
                color: HelixTheme.cyan,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: HelixTheme.cyan,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: HelixTheme.cyan,
            overlayColor: HelixTheme.cyan.withValues(alpha: 0.1),
            trackHeight: 2,
          ),
          child: Slider(
            value: _settings.temperature,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: (v) {
              setState(() => _settings.temperature = v);
            },
            onChangeEnd: (v) {
              _settings.update((s) => s.temperature = v);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(
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
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: HelixTheme.cyan,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        ),
      ],
    );
  }

  Widget _buildVoiceSelector() {
    const voices = [
      ('alloy', 'Alloy'),
      ('echo', 'Echo'),
      ('fable', 'Fable'),
      ('onyx', 'Onyx'),
      ('nova', 'Nova'),
      ('shimmer', 'Shimmer'),
    ];
    final selected = _settings.voiceAssistantVoice;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: voices.map((v) {
        final isSelected = v.$1 == selected;
        return _buildSelectionChip(
          label: v.$2,
          isSelected: isSelected,
          onTap: () => _settings.update((s) => s.voiceAssistantVoice = v.$1),
        );
      }).toList(),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog(String providerId) {
    final controller = TextEditingController();
    final providerName = _llmService.providers[providerId]?.name ?? providerId;
    final presentation = _providerPresentation(providerId);
    bool isTesting = false;
    bool? testResult;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HelixTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$providerName API Key',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${presentation.region} • ${presentation.protocol}',
                    style: TextStyle(
                      color: presentation.accent.withValues(alpha: 0.86),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    presentation.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.54),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Paste your API key here',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      suffixIcon: isTesting
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : testResult != null
                          ? Icon(
                              testResult! ? Icons.check_circle : Icons.error,
                              color: testResult! ? Colors.green : Colors.red,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final key = controller.text.trim();
                            if (key.isEmpty) return;
                            setSheetState(() {
                              isTesting = true;
                              testResult = null;
                            });
                            try {
                              final result = await _llmService.testConnection(
                                providerId,
                                key,
                              );
                              setSheetState(() {
                                isTesting = false;
                                testResult = result;
                              });
                            } catch (e) {
                              setSheetState(() {
                                isTesting = false;
                                testResult = false;
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: presentation.accent.withValues(
                                alpha: 0.24,
                              ),
                            ),
                            foregroundColor: presentation.accent,
                          ),
                          child: const Text('Test'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final key = controller.text.trim();
                            if (key.isEmpty) return;
                            await _settings.setApiKey(providerId, key);
                            _llmService.setApiKey(providerId, key);
                            await _loadProviderStatus();
                            if (context.mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: presentation.accent,
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_configuredProviders[providerId] == true) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await _settings.deleteApiKey(providerId);
                          _llmService.setApiKey(providerId, '');
                          await _loadProviderStatus();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Text(
                          'Remove Key',
                          style: TextStyle(
                            color: Colors.red.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _openAISessionModeLabel(String mode) {
    switch (mode) {
      case 'realtime':
        return 'Transcription plus live text answers for detected questions';
      case 'transcription':
      default:
        return 'Transcription only';
    }
  }

}
