import 'dart:async';

import 'package:flutter/material.dart';

import '../models/assistant_profile.dart';
import '../services/llm/llm_service.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';

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

  Future<void> _showCustomModelDialog() async {
    final controller = TextEditingController(text: _settings.activeModel ?? '');
    final provider =
        _llmService.providers[_settings.activeProviderId]?.name ??
        _settings.activeProviderId;

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
              borderSide: BorderSide(
                color: HelixTheme.cyan.withValues(alpha: 0.42),
              ),
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
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
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
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildAssistantProfileCard(profile),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Glasses', Icons.visibility, [
              _buildToggle(
                'Auto-connect',
                'Connect when glasses are in range',
                _settings.autoConnect,
                (v) => _settings.update((s) => s.autoConnect = v),
              ),
              const SizedBox(height: 12),
              _buildSlider(
                'HUD Brightness',
                _settings.hudBrightness,
                (v) => _settings.update((s) => s.hudBrightness = v),
              ),
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
    final providers = _llmService.providers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Provider',
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
          children: providers.entries.map((entry) {
            final isActive = entry.key == _settings.activeProviderId;
            final isConfigured = _configuredProviders[entry.key] ?? false;

            return GestureDetector(
              onTap: () async {
                await _settings.update((s) {
                  s.activeProviderId = entry.key;
                  s.activeModel = null;
                });
                try {
                  _llmService.setActiveProvider(entry.key, model: null);
                } catch (_) {}
                await _loadModelsForActiveProvider();
                setState(() {
                  _connectionTestResult = null;
                  _connectionTestError = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? HelixTheme.cyan.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? HelixTheme.cyan.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.value.name,
                      style: TextStyle(
                        color: isActive
                            ? HelixTheme.cyan
                            : Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (isConfigured) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Colors.green.withValues(alpha: 0.7),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
              subtitle: profile.description,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault
              ? HelixTheme.cyan.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniBadge('Style', profile.answerStyle),
              if (profile.showSummaryTool) _buildMiniBadge('Summary', 'On'),
              if (profile.showFollowUps) _buildMiniBadge('Follow-ups', 'On'),
              if (profile.showFactCheck) _buildMiniBadge('Fact Check', 'On'),
              if (profile.showActionItems)
                _buildMiniBadge('Action Items', 'On'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showProfileEditor(profile),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Profile'),
              style: TextButton.styleFrom(
                foregroundColor: HelixTheme.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11,
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
    final isConfigured =
        _configuredProviders[_settings.activeProviderId] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showApiKeyDialog(_settings.activeProviderId),
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
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isConfigured ? 'API Key configured' : 'Set API Key',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        isConfigured ? Icons.check_circle : Icons.warning_amber,
                        size: 16,
                        color: isConfigured ? Colors.green : Colors.orange,
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
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _connectionTestResult == true
                        ? Colors.green.withValues(alpha: 0.1)
                        : _connectionTestResult == false
                        ? Colors.red.withValues(alpha: 0.1)
                        : HelixTheme.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _connectionTestResult == true
                          ? Colors.green.withValues(alpha: 0.3)
                          : _connectionTestResult == false
                          ? Colors.red.withValues(alpha: 0.3)
                          : HelixTheme.cyan.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _isTestingConnection
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: HelixTheme.cyan.withValues(alpha: 0.6),
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
                          color: HelixTheme.cyan.withValues(alpha: 0.7),
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

    final models =
        _queriedModelsByProvider[_settings.activeProviderId] ??
        provider.availableModels;
    final currentModel = _settings.activeModel ?? provider.defaultModel;
    final canRefreshModels =
        (_configuredProviders[_settings.activeProviderId] ?? false) &&
        !_isLoadingModels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Model',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: canRefreshModels
                  ? () => _loadModelsForActiveProvider(refresh: true)
                  : null,
              icon: _isLoadingModels
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HelixTheme.cyan.withValues(alpha: 0.7),
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: HelixTheme.cyan.withValues(alpha: 0.75),
                    ),
              label: Text(
                _isLoadingModels ? 'Loading' : 'Query Models',
                style: TextStyle(
                  color: HelixTheme.cyan.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _showCustomModelDialog,
              child: Text(
                'Custom',
                style: TextStyle(
                  color: HelixTheme.purple.withValues(alpha: 0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: models.map((model) {
            final isSelected = model == currentModel;
            return GestureDetector(
              onTap: () async {
                await _setActiveModel(model);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? HelixTheme.purple.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? HelixTheme.purple.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  model,
                  style: TextStyle(
                    color: isSelected
                        ? HelixTheme.purple
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (currentModel.isNotEmpty && !models.contains(currentModel)) ...[
          const SizedBox(height: 10),
          Text(
            'Using custom model: $currentModel',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 12,
            ),
          ),
        ],
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

  Widget _buildSlider(
    String title,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return StatefulBuilder(
      builder: (context, setSliderState) {
        var currentValue = value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  '${(currentValue * 100).round()}%',
                  style: TextStyle(color: HelixTheme.cyan, fontSize: 13),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: HelixTheme.cyan,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                thumbColor: HelixTheme.cyan,
                trackHeight: 2,
              ),
              child: Slider(
                value: currentValue,
                onChanged: (v) => setSliderState(() => currentValue = v),
                onChangeEnd: onChanged,
              ),
            ),
          ],
        );
      },
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
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
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
}
