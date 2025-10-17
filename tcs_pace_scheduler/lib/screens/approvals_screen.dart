import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/drawer_service.dart';
import '../widgets/pending_approval_card.dart';
import '../widgets/reschedule_dialog.dart';

class ApprovalsScreen extends StatefulWidget {
  final String? initialBookingId;

  const ApprovalsScreen({
    super.key,
    this.initialBookingId,
  });

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final ApiService _apiService = ApiService();
  final RealtimeService _realtimeService = RealtimeService();
  List<Booking> _allBookings = [];
  List<Booking> _newRequests = [];
  List<Booking> _recentHistory = [];
  bool _loading = true;
  String? _error;

  // Keep listener references for proper cleanup
  late final Function(Map<String, dynamic>) _onBookingCreatedListener;
  late final Function(Map<String, dynamic>) _onBookingUpdatedListener;
  late final Function(Map<String, dynamic>) _onBookingApprovedListener;
  late final Function(String) _onBookingDeletedListener;

  @override
  void initState() {
    super.initState();
    _loadAllBookings();
    _setupRealtimeUpdates();

    // Open drawer if initialBookingId is provided
    if (widget.initialBookingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInitialBooking();
      });
    }
  }

  void _openInitialBooking() {
    if (widget.initialBookingId == null) return;

    // Use DrawerService to open the booking details drawer
    DrawerService.instance.openDrawer(
      context,
      DrawerType.bookingDetails,
      params: {'bookingId': widget.initialBookingId!},
      updateUrl: false,
    );
  }

  void _setupRealtimeUpdates() {
    debugPrint('[Approvals] Setting up real-time listeners...');

    // Create listener references
    _onBookingCreatedListener = (bookingData) {
      debugPrint('[Approvals] 🔔 NEW BOOKING via WebSocket - Reloading...');
      _loadAllBookings(); // Refresh list
    };

    _onBookingUpdatedListener = (bookingData) {
      debugPrint('[Approvals] 🔔 BOOKING UPDATED via WebSocket - Reloading...');
      _loadAllBookings(); // Refresh list
    };

    _onBookingApprovedListener = (bookingData) {
      debugPrint('[Approvals] 🔔 BOOKING APPROVED via WebSocket - Reloading...');
      _loadAllBookings(); // Refresh list
    };

    _onBookingDeletedListener = (bookingId) {
      debugPrint('[Approvals] 🔔 BOOKING DELETED via WebSocket: $bookingId - Reloading...');
      _loadAllBookings(); // Refresh list
    };

    // Add listeners to service
    debugPrint('[Approvals] Adding listeners to RealtimeService...');
    _realtimeService.addBookingCreatedListener(_onBookingCreatedListener);
    _realtimeService.addBookingUpdatedListener(_onBookingUpdatedListener);
    _realtimeService.addBookingApprovedListener(_onBookingApprovedListener);
    _realtimeService.addBookingDeletedListener(_onBookingDeletedListener);
    debugPrint('[Approvals] ✅ All listeners added successfully');
  }

  void _categorizeBookings() {
    // New Requests: All bookings that need review/action
    // Sorted by latest status update (updatedAt) - most recently updated first
    _newRequests = _allBookings
        .where((b) =>
            b.status == BookingStatus.CREATED ||
            b.status == BookingStatus.UNDER_REVIEW ||
            b.status == BookingStatus.NEED_EDIT ||
            b.status == BookingStatus.NEED_RESCHEDULE ||
            b.status == BookingStatus.PENDING_APPROVAL) // DEPRECATED
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Recent History: Completed/final states (approved, rejected, cancelled)
    _recentHistory = _allBookings
        .where((b) =>
            b.status == BookingStatus.APPROVED ||
            b.status == BookingStatus.NOT_APPROVED ||
            b.status == BookingStatus.CANCELLED)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  void dispose() {
    // Remove listeners
    _realtimeService.removeBookingCreatedListener(_onBookingCreatedListener);
    _realtimeService.removeBookingUpdatedListener(_onBookingUpdatedListener);
    _realtimeService.removeBookingApprovedListener(_onBookingApprovedListener);
    _realtimeService.removeBookingDeletedListener(_onBookingDeletedListener);
    super.dispose();
  }

  Future<void> _loadAllBookings() async {
    try {
      // Only show loading on initial load, not on auto-refresh
      if (_allBookings.isEmpty) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      // Load all bookings (no status filter)
      final response = await _apiService.getBookings();
      final bookingsData = (response['bookings'] as List?) ?? [];

      if (mounted) {
        setState(() {
          _allBookings = bookingsData.map((e) => Booking.fromJson(e)).toList();
          _categorizeBookings();
          _loading = false;
        });
        debugPrint('[Approvals] Loaded ${_allBookings.length} bookings');
      }
    } catch (e) {
      debugPrint('[Approvals] Error loading bookings: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _showRescheduleDialog(Booking booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RescheduleDialog(
        booking: booking,
        onRescheduled: _loadAllBookings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bookings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage all booking requests',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadAllBookings,
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        tooltip: 'Retry',
                      ),
                    ],
                  ),
                ),

              // Loading state
              if (_loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading bookings...',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                )

              // Content
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NEW REQUESTS SECTION
                    if (_newRequests.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            'New Requests',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_newRequests.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._newRequests.map((booking) {
                        return PendingApprovalCard(
                          booking: booking,
                          onApproved: _loadAllBookings,
                        );
                      }),
                      const SizedBox(height: 32),
                    ],

                    // RECENT HISTORY SECTION
                    if (_recentHistory.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            'Recent History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[700] : Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_recentHistory.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._recentHistory.take(10).map((booking) {
                        return PendingApprovalCard(
                          booking: booking,
                          onApproved: _loadAllBookings,
                        );
                      }),
                    ],

                    // Empty state when no bookings at all
                    if (_newRequests.isEmpty && _recentHistory.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 80,
                                color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No Bookings Yet',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Booking requests will appear here',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextButton.icon(
                                onPressed: _loadAllBookings,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
    );
  }
}
