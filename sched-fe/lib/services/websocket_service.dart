import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket, Platform;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../config/api_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  String? _userId;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  Stream<Map<String, dynamic>> get messages => _messageController!.stream;
  bool get isConnected => _channel != null;

  void connect(String userId) {
    _userId = userId;

    if (_isConnecting) {
      debugPrint('[WS] Already connecting, skipping...');
      return;
    }

    if (_channel != null) {
      debugPrint('[WS] Already connected, skipping...');
      return;
    }

    _isConnecting = true;
    _messageController ??= StreamController<Map<String, dynamic>>.broadcast();

    // Convert http/https to ws/wss
    var wsUrl = ApiConfig.baseUrl;

    // Ensure we're using the correct protocol
    if (wsUrl.startsWith('https://')) {
      wsUrl = wsUrl.replaceFirst('https://', 'wss://');
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = wsUrl.replaceFirst('http://', 'ws://');
    }

    final uri = Uri.parse('$wsUrl/ws?userId=$userId');
    debugPrint('[WS] Connecting to: $uri (platform: ${kIsWeb ? "web" : "mobile"})');

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
        debugPrint('[WS] ❌ Connection error: $e');
        _isConnecting = false;
        _handleDisconnect();
      }
    } else {
      // Mobile: Use native dart:io WebSocket
      debugPrint('[WS] Using native dart:io WebSocket for mobile');
      WebSocket.connect(
        uri.toString(),
        protocols: ['websocket'],
      ).then((socket) {
        _channel = IOWebSocketChannel(socket);
        _setupConnection();
      }).catchError((e) {
        debugPrint('[WS] ❌ Connection error: $e');
        _isConnecting = false;
        _handleDisconnect();
      });
    }
  }

  void _setupConnection() {
    try {
      // Start heartbeat
      _startHeartbeat();

      // Listen to messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message as String) as Map<String, dynamic>;
            final type = data['type'] as String?;
            debugPrint('[WS] ✅ Received: $type');

            if (type != 'pong') {
              _messageController!.add(data);
            }

            _reconnectAttempts = 0; // Reset on successful message
          } catch (e) {
            debugPrint('[WS] ❌ Error decoding message: $e');
          }
        },
        onError: (error) {
          debugPrint('[WS] ❌ Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[WS] Connection closed');
          _handleDisconnect();
        },
      );

      _isConnecting = false;
      debugPrint('[WS] ✅ Connected successfully');
    } catch (e) {
      debugPrint('[WS] ❌ Setup error: $e');
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
          debugPrint('[WS] 💓 Sent heartbeat');
        } catch (e) {
          debugPrint('[WS] ❌ Heartbeat failed: $e');
          _handleDisconnect();
        }
      }
    });
  }

  void _handleDisconnect() {
    _channel = null;
    _isConnecting = false;
    _heartbeatTimer?.cancel();

    // Attempt reconnection if we have a userId
    if (_userId != null && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      debugPrint('[WS] 🔄 Reconnecting in ${_reconnectDelay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        debugPrint('[WS] Attempting reconnect...');
        if (_userId != null) {
          connect(_userId!);
        }
      });
    } else {
      debugPrint('[WS] ❌ Max reconnect attempts reached or no userId');
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(json.encode(message));
    } else {
      debugPrint('[WS] Cannot send message: not connected');
    }
  }

  /// Mark ticket messages as read via WebSocket (real-time)
  void markTicketAsRead(String ticketId) {
    debugPrint('[WS] 📖 Sending mark_as_read for ticket: $ticketId');
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
    debugPrint('[WS] Disconnecting...');
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
