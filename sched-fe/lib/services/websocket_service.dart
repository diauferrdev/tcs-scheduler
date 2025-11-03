import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;
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
  int _reconnectAttempts = 0;
  String? _userId;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  Stream<Map<String, dynamic>> get messages => _messageController!.stream;
  bool get isConnected => _channel != null;

  void connect(String userId) async {
    _userId = userId;

    if (_isConnecting) {
      return;
    }

    if (_channel != null) {
      return;
    }

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
          } catch (e) {
          }
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

    // Attempt reconnection if we have a userId
    if (_userId != null && _reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        if (_userId != null) {
          connect(_userId!);
        }
      });
    } else {
    }
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
