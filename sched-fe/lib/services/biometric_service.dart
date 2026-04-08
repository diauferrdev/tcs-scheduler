import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Biometric authentication service (fingerprint, face ID).
/// Stores nickname + password in secure storage after first login.
/// On biometric re-login, does a real login with stored credentials.
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const _enabledKey = 'biometric_enabled';
  static const _nicknameKey = 'biometric_nickname';
  static const _passwordKey = 'biometric_password';
  static const _storage = FlutterSecureStorage();

  /// Available on Android, iOS, Windows (Hello), macOS (Touch ID). Not web.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    if (kIsWeb) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_enabledKey) ?? false)) return false;
      final nickname = await _storage.read(key: _nicknameKey);
      final password = await _storage.read(key: _passwordKey);
      return nickname != null && password != null;
    } catch (_) {
      return false;
    }
  }

  /// Save credentials after successful login.
  Future<void> enable(String nickname, String password) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      await _storage.write(key: _nicknameKey, value: nickname);
      await _storage.write(key: _passwordKey, value: password);
    } catch (_) {}
  }

  Future<void> disable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_enabledKey);
      await _storage.delete(key: _nicknameKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {}
  }

  /// Get stored credentials for re-login.
  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final nickname = await _storage.read(key: _nicknameKey);
      final password = await _storage.read(key: _passwordKey);
      if (nickname != null && password != null) {
        return {'nickname': nickname, 'password': password};
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Prompt biometric authentication (fingerprint/face).
  Future<bool> authenticate({String reason = 'Authenticate to access Pace Scheduler'}) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
    } on PlatformException {
      return false;
    }
  }
}
