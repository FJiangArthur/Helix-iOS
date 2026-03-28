// ABOUTME: Chat UI for Buzz AI — lets users ask natural-language questions
// ABOUTME: about their past conversations and facts, with streaming answers.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_helix/models/buzz_citation.dart';
import 'package:flutter_helix/services/buzz/buzz_service.dart';
import 'package:flutter_helix/theme/helix_theme.dart';
import 'package:flutter_helix/widgets/glass_card.dart';

// ---------------------------------------------------------------------------
// Data models for the chat message list
// ---------------------------------------------------------------------------

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String? staticText; // set when response is complete
  final Stream<String>? textStream; // set while streaming
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
// Screen
// ---------------------------------------------------------------------------

class BuzzScreen extends StatefulWidget {
  const BuzzScreen({super.key});

  @override
  State<BuzzScreen> createState() => _BuzzScreenState();
}

class _BuzzScreenState extends State<BuzzScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _messages = <_ChatMessage>[];

  bool _isProcessing = false;
  StreamSubscription<BuzzResponseEvent>? _activeSub;

  static const _starterChips = [
    'What topics came up this week?',
    'Summarize my last conversation',
    'What do I know about...',
  ];

  @override
  void dispose() {
    _activeSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  void _send(String text) {
    final question = text.trim();
    if (question.isEmpty || _isProcessing) return;

    _controller.clear();

    // Add user bubble.
    setState(() {
      _messages.add(_ChatMessage(role: 'user', staticText: question));
      _isProcessing = true;
    });
    _scrollToBottom();

    // Streaming controller that feeds the AnimatedTextStream-style widget.
    final streamController = StreamController<String>.broadcast();
    var fullText = '';
    var citations = <BuzzCitation>[];

    // Add placeholder assistant bubble with the live stream.
    final assistantMsg = _ChatMessage(
      role: 'assistant',
      textStream: streamController.stream,
      isSearching: true,
    );
    setState(() => _messages.add(assistantMsg));

    _activeSub = BuzzService.instance.ask(question).listen(
      (event) {
        switch (event) {
          case BuzzSearching():
            // Already showing the searching indicator.
            break;
          case BuzzCitationsAvailable():
            final newCitations = event.citations;
            citations = newCitations;
            // Replace with streaming bubble (no longer "searching").
            setState(() {
              final idx = _messages.indexOf(assistantMsg);
              if (idx >= 0) {
                _messages[idx] = _ChatMessage(
                  role: 'assistant',
                  textStream: streamController.stream,
                  citations: newCitations,
                );
              }
            });
          case BuzzTextDelta(:final text):
            fullText += text;
            streamController.add(text);
            _scrollToBottom();
          case BuzzComplete():
            streamController.close();
            // Replace stream bubble with static text bubble for performance.
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

  void _clearHistory() {
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

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      appBar: AppBar(
        title: const Text('Buzz'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: HelixTheme.textMuted),
              tooltip: 'Clear history',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty ? _buildStarters() : _buildChatList(),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Starter chips (empty state)
  // ------------------------------------------------------------------

  Widget _buildStarters() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: HelixTheme.cyan.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(
              'Ask Buzz anything about your conversations',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: HelixTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _starterChips.map((chip) {
                return ActionChip(
                  label: Text(chip, style: const TextStyle(color: HelixTheme.cyan, fontSize: 13)),
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: HelixTheme.cyan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => _send(chip),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Chat message list
  // ------------------------------------------------------------------

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
          borderRadius: BorderRadius.circular(16),
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
          'Searching your conversations...',
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

    // Streaming text — use a StreamBuilder.
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
            color: HelixTheme.purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
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

  // ------------------------------------------------------------------
  // Input bar
  // ------------------------------------------------------------------

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: HelixTheme.backgroundRaised,
        border: Border(
          top: BorderSide(color: HelixTheme.borderSubtle.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(color: HelixTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Ask Buzz a question...',
                filled: true,
                fillColor: HelixTheme.surfaceInteractive,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: HelixTheme.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: HelixTheme.cyan),
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: _isProcessing
                  ? HelixTheme.textMuted
                  : HelixTheme.cyan,
            ),
            onPressed: _isProcessing ? null : () => _send(_controller.text),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Streaming text widget (lightweight, avoids rebuilding entire chat list)
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
    return SelectableText(
      _text,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
