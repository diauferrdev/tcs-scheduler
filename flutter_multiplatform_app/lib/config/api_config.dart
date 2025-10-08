class ApiConfig {
  static const String baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'https://diplostemonous-merri-hermitically.ngrok-free.dev');

  static const Duration timeout = Duration(seconds: 30);

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };
}
