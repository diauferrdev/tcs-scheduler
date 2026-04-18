import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/booking.dart';
import '../services/realtime_service.dart';
import '../services/drawer_service.dart';
import '../widgets/booking_card.dart';
import '../widgets/room_booking_card.dart';

class MyBookingsScreen extends StatefulWidget {
  final bool skipLayout;
  final String? initialBookingId;

  const MyBookingsScreen({
    super.key,
    this.skipLayout = false,
    this.initialBookingId,
  });

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final ApiService _apiService = ApiService();
  final RealtimeService _realtimeService = RealtimeService();
  List<Booking> _allBookings = [];
  List<Booking> _newRequests = [];
  List<Booking> _recentHistory = [];
  List<Map<String, dynamic>> _myRoomBookings = [];
  bool _isLoading = true;
  String? _error;
  bool _isLoadingInProgress = false; // Prevent concurrent loads
  bool _pendingReload = false; // Re-load after current finishes
  int _retryCount = 0;
  static const int _maxRetries = 3;
  // Keep listener references for proper cleanup
  late final Function(Map<String, dynamic>) _onBookingCreatedListener;
  late final Function(Map<String, dynamic>) _onBookingUpdatedListener;
  late final Function(Map<String, dynamic>) _onBookingApprovedListener;
  late final Function(String) _onBookingDeletedListener;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _setupRealtimeUpdates();
    _setupRoomRealtimeUpdates();

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
      if (mounted) _loadBookings(seamless: true);
    };

    _onBookingUpdatedListener = (bookingData) {
      if (mounted) _loadBookings(seamless: true);
    };

    _onBookingApprovedListener = (bookingData) {
      if (mounted) _loadBookings(seamless: true);
    };

    _onBookingDeletedListener = (bookingId) {
      if (mounted) _loadBookings(seamless: true);
    };

    // Add listeners to service
    _realtimeService.addBookingCreatedListener(_onBookingCreatedListener);
    _realtimeService.addBookingUpdatedListener(_onBookingUpdatedListener);
    _realtimeService.addBookingApprovedListener(_onBookingApprovedListener);
    _realtimeService.addBookingDeletedListener(_onBookingDeletedListener);
  }

  late final Function(Map<String, dynamic>) _onRoomBookingChangedListener;

  void _setupRoomRealtimeUpdates() {
    _onRoomBookingChangedListener = (_) {
      if (mounted) _loadBookings(seamless: true);
    };
    _realtimeService.addRoomBookingChangedListener(_onRoomBookingChangedListener);
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

  Future<void> _loadBookings({bool seamless = false}) async {
    if (!mounted) return;
    if (_isLoadingInProgress) {
      _pendingReload = true;
      return;
    }

    _isLoadingInProgress = true;

    if (!seamless) {
      if (mounted && !_isLoading) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      } else if (mounted) {
        setState(() {
          _error = null;
        });
      }
    }

    try {
      final response = await _apiService.get('/api/bookings?mine=true');

      // Also load user's room bookings
      List<Map<String, dynamic>> roomBookings = [];
      try {
        final roomResponse = await _apiService.get('/api/rooms?mine=true');
        roomBookings = ((roomResponse['bookings'] as List?) ?? [])
            .map((b) => b as Map<String, dynamic>)
            .toList();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _allBookings = (response['bookings'] as List)
              .map((json) => Booking.fromJson(json))
              .toList();
          _myRoomBookings = roomBookings;
          _categorizeBookings();
          _isLoading = false;
          _error = null;
          _retryCount = 0;
        });
      }
    } catch (e) {
      final isConnectionError = e.toString().contains('connection abort') ||
                                 e.toString().contains('Connection closed') ||
                                 e.toString().contains('SocketException') ||
                                 e.toString().contains('TimeoutException');

      if (isConnectionError && _retryCount < _maxRetries && mounted) {
        _retryCount++;
        final delayMs = 500 * _retryCount;

        _isLoadingInProgress = false;
        await Future.delayed(Duration(milliseconds: delayMs));

        if (mounted) {
          _loadBookings();
        }
      } else {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isLoading = false;
            _retryCount = 0;
          });
        }
        _isLoadingInProgress = false;
      }
    } finally {
      if (_retryCount == 0 || _retryCount >= _maxRetries) {
        _isLoadingInProgress = false;
        if (_pendingReload && mounted) {
          _pendingReload = false;
          _loadBookings(seamless: true);
        }
      }
    }
  }

  void _categorizeBookings() {
    // New Requests: Bookings waiting for review or user action
    // Sorted by latest status update (updatedAt) - most recently updated first
    _newRequests = _allBookings
        .where((b) =>
            b.status == BookingStatus.CREATED ||
            b.status == BookingStatus.UNDER_REVIEW ||
            b.status == BookingStatus.NEED_EDIT ||
            b.status == BookingStatus.NEED_RESCHEDULE)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // Recent History: Completed/final states
    _recentHistory = _allBookings
        .where((b) =>
            b.status == BookingStatus.APPROVED ||
            b.status == BookingStatus.NOT_APPROVED ||
            b.status == BookingStatus.CANCELLED)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.black,
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: _buildBody(isDark),
            ),
    );
  }


  Widget _buildBody(bool isDark) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Bookings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBookings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_newRequests.isEmpty && _recentHistory.isEmpty && _myRoomBookings.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_note,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No Bookings Yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your bookings will appear here',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Check if desktop (width >= 1024px) for side-by-side layout
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    if (isDesktop) {
      // Desktop: 2-column layout, fills height
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildNewRequestsSection(isDark)),
          const SizedBox(width: 24),
          Expanded(child: _buildRecentHistorySection(isDark)),
        ],
      );
    } else {
      // Mobile: Vertical stack, history fills remaining space
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNewRequestsSection(isDark),
          const SizedBox(height: 32),
          Expanded(child: _buildRecentHistorySection(isDark)),
        ],
      );
    }
  }

  Widget _buildNewRequestsSection(bool isDark) {
    final pendingRooms = _myRoomBookings.where((r) => r['status'] == 'PENDING' || r['status'] == 'APPROVED').toList();
    if (_newRequests.isEmpty && pendingRooms.isEmpty) {
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
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All caught up!',
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
                color: const Color(0xFFF05E1B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_newRequests.length + pendingRooms.length}',
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
        // Room bookings (pending + approved)
        ...pendingRooms.map((room) => _buildRoomCard(room, isDark)),
        // Event bookings
        ..._newRequests.map((booking) {
          return BookingCard(
            booking: booking,
            onTap: () => _showBookingDetailsDrawer(booking),
          );
        }),
      ],
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room, bool isDark) {
    return RoomBookingCard(
      roomBooking: room,
      onTap: () => _showRoomDetailDrawer(room),
    );
  }

  Future<void> _showRoomDetailDrawer(Map<String, dynamic> room) async {
    final id = room['id'] as String;
    await DrawerService.instance.openDrawer(
      context,
      DrawerType.roomBookingDetails,
      params: {'roomBookingId': id},
      updateUrl: false,
    );
    // Reload when drawer closes
    if (mounted) _loadBookings(seamless: true);
  }

  Widget _buildRecentHistorySection(bool isDark) {
    final historyRooms = _myRoomBookings.where((r) => r['status'] == 'REJECTED' || r['status'] == 'CANCELLED').toList();
    if (_recentHistory.isEmpty && historyRooms.isEmpty) {
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
                '${_recentHistory.length + historyRooms.length}',
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
        // Scrollable history list — fills remaining space
        Expanded(
          child: ListView(
            children: [
              // Rejected/cancelled room bookings
              ...historyRooms.map((room) => _buildRoomCard(room, isDark)),
              // Event bookings history
              ..._recentHistory.map((booking) {
                return BookingCard(
                  booking: booking,
                  onTap: () => _showBookingDetailsDrawer(booking),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _showBookingDetailsDrawer(Booking booking) {
    // Use DrawerService for consistent drawer experience
    DrawerService.instance.openDrawer(
      context,
      DrawerType.bookingDetails,
      params: {'bookingId': booking.id},
      updateUrl: false, // Don't update URL from My Bookings screen
    );
  }
}
