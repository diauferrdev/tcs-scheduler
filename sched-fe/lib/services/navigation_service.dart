import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/toast_notification.dart';

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
    navigateTo('/app/schedule');
    debugPrint('[NavigationService] Navigated to calendar${date != null ? ' with date: $date' : ''}');
  }

  /// Navigate to notifications
  void navigateToNotifications() {
    navigateTo('/app/notifications');
  }

  /// Navigate to dashboard
  void navigateToDashboard() {
    navigateTo('/app/dashboard');
  }

  /// Navigate to approvals
  void navigateToApprovals() {
    navigateTo('/app/pending');
  }

  /// Navigate to agenda
  void navigateToAgenda() {
    navigateTo('/app/agenda');
  }

  /// Navigate to my bookings
  void navigateToMyBookings() {
    navigateTo('/app/my-visits');
  }

  /// Navigate to booking details (goes to My Bookings first, then opens details drawer)
  void navigateToBookingDetails(String bookingId) {
    navigateTo('/app/my-visits?bookingId=$bookingId');
    debugPrint('[NavigationService] Navigated to My Visits with booking details: $bookingId');
  }

  /// Navigate to approvals with booking details (for ADMIN/MANAGER)
  void navigateToApprovalsWithBooking(String bookingId) {
    navigateTo('/app/pending?bookingId=$bookingId');
    debugPrint('[NavigationService] Navigated to Pending with booking details: $bookingId');
  }

  /// Show snackbar
  void showSnackBar(String message, {bool isError = false}) {
    if (context != null) {
      ToastNotification.show(
        context!,
        message: message,
        type: isError ? ToastType.error : ToastType.success,
        duration: const Duration(seconds: 2),
      );
    }
  }
}
