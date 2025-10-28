import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import 'api_service.dart';

/// RealtimeService - Native WebSocket client
/// Connects to backend WebSocket server at port 7777/ws for real-time updates
class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final ApiService _apiService = ApiService();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // Callbacks for UnifiedNotificationService
  Function(Map<String, dynamic>)? onNewNotification;
  Function(int)? onUnreadCountUpdated;
  Function(Map<String, dynamic>)? onNotificationSync;
  Function(List<dynamic>)? onUnreadNotifications;
  Function()? onNotificationConnected;
  Function()? onNotificationDisconnected;

  // Multiple listeners for booking events (support multiple screens)
  final List<Function(Map<String, dynamic>)> _onBookingCreatedListeners = [];
  final List<Function(Map<String, dynamic>)> _onBookingUpdatedListeners = [];
  final List<Function(String)> _onBookingDeletedListeners = [];
  final List<Function(Map<String, dynamic>)> _onBookingApprovedListeners = [];

  // Legacy single callbacks for backward compatibility
  Function(Map<String, dynamic>)? onBookingCreated;
  Function(Map<String, dynamic>)? onBookingUpdated;
  Function(String)? onBookingDeleted;
  Function(Map<String, dynamic>)? onBookingApproved;
  Function(Map<String, dynamic>)? onCalendarSync;
  Function()? onCalendarConnected;
  Function()? onCalendarDisconnected;

  // Methods to add/remove listeners
  void addBookingCreatedListener(Function(Map<String, dynamic>) listener) {
    if (!_onBookingCreatedListeners.contains(listener)) {
      _onBookingCreatedListeners.add(listener);
    }
  }

  void addBookingUpdatedListener(Function(Map<String, dynamic>) listener) {
    if (!_onBookingUpdatedListeners.contains(listener)) {
      _onBookingUpdatedListeners.add(listener);
    }
  }

  void addBookingDeletedListener(Function(String) listener) {
    if (!_onBookingDeletedListeners.contains(listener)) {
      _onBookingDeletedListeners.add(listener);
    }
  }

  void addBookingApprovedListener(Function(Map<String, dynamic>) listener) {
    if (!_onBookingApprovedListeners.contains(listener)) {
      _onBookingApprovedListeners.add(listener);
    }
  }

  void removeBookingCreatedListener(Function(Map<String, dynamic>) listener) {
    _onBookingCreatedListeners.remove(listener);
  }

  void removeBookingUpdatedListener(Function(Map<String, dynamic>) listener) {
    _onBookingUpdatedListeners.remove(listener);
  }

  void removeBookingDeletedListener(Function(String) listener) {
    _onBookingDeletedListeners.remove(listener);
  }

  void removeBookingApprovedListener(Function(Map<String, dynamic>) listener) {
    _onBookingApprovedListeners.remove(listener);
  }

  bool get isNotificationConnected => _isConnected;
  bool get isCalendarConnected => _isConnected;
  bool get isFullyConnected => _isConnected;

  String _getWebSocketUrl() {
    final uri = Uri.parse(ApiConfig.baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';

    // Get host and port from base URL
    final host = uri.host;
    final port = uri.port;

    // For localhost, use explicit port
    if (host == 'localhost' || host == '127.0.0.1') {
      return '$scheme://$host:7777/ws';
    }

    // For ngrok/production, use host as-is (ngrok handles port mapping)
    if (port != 0 && port != 80 && port != 443) {
      return '$scheme://$host:$port/ws';
    }

    return '$scheme://$host/ws';
  }

  /// Connect to WebSocket with authentication
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      debugPrint('[Realtime] 1. Connecting WebSocket (${kIsWeb ? "Web" : "Mobile"})...');

      String wsUrl;

      if (kIsWeb) {
        // Web: Browser manages cookies automatically
        wsUrl = _getWebSocketUrl();
      } else {
        // Mobile: Extract session and add to URL
        await _apiService.initialize();
        String? sessionCookie = _apiService.getSessionCookie();

        if (sessionCookie == null) {
          await Future.delayed(const Duration(milliseconds: 100));
          sessionCookie = _apiService.getSessionCookie();
        }

        if (sessionCookie == null) {
          debugPrint('[Realtime] ❌ No session cookie, retrying in 5s');
          _scheduleReconnect();
          return;
        }

        // Extract session ID from cookie
        String? sessionId;
        if (sessionCookie.contains('auth_session=')) {
          final parts = sessionCookie.split(';');
          for (final part in parts) {
            if (part.trim().startsWith('auth_session=')) {
              sessionId = part.trim().substring('auth_session='.length);
              break;
            }
          }
        }

        if (sessionId == null) {
          debugPrint('[Realtime] ❌ Could not extract session ID');
          _scheduleReconnect();
          return;
        }

        final wsBaseUrl = _getWebSocketUrl();
        wsUrl = '$wsBaseUrl?sessionId=$sessionId';
      }

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('[Realtime] ❌ Error: $error');
          _handleDisconnection();
        },
        onDone: _handleDisconnection,
        cancelOnError: false,
      );

      _isConnected = true;
      debugPrint('[Realtime] 2. ✅ Connected successfully');

      _startPingTimer();
      onNotificationConnected?.call();
      onCalendarConnected?.call();
    } catch (e) {
      debugPrint('[Realtime] ❌ Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic rawMessage) {
    try {
      final message = rawMessage is String ? jsonDecode(rawMessage) : rawMessage;

      if (message is! Map<String, dynamic>) return;

      final type = message['type'] as String?;
      final data = message['data'];

      switch (type) {
        case 'connected':
          debugPrint('[Realtime] 3. ✅ Server confirmed connection');
          break;

        case 'pong':
          // Keep-alive response
          break;

        case 'notification':
          if (data is Map<String, dynamic>) {
            onNewNotification?.call(data);
          }
          break;

        case 'booking_created':
          debugPrint('[Realtime] 📩 New booking created');
          if (data is Map<String, dynamic> && data['booking'] != null) {
            final booking = data['booking'] as Map<String, dynamic>;
            for (final listener in _onBookingCreatedListeners) {
              listener(booking);
            }
            onBookingCreated?.call(booking);
          }
          break;

        case 'booking_updated':
          debugPrint('[Realtime] 📩 Booking updated');
          if (data is Map<String, dynamic> && data['booking'] != null) {
            final booking = data['booking'] as Map<String, dynamic>;
            for (final listener in _onBookingUpdatedListeners) {
              listener(booking);
            }
            onBookingUpdated?.call(booking);
          }
          break;

        case 'booking_deleted':
          debugPrint('[Realtime] 📩 Booking deleted');
          if (data is Map<String, dynamic> && data['bookingId'] != null) {
            final bookingId = data['bookingId'] as String;
            for (final listener in _onBookingDeletedListeners) {
              listener(bookingId);
            }
            onBookingDeleted?.call(bookingId);
          }
          break;

        case 'booking_approved':
          debugPrint('[Realtime] 📩 Booking approved');
          if (data is Map<String, dynamic> && data['booking'] != null) {
            final booking = data['booking'] as Map<String, dynamic>;
            for (final listener in _onBookingApprovedListeners) {
              listener(booking);
            }
            onBookingApproved?.call(booking);
          }
          break;
      }
    } catch (e) {
      debugPrint('[Realtime] ❌ Message error: $e');
    }
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _sendPing();
      }
    });
  }

  /// Send ping to server
  void _sendPing() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    } catch (e) {
      debugPrint('[Realtime] ❌ Ping error: $e');
    }
  }

  /// Handle disconnection
  void _handleDisconnection() {
    _isConnected = false;
    _pingTimer?.cancel();

    onNotificationDisconnected?.call();
    onCalendarDisconnected?.call();

    _scheduleReconnect();
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) connect();
    });
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _isConnected = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  /// Send custom message to server
  void sendMessage(String type, Map<String, dynamic> data) {
    if (!_isConnected) return;

    try {
      _channel?.sink.add(jsonEncode({
        'type': type,
        'data': data,
      }));
    } catch (e) {
      debugPrint('[Realtime] ❌ Send error: $e');
    }
  }
}
