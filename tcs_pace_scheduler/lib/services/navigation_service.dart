import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Global Navigation Service
/// Provides navigation from anywhere in the app, including notification handlers
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // Global navigator key
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Get current context
  BuildContext? get context => navigatorKey.currentContext;

  /// Navigate to route
  void navigateTo(String path) {
    if (context != null) {
      context!.go(path);
      debugPrint('[NavigationService] Navigated to: $path');
    } else {
      debugPrint('[NavigationService] ⚠️ No context available for navigation');
    }
  }

  /// Navigate to calendar with optional date
  void navigateToCalendar({DateTime? date}) {
    navigateTo('/calendar');
    debugPrint('[NavigationService] Navigated to calendar${date != null ? ' with date: $date' : ''}');
  }

  /// Navigate to notifications
  void navigateToNotifications() {
    navigateTo('/notifications');
  }

  /// Navigate to dashboard
  void navigateToDashboard() {
    navigateTo('/dashboard');
  }

  /// Navigate to approvals
  void navigateToApprovals() {
    navigateTo('/approvals');
  }

  /// Navigate to agenda
  void navigateToAgenda() {
    navigateTo('/agenda');
  }

  /// Show snackbar
  void showSnackBar(String message, {bool isError = false}) {
    if (context != null) {
      ScaffoldMessenger.of(context!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
