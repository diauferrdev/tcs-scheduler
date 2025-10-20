import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/navigation_service.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

/// Modern Agenda Screen - Timeline view of confirmed bookings
///
/// Simple architecture:
/// - Shows only days WITH bookings (no empty days)
/// - Month-by-month navigation with Previous/Next buttons
/// - "Today" button to jump to current month
/// - No infinite scroll - full control of data display
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final ApiService _apiService = ApiService();
  final RealtimeService _realtimeService = RealtimeService();
  final NavigationService _navigationService = NavigationService();

  // State
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  // Current month being displayed
  DateTime _currentMonth = DateTime.now();

  // Keep listener references for cleanup
  late final Function(Map<String, dynamic>) _onBookingCreatedListener;
  late final Function(Map<String, dynamic>) _onBookingUpdatedListener;
  late final Function(Map<String, dynamic>) _onBookingApprovedListener;
  late final Function(String) _onBookingDeletedListener;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    _loadMonth(_currentMonth);
  }

  @override
  void dispose() {
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

      // Only update if booking is in current month
      if (booking.date.year == _currentMonth.year &&
          booking.date.month == _currentMonth.month) {
        setState(() {
          final index = _bookings.indexWhere((b) => b.id == booking.id);
          if (index >= 0) {
            _bookings[index] = booking;
          } else {
            _bookings.add(booking);
            _bookings.sort((a, b) => a.date.compareTo(b.date));
          }
        });
      }
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

  /// Load bookings for a specific month
  Future<void> _loadMonth(DateTime month) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _currentMonth = DateTime(month.year, month.month);
    });

    try {
      final monthStr = DateFormat('yyyy-MM').format(month);
      debugPrint('[Agenda] Loading month: $monthStr');

      final response = await _apiService.getConfirmedBookings(month: monthStr);
      final bookings = (response['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();

      // Sort by date and time
      bookings.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.startTime.compareTo(b.startTime);
      });

      if (!mounted) return;

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });

      debugPrint('[Agenda] Loaded ${bookings.length} bookings for $monthStr');
    } catch (e) {
      debugPrint('[Agenda] Error loading month: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Navigate to previous month
  void _goToPreviousMonth() {
    final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    _loadMonth(prevMonth);
  }

  /// Navigate to next month
  void _goToNextMonth() {
    final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    _loadMonth(nextMonth);
  }

  /// Navigate to current month
  void _goToToday() {
    _loadMonth(DateTime.now());
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

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: _buildBody(isDark),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    final isCurrentMonth = _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Agenda',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          // Month navigation
          Row(
            children: [
              // Previous month button
              IconButton(
                onPressed: _goToPreviousMonth,
                icon: const Icon(Icons.chevron_left),
                color: isDark ? Colors.white : Colors.black,
                tooltip: 'Previous month',
              ),

              // Current month display
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),

              // Next month button
              IconButton(
                onPressed: _goToNextMonth,
                icon: const Icon(Icons.chevron_right),
                color: isDark ? Colors.white : Colors.black,
                tooltip: 'Next month',
              ),

              const SizedBox(width: 8),

              // Today button
              OutlinedButton.icon(
                onPressed: isCurrentMonth ? null : _goToToday,
                icon: const Icon(Icons.today, size: 16),
                label: const Text('Today'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  side: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      );
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
              onPressed: () => _loadMonth(_currentMonth),
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
              Icons.event_available,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No events this month',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confirmed bookings for ${DateFormat('MMMM').format(_currentMonth)} will appear here',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group bookings by day
    final groupedBookings = <DateTime, List<Booking>>{};
    for (final booking in _bookings) {
      final day = DateTime(booking.date.year, booking.date.month, booking.date.day);
      groupedBookings.putIfAbsent(day, () => []);
      groupedBookings[day]!.add(booking);
    }

    final sortedDays = groupedBookings.keys.toList()..sort();

    // Always include today at the top if it's in the current month
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final isCurrentMonth = _currentMonth.year == today.year && _currentMonth.month == today.month;

    // Build final list with today first if applicable
    final List<DateTime> finalDays = [];
    if (isCurrentMonth) {
      finalDays.add(todayNormalized);
      // Add other days that are not today
      for (final day in sortedDays) {
        if (!_isSameDay(day, todayNormalized)) {
          finalDays.add(day);
        }
      }
    } else {
      // Not current month, just show sorted days
      finalDays.addAll(sortedDays);
    }

    return RefreshIndicator(
      onRefresh: () => _loadMonth(_currentMonth),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: finalDays.length,
        itemBuilder: (context, index) {
          final day = finalDays[index];
          final dayBookings = groupedBookings[day] ?? [];
          final isFirst = index == 0;
          final isLast = index == finalDays.length - 1;
          return _buildDayCard(day, dayBookings, isDark, isFirst, isLast);
        },
      ),
    );
  }

  Widget _buildDayCard(DateTime date, List<Booking> bookings, bool isDark, bool isFirst, bool isLast) {
    final today = DateTime.now();
    final isToday = _isSameDay(date, today);
    final isPast = date.isBefore(DateTime(today.year, today.month, today.day));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line on the left
          Column(
            children: [
              // Line above badge (only if not first day)
              if (!isFirst)
                Container(
                  width: 3,
                  height: 20,
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                ),
              // Weekday badge
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isToday
                      ? (isDark ? Colors.blue[700] : Colors.blue[600])
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('EEE').format(date).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isToday
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ),
              // Line below badge (continues to next day, only if not last)
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 3,
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Day content
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header - aligned with badge
                  Row(
                    children: [
                      // Day number (large)
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? (isDark ? Colors.blue[400] : Colors.blue[600])
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Month and year only (without repeating day)
                      Text(
                        DateFormat('MMMM yyyy').format(date),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),

                      const Spacer(),

                      // Badge with event count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isToday
                              ? (isDark ? Colors.blue[700]!.withOpacity(0.3) : Colors.blue[100])
                              : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${bookings.length} event${bookings.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? (isDark ? Colors.blue[300] : Colors.blue[700])
                                : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Bookings list
                  ...bookings.asMap().entries.map((entry) {
                    final booking = entry.value;
                    return _buildBookingCard(booking, isDark, isPast);
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, bool isDark, bool isPast) {
    return InkWell(
      onTap: () => _onBookingTap(booking),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
                const SizedBox(width: 6),
                Text(
                  booking.startTime,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getDurationText(booking.duration),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Company name
            Text(
              booking.companyName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 6),

            // Visit type
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getVisitTypeColor(booking.visitType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getVisitTypeLabel(booking.visitType),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getVisitTypeColor(booking.visitType),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.people_outline,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                const SizedBox(width: 4),
                Text(
                  '${booking.expectedAttendees} attendees',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getDurationText(VisitDuration duration) {
    switch (duration) {
      case VisitDuration.ONE_HOUR:
        return '1h';
      case VisitDuration.TWO_HOURS:
        return '2h';
      case VisitDuration.THREE_HOURS:
        return '3h';
      case VisitDuration.FOUR_HOURS:
        return '4h';
      case VisitDuration.FIVE_HOURS:
        return '5h';
      case VisitDuration.SIX_HOURS:
        return '6h';
    }
  }

  String _getVisitTypeLabel(VisitType type) {
    switch (type) {
      case VisitType.PACE_TOUR:
        return 'Pace Tour';
      case VisitType.PACE_EXPERIENCE:
        return 'Pace Experience';
      case VisitType.INNOVATION_EXCHANGE:
        return 'Innovation Exchange';
    }
  }

  Color _getVisitTypeColor(VisitType type) {
    switch (type) {
      case VisitType.PACE_TOUR:
        return const Color(0xFF3B82F6); // Blue
      case VisitType.PACE_EXPERIENCE:
        return const Color(0xFF8B5CF6); // Purple
      case VisitType.INNOVATION_EXCHANGE:
        return const Color(0xFF06B6D4); // Cyan
    }
  }
}
