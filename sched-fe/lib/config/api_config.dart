class ApiConfig {
  // ============================================================
  // CHANGE THIS TO SWITCH BETWEEN DEV AND PROD
  // ============================================================
  static const bool isDev = false;
  // ============================================================

  static const String _devUrl = 'http://localhost:8778';
  static const String _prodUrl = 'https://api.pacesched.com';

  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: isDev ? _devUrl : _prodUrl);

  static const String colyseusUrl =
      String.fromEnvironment('COLYSEUS_URL', defaultValue: isDev ? _devUrl : _prodUrl);

  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
      };
}
