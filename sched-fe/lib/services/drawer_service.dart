import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/booking_details_screen.dart';
import '../screens/room_booking_details_screen.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../widgets/ticket_chat_widget.dart';

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

      case DrawerType.ticketDetails:
        final ticketId = params?['ticketId'];
        return ticketId != null ? '/app/support/$ticketId' : null;

      case DrawerType.roomBookingDetails:
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

    // BookingDetails and TicketDetails manage their own headers
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

    if (type == DrawerType.ticketDetails) {
      final ticketId = params?['ticketId'] as String?;
      if (ticketId == null) {
        return _buildErrorDrawer(isDark, 'Ticket ID is required');
      }

      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
              // Ticket Detail - will need to create a drawer version
              Expanded(
                child: _TicketDetailDrawerContent(
                  ticketId: ticketId,
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

    if (type == DrawerType.roomBookingDetails) {
      final roomBookingId = params?['roomBookingId'] as String?;
      if (roomBookingId == null) {
        return _buildErrorDrawer(isDark, 'Room Booking ID is required');
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
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: RoomBookingDetailsScreen(
                  roomBookingId: roomBookingId,
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
      case DrawerType.ticketDetails:
        return 'Support Ticket';
      case DrawerType.roomBookingDetails:
        return 'Room Booking';
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
      case DrawerType.ticketDetails:
        context.go('/app/support');
        break;
      case DrawerType.roomBookingDetails:
        break;
    }
  }
}

/// Ticket Detail Drawer Content Widget
class _TicketDetailDrawerContent extends StatefulWidget {
  final String ticketId;
  final ScrollController scrollController;
  final VoidCallback onClose;

  const _TicketDetailDrawerContent({
    required this.ticketId,
    required this.scrollController,
    required this.onClose,
  });

  @override
  State<_TicketDetailDrawerContent> createState() => _TicketDetailDrawerContentState();
}

class _TicketDetailDrawerContentState extends State<_TicketDetailDrawerContent> {
  Ticket? _ticket;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    try {
      final api = ApiService();
      final response = await api.get('/api/tickets/${widget.ticketId}');
      if (!mounted) return;

      setState(() {
        _ticket = Ticket.fromJson(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onTicketUpdated(Ticket updatedTicket) {
    if (mounted) {
      setState(() {
        _ticket = updatedTicket;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDark;
    final textColor = isDark ? Colors.white : Colors.black;
    final user = authProvider.user;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _ticket == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(_error ?? 'Ticket not found', style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with close button, title, and status selector (admin only)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close button and title row
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(Icons.close, color: textColor),
                    tooltip: 'Close',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ticket!.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Status selector for ADMIN
              if (user?.role == UserRole.ADMIN) ...[
                const SizedBox(height: 12),
                _buildAdminStatusSelector(isDark, textColor),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  _ticket!.getStatusLabel(),
                  style: TextStyle(
                    color: _getStatusColor(_ticket!.status),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Chat Widget
        Expanded(
          child: TicketChatWidget(
            ticketId: widget.ticketId,
            onTicketUpdated: _onTicketUpdated,
            isAdminView: user?.role == UserRole.ADMIN,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminStatusSelector(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor(_ticket!.status).withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TicketStatus>(
          value: _ticket!.status,
          isDense: true,
          dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
          style: TextStyle(
            color: _getStatusColor(_ticket!.status),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          icon: Icon(Icons.arrow_drop_down, color: _getStatusColor(_ticket!.status)),
          items: TicketStatus.values.map((status) {
            return DropdownMenuItem(
              value: status,
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    size: 16,
                    color: _getStatusColor(status),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusLabel(status),
                    style: TextStyle(color: _getStatusColor(status)),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newStatus) {
            if (newStatus != null && newStatus != _ticket!.status) {
              _updateTicketStatus(newStatus);
            }
          },
        ),
      ),
    );
  }

  Future<void> _updateTicketStatus(TicketStatus newStatus) async {
    try {
      final api = ApiService();
      await api.patch('/api/tickets/${widget.ticketId}', {
        'status': newStatus.toString().split('.').last,
      });

      if (!mounted) return;

      // Reload ticket to get updated data
      await _loadTicket();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${_getStatusLabel(newStatus)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getStatusLabel(TicketStatus status) {
    switch (status) {
      case TicketStatus.OPEN:
        return 'Open';
      case TicketStatus.IN_PROGRESS:
        return 'In Progress';
      case TicketStatus.WAITING_USER:
        return 'Waiting for User';
      case TicketStatus.WAITING_ADMIN:
        return 'Waiting for Admin';
      case TicketStatus.RESOLVED:
        return 'Resolved';
      case TicketStatus.CLOSED:
        return 'Closed';
    }
  }

  IconData _getStatusIcon(TicketStatus status) {
    switch (status) {
      case TicketStatus.OPEN:
        return Icons.mark_email_unread;
      case TicketStatus.IN_PROGRESS:
        return Icons.pending;
      case TicketStatus.WAITING_USER:
        return Icons.schedule;
      case TicketStatus.WAITING_ADMIN:
        return Icons.support_agent;
      case TicketStatus.RESOLVED:
        return Icons.check_circle;
      case TicketStatus.CLOSED:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.OPEN:
        return Colors.blue;
      case TicketStatus.IN_PROGRESS:
        return Colors.purple;
      case TicketStatus.WAITING_USER:
        return Colors.orange;
      case TicketStatus.WAITING_ADMIN:
        return Colors.amber;
      case TicketStatus.RESOLVED:
        return Colors.green;
      case TicketStatus.CLOSED:
        return Colors.grey;
    }
  }
}

/// Available drawer types in the app
enum DrawerType {
  bookingDetails,
  notifications,
  bookingForm,
  ticketDetails,
  roomBookingDetails,
}
