import 'dart:async';

import 'package:flutter/material.dart';

import '../models/assistant_profile.dart';
import '../services/llm/llm_provider.dart';
import '../services/llm/llm_service.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<({String id, String label})> _presetOptions = [
    (id: 'concise', label: 'Concise'),
    (id: 'speakForMe', label: 'Speak For Me'),
    (id: 'interview', label: 'Interview'),
    (id: 'factCheck', label: 'Fact Check'),
  ];

  final _settings = SettingsManager.instance;
  final _llmService = LlmService.instance;
  Map<String, bool> _configuredProviders = {};
  final Map<String, List<String>> _queriedModelsByProvider = {};
  StreamSubscription? _settingsSub;
  bool _isLoadingModels = false;
  String? _modelQueryError;

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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('AI Provider', Icons.psychology, [
              _buildProviderSelector(),
              const SizedBox(height: 12),
              _buildApiKeyTile(),
              const SizedBox(height: 12),
              _buildModelSelector(),
              const SizedBox(height: 12),
              _buildTemperatureSlider(),
            ]),
            const SizedBox(height: 20),
            _buildSection('Conversation', Icons.chat, [
              _buildLanguageSelector(),
              const SizedBox(height: 12),
              _buildToggle(
                'Auto-detect Questions',
                'Listen for questions in conversations',
                _settings.autoDetectQuestions,
                (v) => _settings.update((s) => s.autoDetectQuestions = v),
              ),
              const SizedBox(height: 8),
              _buildToggle(
                'Auto-answer',
                'Answer detected questions automatically',
                _settings.autoAnswerQuestions,
                (v) => _settings.update((s) => s.autoAnswerQuestions = v),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Transcription', Icons.record_voice_over, [
              ListTile(
                title: const Text('Backend'),
                subtitle: Text(_transcriptionBackendLabel(_settings.transcriptionBackend)),
                trailing: DropdownButton<String>(
                  value: _settings.transcriptionBackend,
                  dropdownColor: const Color(0xFF1A1F35),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'openai', child: Text('OpenAI')),
                    DropdownMenuItem(value: 'appleCloud', child: Text('Apple Cloud')),
                    DropdownMenuItem(value: 'appleOnDevice', child: Text('On-Device')),
                    DropdownMenuItem(value: 'whisper', child: Text('Whisper')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _settings.update((s) {
                        s.transcriptionBackend = value;
                        if (value != 'openai') {
                          s.openAISessionMode = 'transcription';
                        }
                      });
                    }
                  },
                ),
              ),
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
                  'Speaker Diarization',
                  'Identify different speakers in conversations (experimental)',
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
              ListTile(
                title: const Text('Microphone'),
                subtitle: Text(_micSourceLabel(_settings.preferredMicSource)),
                trailing: DropdownButton<String>(
                  value: _settings.preferredMicSource,
                  dropdownColor: const Color(0xFF1A1F35),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'auto', child: Text('Auto')),
                    DropdownMenuItem(value: 'glasses', child: Text('Glasses')),
                    DropdownMenuItem(value: 'phone', child: Text('Phone')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _settings.update((s) => s.preferredMicSource = value);
                    }
                  },
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Assistant Defaults', Icons.tune_rounded, [
              _buildAssistantProfileSelector(),
              const SizedBox(height: 12),
              _buildDefaultPresetSelector(),
              const SizedBox(height: 12),
              _buildToggle(
                'Auto-show Summary',
                'Expand summary tools after a completed answer',
                _settings.autoShowSummary,
                (v) => _settings.update((s) => s.autoShowSummary = v),
              ),
              const SizedBox(height: 8),
              _buildToggle(
                'Auto-show Follow-ups',
                'Open follow-up suggestions when the answer settles',
                _settings.autoShowFollowUps,
                (v) => _settings.update((s) => s.autoShowFollowUps = v),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Max Response Sentences'),
                subtitle: Text(
                  '${_settings.maxResponseSentences} sentences per answer on glasses',
                ),
                trailing: SizedBox(
                  width: 160,
                  child: Slider(
                    value: _settings.maxResponseSentences.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${_settings.maxResponseSentences}',
                    onChanged: (v) {
                      setState(() {
                        _settings.update(
                          (s) => s.maxResponseSentences = v.round(),
                        );
                      });
                    },
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Assistant Profiles', Icons.badge_outlined, [
              Text(
                'Profiles stay lightweight and prompt-driven. Edit the built-in profiles to tune tone, focus, and visible tools without introducing custom prompt plumbing.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              ..._settings.assistantProfiles.map(
                (profile) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildAssistantProfileCard(profile),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('AI Tools', Icons.build_circle_outlined, [
              _buildToggle(
                'Web Search',
                'Allow AI to search the web for fact-checking',
                _settings.webSearchEnabled,
                (v) => _settings.update((s) => s.webSearchEnabled = v),
              ),
              const SizedBox(height: 8),
              _buildToggle(
                'Voice Responses',
                'AI speaks answers through phone speaker',
                _settings.voiceResponseEnabled,
                (v) => _settings.update((s) => s.voiceResponseEnabled = v),
              ),
              if (_settings.voiceResponseEnabled) ...[
                const SizedBox(height: 8),
                _buildVoiceSelector(),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSection('Features', Icons.auto_awesome, [
              _buildToggle(
                'Sentiment Monitor',
                'Analyze conversation tone in real time',
                _settings.sentimentMonitorEnabled,
                (v) => _settings.update((s) => s.sentimentMonitorEnabled = v),
              ),
              const SizedBox(height: 8),
              _buildToggle(
                'Entity Memory',
                'Detect and remember people and companies mentioned',
                _settings.entityMemoryEnabled,
                (v) => _settings.update((s) => s.entityMemoryEnabled = v),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('All-Day Mode', Icons.hearing, [
              _buildToggle(
                'All-Day Listening',
                'Always-on phone mic with on-device transcription',
                _settings.allDayModeEnabled,
                (v) => _settings.update((s) => s.allDayModeEnabled = v),
              ),
              if (_settings.allDayModeEnabled) ...[
                const SizedBox(height: 12),
                _buildAnalysisBackendSelector(),
                const SizedBox(height: 8),
                _buildToggle(
                  'Auto-Update Profile',
                  'Let AI learn your preferences and contacts over time',
                  _settings.profileAutoUpdateEnabled,
                  (v) => _settings.update(
                      (s) => s.profileAutoUpdateEnabled = v),
                ),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSection('Translation', Icons.translate, [
              _buildToggle(
                'Live Translation',
                'Translate foreign-language speech in real time',
                _settings.translationEnabled,
                (v) => _settings.update((s) => s.translationEnabled = v),
              ),
              if (_settings.translationEnabled) ...[
                const SizedBox(height: 12),
                _buildTranslationTargetSelector(),
              ],
            ]),
            const SizedBox(height: 20),
            _buildSection('About', Icons.info_outline, [
              _buildInfoTile('Version', '1.0.0'),
              _buildInfoTile('Build', '1'),
            ]),
            const SizedBox(height: 80),
          ],
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

  Widget _buildProviderSelector() {
    final providerEntries = _orderedProviderEntries();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...providerEntries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildProviderCard(entry.key),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Each provider keeps its own API key. Anthropic uses its native API, while DeepSeek, Qwen, and Zhipu follow OpenAI-style request formats.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );
  }


  Widget _buildProviderCard(String providerId) {
    final provider = _llmService.providers[providerId];
    if (provider == null) return const SizedBox.shrink();

    final presentation = _providerPresentation(providerId);
    final isActive = providerId == _settings.activeProviderId;
    final isConfigured = _configuredProviders[providerId] ?? false;

    return GestureDetector(
      onTap: () => _setActiveProvider(providerId),
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
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildProviderTag(
                        label: provider.defaultModel,
                        color: Colors.white,
                      ),
                      _buildProviderTag(
                        label: isConfigured ? 'Configured' : 'Add key',
                        color: isConfigured ? Colors.green : Colors.orange,
                      ),
                    ],
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

  Widget _buildAssistantProfileSelector() {
    final currentProfile = _settings.resolveAssistantProfile();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default Assistant Profile',
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
          children: _settings.assistantProfiles.map((profile) {
            final isSelected = profile.id == currentProfile.id;
            return _buildSelectionChip(
              label: profile.name,
              isSelected: isSelected,
              onTap: () async {
                await _settings.update(
                  (s) => s.assistantProfileId = profile.id,
                );
                setState(() {});
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDefaultPresetSelector() {
    final selectedPreset = _settings.defaultQuickAskPreset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default Quick Ask Preset',
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
          children: _presetOptions.map((preset) {
            final isSelected = preset.id == selectedPreset;
            return _buildSelectionChip(
              label: preset.label,
              isSelected: isSelected,
              onTap: () async {
                await _settings.update(
                  (s) => s.defaultQuickAskPreset = preset.id,
                );
                setState(() {});
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAssistantProfileCard(AssistantProfile profile) {
    final isDefault = profile.id == _settings.assistantProfileId;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDefault
              ? HelixTheme.cyan.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HelixTheme.cyan.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: HelixTheme.cyan.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: HelixTheme.cyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            profile.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMiniBadge('Style', profile.answerStyle),
              if (profile.showSummaryTool) _buildMiniBadge('Summary', 'On'),
              if (profile.showFollowUps) _buildMiniBadge('Follow-ups', 'On'),
              if (profile.showFactCheck) _buildMiniBadge('Fact Check', 'On'),
              if (profile.showActionItems)
                _buildMiniBadge('Action Items', 'On'),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showProfileEditor(profile),
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: HelixTheme.cyan,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildLanguageSelector() {
    const languages = [
      ('en', 'English', '🇺🇸'),
      ('zh', '中文', '🇨🇳'),
      ('ja', '日本語', '🇯🇵'),
      ('ko', '한국어', '🇰🇷'),
      ('es', 'Español', '🇪🇸'),
      ('ru', 'Русский', '🇷🇺'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Language',
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
            final (code, label, flag) = lang;
            final isSelected = code == _settings.language;

            return GestureDetector(
              onTap: () async {
                await _settings.update((s) => s.language = code);
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? HelixTheme.cyan.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? HelixTheme.cyan.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? HelixTheme.cyan
                            : Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
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
        const SizedBox(height: 6),
        Text(
          'Switch providers at any time. Keys are stored separately, so you can keep Anthropic and Chinese provider credentials ready in parallel.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.48),
            fontSize: 11,
            height: 1.45,
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
        const SizedBox(height: 6),
        Text(
          isUsingProviderDefault
              ? 'Automatic follows ${provider.name} default model: ${provider.defaultModel}.'
              : models.contains(currentModel)
              ? 'Selected from the ${provider.name} model catalog.'
              : 'Using a custom model override: $currentModel',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.52),
            fontSize: 12,
            height: 1.45,
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

  void _showProfileEditor(AssistantProfile profile) {
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
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                    const SizedBox(height: 8),
                    Text(
                      'Keep the profile small and operational. This editor only tunes tone, purpose, and which assistant tools should be emphasized.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildProfileField('Profile Name', nameController),
                    const SizedBox(height: 12),
                    _buildProfileField(
                      'Short Description',
                      descriptionController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    _buildProfileField(
                      'Answer Style',
                      answerStyleController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildToggle(
                      'Summary Tool',
                      'Show summary actions for this profile',
                      showSummaryTool,
                      (v) => setSheetState(() => showSummaryTool = v),
                    ),
                    const SizedBox(height: 8),
                    _buildToggle(
                      'Follow-up Suggestions',
                      'Keep follow-up chips visible when useful',
                      showFollowUps,
                      (v) => setSheetState(() => showFollowUps = v),
                    ),
                    const SizedBox(height: 8),
                    _buildToggle(
                      'Fact Check',
                      'Surface verification actions by default',
                      showFactCheck,
                      (v) => setSheetState(() => showFactCheck = v),
                    ),
                    const SizedBox(height: 8),
                    _buildToggle(
                      'Action Items',
                      'Highlight action-item extraction on Home',
                      showActionItems,
                      (v) => setSheetState(() => showActionItems = v),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
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
                              );
                              await _settings.saveAssistantProfile(updated);
                              if (mounted) {
                                setState(() {});
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
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

  Widget _buildProfileField(
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
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: maxLines,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.34)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: HelixTheme.cyan.withValues(alpha: 0.32),
              ),
            ),
          ),
        ),
      ],
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

  String _transcriptionBackendLabel(String backend) {
    switch (backend) {
      case 'openai':
        return 'OpenAI speech with selectable transcription or realtime session';
      case 'appleCloud':
        return 'Apple cloud speech (free, ~1min limit)';
      case 'appleOnDevice':
        return 'On-device (works offline, lower accuracy)';
      case 'whisper':
        return 'Whisper batch API (chunked, with optional diarization)';
      default:
        return backend;
    }
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

  String _micSourceLabel(String source) {
    switch (source) {
      case 'auto':
        return 'Glasses when connected, phone otherwise';
      case 'glasses':
        return 'Always use glasses microphone';
      case 'phone':
        return 'Always use phone microphone';
      default:
        return source;
    }
  }
}
