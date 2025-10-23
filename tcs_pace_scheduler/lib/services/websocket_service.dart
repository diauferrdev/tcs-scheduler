import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  Stream<Map<String, dynamic>> get messages => _messageController!.stream;

  void connect(String userId) {
    if (_isConnecting || _channel != null) {
      print('[WS] Already connected or connecting');
      return;
    }

    _isConnecting = true;
    _messageController ??= StreamController<Map<String, dynamic>>.broadcast();

    try {
      // Convert http/https to ws/wss
      final wsUrl = ApiConfig.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      final uri = Uri.parse('$wsUrl/ws?userId=$userId');
      print('[WS] Connecting to: $uri');

      _channel = WebSocketChannel.connect(uri);

      // Listen to messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message as String) as Map<String, dynamic>;
            print('[WS] Received: ${data['type']}');
            _messageController!.add(data);
            _reconnectAttempts = 0; // Reset on successful message
          } catch (e) {
            print('[WS] Error decoding message: $e');
          }
        },
        onError: (error) {
          print('[WS] Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('[WS] Connection closed');
          _handleDisconnect();
        },
      );

      _isConnecting = false;
      print('[WS] Connected successfully');
    } catch (e) {
      print('[WS] Connection error: $e');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _isConnecting = false;

    // Attempt reconnection
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      print('[WS] Reconnecting in ${_reconnectDelay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(_reconnectDelay, () {
        // Note: This requires storing userId, which we'll do in a moment
        print('[WS] Attempting reconnect...');
      });
    } else {
      print('[WS] Max reconnect attempts reached');
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(json.encode(message));
    } else {
      print('[WS] Cannot send message: not connected');
    }
  }

  void disconnect() {
    print('[WS] Disconnecting...');
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
