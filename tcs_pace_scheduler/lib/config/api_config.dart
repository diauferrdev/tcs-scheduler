class ApiConfig {
  // Backend REST API URL
  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'https://diplostemonous-merri-hermitically.ngrok-free.dev');

  // Colyseus WebSocket Server URL
  static const String colyseusUrl =
      String.fromEnvironment('COLYSEUS_URL', defaultValue: 'https://shingly-adulatingly-lakia.ngrok-free.dev');

  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };
}
