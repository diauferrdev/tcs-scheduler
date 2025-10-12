import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

/// HTTP client configured for web with credentials support
class HttpConfig {
  static http.Client createClient() {
    // For web, use BrowserClient with credentials
    final client = BrowserClient();
    client.withCredentials = true;
    return client;
  }
}
