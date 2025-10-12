import 'package:http/http.dart' as http;

/// HTTP client configured for mobile/desktop
class HttpConfig {
  static http.Client createClient() {
    // For mobile/desktop, use default client
    return http.Client();
  }
}
