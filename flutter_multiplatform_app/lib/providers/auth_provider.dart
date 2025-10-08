import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

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

      // Try to restore session from storage
      final prefs = await SharedPreferences.getInstance();
      final sessionCookie = prefs.getString('session_cookie');

      if (sessionCookie != null) {
        _apiService.setSessionCookie(sessionCookie);
      }

      final response = await _apiService.get('/api/auth/me');
      _user = User.fromJson(response['user'] as Map<String, dynamic>);

      debugPrint('[Auth] Authentication successful: ${_user?.email}');
    } catch (e) {
      debugPrint('[Auth] Authentication failed: $e');
      _user = null;
      _apiService.setSessionCookie(null);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_cookie');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      debugPrint('[Auth] Login attempt: $email');

      final response = await _apiService.post('/api/auth/login', {
        'email': email,
        'password': password,
      });

      _user = User.fromJson(response['user'] as Map<String, dynamic>);

      // Save session cookie
      final sessionCookie = _apiService.getSessionCookie();
      if (sessionCookie != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_cookie', sessionCookie);
      }

      debugPrint('[Auth] Login successful: ${_user?.email}');
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] Login failed: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.post('/api/auth/logout', {});
    } catch (e) {
      debugPrint('[Auth] Logout error: $e');
    } finally {
      _user = null;
      _apiService.setSessionCookie(null);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_cookie');

      notifyListeners();
    }
  }
}
