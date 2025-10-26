class ApiConfig {
  // Backend REST API URL
  // PRODUCTION: ppspsched.lat domain
  static const String baseUrl =
      String.fromEnvironment('API_URL',
        defaultValue: 'https://api.ppspsched.lat');

  // Colyseus WebSocket Server URL (Not used currently - using native WebSocket)
  static const String colyseusUrl =
      String.fromEnvironment('COLYSEUS_URL',
        defaultValue: 'https://api.ppspsched.lat');

  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
      };
}
