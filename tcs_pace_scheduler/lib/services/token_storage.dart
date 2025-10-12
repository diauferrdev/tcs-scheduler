import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token storage service that adapts to the platform:
/// - Web: Uses SharedPreferences (localStorage)
/// - Mobile/Desktop: Uses FlutterSecureStorage (Keychain/Keystore)
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  final _secure = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _sessionCookieKey = 'session_cookie';

  /// Save authentication token
  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      _log('[TokenStorage] Token saved to localStorage (web)');
    } else {
      await _secure.write(key: _tokenKey, value: token);
      _log('[TokenStorage] Token saved to secure storage (mobile/desktop)');
    }
  }

  /// Read authentication token
  Future<String?> readToken() async {
    String? token;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(_tokenKey);
      _log('[TokenStorage] Token read from localStorage (web): ${token != null ? "found" : "not found"}');
    } else {
      token = await _secure.read(key: _tokenKey);
      _log('[TokenStorage] Token read from secure storage (mobile/desktop): ${token != null ? "found" : "not found"}');
    }
    return token;
  }

  /// Delete authentication token
  Future<void> deleteToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      _log('[TokenStorage] Token deleted from localStorage (web)');
    } else {
      await _secure.delete(key: _tokenKey);
      _log('[TokenStorage] Token deleted from secure storage (mobile/desktop)');
    }
  }

  /// Save session cookie (for web compatibility)
  Future<void> saveSessionCookie(String cookie) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionCookieKey, cookie);
      _log('[TokenStorage] Session cookie saved to localStorage (web)');
    } else {
      await _secure.write(key: _sessionCookieKey, value: cookie);
      _log('[TokenStorage] Session cookie saved to secure storage (mobile/desktop)');
    }
  }

  /// Read session cookie
  Future<String?> readSessionCookie() async {
    String? cookie;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      cookie = prefs.getString(_sessionCookieKey);
      _log('[TokenStorage] Session cookie read from localStorage (web): ${cookie != null ? "found" : "not found"}');
    } else {
      cookie = await _secure.read(key: _sessionCookieKey);
      _log('[TokenStorage] Session cookie read from secure storage (mobile/desktop): ${cookie != null ? "found" : "not found"}');
    }
    return cookie;
  }

  /// Delete session cookie
  Future<void> deleteSessionCookie() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionCookieKey);
      _log('[TokenStorage] Session cookie deleted from localStorage (web)');
    } else {
      await _secure.delete(key: _sessionCookieKey);
      _log('[TokenStorage] Session cookie deleted from secure storage (mobile/desktop)');
    }
  }

  /// Clear all authentication data
  Future<void> clearAll() async {
    await deleteToken();
    await deleteSessionCookie();
    _log('[TokenStorage] All auth data cleared');
  }

  void _log(String message) {
    // Logs disabled in production for cleaner output
    if (kDebugMode && !kIsWeb) {
      print(message);
    }
  }
}

bool get kDebugMode {
  bool debug = false;
  assert(debug = true);
  return debug;
}
