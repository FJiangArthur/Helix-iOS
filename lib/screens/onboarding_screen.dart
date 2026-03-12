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
          'Imagine never being caught off guard in a conversation again. Get real-time AI coaching, instant answers, and brilliant talking points delivered right when you need them.',
      gradient: [HelixTheme.cyan, HelixTheme.purple],
    ),
    _OnboardingPage(
      icon: Icons.hearing,
      title: 'Smart Listening',
      subtitle: 'The right mode for every moment',
      description:
          'General mode keeps any conversation flowing naturally. Interview mode coaches you with structured, impressive answers. Passive mode listens quietly and only chimes in when it matters.',
      gradient: [Color(0xFF00D4FF), Color(0xFF00FF88)],
    ),
    _OnboardingPage(
      icon: Icons.psychology,
      title: 'Your Choice of AI',
      subtitle: 'Five providers, one seamless experience',
      description:
          'Bring your own API key from OpenAI, Anthropic, DeepSeek, Qwen, or Zhipu. Responses stream to your glasses in real-time with no subscription required and no data stored on our servers.',
      gradient: [HelixTheme.purple, Color(0xFFFF6B6B)],
    ),
    _OnboardingPage(
      icon: Icons.visibility,
      title: 'Glasses + Phone',
      subtitle: 'Brilliant both ways',
      description:
          'Pair with Even Realities G1 glasses for discreet, hands-free AI answers on your HUD. No glasses? No problem. The full experience works standalone on your phone too.',
      gradient: [Color(0xFFFF6B6B), Color(0xFFFFAA00)],
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
              child: TextButton(
                onPressed: widget.onComplete,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 15,
                  ),
                ),
              ),
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
                                color: page.gradient.first.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            page.icon,
                            size: 44,
                            color: Colors.white,
                          ),
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

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
  });
}
