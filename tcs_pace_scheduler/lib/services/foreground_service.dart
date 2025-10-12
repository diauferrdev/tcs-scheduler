import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'realtime_service.dart';

/// Foreground Service for Android
/// Keeps Colyseus WebSocket connection alive in background for instant notifications
class ForegroundNotificationService {
  static final ForegroundNotificationService _instance = ForegroundNotificationService._internal();
  factory ForegroundNotificationService() => _instance;
  ForegroundNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final RealtimeService _realtimeService = RealtimeService();

  bool _isRunning = false;
  Timer? _keepAliveTimer;

  static const String CHANNEL_ID = 'foreground_service';
  static const int NOTIFICATION_ID = 999999;

  /// Start foreground service with persistent notification
  Future<void> start() async {
    if (_isRunning) {
      debugPrint('[ForegroundService] Already running');
      return;
    }

    try {
      debugPrint('[ForegroundService] Starting foreground service...');

      // Only Android supports foreground services
      if (!kIsWeb && Platform.isAndroid) {
        // Create notification channel for foreground service
        await _createServiceChannel();

        // Show persistent notification (required for foreground service)
        await _showForegroundNotification();

        // Connect to Colyseus for real-time notifications
        debugPrint('[ForegroundService] Connecting to Colyseus...');
        await _realtimeService.connect();

        if (_realtimeService.isFullyConnected) {
          debugPrint('[ForegroundService] ✅ Colyseus connected');

          // Start keep-alive timer to maintain connection
          _startKeepAlive();

          _isRunning = true;
          debugPrint('[ForegroundService] ✅ Foreground service started');
        } else {
          debugPrint('[ForegroundService] ⚠️ Colyseus failed to connect');
          await _hideForegroundNotification();
        }
      }
    } catch (e) {
      debugPrint('[ForegroundService] Error starting: $e');
      await _hideForegroundNotification();
    }
  }

  /// Stop foreground service
  Future<void> stop() async {
    if (!_isRunning) {
      debugPrint('[ForegroundService] Not running');
      return;
    }

    debugPrint('[ForegroundService] Stopping foreground service...');

    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;

    await _realtimeService.disconnect();
    await _hideForegroundNotification();

    _isRunning = false;
    debugPrint('[ForegroundService] ✅ Foreground service stopped');
  }

  /// Create notification channel for foreground service
  Future<void> _createServiceChannel() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        CHANNEL_ID,
        'Background Service',
        description: 'Keeps app running in background for instant notifications',
        importance: Importance.low, // Low importance = no sound/vibration
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
  }

  /// Show persistent foreground notification
  Future<void> _showForegroundNotification() async {
    const androidDetails = AndroidNotificationDetails(
      CHANNEL_ID,
      'Background Service',
      channelDescription: 'Keeps app running in background for instant notifications',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      ongoing: true, // Makes notification persistent
      autoCancel: false,
      showWhen: false,
      // Use app icon (tcs_pace_scheduler) which already exists
      icon: '@mipmap/tcs_pace_scheduler',
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      NOTIFICATION_ID,
      'TCS Scheduler Active',
      'Receiving notifications in real-time',
      details,
    );

    debugPrint('[ForegroundService] Foreground notification shown');
  }

  /// Hide foreground notification
  Future<void> _hideForegroundNotification() async {
    await _notifications.cancel(NOTIFICATION_ID);
    debugPrint('[ForegroundService] Foreground notification hidden');
  }

  /// Keep-alive timer to maintain Colyseus connection
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();

    // Check connection every 30 seconds and reconnect if needed
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_realtimeService.isFullyConnected) {
        debugPrint('[ForegroundService] Colyseus disconnected, reconnecting...');
        await _realtimeService.connect();
      } else {
        debugPrint('[ForegroundService] Colyseus connection healthy');
      }
    });
  }

  bool get isRunning => _isRunning;
}
