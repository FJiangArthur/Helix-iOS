import 'package:flutter/material.dart';

import '../services/session_prep_service.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';

/// Session Prep screen — lets the user paste prep material (JD, resume,
/// meeting notes) that will be grounded into LLM responses during the
/// next prepared conversation.
///
/// Three key UI states:
///   - empty       — prompt user to paste
///   - loaded      — show character + token count, Clear button
///   - overflow    — truncation banner if paste exceeded 8k tokens
///   - rejected    — injection-rejection banner if content blocked
class SessionPrepScreen extends StatefulWidget {
  const SessionPrepScreen({super.key});

  @override
  State<SessionPrepScreen> createState() => _SessionPrepScreenState();
}

class _SessionPrepScreenState extends State<SessionPrepScreen> {
  late final TextEditingController _controller;
  void Function()? _disposePrepListener;
  bool _initialized = false;
  bool _saving = false;
  String? _statusMessage;
  _StatusTone _statusTone = _StatusTone.info;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await SessionPrepService.instance.initialize();
    _controller.text = SessionPrepService.instance.prep;
    _disposePrepListener = SessionPrepService.instance.addListener(() {
      if (!mounted) return;
      // Only refresh from the service when the screen isn't mid-edit.
      // If the user is actively typing, their buffer wins.
      if (!_saving && _controller.text != SessionPrepService.instance.prep) {
        setState(() {
          _controller.text = SessionPrepService.instance.prep;
        });
      }
    });
    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _disposePrepListener?.call();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _statusMessage = null;
    });
    final result = await SessionPrepService.instance.save(_controller.text);
    if (!mounted) return;
    final message = _messageFor(result);
    setState(() {
      _saving = false;
      _statusMessage = message?.text;
      _statusTone = message?.tone ?? _StatusTone.info;
      // If truncation happened the text buffer is now the truncated version.
      _controller.text = SessionPrepService.instance.prep;
    });
  }

  Future<void> _clear() async {
    _controller.clear();
    await SessionPrepService.instance.clear();
    if (!mounted) return;
    setState(() {
      _statusMessage = 'Prep cleared.';
      _statusTone = _StatusTone.info;
    });
  }

  _StatusMessage? _messageFor(SaveResult result) {
    switch (result) {
      case SaveResult.saved:
        return const _StatusMessage('Prep saved.', _StatusTone.success);
      case SaveResult.savedInMemory:
        return const _StatusMessage(
          "Saved for this session only — couldn't write to storage.",
          _StatusTone.warning,
        );
      case SaveResult.truncated:
        return _StatusMessage(
          'Prep exceeded the ${SessionPrepService.maxPrepTokens}-token '
          'budget and was truncated.',
          _StatusTone.warning,
        );
      case SaveResult.truncatedAndInMemory:
        return _StatusMessage(
          'Prep truncated and stored in-memory only — storage write failed.',
          _StatusTone.warning,
        );
      case SaveResult.rejected:
        return const _StatusMessage(
          'Prep rejected — content looks like a prompt-injection attempt. '
          'Remove phrases like "ignore previous instructions" and try again.',
          _StatusTone.error,
        );
      case SaveResult.cleared:
        return const _StatusMessage('Prep cleared.', _StatusTone.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prepLength = _controller.text.length;
    final tokens = SessionPrepService.estimateTokens(_controller.text);
    final overBudget = tokens > SessionPrepService.maxPrepTokens;
    final prepEnabled = SettingsManager.instance.sessionPrepEnabled;

    return Scaffold(
      backgroundColor: HelixTheme.background,
      appBar: AppBar(
        backgroundColor: HelixTheme.background,
        title: const Text('Session Prep'),
        titleTextStyle: const TextStyle(
          color: HelixTheme.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
        iconTheme: const IconThemeData(color: HelixTheme.textPrimary),
      ),
      body: SafeArea(
        child: _initialized
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _FeatureFlagBanner(prepEnabled: prepEnabled),
                  const SizedBox(height: 12),
                  _DisclosureCard(),
                  const SizedBox(height: 12),
                  _PrepInputCard(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _CounterRow(
                    chars: prepLength,
                    tokens: tokens,
                    overBudget: overBudget,
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    _StatusBanner(
                      message: _statusMessage!,
                      tone: _statusTone,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _clear,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: HelixTheme.textPrimary,
                            side: const BorderSide(
                              color: HelixTheme.borderStrong,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: HelixTheme.cyan,
                            foregroundColor: HelixTheme.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(_saving ? 'Saving...' : 'Save prep'),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(color: HelixTheme.cyan),
              ),
      ),
    );
  }
}

class _FeatureFlagBanner extends StatelessWidget {
  const _FeatureFlagBanner({required this.prepEnabled});
  final bool prepEnabled;

  @override
  Widget build(BuildContext context) {
    final tone = prepEnabled ? _StatusTone.success : _StatusTone.warning;
    final text = prepEnabled
        ? 'Session Prep is enabled. Saved prep will be injected into the '
              'system prompt on every LLM call during conversations.'
        : 'Session Prep is currently disabled in Settings. You can save prep '
              "here, but it won't be used until the feature is enabled.";
    return _StatusBanner(message: text, tone: tone);
  }
}

class _DisclosureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How this works',
              style: TextStyle(
                color: HelixTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste your prep material for the next conversation — a job '
              'description, resume, meeting notes, anything relevant. Helix '
              'will surface specific facts from this material when they '
              'answer the question being asked.',
              style: TextStyle(
                color: HelixTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            _BulletRow(
              'Prep is sent to your configured LLM provider on every message.',
            ),
            _BulletRow(
              'Prep clears automatically when the conversation ends.',
            ),
            _BulletRow(
              'Pasted content is treated as data, not instructions — prompt-'
              'injection patterns are rejected.',
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 5, color: HelixTheme.cyan),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: HelixTheme.textSecondary,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrepInputCard extends StatelessWidget {
  const _PrepInputCard({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          minLines: 8,
          maxLines: 20,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: const TextStyle(
            color: HelixTheme.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText:
                'Paste your prep material here — JD, resume, meeting notes,\n'
                'customer CRM history, company research...',
            hintStyle: TextStyle(color: HelixTheme.textMuted, fontSize: 13),
          ),
          inputFormatters: const [],
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.chars,
    required this.tokens,
    required this.overBudget,
  });
  final int chars;
  final int tokens;
  final bool overBudget;

  @override
  Widget build(BuildContext context) {
    final pctOfBudget =
        ((tokens / SessionPrepService.maxPrepTokens) * 100).clamp(0, 999);
    // Wrap (not Row) so chips re-flow to a second line on narrow widths
    // instead of overflowing horizontally.
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _chip('Chars: $chars', HelixTheme.textSecondary),
        _chip(
          'Tokens: ~$tokens / ${SessionPrepService.maxPrepTokens} '
          '(${pctOfBudget.toStringAsFixed(0)}%)',
          overBudget ? HelixTheme.amber : HelixTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HelixTheme.surfaceInteractive,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HelixTheme.borderSubtle),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

enum _StatusTone { info, success, warning, error }

class _StatusMessage {
  const _StatusMessage(this.text, this.tone);
  final String text;
  final _StatusTone tone;
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.tone});
  final String message;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, border, accent, icon) = switch (tone) {
      _StatusTone.info => (
          HelixTheme.surfaceRaised,
          HelixTheme.borderSubtle,
          HelixTheme.cyan,
          Icons.info_outline,
        ),
      _StatusTone.success => (
          HelixTheme.surfaceRaised,
          HelixTheme.lime.withValues(alpha: 0.5),
          HelixTheme.lime,
          Icons.check_circle_outline,
        ),
      _StatusTone.warning => (
          HelixTheme.surfaceRaised,
          HelixTheme.amber.withValues(alpha: 0.5),
          HelixTheme.amber,
          Icons.warning_amber_outlined,
        ),
      _StatusTone.error => (
          HelixTheme.surfaceRaised,
          HelixTheme.error.withValues(alpha: 0.5),
          HelixTheme.error,
          Icons.error_outline,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: HelixTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
