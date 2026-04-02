import 'package:flutter/material.dart';

import '../theme/helix_theme.dart';
import '../widgets/glow_button.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.auto_awesome,
      title: 'Welcome to Even Companion',
      subtitle: 'Your AI-powered conversation edge',
      description:
          'Get real-time AI coaching, instant answers, and brilliant talking points \u2014 on your phone or streamed to your G1 glasses.',
      gradient: [HelixTheme.cyan, HelixTheme.purple],
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_rounded,
      title: 'Your AI Assistant',
      subtitle: 'Home',
      description:
          'Ask questions, start conversations, and get AI-powered answers instantly. Choose from 4 quick modes \u2014 Concise, Speak For Me, Interview Coach, or Fact Check. Tap the mic to start recording and let AI listen along.',
      gradient: [HelixTheme.cyan, HelixTheme.lime],
      bullets: [
        'Quick Ask',
        'Live Transcription',
        'AI Answers',
        'Follow-up Chips',
      ],
    ),
    _OnboardingPage(
      icon: Icons.bluetooth_connected_rounded,
      title: 'G1 Glasses Control',
      subtitle: 'Glasses',
      description:
          'Connect and manage your Even Realities G1 smart glasses. Choose your microphone source (Phone, Glasses, or Auto), monitor connection status, and configure your HUD display.',
      gradient: [HelixTheme.purple, HelixTheme.cyan],
      bullets: ['BLE Pairing', 'Mic Source', 'HUD Config', 'Dashboard'],
    ),
    _OnboardingPage(
      icon: Icons.history_rounded,
      title: 'Conversation History',
      subtitle: 'History',
      description:
          'Browse, search, and filter all your past conversations. Filter by mode (General, Interview, Answer All, or Answer On-demand), mark favorites, and find action items or fact-check flags.',
      gradient: [HelixTheme.purple, HelixTheme.amber],
      bullets: ['Search', 'Filter by Mode', 'Favorites', 'Action Items'],
    ),
    _OnboardingPage(
      icon: Icons.radio_button_checked_rounded,
      title: 'Live Conversation',
      subtitle: 'Live',
      description:
          'See your conversation unfold in real-time. Live transcription, AI Q&A as it happens, word and segment counts, and post-conversation analysis with topics, summaries, and action items.',
      gradient: [Color(0xFFFF6B6B), HelixTheme.amber],
      bullets: [
        'Real-time Transcript',
        'Live Q&A',
        'Word Count',
        'Post Analysis',
      ],
    ),
    _OnboardingPage(
      icon: Icons.lightbulb_rounded,
      title: 'Your Knowledge Hub',
      subtitle: 'Insights',
      description:
          'Three powerful tools in one tab. Facts extracts and organizes knowledge from your conversations. Memories creates daily narratives. Ask Buzz lets you chat with AI about everything you\'ve discussed.',
      gradient: [HelixTheme.amber, HelixTheme.lime],
      bullets: ['Facts', 'Daily Memories', 'Ask Buzz', 'Citations'],
    ),
    _OnboardingPage(
      icon: Icons.rocket_launch_rounded,
      title: "You're All Set",
      subtitle: 'Start your first conversation',
      description:
          'Head to Settings (gear icon) to add your AI provider API key, then tap the record button on the Home tab to begin. Your AI assistant is ready.',
      gradient: [HelixTheme.lime, HelixTheme.cyan],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: _currentPage < _pages.length - 1
                  ? TextButton(
                      onPressed: widget.onComplete,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 15,
                        ),
                      ),
                    )
                  : const SizedBox(height: 48),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon with gradient background
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: page.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: page.gradient.first.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(page.icon, size: 44, color: Colors.white),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          page.subtitle,
                          style: TextStyle(
                            color: HelixTheme.cyan.withValues(alpha: 0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          page.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 15,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (page.bullets != null) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: page.bullets!.map((label) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isActive
                        ? HelixTheme.cyan
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _currentPage == _pages.length - 1
                  ? GlowButton(
                      label: 'Get Started',
                      icon: Icons.arrow_forward,
                      onPressed: widget.onComplete,
                    )
                  : GlowButton(
                      label: 'Next',
                      icon: Icons.arrow_forward,
                      onPressed: () {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradient;
  final List<String>? bullets;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    this.bullets,
  });
}
