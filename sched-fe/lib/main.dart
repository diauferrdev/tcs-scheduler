import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'router.dart';
import 'services/unified_notification_service.dart';
import 'screens/animated_splash_screen.dart';

/// Check if Firebase is supported on current platform
/// Firebase is supported on: Android, iOS, web, macOS
/// NOT supported on: Windows, Linux
bool get _isFirebaseSupported {
  if (kIsWeb) return true;
  return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
}

/// Firebase Cloud Messaging background handler - MUST be top-level function
/// This runs in a separate isolate when FCM push arrives with app closed/terminated
/// The @pragma annotation ensures this function isn't tree-shaken by Dart AOT compiler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Only initialize Firebase on supported platforms
  if (_isFirebaseSupported) {
    // Initialize Firebase (required for background isolate)
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);


    // Note: UnifiedNotificationService handles showing the notification
    // when the app comes back to foreground
  }
}

/// Background notification handler - MUST be top-level function
/// This runs in a separate isolate when notifications arrive with app closed (Android/iOS/macOS)
/// The @pragma annotation ensures this function isn't tree-shaken by Dart AOT compiler
@pragma('vm:entry-point')
void notificationTapBackgroundHandler(NotificationResponse details) {
  // Navigation will be handled when app resumes to foreground
}

/// Request necessary permissions for the app
Future<void> _requestPermissions() async {
  try {
    // Request microphone permission for audio recording
    await Permission.microphone.request();

    // Request storage permission for file uploads/downloads
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
  } catch (e) { /* ignored: non-critical failure */ }
}

void main() {
  // Run inside a guarded zone so any uncaught async error is logged instead of
  // crashing the app — a last-resort safety net for store-review stability.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Framework + platform-level error handlers (sync build errors, engine errors).
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[PlatformError] $error');
      return true; // handled — do not crash the app
    };

  // Initialize Firebase ONLY on supported platforms (Android, iOS, web, macOS)
  // Windows and Linux desktop use local_notifier instead
  if (_isFirebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Setup Firebase Cloud Messaging background handler
    // This allows push notifications to arrive even when app is completely closed/terminated
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Initialize unified notification service with background handler support
  // On mobile (Android/iOS/macOS), the background handler allows notifications to work even when app is closed
  // On web, Service Worker handles background notifications
  // On desktop (Windows/Linux), local_notifier handles system tray notifications
  await UnifiedNotificationService().initialize(
    onBackgroundNotificationResponse: notificationTapBackgroundHandler,
  );

  // Request permissions for audio recording
  if (!kIsWeb) {
    await _requestPermissions();
  }

  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Start the app with splash screen
  runApp(const MyApp());
  }, (error, stack) {
    // Uncaught async errors from anywhere in the app land here.
    debugPrint('[Uncaught] $error');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> with WidgetsBindingObserver {
  late final GoRouter _router;
  bool _showSplash = false; // Splash animation disabled for now

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final authProvider = context.read<AuthProvider>();
    _router = createRouter(authProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On resume from background, silently re-validate the session (expired →
    // 401 → redirect to login) and let checkAuth reconnect realtime/WS.
    if (state == AppLifecycleState.resumed && mounted) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAuthenticated) {
        authProvider.checkAuth(silent: true);
      }
    }
  }

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final app = MaterialApp.router(
          title: 'Pace Scheduler | Enterprise Office Visit Scheduling System',
          debugShowCheckedModeBanner: false,
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: _router,
        );

        // Show animated splash screen on mobile only (web has its own splash)
        if (_showSplash) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: AnimatedSplashScreen(
              nextScreen: Container(), // Not used since we handle navigation ourselves
              onAnimationComplete: _onSplashComplete,
            ),
          );
        }

        return app;
      },
    );
  }
}
