class ApiConfig {
  // Backend REST API URL
  // PRODUCTION: Change to your domain before building
  // Development: Use ngrok or localhost
  static const String baseUrl =
      String.fromEnvironment('API_URL',
        defaultValue: 'https://diplostemonous-merri-hermitically.ngrok-free.dev');
      // PRODUCTION EXAMPLE: defaultValue: 'https://api.seu-dominio.com'

  // Colyseus WebSocket Server URL (Not used currently - using native WebSocket)
  static const String colyseusUrl =
      String.fromEnvironment('COLYSEUS_URL',
        defaultValue: 'https://shingly-adulatingly-lakia.ngrok-free.dev');

  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };
}
