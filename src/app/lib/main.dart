import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'providers/events_provider.dart';
import 'services/notification_display_service.dart';
import 'services/notification_navigation_service.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp();

  final notificationDisplay = NotificationDisplayService();
  await notificationDisplay.init();

  runApp(ProviderScope(
    child: GoCalGoApp(notificationDisplay: notificationDisplay),
  ));
}

class GoCalGoApp extends ConsumerStatefulWidget {
  const GoCalGoApp({required this.notificationDisplay, super.key});

  final NotificationDisplayService notificationDisplay;

  @override
  ConsumerState<GoCalGoApp> createState() => _GoCalGoAppState();
}

class _GoCalGoAppState extends ConsumerState<GoCalGoApp> {
  NotificationNavigationService? _navigationService;

  @override
  void initState() {
    super.initState();
    _initNavigationService();
  }

  Future<void> _initNavigationService() async {
    final router = ref.read(routerProvider);
    final eventsService = ref.read(cachedEventsServiceProvider);

    final navigationService = NotificationNavigationService(
      messaging: FirebaseMessaging.instance,
      eventsService: eventsService,
      router: router,
    );

    // Wire foreground local notification taps to navigate via the event cache.
    widget.notificationDisplay.onNotificationTap = (payload) async {
      if (payload == null) return;
      try {
        final response = await eventsService.getEvents();
        final event = response.events.cast().firstWhere(
              (e) => e.id == payload,
              orElse: () => null,
            );
        if (event != null) {
          router.push('/event/$payload', extra: event);
        }
      } on Exception {
        // Event not found in cache — silently ignore.
      }
    };

    await navigationService.init();
    _navigationService = navigationService;
    FlutterNativeSplash.remove();
  }

  @override
  void dispose() {
    _navigationService?.dispose();
    widget.notificationDisplay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'GoCalGo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
