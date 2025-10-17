import 'dart:io' show WebSocket;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Native (mobile/desktop) implementation using IOWebSocketChannel
/// Supports custom headers for authentication
Future<WebSocketChannel> createWebSocketChannel(String url, {Map<String, String>? headers}) async {
  final ws = await WebSocket.connect(url, headers: headers);
  return IOWebSocketChannel(ws);
}
