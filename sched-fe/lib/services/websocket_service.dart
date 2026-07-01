import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../config/api_config.dart';
import 'token_storage.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isConnecting = false;
  bool _manualDisconnect = false;
  int _reconnectAttempts = 0;
  String? _userId;
  static const Duration _reconnectBaseDelay = Duration(seconds: 3);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  Stream<Map<String, dynamic>> get messages => _messageController!.stream;
  bool get isConnected => _channel != null;

  void connect(String userId) async {
    _manualDisconnect = false;

    if (_isConnecting) {
      return;
    }

    // If already connected but for a different user, tear down the stale
    // connection first so we don't leak messages across accounts.
    if (_channel != null && _userId != null && _userId != userId) {
      disconnect();
      // disconnect() flips _manualDisconnect to true; clear it again since
      // we are about to open a fresh connection right below.
      _manualDisconnect = false;
    } else if (_channel != null) {
      _userId = userId;
      return;
    }

    _userId = userId;
    _isConnecting = true;
    _messageController ??= StreamController<Map<String, dynamic>>.broadcast();

    // Get auth token
    final tokenStorage = TokenStorage();
    final token = await tokenStorage.readToken();

    if (token == null) {
      _isConnecting = false;
      return;
    }

    // Convert http/https to ws/wss
    var wsUrl = ApiConfig.baseUrl;

    // Ensure we're using the correct protocol
    if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    }

    // Add token as query parameter for web, headers for mobile
    final uri = kIsWeb
        ? Uri.parse('$wsUrl/ws?userId=$userId&token=$token')
        : Uri.parse('$wsUrl/ws?userId=$userId');

    // Prepare headers with auth token (mobile only)
    final headers = {
      'Authorization': 'Bearer $token',
      'Cookie': 'auth_session=$token',
    };

    // Use native dart:io WebSocket on mobile for better compatibility
    // Use web_socket_channel on web
    if (kIsWeb) {
      try {
        _channel = WebSocketChannel.connect(
          uri,
          protocols: ['websocket'],
        );
        _setupConnection();
      } catch (e) {
        _isConnecting = false;
        _handleDisconnect();
      }
    } else {
      // Mobile: Use native dart:io WebSocket with auth headers
      WebSocket.connect(
        uri.toString(),
        headers: headers,
        protocols: ['websocket'],
      ).then((socket) {
        _channel = IOWebSocketChannel(socket);
        _setupConnection();
      }).catchError((e) {
        _isConnecting = false;
        _handleDisconnect();
      });
    }
  }

  void _setupConnection() {
    try {
      // Connection successfully opened - reset backoff counter
      _reconnectAttempts = 0;

      // Start heartbeat
      _startHeartbeat();

      // Listen to messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message as String) as Map<String, dynamic>;
            final type = data['type'] as String?;

            if (type != 'pong') {
              _messageController!.add(data);
            }

            _reconnectAttempts = 0; // Reset on successful message
          } catch (e) { /* ignored: non-critical failure */ }
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );

      _isConnecting = false;
    } catch (e) {
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_channel != null) {
        try {
          sendMessage({'type': 'ping'});
        } catch (e) {
          _handleDisconnect();
        }
      }
    });
  }

  void _handleDisconnect() {
    _channel = null;
    _isConnecting = false;
    _heartbeatTimer?.cancel();

    // Do not reconnect after an explicit/manual disconnect (e.g. logout)
    if (_manualDisconnect) {
      return;
    }

    // Attempt reconnection if we have a userId. Keep retrying indefinitely
    // while foregrounded, spaced out by exponential backoff capped at 30s.
    if (_userId != null) {
      final delay = _nextReconnectDelay();
      _reconnectAttempts++;

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () {
        if (_userId != null && !_manualDisconnect) {
          connect(_userId!);
        }
      });
    }
  }

  /// Exponential backoff with jitter, capped at [_maxReconnectDelay].
  Duration _nextReconnectDelay() {
    final exponentialMs =
        _reconnectBaseDelay.inMilliseconds * pow(2, _reconnectAttempts).toInt();
    final cappedMs = min(exponentialMs, _maxReconnectDelay.inMilliseconds);
    final jitterMs = Random().nextInt(1000);
    return Duration(milliseconds: cappedMs + jitterMs);
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(json.encode(message));
    } else {
    }
  }

  /// Mark ticket messages as read via WebSocket (real-time)
  void markTicketAsRead(String ticketId) {
    sendMessage({
      'type': 'mark_as_read',
      'ticketId': ticketId,
    });
  }

  /// Send typing indicator for ticket
  void sendTypingIndicator(String ticketId, bool isTyping) {
    sendMessage({
      'type': 'typing',
      'ticketId': ticketId,
      'isTyping': isTyping,
    });
  }

  void sendRecordingIndicator(String ticketId, bool isRecording) {
    sendMessage({
      'type': 'recording',
      'ticketId': ticketId,
      'isRecording': isRecording,
    });
  }

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnecting = false;
    _reconnectAttempts = 0;
  }

  void dispose() {
    disconnect();
    _messageController?.close();
    _messageController = null;
  }
}
