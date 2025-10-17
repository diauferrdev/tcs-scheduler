import 'package:web_socket_channel/web_socket_channel.dart';

/// Stub implementation - should never be called
/// The conditional exports will use either web or io implementation
Future<WebSocketChannel> createWebSocketChannel(String url, {Map<String, String>? headers}) async {
  throw UnsupportedError('WebSocket not supported on this platform');
}
