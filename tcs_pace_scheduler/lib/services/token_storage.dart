import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token storage service that adapts to the platform:
/// - Web: Uses SharedPreferences (localStorage)
/// - Linux: Uses SharedPreferences (fallback when keyring unavailable)
/// - Mobile/Desktop: Uses FlutterSecureStorage (Keychain/Keystore)
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  final _secure = const FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _sessionCookieKey = 'session_cookie';

  // Track if secure storage is available (keyring on Linux)
  bool? _secureStorageAvailable;

  /// Check if we should use SharedPreferences instead of secure storage
  bool get _useSharedPrefs {
    if (kIsWeb) return true;
    if (!Platform.isLinux) return false;
    // On Linux, use SharedPreferences if secure storage failed before
    return _secureStorageAvailable == false;
  }

  /// Try to use secure storage, fall back to SharedPreferences on error
  Future<T> _withFallback<T>(
    Future<T> Function() secureOp,
    Future<T> Function() fallbackOp,
  ) async {
    if (_useSharedPrefs) {
      return fallbackOp();
    }

    try {
      final result = await secureOp();
      _secureStorageAvailable = true;
      return result;
    } catch (e) {
      if (e.toString().contains('libsecret') || e.toString().contains('keyring')) {
        _secureStorageAvailable = false;
        _log('[TokenStorage] Secure storage unavailable, using SharedPreferences fallback');
        return fallbackOp();
      }
      rethrow;
    }
  }

  /// Save authentication token
  Future<void> saveToken(String token) async {
    await _withFallback(
      () async {
        await _secure.write(key: _tokenKey, value: token);
        _log('[TokenStorage] Token saved to secure storage');
      },
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        _log('[TokenStorage] Token saved to SharedPreferences (fallback)');
      },
    );
  }

  /// Read authentication token
  Future<String?> readToken() async {
    return await _withFallback(
      () async {
        final token = await _secure.read(key: _tokenKey);
        _log('[TokenStorage] Token read from secure storage: ${token != null ? "found" : "not found"}');
        return token;
      },
      () async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_tokenKey);
        _log('[TokenStorage] Token read from SharedPreferences (fallback): ${token != null ? "found" : "not found"}');
        return token;
      },
    );
  }

  /// Delete authentication token
  Future<void> deleteToken() async {
    await _withFallback(
      () async {
        await _secure.delete(key: _tokenKey);
        _log('[TokenStorage] Token deleted from secure storage');
      },
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        _log('[TokenStorage] Token deleted from SharedPreferences (fallback)');
      },
    );
  }

  /// Save session cookie (for web compatibility)
  Future<void> saveSessionCookie(String cookie) async {
    await _withFallback(
      () async {
        await _secure.write(key: _sessionCookieKey, value: cookie);
        _log('[TokenStorage] Session cookie saved to secure storage');
      },
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionCookieKey, cookie);
        _log('[TokenStorage] Session cookie saved to SharedPreferences (fallback)');
      },
    );
  }

  /// Read session cookie
  Future<String?> readSessionCookie() async {
    return await _withFallback(
      () async {
        final cookie = await _secure.read(key: _sessionCookieKey);
        _log('[TokenStorage] Session cookie read from secure storage: ${cookie != null ? "found" : "not found"}');
        return cookie;
      },
      () async {
        final prefs = await SharedPreferences.getInstance();
        final cookie = prefs.getString(_sessionCookieKey);
        _log('[TokenStorage] Session cookie read from SharedPreferences (fallback): ${cookie != null ? "found" : "not found"}');
        return cookie;
      },
    );
  }

  /// Delete session cookie
  Future<void> deleteSessionCookie() async {
    await _withFallback(
      () async {
        await _secure.delete(key: _sessionCookieKey);
        _log('[TokenStorage] Session cookie deleted from secure storage');
      },
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_sessionCookieKey);
        _log('[TokenStorage] Session cookie deleted from SharedPreferences (fallback)');
      },
    );
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
