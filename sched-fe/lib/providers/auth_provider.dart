import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';
import '../services/unified_notification_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final TokenStorage _tokenStorage = TokenStorage();
  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      _loading = true;
      notifyListeners();

      // ApiService will automatically load session cookie from TokenStorage
      await _apiService.initialize();

      final response = await _apiService.get('/api/auth/me');
      _user = User.fromJson(response['user'] as Map<String, dynamic>);

      // If user is already logged in, request permissions (but don't connect WebSocket)
      // WebSocket disabled on mobile due to ngrok limitations
      try {
        debugPrint('[AuthProvider] User authenticated, requesting permissions');
        await UnifiedNotificationService().requestPermissionsAfterLogin();
        debugPrint('[AuthProvider] Permission request complete');
      } catch (e) {
        debugPrint('[AuthProvider] Error requesting permissions: $e');
        // Don't fail auth check if permission request fails
      }
    } catch (e) {
      _user = null;
      _apiService.setSessionCookie(null);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiService.post('/api/auth/login', {
        'email': email,
        'password': password,
      });

      _user = User.fromJson(response['user'] as Map<String, dynamic>);

      // IMPORTANT: Extract cookie from response body as fallback
      // This handles cases where Set-Cookie header is stripped by proxies (like ngrok)
      if (response['sessionCookie'] != null) {
        final sessionCookie = response['sessionCookie'] as Map<String, dynamic>;
        final cookieName = sessionCookie['name'] as String;
        final cookieValue = sessionCookie['value'] as String;
        final fullCookie = '$cookieName=$cookieValue';
        await _apiService.setSessionCookie(fullCookie);
      }

      // Request notification permissions after successful login
      try {
        debugPrint('[AuthProvider] Requesting notification permissions after login');
        await UnifiedNotificationService().requestPermissionsAfterLogin();
        debugPrint('[AuthProvider] Notification permissions request complete');
      } catch (e) {
        debugPrint('[AuthProvider] Error requesting notification permissions: $e');
        // Don't fail login if permission request fails
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.post('/api/auth/logout', {});
    } catch (e) {
      // Ignore logout errors
    } finally {
      _user = null;
      _apiService.setSessionCookie(null); // This will also clear from TokenStorage

      // Clear notification badge on logout
      try {
        debugPrint('[AuthProvider] Clearing notifications on logout');
        await UnifiedNotificationService().disconnectWebSocket();
      } catch (e) {
        debugPrint('[AuthProvider] Error clearing notifications: $e');
      }

      notifyListeners();
    }
  }

  /// Update user data (used after profile update)
  void updateUser(Map<String, dynamic> userData) {
    _user = User.fromJson(userData);
    notifyListeners();
  }
}
