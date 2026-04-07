import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_storage.dart';

/// Service for biometric authentication (fingerprint, face ID).
/// Only available on mobile (iOS/Android) after first successful login.
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _biometricUserKey = 'biometric_user_email';

  /// Check if biometrics are available on this device.
  /// Returns false on web and desktop platforms.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];

    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if biometric login is enabled (user has logged in before and opted in).
  Future<bool> isEnabled() async {
    if (kIsWeb) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_biometricEnabledKey) ?? false;
      if (!enabled) return false;

      // Also check that we have a stored session
      final tokenStorage = TokenStorage();
      final cookie = await tokenStorage.readSessionCookie();
      return cookie != null;
    } catch (_) {
      return false;
    }
  }

  /// Enable biometric login after successful password login.
  /// Stores the user's email so we know who to authenticate.
  Future<void> enable(String userEmail) async {
    if (kIsWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricEnabledKey, true);
      await prefs.setString(_biometricUserKey, userEmail);
    } catch (_) {
      // Silently fail — biometric is optional
    }
  }

  /// Disable biometric login.
  Future<void> disable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_biometricEnabledKey);
      await prefs.remove(_biometricUserKey);
    } catch (_) {
      // Silently fail
    }
  }

  /// Get the stored user email for biometric login.
  Future<String?> getStoredUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_biometricUserKey);
    } catch (_) {
      return null;
    }
  }

  /// Authenticate using biometrics.
  /// Returns true if authentication succeeded, false otherwise.
  Future<bool> authenticate({String reason = 'Authenticate to access Pace Scheduler'}) async {
    if (kIsWeb) return false;

    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Full biometric login flow:
  /// 1. Authenticate with biometric
  /// 2. If successful, restore session from secure storage
  /// Returns the stored session cookie if successful, null otherwise.
  Future<String?> biometricLogin() async {
    final authenticated = await authenticate();
    if (!authenticated) return null;

    // Restore session cookie from secure storage
    final tokenStorage = TokenStorage();
    final cookie = await tokenStorage.readSessionCookie();
    return cookie;
  }
}
