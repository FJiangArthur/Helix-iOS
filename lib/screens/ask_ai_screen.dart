// ABOUTME: Center tab combining Buzz AI chat (Q&A on memories/facts) and fact Review (swipe cards).
// ABOUTME: Uses DefaultTabController with two sub-tabs: Chat and Review.

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/buzz_citation.dart';
import '../services/buzz/buzz_service.dart';
import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import '../widgets/glass_card.dart';
import '../widgets/helix_visuals.dart';
import 'pending_facts_review.dart';
import 'settings_screen.dart';

// ---------------------------------------------------------------------------
// Chat message model
// ---------------------------------------------------------------------------

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String? staticText;
  final Stream<String>? textStream;
  final List<BuzzCitation> citations;
  final bool isSearching;

  _ChatMessage({
    required this.role,
    this.staticText,
    this.textStream,
    this.citations = const [],
    this.isSearching = false,
  });
}

// ---------------------------------------------------------------------------
// AskAiScreen
// ---------------------------------------------------------------------------

class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key});

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _buzzController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _messages = <_ChatMessage>[];
  bool _isProcessing = false;
  StreamSubscription<BuzzResponseEvent>? _activeSub;

  static final _starterChips = [
    tr('What topics came up this week?', '这周讨论了哪些话题？'),
    tr('Summarize my last conversation', '总结我的上一次对话'),
    tr('What do I know about...', '我了解到关于...'),
  ];

  @override
  void dispose() {
    _activeSub?.cancel();
    _buzzController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---- Buzz logic ----

  void _sendBuzz(String text) {
    final question = text.trim();
    if (question.isEmpty || _isProcessing) return;

    _buzzController.clear();

    setState(() {
      _messages.add(_ChatMessage(role: 'user', staticText: question));
      _isProcessing = true;
    });
    _scrollToBottom();

    final streamController = StreamController<String>.broadcast();
    var fullText = '';
    var citations = <BuzzCitation>[];

    final assistantMsg = _ChatMessage(
      role: 'assistant',
      textStream: streamController.stream,
      isSearching: true,
    );
    setState(() => _messages.add(assistantMsg));

    _activeSub = BuzzService.instance
        .ask(question)
        .listen(
          (event) {
            switch (event) {
              case BuzzSearching():
                break;
              case BuzzCitationsAvailable():
                citations = event.citations;
                setState(() {
                  final idx = _messages.indexOf(assistantMsg);
                  if (idx >= 0) {
                    _messages[idx] = _ChatMessage(
                      role: 'assistant',
                      textStream: streamController.stream,
                      citations: citations,
                    );
                  }
                });
              case BuzzTextDelta(:final text):
                fullText += text;
                streamController.add(text);
                _scrollToBottom();
              case BuzzComplete():
                streamController.close();
                setState(() {
                  final idx = _messages.indexOf(assistantMsg);
                  if (idx >= 0) {
                    _messages[idx] = _ChatMessage(
                      role: 'assistant',
                      staticText: fullText,
                      citations: citations,
                    );
                  }
                  _isProcessing = false;
                });
              case BuzzError(:final message):
                streamController.close();
                setState(() {
                  final idx = _messages.indexOf(assistantMsg);
                  if (idx >= 0) {
                    _messages[idx] = _ChatMessage(
                      role: 'assistant',
                      staticText: 'Error: $message',
                    );
                  }
                  _isProcessing = false;
                });
            }
          },
          onError: (Object e) {
            streamController.close();
            setState(() => _isProcessing = false);
          },
        );
  }

  void _clearBuzzHistory() {
    BuzzService.instance.clearHistory();
    setState(() => _messages.clear());
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

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: HelixTheme.background,
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight + 8),
            child: SizedBox(
              height: kTextTabBarHeight + 8,
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      indicatorColor: HelixTheme.cyan,
                      indicatorWeight: 2.5,
                      labelColor: HelixTheme.textPrimary,
                      unselectedLabelColor: HelixTheme.textMuted,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: tr('Daily AI', '每日 AI')),
                        Tab(text: tr('Review', '审阅')),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: HelixTheme.textSecondary,
                    ),
                    tooltip: tr('Settings', '设置'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [_buildChatTab(), const PendingFactsReview()],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          if (_messages.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: HelixTheme.textMuted,
                  ),
                  tooltip: tr('Clear history', '清除历史'),
                  onPressed: _clearBuzzHistory,
                ),
              ),
            ),
          Expanded(
            child: _messages.isEmpty ? _buildStarters() : _buildChatList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildStarters() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HelixVisual(
              type: HelixVisualType.knowledge,
              height: 132,
              compact: true,
            ),
            const SizedBox(height: 16),
            Text(
              tr(
                'Ask anything about your conversations, facts, and memories',
                '询问关于你的对话、事实和记忆的任何问题',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: HelixTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _starterChips.map((chip) {
                return ActionChip(
                  label: Text(
                    chip,
                    style: const TextStyle(
                      color: HelixTheme.cyan,
                      fontSize: 13,
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: HelixTheme.cyan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(HelixTheme.radiusPill),
                  ),
                  onPressed: () => _sendBuzz(chip),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: msg.role == 'user'
              ? _buildUserBubble(msg)
              : _buildAssistantBubble(msg),
        );
      },
    );
  }

  Widget _buildUserBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: HelixTheme.surfaceInteractive,
          borderRadius: BorderRadius.circular(HelixTheme.radiusPanel),
        ),
        child: Text(
          msg.staticText ?? '',
          style: const TextStyle(color: HelixTheme.textPrimary, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(_ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: msg.isSearching
                  ? _buildSearchingIndicator()
                  : _buildAssistantText(msg),
            ),
            if (msg.citations.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildCitationChips(msg.citations),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: HelixTheme.cyan.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          tr('Searching your conversations...', '搜索对话中...'),
          style: TextStyle(
            color: HelixTheme.textSecondary,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantText(_ChatMessage msg) {
    if (msg.staticText != null) {
      return SelectableText(
        msg.staticText!,
        style: Theme.of(context).textTheme.bodyLarge,
      );
    }
    return _StreamingText(stream: msg.textStream!);
  }

  Widget _buildCitationChips(List<BuzzCitation> citations) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: citations.take(5).map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: HelixTheme.purple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(HelixTheme.radiusPanel),
            border: Border.all(color: HelixTheme.purple.withValues(alpha: 0.3)),
          ),
          child: Text(
            c.label,
            style: const TextStyle(
              color: HelixTheme.purple,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: HelixTheme.backgroundRaised,
        border: Border(
          top: BorderSide(
            color: HelixTheme.borderSubtle.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _buzzController,
              focusNode: _focusNode,
              style: const TextStyle(
                color: HelixTheme.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: tr('Ask about your conversations...', '询问你的对话...'),
                filled: true,
                fillColor: HelixTheme.surfaceInteractive,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HelixTheme.radiusControl),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HelixTheme.radiusControl),
                  borderSide: const BorderSide(color: HelixTheme.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(HelixTheme.radiusControl),
                  borderSide: const BorderSide(color: HelixTheme.cyan),
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _sendBuzz,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: _isProcessing ? HelixTheme.textMuted : HelixTheme.cyan,
            ),
            onPressed: _isProcessing
                ? null
                : () => _sendBuzz(_buzzController.text),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streaming text widget
// ---------------------------------------------------------------------------

class _StreamingText extends StatefulWidget {
  final Stream<String> stream;
  const _StreamingText({required this.stream});

  @override
  State<_StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<_StreamingText> {
  String _text = '';
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen((chunk) {
      if (mounted) setState(() => _text += chunk);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) {
      return SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: HelixTheme.cyan.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return SelectableText(_text, style: Theme.of(context).textTheme.bodyLarge);
  }
}
