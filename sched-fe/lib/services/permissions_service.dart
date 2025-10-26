import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  /// Request all necessary permissions on app startup
  Future<void> requestInitialPermissions(BuildContext context) async {
    // Skip storage permission on web (not supported)
    await _requestNotificationPermission();
    await _requestMicrophonePermission();
    await _requestCameraPermission();
    if (!kIsWeb) {
      await _requestStoragePermission();
    }
  }

  /// Request notification permission
  Future<bool> _requestNotificationPermission() async {
    final status = await Permission.notification.status;

    if (status.isDenied || status.isLimited || status.isPermanentlyDenied) {
      final newStatus = await Permission.notification.request();
      debugPrint('[Permissions] Notification permission: $newStatus');
      return newStatus.isGranted;
    }

    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.status;

    if (status.isDenied || status.isPermanentlyDenied) {
      final newStatus = await Permission.microphone.request();
      debugPrint('[Permissions] Microphone permission: $newStatus');
      return newStatus.isGranted;
    }

    return status.isGranted;
  }

  /// Request camera permission
  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isDenied || status.isPermanentlyDenied) {
      final newStatus = await Permission.camera.request();
      debugPrint('[Permissions] Camera permission: $newStatus');
      return newStatus.isGranted;
    }

    return status.isGranted;
  }

  /// Request storage permission
  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.status;

    if (status.isDenied || status.isPermanentlyDenied) {
      final newStatus = await Permission.storage.request();
      debugPrint('[Permissions] Storage permission: $newStatus');
      return newStatus.isGranted;
    }

    return status.isGranted;
  }

  /// Show permission explanation dialog
  Future<bool?> _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
    String permissionType,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Permissão: $title'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Agora não'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Permitir'),
            ),
          ],
        );
      },
    );
  }

  /// Check if all critical permissions are granted
  Future<bool> areAllCriticalPermissionsGranted() async {
    final notificationStatus = await Permission.notification.status;
    return notificationStatus.isGranted;
  }

  /// Open app settings if user denied permissions
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Request specific permission
  Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

  /// Check specific permission status
  Future<bool> checkPermission(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Request notification permission (public method)
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request microphone permission (public method)
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request camera permission (public method)
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request storage permission (public method)
  Future<bool> requestStoragePermission() async {
    if (kIsWeb) return true; // Not applicable on web
    final status = await Permission.storage.request();
    return status.isGranted;
  }
}
