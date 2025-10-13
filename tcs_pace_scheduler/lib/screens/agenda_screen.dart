import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/navigation_service.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

/// Professional Agenda Screen - Timeline view of confirmed bookings
///
/// Architecture:
/// - Loads 3 months at a time (previous, current, next)
/// - Infinite scroll in both directions
/// - Simple state management without complex debouncing
/// - Always functional "Today" button
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final ApiService _apiService = ApiService();
  final RealtimeService _realtimeService = RealtimeService();
  final NavigationService _navigationService = NavigationService();
  final ScrollController _scrollController = ScrollController();

  // State
  List<Booking> _bookings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  // Date range currently loaded
  DateTime _startMonth = DateTime.now();
  DateTime _endMonth = DateTime.now();

  // Current display month (for header)
  DateTime _displayMonth = DateTime.now();

  // Keep listener references for cleanup
  late final Function(Map<String, dynamic>) _onBookingCreatedListener;
  late final Function(Map<String, dynamic>) _onBookingUpdatedListener;
  late final Function(Map<String, dynamic>) _onBookingApprovedListener;
  late final Function(String) _onBookingDeletedListener;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _setupRealtimeListeners();
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _clearRealtimeListeners();
    super.dispose();
  }

  /// Setup WebSocket listeners
  void _setupRealtimeListeners() {
    _onBookingCreatedListener = (bookingData) {
      if (!mounted) return;
      _handleRealtimeBookingUpdate(bookingData);
    };

    _onBookingUpdatedListener = (bookingData) {
      if (!mounted) return;
      _handleRealtimeBookingUpdate(bookingData);
    };

    _onBookingApprovedListener = (bookingData) {
      if (!mounted) return;
      _handleRealtimeBookingUpdate(bookingData);
    };

    _onBookingDeletedListener = (bookingId) {
      if (!mounted) return;
      _handleRealtimeBookingDelete(bookingId);
    };

    _realtimeService.onBookingCreated = _onBookingCreatedListener;
    _realtimeService.onBookingUpdated = _onBookingUpdatedListener;
    _realtimeService.onBookingApproved = _onBookingApprovedListener;
    _realtimeService.onBookingDeleted = _onBookingDeletedListener;
  }

  void _clearRealtimeListeners() {
    _realtimeService.onBookingCreated = null;
    _realtimeService.onBookingUpdated = null;
    _realtimeService.onBookingApproved = null;
    _realtimeService.onBookingDeleted = null;
  }

  /// Handle realtime booking update
  void _handleRealtimeBookingUpdate(Map<String, dynamic> bookingData) {
    try {
      final booking = Booking.fromJson(bookingData);

      // Only show approved bookings
      if (booking.status != BookingStatus.APPROVED) {
        setState(() {
          _bookings.removeWhere((b) => b.id == booking.id);
        });
        return;
      }

      setState(() {
        final index = _bookings.indexWhere((b) => b.id == booking.id);
        if (index >= 0) {
          _bookings[index] = booking;
        } else {
          _bookings.add(booking);
          _bookings.sort((a, b) => a.date.compareTo(b.date));
        }
      });
    } catch (e) {
      debugPrint('[Agenda] Error handling realtime update: $e');
    }
  }

  /// Handle realtime booking deletion
  void _handleRealtimeBookingDelete(String bookingId) {
    setState(() {
      _bookings.removeWhere((b) => b.id == bookingId);
    });
  }

  /// Load initial 3 months of data
  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final startMonth = DateTime(now.year, now.month - 1, 1);
      final endMonth = DateTime(now.year, now.month + 2, 0);

      final bookings = await _loadBookingsInRange(startMonth, endMonth);

      if (!mounted) return;

      setState(() {
        _bookings = bookings;
        _startMonth = startMonth;
        _endMonth = endMonth;
        _displayMonth = DateTime(now.year, now.month);
        _isLoading = false;
      });

      // Scroll to today after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _scrollToToday(animated: false);
        });
      });
    } catch (e) {
      debugPrint('[Agenda] Error loading initial data: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Load bookings in a date range
  Future<List<Booking>> _loadBookingsInRange(DateTime start, DateTime end) async {
    final List<Booking> allBookings = [];

    // Load each month in the range
    var current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final monthStr = DateFormat('yyyy-MM').format(current);
      try {
        final response = await _apiService.getConfirmedBookings(month: monthStr);
        final monthBookings = (response['bookings'] as List)
            .map((b) => Booking.fromJson(b))
            .toList();
        allBookings.addAll(monthBookings);
      } catch (e) {
        debugPrint('[Agenda] Error loading month $monthStr: $e');
      }

      // Move to next month
      current = DateTime(current.year, current.month + 1, 1);
    }

    // Sort by date
    allBookings.sort((a, b) => a.date.compareTo(b.date));
    return allBookings;
  }

  /// Handle scroll events
  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) return;

    final position = _scrollController.position;

    // Load previous month when near top
    if (position.pixels < 500) {
      _loadPreviousMonth();
    }

    // Load next month when near bottom
    if (position.pixels > position.maxScrollExtent - 500) {
      _loadNextMonth();
    }

    // Update display month based on scroll position
    _updateDisplayMonth();
  }

  /// Update the displayed month in header based on scroll position
  void _updateDisplayMonth() {
    // Find the booking closest to the center of the viewport
    final viewportHeight = MediaQuery.of(context).size.height;
    final centerY = _scrollController.offset + viewportHeight / 2;

    // Simple estimation: each day takes ~80px
    final estimatedDayIndex = (centerY / 80).floor();

    if (estimatedDayIndex >= 0 && estimatedDayIndex < _bookings.length) {
      final centerDate = _bookings[estimatedDayIndex].date;
      final newDisplayMonth = DateTime(centerDate.year, centerDate.month);

      if (newDisplayMonth != _displayMonth) {
        setState(() {
          _displayMonth = newDisplayMonth;
        });
      }
    }
  }

  /// Load previous month
  Future<void> _loadPreviousMonth() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final prevMonth = DateTime(_startMonth.year, _startMonth.month - 1, 1);
      final prevMonthEnd = DateTime(_startMonth.year, _startMonth.month, 0);

      final bookings = await _loadBookingsInRange(prevMonth, prevMonthEnd);

      if (!mounted) return;

      setState(() {
        _bookings = [...bookings, ..._bookings];
        _startMonth = prevMonth;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('[Agenda] Error loading previous month: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// Load next month
  Future<void> _loadNextMonth() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextMonth = DateTime(_endMonth.year, _endMonth.month + 1, 1);
      final nextMonthEnd = DateTime(_endMonth.year, _endMonth.month + 2, 0);

      final bookings = await _loadBookingsInRange(nextMonth, nextMonthEnd);

      if (!mounted) return;

      setState(() {
        _bookings = [..._bookings, ...bookings];
        _endMonth = nextMonthEnd;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('[Agenda] Error loading next month: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// Navigate to today
  Future<void> _goToToday() async {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    // Check if today is in the loaded range
    final isTodayLoaded = _bookings.any((b) => _isSameDay(b.date, todayNormalized));

    if (isTodayLoaded) {
      // Just scroll to it
      _scrollToToday(animated: true);
    } else {
      // Reload centered on today
      setState(() {
        _isLoading = true;
        _displayMonth = DateTime(today.year, today.month);
      });

      try {
        final startMonth = DateTime(today.year, today.month - 1, 1);
        final endMonth = DateTime(today.year, today.month + 2, 0);

        final bookings = await _loadBookingsInRange(startMonth, endMonth);

        if (!mounted) return;

        setState(() {
          _bookings = bookings;
          _startMonth = startMonth;
          _endMonth = endMonth;
          _isLoading = false;
        });

        // Scroll to today
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _scrollToToday(animated: true);
          });
        });
      } catch (e) {
        debugPrint('[Agenda] Error navigating to today: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  /// Scroll to today's position
  void _scrollToToday({bool animated = true}) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);

    // Find today's index
    final todayIndex = _bookings.indexWhere((b) => _isSameDay(b.date, todayNormalized));

    if (todayIndex >= 0) {
      // Each day card is approximately 80px tall
      final targetOffset = todayIndex * 80.0;

      if (animated) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _scrollController.jumpTo(targetOffset);
      }
    }
  }

  /// Pull to refresh
  Future<void> _refresh() async {
    try {
      final bookings = await _loadBookingsInRange(_startMonth, _endMonth);

      if (!mounted) return;

      setState(() {
        _bookings = bookings;
      });
    } catch (e) {
      debugPrint('[Agenda] Error refreshing: $e');
    }
  }

  /// Handle booking tap
  void _onBookingTap(Booking booking) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) return;

    if (user.role == UserRole.USER) {
      _navigationService.navigateToBookingDetails(booking.id);
    } else {
      _navigationService.navigateToApprovalsWithBooking(booking.id);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: _buildBody(isDark),
            ),
          ],
        ),

        // Floating Today button
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton.extended(
            onPressed: _goToToday,
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
            icon: const Icon(Icons.today, size: 20),
            label: const Text(
              'Today',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Agenda',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_displayMonth),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
              'Error loading agenda',
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
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_bookings.isEmpty) {
      return Center(
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
              'No appointments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confirmed bookings will appear here',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _buildDaysList().length,
        itemBuilder: (context, index) {
          return _buildDaysList()[index];
        },
      ),
    );
  }

  List<Widget> _buildDaysList() {
    if (_bookings.isEmpty) return [];

    // Group bookings by day
    final dayGroups = <DateTime, List<Booking>>{};
    for (final booking in _bookings) {
      final day = DateTime(booking.date.year, booking.date.month, booking.date.day);
      dayGroups.putIfAbsent(day, () => []);
      dayGroups[day]!.add(booking);
    }

    // Build widgets for each day
    final widgets = <Widget>[];
    final sortedDays = dayGroups.keys.toList()..sort();

    for (final day in sortedDays) {
      final bookings = dayGroups[day]!;
      widgets.add(_buildDayCard(day, bookings));
    }

    return widgets;
  }

  Widget _buildDayCard(DateTime date, List<Booking> bookings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final isToday = _isSameDay(date, today);

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F9FF))
            : (isDark ? Colors.black : Colors.white),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date column
            SizedBox(
              width: 60,
              child: Column(
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isToday
                          ? (isDark ? Colors.blue[300] : Colors.blue[700])
                          : (isDark ? Colors.white60 : Colors.black45),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isToday
                          ? (isDark ? Colors.blue[700] : Colors.blue[600])
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bookings column
            Expanded(
              child: Column(
                children: bookings.map((booking) => _buildBookingCard(booking)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _onBookingTap(booking),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.blue[400] : Colors.blue[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.companyName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.startTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : Colors.black38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
