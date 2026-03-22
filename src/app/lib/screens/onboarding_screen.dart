import 'package:flutter/material.dart';

import '../services/notification_display_service.dart';

/// Data for a single onboarding page.
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Default onboarding pages for the app.
const defaultOnboardingPages = [
  OnboardingPage(
    title: "Today's Buffs",
    description: 'See active bonuses like 2× Candy and bonus XP at a glance.',
    icon: Icons.local_fire_department,
  ),
  OnboardingPage(
    title: 'Flag Events',
    description:
        'Flag the events you care about so you never miss Community Day or Raid Hour.',
    icon: Icons.flag,
  ),
  OnboardingPage(
    title: 'Get Notified',
    description:
        'Turn on notifications to get a heads-up before events start.',
    icon: Icons.notifications_active,
  ),
];

/// First-launch onboarding carousel.
///
/// Displays 2–3 screens explaining key features. Every screen includes a
/// "Skip" button so users can jump straight to the daily events view.
///
/// On the "Get Notified" page, tapping "Get Started" requests iOS notification
/// permissions before completing onboarding.
class OnboardingScreen extends StatefulWidget {
  /// The pages to display. Defaults to [defaultOnboardingPages].
  final List<OnboardingPage> pages;

  /// Called when the user finishes or skips onboarding.
  final VoidCallback onComplete;

  /// Service used to request iOS notification permissions.
  final NotificationDisplayService? notificationDisplayService;

  const OnboardingScreen({
    super.key,
    this.pages = defaultOnboardingPages,
    required this.onComplete,
    this.notificationDisplayService,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLastPage => _currentPage == widget.pages.length - 1;

  /// Whether the current page is the notification page.
  bool get _isNotificationPage {
    if (!_isLastPage) return false;
    final page = widget.pages[_currentPage];
    return page.title == 'Get Notified';
  }

  Future<void> _onNext() async {
    if (_isLastPage) {
      if (_isNotificationPage) {
        await widget.notificationDisplayService?.requestIOSPermission();
      }
      widget.onComplete();
    } else {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — always visible
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                key: const Key('onboarding_skip'),
                onPressed: widget.onComplete,
                child: const Text('Skip'),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.pages.length,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final page = widget.pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 80, color: theme.colorScheme.primary),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: theme.textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicator dots
            Semantics(
              label: 'Page ${_currentPage + 1} of ${widget.pages.length}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withAlpha(77),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onNext,
                  child: Text(_isLastPage ? 'Get Started' : 'Next'),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
