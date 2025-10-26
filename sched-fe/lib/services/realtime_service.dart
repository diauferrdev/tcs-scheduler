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
      debugPrint('[RealtimeService] Added booking created listener (total: ${_onBookingCreatedListeners.length})');
    }
  }

  void addBookingUpdatedListener(Function(Map<String, dynamic>) listener) {
    if (!_onBookingUpdatedListeners.contains(listener)) {
      _onBookingUpdatedListeners.add(listener);
      debugPrint('[RealtimeService] Added booking updated listener (total: ${_onBookingUpdatedListeners.length})');
    }
  }

  void addBookingDeletedListener(Function(String) listener) {
    if (!_onBookingDeletedListeners.contains(listener)) {
      _onBookingDeletedListeners.add(listener);
      debugPrint('[RealtimeService] Added booking deleted listener (total: ${_onBookingDeletedListeners.length})');
    }
  }

  void addBookingApprovedListener(Function(Map<String, dynamic>) listener) {
    if (!_onBookingApprovedListeners.contains(listener)) {
      _onBookingApprovedListeners.add(listener);
      debugPrint('[RealtimeService] Added booking approved listener (total: ${_onBookingApprovedListeners.length})');
    }
  }

  void removeBookingCreatedListener(Function(Map<String, dynamic>) listener) {
    _onBookingCreatedListeners.remove(listener);
    debugPrint('[RealtimeService] Removed booking created listener (total: ${_onBookingCreatedListeners.length})');
  }

  void removeBookingUpdatedListener(Function(Map<String, dynamic>) listener) {
    _onBookingUpdatedListeners.remove(listener);
    debugPrint('[RealtimeService] Removed booking updated listener (total: ${_onBookingUpdatedListeners.length})');
  }

  void removeBookingDeletedListener(Function(String) listener) {
    _onBookingDeletedListeners.remove(listener);
    debugPrint('[RealtimeService] Removed booking deleted listener (total: ${_onBookingDeletedListeners.length})');
  }

  void removeBookingApprovedListener(Function(Map<String, dynamic>) listener) {
    _onBookingApprovedListeners.remove(listener);
    debugPrint('[RealtimeService] Removed booking approved listener (total: ${_onBookingApprovedListeners.length})');
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
    if (_isConnected) {
      debugPrint('[RealtimeService] Already connected');
      return;
    }

    try {
      // IMPORTANT: Initialize ApiService first to load session cookie from storage
      await _apiService.initialize();

      final sessionCookie = _apiService.getSessionCookie();
      if (sessionCookie == null) {
        debugPrint('[RealtimeService] No session cookie, cannot connect');
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
        debugPrint('[RealtimeService] Could not extract session ID from cookie');
        return;
      }

      // Add session ID as query parameter for authentication
      final wsBaseUrl = _getWebSocketUrl();
      final wsUrl = '$wsBaseUrl?sessionId=$sessionId';
      debugPrint('[RealtimeService] Connecting to: $wsBaseUrl?sessionId=***');

      // Connect to WebSocket
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      // Wait for connection
      await _channel!.ready;

      // Listen for messages
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          debugPrint('[RealtimeService] WebSocket error: $error');
          _handleDisconnection();
        },
        onDone: () {
          debugPrint('[RealtimeService] WebSocket disconnected');
          _handleDisconnection();
        },
      );

      _isConnected = true;
      debugPrint('[RealtimeService] ✅ Connected to native WebSocket');

      // Start ping/pong to keep connection alive
      _startPingTimer();

      // Notify listeners
      onNotificationConnected?.call();
      onCalendarConnected?.call();
    } catch (e) {
      debugPrint('[RealtimeService] Failed to connect: $e');
      _scheduleReconnect();
    }
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic rawMessage) {
    try {
      final message = rawMessage is String ? jsonDecode(rawMessage) : rawMessage;

      if (message is! Map<String, dynamic>) {
        debugPrint('[RealtimeService] Invalid message format: $message');
        return;
      }

      final type = message['type'] as String?;
      final data = message['data'];

      debugPrint('[RealtimeService] Received: $type');

      switch (type) {
        case 'connected':
          debugPrint('[RealtimeService] ✅ Server confirmed connection: $data');
          break;

        case 'pong':
          // Ping/pong response - connection alive
          break;

        case 'notification':
          if (data is Map<String, dynamic>) {
            onNewNotification?.call(data);
          }
          break;

        case 'booking_created':
          if (data is Map<String, dynamic> && data['booking'] != null) {
            final booking = data['booking'] as Map<String, dynamic>;
            // Notify all listeners
            for (final listener in _onBookingCreatedListeners) {
              listener(booking);
            }
            // Legacy single callback
            onBookingCreated?.call(booking);
          }
          break;

        case 'booking_updated':
          if (data is Map<String, dynamic> && data['booking'] != null) {
            final booking = data['booking'] as Map<String, dynamic>;
            // Notify all listeners
            for (final listener in _onBookingUpdatedListeners) {
              listener(booking);
            }
            // Legacy single callback
            onBookingUpdated?.call(booking);
          }
          break;

        case 'booking_deleted':
          if (data is Map<String, dynamic> && data['bookingId'] != null) {
            final bookingId = data['bookingId'] as String;
            // Notify all listeners
            for (final listener in _onBookingDeletedListeners) {
              listener(bookingId);
            }
            // Legacy single callback
            onBookingDeleted?.call(bookingId);
          }
          break;

        case 'booking_approved':
          if (data is Map<String, dynamic> && data['booking'] != null) {
            final booking = data['booking'] as Map<String, dynamic>;
            // Notify all listeners
            for (final listener in _onBookingApprovedListeners) {
              listener(booking);
            }
            // Legacy single callback
            onBookingApproved?.call(booking);
          }
          break;

        default:
          debugPrint('[RealtimeService] Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('[RealtimeService] Error handling message: $e');
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
      debugPrint('[RealtimeService] Error sending ping: $e');
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
      if (!_isConnected) {
        debugPrint('[RealtimeService] Attempting to reconnect...');
        connect();
      }
    });
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    debugPrint('[RealtimeService] Disconnecting...');

    _isConnected = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    await _channel?.sink.close();
    _channel = null;

    debugPrint('[RealtimeService] Disconnected');
  }

  /// Send custom message to server
  void sendMessage(String type, Map<String, dynamic> data) {
    if (!_isConnected) {
      debugPrint('[RealtimeService] Not connected, cannot send message');
      return;
    }

    try {
      _channel?.sink.add(jsonEncode({
        'type': type,
        'data': data,
      }));
    } catch (e) {
      debugPrint('[RealtimeService] Error sending message: $e');
    }
  }
}
