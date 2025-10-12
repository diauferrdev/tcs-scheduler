import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';

/// Web implementation using HtmlWebSocketChannel
/// Note: Browser WebSocket connections automatically include cookies
Future<WebSocketChannel> createWebSocketChannel(String url, {Map<String, String>? headers}) async {
  // Headers are ignored on web - cookies are sent automatically by the browser
  return HtmlWebSocketChannel.connect(url);
}
