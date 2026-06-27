import 'package:flutter/material.dart';

import '../theme/helix_assets.dart';
import '../theme/helix_theme.dart';
import '../widgets/glow_button.dart';
import '../widgets/helix/helix_generated_art.dart';

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
      heroAsset: HelixAssets.assistantHero,
      iconAsset: HelixAssets.navAssistant,
      title: 'Helix',
      subtitle: 'Assistant',
      description:
          'Listen, detect the moment that matters, and send concise answers to your phone or G1 glasses.',
      gradient: [HelixTheme.cyan, HelixTheme.purple],
    ),
    _OnboardingPage(
      heroAsset: HelixAssets.assistantHero,
      iconAsset: HelixAssets.navAssistant,
      title: 'Live Assistant',
      subtitle: 'Assistant',
      description:
          'Use Tune presets for concise answers, speakable replies, interview coaching, and fact checking.',
      gradient: [HelixTheme.cyan, HelixTheme.lime],
      bullets: ['Tune presets', 'Live transcript', 'Q&A handoff', 'Follow-ups'],
    ),
    _OnboardingPage(
      heroAsset: HelixAssets.deviceHero,
      iconAsset: HelixAssets.navDevice,
      title: 'G1 Control',
      subtitle: 'Device',
      description:
          'Connect your glasses, choose the mic source, and keep HUD delivery visible at a glance.',
      gradient: [HelixTheme.purple, HelixTheme.cyan],
      bullets: ['BLE Pairing', 'Mic Source', 'HUD Config', 'Dashboard'],
    ),
    _OnboardingPage(
      heroAsset: HelixAssets.sessionsHero,
      iconAsset: HelixAssets.navSessions,
      title: 'Sessions',
      subtitle: 'Monitor, archive, projects',
      description:
          'Review live analysis, archived conversations, project context, and metrics in one place.',
      gradient: [HelixTheme.lime, HelixTheme.cyan],
      bullets: ['Monitor', 'Archive', 'Projects', 'Metrics'],
    ),
    _OnboardingPage(
      heroAsset: HelixAssets.knowledgeHero,
      iconAsset: HelixAssets.navKnowledge,
      title: 'Knowledge Hub',
      subtitle: 'Knowledge',
      description:
          'Facts, memories, projects, and citations stay organized after the conversation ends.',
      gradient: [HelixTheme.amber, HelixTheme.lime],
      bullets: ['Ask', 'Facts', 'Memories', 'Review'],
    ),
    _OnboardingPage(
      heroAsset: HelixAssets.settingsHero,
      iconAsset: HelixAssets.navSettings,
      title: "You're All Set",
      subtitle: 'Settings',
      description:
          'Add an AI provider key, confirm your speech backend, then tap the record button on Assistant.',
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
                        HelixGeneratedBackdrop(
                          key: Key('onboarding-generated-hero-$index'),
                          asset: page.heroAsset,
                          height: 156,
                          accent: page.gradient.first,
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: HelixGeneratedIcon(
                              asset: page.iconAsset,
                              selected: true,
                              size: 44,
                              semanticLabel: page.subtitle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0,
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
  final String heroAsset;
  final String iconAsset;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradient;
  final List<String>? bullets;

  const _OnboardingPage({
    required this.heroAsset,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    this.bullets,
  });
}
