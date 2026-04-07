import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/drawer_service.dart';
import '../widgets/pending_approval_card.dart';
import '../widgets/room_booking_card.dart';

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
  List<Map<String, dynamic>> _pendingRoomBookings = [];
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
    _setupRoomRealtimeUpdates();

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
    _onBookingCreatedListener = (bookingData) {
      _loadAllBookings();
    };

    _onBookingUpdatedListener = (bookingData) {
      _loadAllBookings();
    };

    _onBookingApprovedListener = (bookingData) {
      _loadAllBookings();
    };

    _onBookingDeletedListener = (bookingId) {
      _loadAllBookings();
    };

    _realtimeService.addBookingCreatedListener(_onBookingCreatedListener);
    _realtimeService.addBookingUpdatedListener(_onBookingUpdatedListener);
    _realtimeService.addBookingApprovedListener(_onBookingApprovedListener);
    _realtimeService.addBookingDeletedListener(_onBookingDeletedListener);
  }

  late final Function(Map<String, dynamic>) _onRoomBookingChangedListener;

  void _setupRoomRealtimeUpdates() {
    _onRoomBookingChangedListener = (_) {
      if (mounted) _loadAllBookings();
    };
    _realtimeService.addRoomBookingChangedListener(_onRoomBookingChangedListener);
  }

  void _categorizeBookings() {
    // New Requests: All bookings that need review/action
    // Sorted by latest status update (updatedAt) - most recently updated first
    _newRequests = _allBookings
        .where((b) =>
            b.status == BookingStatus.CREATED ||
            b.status == BookingStatus.UNDER_REVIEW ||
            b.status == BookingStatus.NEED_EDIT ||
            b.status == BookingStatus.NEED_RESCHEDULE)
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
    _realtimeService.removeBookingCreatedListener(_onBookingCreatedListener);
    _realtimeService.removeBookingUpdatedListener(_onBookingUpdatedListener);
    _realtimeService.removeBookingApprovedListener(_onBookingApprovedListener);
    _realtimeService.removeBookingDeletedListener(_onBookingDeletedListener);
    _realtimeService.removeRoomBookingChangedListener(_onRoomBookingChangedListener);
    super.dispose();
  }

  Future<void> _loadAllBookings() async {
    try {
      if (_allBookings.isEmpty) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final response = await _apiService.getBookings();
      final bookingsData = (response['bookings'] as List?) ?? [];

      // Also load pending room bookings
      List<Map<String, dynamic>> pendingRooms = [];
      try {
        final roomResponse = await _apiService.get('/api/rooms?status=PENDING');
        pendingRooms = ((roomResponse['bookings'] as List?) ?? [])
            .map((b) => b as Map<String, dynamic>)
            .toList();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _allBookings = bookingsData.map((e) => Booking.fromJson(e)).toList();
          _pendingRoomBookings = pendingRooms;
          _categorizeBookings();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      child: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.black,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                // Content
                _buildBody(isDark),
            ],
          ),
        ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_newRequests.isEmpty && _recentHistory.isEmpty && _pendingRoomBookings.isEmpty) {
      return Center(
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
      );
    }

    // Check if desktop (width >= 1024px) for side-by-side layout
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      // Desktop: 2-column layout
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildNewRequestsSection(isDark)),
          const SizedBox(width: 24),
          Expanded(child: _buildRecentHistorySection(isDark)),
        ],
      );
    } else {
      // Mobile: Vertical stack
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNewRequestsSection(isDark),
          const SizedBox(height: 32),
          _buildRecentHistorySection(isDark),
        ],
      );
    }
  }

  Widget _buildNewRequestsSection(bool isDark) {
    final totalPending = _newRequests.length + _pendingRoomBookings.length;

    if (totalPending == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('All caught up!', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'New Requests',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF05E1B), borderRadius: BorderRadius.circular(10)),
              child: Text('$totalPending', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Room bookings first (using same card style)
        ..._pendingRoomBookings.map((room) => _buildRoomBookingCard(room, isDark)),
        // Event bookings
        ..._newRequests.map((booking) {
          return PendingApprovalCard(booking: booking, onApproved: _loadAllBookings);
        }),
      ],
    );
  }

  Widget _buildRoomBookingCard(Map<String, dynamic> room, bool isDark) {
    return RoomBookingCard(
      roomBooking: room,
      onTap: () async {
        final id = room['id'] as String;
        await DrawerService.instance.openDrawer(
          context,
          DrawerType.roomBookingDetails,
          params: {'roomBookingId': id},
          updateUrl: false,
        );
        // Reload when drawer closes (after approve/reject)
        if (mounted) _loadAllBookings();
      },
    );
  }

  Widget _buildRecentHistorySection(bool isDark) {
    if (_recentHistory.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No history yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );
  }

}
