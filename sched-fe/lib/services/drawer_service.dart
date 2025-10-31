import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/booking_details_screen.dart';

/// Service to manage drawer deep linking and navigation
///
/// This service allows drawers to be opened via URLs and provides
/// a centralized way to manage drawer state across the app.
///
/// Example usage:
/// ```dart
/// // Open booking details drawer
/// DrawerService.instance.openDrawer(
///   context,
///   DrawerType.bookingDetails,
///   params: {'bookingId': '123'},
/// );
///
/// // Or via URL (will be intercepted by router)
/// context.go('/app/booking/123'); // Opens drawer instead of full page
/// ```
class DrawerService {
  static final DrawerService instance = DrawerService._internal();

  factory DrawerService() {
    return instance;
  }

  DrawerService._internal();

  /// Currently open drawer (if any)
  DrawerType? _currentDrawer;
  Map<String, dynamic>? _currentParams;

  /// Get currently open drawer type
  DrawerType? get currentDrawer => _currentDrawer;

  /// Get current drawer parameters
  Map<String, dynamic>? get currentParams => _currentParams;

  /// Open a drawer with the specified type and parameters
  ///
  /// This will show the drawer and optionally update the URL
  /// to support deep linking and browser back/forward navigation.
  Future<T?> openDrawer<T>(
    BuildContext context,
    DrawerType type, {
    Map<String, dynamic>? params,
    bool updateUrl = true,
  }) async {
    // Store current route before opening drawer
    _storePreviousRoute(context);

    _currentDrawer = type;
    _currentParams = params;

    // Update URL for web deep linking (without actually navigating)
    if (updateUrl) {
      final url = _buildUrlForDrawer(type, params);
      if (url != null) {
        // Use replace to avoid adding to history stack
        context.replace(url);
      }
    }

    // Show bottom sheet drawer for all types (consistent UX)
    final result = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _buildDrawerContent(context, type, params),
    );

    // Clear current drawer when closed
    _currentDrawer = null;
    _currentParams = null;

    return result;
  }

  /// Close the currently open drawer
  void closeDrawer(BuildContext context) {
    if (_currentDrawer != null) {
      Navigator.of(context).pop();
      _currentDrawer = null;
      _currentParams = null;
    }
  }

  /// Build the URL for a drawer type and parameters
  String? _buildUrlForDrawer(DrawerType type, Map<String, dynamic>? params) {
    switch (type) {
      case DrawerType.bookingDetails:
        final bookingId = params?['bookingId'];
        return bookingId != null ? '/app/booking/$bookingId' : null;

      case DrawerType.notifications:
        return '/app/notifications';

      case DrawerType.bookingForm:
        // Booking form typically doesn't need a URL
        return null;

      default:
        return null;
    }
  }

  /// Build the drawer content based on type
  Widget _buildDrawerContent(
    BuildContext context,
    DrawerType type,
    Map<String, dynamic>? params,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // BookingDetails manages its own header, so we use a different structure
    if (type == DrawerType.bookingDetails) {
      final bookingId = params?['bookingId'] as String?;
      if (bookingId == null) {
        return _buildErrorDrawer(isDark, 'Booking ID is required');
      }

      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content includes its own header
              Expanded(
                child: BookingDetailsScreen(
                  bookingId: bookingId,
                  showScaffold: false,
                  scrollController: scrollController,
                  onClose: () {
                    closeDrawer(context);
                    _navigateToBaseRoute(context, type);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Standard drawer with generic header for other types
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      closeDrawer(context);
                      // Navigate back to base route
                      _navigateToBaseRoute(context, type);
                    },
                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                    tooltip: 'Close',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getDrawerTitle(type),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _buildDrawerBodyContent(
                context,
                type,
                params,
                scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDrawer(bool isDark, String message) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  /// Get the title for a drawer type
  String _getDrawerTitle(DrawerType type) {
    switch (type) {
      case DrawerType.bookingDetails:
        return 'Booking Details';
      case DrawerType.notifications:
        return 'Notifications';
      case DrawerType.bookingForm:
        return 'New Booking';
      default:
        return '';
    }
  }

  /// Build the body content for each drawer type
  Widget _buildDrawerBodyContent(
    BuildContext context,
    DrawerType type,
    Map<String, dynamic>? params,
    ScrollController scrollController,
  ) {
    switch (type) {
      case DrawerType.notifications:
        // NotificationsScreen has a dedicated drawer version
        // We need to import it
        return Center(
          child: Text('Notifications drawer - needs NotificationsDrawer widget'),
        );

      case DrawerType.bookingForm:
        // Booking form is handled separately (has its own drawer implementation)
        return Center(
          child: Text('Booking form drawer'),
        );

      default:
        return Center(
          child: Text('Unknown drawer type: ${type.name}'),
        );
    }
  }

  String? _previousRoute;

  /// Store the current route before opening a drawer
  void _storePreviousRoute(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    _previousRoute = location;
  }

  /// Navigate back to base route when drawer closes
  void _navigateToBaseRoute(BuildContext context, DrawerType type) {
    // If we have a stored previous route, use it
    if (_previousRoute != null && _previousRoute!.isNotEmpty) {
      // Extract base route (without query params or drawer paths)
      String baseRoute = _previousRoute!;

      // Remove /booking/:id routes
      if (baseRoute.startsWith('/app/booking/')) {
        baseRoute = '/app/schedule'; // Default to calendar if coming from booking details
      }

      // Remove query params
      if (baseRoute.contains('?')) {
        baseRoute = baseRoute.split('?').first;
      }

      context.go(baseRoute);
      _previousRoute = null;
      return;
    }

    // Fallback to default routes
    switch (type) {
      case DrawerType.bookingDetails:
        context.go('/app/schedule');
        break;
      case DrawerType.notifications:
        context.go('/app/schedule');
        break;
      case DrawerType.bookingForm:
        // Usually stays on current page
        break;
    }
  }
}

/// Available drawer types in the app
enum DrawerType {
  bookingDetails,
  notifications,
  bookingForm,
}
