import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/unified_notification_service.dart';
import '../utils/web_helper.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
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

      await _apiService.initialize();

      final response = await _apiService.get('/api/auth/me');
      _user = User.fromJson(response['user'] as Map<String, dynamic>);

      // If user is already logged in, request permissions and connect WebSocket
      try {
        await UnifiedNotificationService().requestPermissionsAfterLogin();
      } catch (e) {
        debugPrint('[Auth] ❌ Permission error: $e');
      }
    } catch (e) {
      _user = null;
      _apiService.setSessionCookie(null);
    } finally {
      _loading = false;
      notifyListeners();
      _signalAppReady();
    }
  }

  /// Signal to web platform that app is ready (removes splash screen)
  void _signalAppReady() {
    if (!kIsWeb) return;

    try {
      Future.delayed(const Duration(milliseconds: 300), () {
        WebHelper.signalAppReady();
      });
    } catch (e) {
      debugPrint('[Auth] ❌ App ready signal error: $e');
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiService.post('/api/auth/login', {
        'email': email,
        'password': password,
      });

      _user = User.fromJson(response['user'] as Map<String, dynamic>);

      // Extract cookie from response body (fallback for proxies like ngrok)
      if (response['sessionCookie'] != null) {
        final sessionCookie = response['sessionCookie'] as Map<String, dynamic>;
        final cookieName = sessionCookie['name'] as String;
        final cookieValue = sessionCookie['value'] as String;
        final fullCookie = '$cookieName=$cookieValue';
        await _apiService.setSessionCookie(fullCookie);
      }

      // Request notification permissions after successful login
      try {
        await UnifiedNotificationService().requestPermissionsAfterLogin();
      } catch (e) {
        debugPrint('[Auth] ❌ Notification permission error: $e');
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
      _apiService.setSessionCookie(null);

      try {
        await UnifiedNotificationService().disconnectWebSocket();
      } catch (e) {
        debugPrint('[Auth] ❌ Disconnect error: $e');
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
