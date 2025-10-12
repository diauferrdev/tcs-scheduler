import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../models/booking.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final ApiService _apiService = ApiService();
  final RealtimeService _realtimeService = RealtimeService();
  late final ScrollController _scrollController;

  List<Booking> _confirmedBookings = [];
  bool _isLoading = true;
  bool _showTodayButton = false;

  // Date range for scroll (1 year back and forward)
  DateTime _earliestDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _latestDate = DateTime.now().add(const Duration(days: 365));

  // Current visible month for sticky header
  String _currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  // Track scroll position for color animation
  double _scrollOffset = 0.0;

  // Flag to prevent multiple simultaneous scroll operations
  bool _isScrollingToToday = false;

  // Constants for height calculations (measured from actual UI)
  // Day card: 16px padding all sides (32px) + ~56px content (text+gap+circle) = 88px
  static const double dayCardHeight = 88.0;
  // Month separator: 8px vertical padding (16px) + 16px content = 32px
  static const double monthSeparatorHeight = 32.0;
  // Week separator: 4px margin vertical (8px) + 1px line = 9px
  static const double weekSeparatorHeight = 9.0;

  @override
  void initState() {
    super.initState();

    // Calculate initial scroll position to center on today
    final initialOffset = _calculateInitialScrollOffset();
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(_onScroll);

    _loadBookings();

    // Setup Colyseus real-time listeners for booking updates
    _realtimeService.onBookingCreated = (booking) {
      debugPrint('[Agenda] New booking via Colyseus: ${booking['title']}');
      _loadBookings();
    };

    _realtimeService.onBookingUpdated = (booking) {
      debugPrint('[Agenda] Booking updated via Colyseus: ${booking['id']}');
      _loadBookings();
    };

    _realtimeService.onBookingDeleted = (bookingId) {
      debugPrint('[Agenda] Booking deleted via Colyseus: $bookingId');
      _loadBookings();
    };
  }

  double _calculateInitialScrollOffset() {
    final today = DateUtils.dateOnly(DateTime.now());
    final daysSinceStart = today.difference(_earliestDate).inDays;

    // Calculate height up to the START of today's card
    double heightBeforeToday = 0.0;
    DateTime currentDate = _earliestDate;

    for (int i = 0; i < daysSinceStart; i++) {
      // Add separator height BEFORE this day
      if (currentDate.day == 1) {
        heightBeforeToday += monthSeparatorHeight;
      } else if (currentDate.weekday == DateTime.monday) {
        heightBeforeToday += weekSeparatorHeight;
      }

      // Add this day's card height
      heightBeforeToday += dayCardHeight;

      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Add today's separator (if any) BEFORE today's card
    if (today.day == 1) {
      heightBeforeToday += monthSeparatorHeight;
    } else if (today.weekday == DateTime.monday) {
      heightBeforeToday += weekSeparatorHeight;
    }

    // In a CustomScrollView, all slivers are part of the scroll,
    // so we don't need to add anything "before" the list
    // The heightBeforeToday already represents the scroll position
    final todayTopPosition = heightBeforeToday;

    // We want today's card CENTER to be at the viewport CENTER
    final estimatedViewport = 700.0;

    // Center position: top position + half of card height
    final todayCenterPosition = todayTopPosition + (dayCardHeight / 2);

    // Scroll offset to center: center position - half viewport
    final centeredOffset = todayCenterPosition - (estimatedViewport / 2);

    return centeredOffset.clamp(0.0, double.infinity);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Clear Colyseus callbacks
    _realtimeService.onBookingCreated = null;
    _realtimeService.onBookingUpdated = null;
    _realtimeService.onBookingDeleted = null;
    super.dispose();
  }

  void _onScroll() {
    final currentScroll = _scrollController.position.pixels;

    // Update scroll offset for color animation
    setState(() {
      _scrollOffset = currentScroll;
    });

    // Update current month based on scroll position
    _updateCurrentMonth();

    // Show "Today" button when scrolled away from today
    _checkShowTodayButton();
  }

  void _updateCurrentMonth() {
    if (!_scrollController.hasClients || !mounted) return;

    final scrollPosition = _scrollController.position.pixels;

    // Estimate which day is visible based on scroll position
    double heightAccumulator = 0.0;
    DateTime currentDate = _earliestDate;
    final totalDays = _latestDate.difference(_earliestDate).inDays;

    for (int i = 0; i <= totalDays; i++) {
      // Add separators height
      if (currentDate.day == 1) {
        heightAccumulator += monthSeparatorHeight;
      } else if (currentDate.weekday == DateTime.monday) {
        heightAccumulator += weekSeparatorHeight;
      }

      // Check if scroll position is within this day's range
      if (scrollPosition >= heightAccumulator && scrollPosition < heightAccumulator + dayCardHeight) {
        final newMonth = DateFormat('MMMM yyyy').format(currentDate);
        if (newMonth != _currentMonth) {
          setState(() {
            _currentMonth = newMonth;
          });
        }
        break;
      }

      heightAccumulator += dayCardHeight;
      currentDate = currentDate.add(const Duration(days: 1));
    }
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);

    try {
      final response = await _apiService.getConfirmedBookings();
      final bookings = (response['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();

      setState(() {
        _confirmedBookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading schedule: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _checkShowTodayButton() {
    if (!_scrollController.hasClients || !mounted) return;

    final today = DateUtils.dateOnly(DateTime.now());
    final daysSinceStart = today.difference(_earliestDate).inDays;

    // Calculate where today's card is positioned
    double heightBeforeToday = 0.0;
    DateTime currentDate = _earliestDate;

    for (int i = 0; i < daysSinceStart; i++) {
      if (currentDate.day == 1) {
        heightBeforeToday += monthSeparatorHeight;
      } else if (currentDate.weekday == DateTime.monday) {
        heightBeforeToday += weekSeparatorHeight;
      }
      heightBeforeToday += dayCardHeight;
      currentDate = currentDate.add(const Duration(days: 1));
    }

    if (today.day == 1) {
      heightBeforeToday += monthSeparatorHeight;
    } else if (today.weekday == DateTime.monday) {
      heightBeforeToday += weekSeparatorHeight;
    }

    // Calculate if today's card is visible in viewport
    final scrollPosition = _scrollController.position.pixels;
    final viewportHeight = _scrollController.position.viewportDimension;

    final todayTop = heightBeforeToday;
    final todayBottom = heightBeforeToday + dayCardHeight;
    final viewportTop = scrollPosition;
    final viewportBottom = scrollPosition + viewportHeight;

    // Check if today's card is at least 50% visible
    final isVisible = todayBottom > viewportTop && todayTop < viewportBottom;
    final visibleHeight = isVisible
        ? (todayBottom.clamp(viewportTop, viewportBottom) - todayTop.clamp(viewportTop, viewportBottom))
        : 0.0;
    final visibilityRatio = visibleHeight / dayCardHeight;

    final shouldShow = visibilityRatio < 0.5; // Show button if less than 50% visible

    if (_showTodayButton != shouldShow) {
      setState(() {
        _showTodayButton = shouldShow;
      });
    }
  }

  void _scrollToToday({bool animated = true}) {
    if (_isScrollingToToday || !_scrollController.hasClients) return;

    _isScrollingToToday = true;

    final today = DateUtils.dateOnly(DateTime.now());
    final daysSinceStart = today.difference(_earliestDate).inDays;

    // Calculate height up to the START of today's card
    double heightBeforeToday = 0.0;
    DateTime currentDate = _earliestDate;

    for (int i = 0; i < daysSinceStart; i++) {
      // Add separator height BEFORE this day
      if (currentDate.day == 1) {
        heightBeforeToday += monthSeparatorHeight;
      } else if (currentDate.weekday == DateTime.monday) {
        heightBeforeToday += weekSeparatorHeight;
      }

      // Add this day's card height
      heightBeforeToday += dayCardHeight;

      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Now add today's separator (if any) BEFORE today's card
    if (today.day == 1) {
      heightBeforeToday += monthSeparatorHeight;
    } else if (today.weekday == DateTime.monday) {
      heightBeforeToday += weekSeparatorHeight;
    }

    // In a CustomScrollView, all slivers are part of the scroll,
    // so we don't need to add anything "before" the list
    // The heightBeforeToday already represents the scroll position
    final todayTopPosition = heightBeforeToday;

    // We want today's card CENTER to be at the viewport CENTER
    final viewportHeight = _scrollController.position.viewportDimension;

    // Center position: top position + half of card height
    final todayCenterPosition = todayTopPosition + (dayCardHeight / 2);

    // Scroll offset to center: center position - half viewport
    final centeredOffset = todayCenterPosition - (viewportHeight / 2);

    final finalOffset = centeredOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    if (animated) {
      _scrollController.animateTo(
        finalOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      ).then((_) {
        _isScrollingToToday = false;
      }).catchError((error) {
        debugPrint('[ScrollToToday] Error: $error');
        _isScrollingToToday = false;
      });
    } else {
      _scrollController.jumpTo(finalOffset);
      _isScrollingToToday = false;
    }
  }


  // Helper to calculate gradient color based on scroll position
  Color _getGradientColor(DateTime date, bool isDark) {
    final today = DateTime.now();
    final daysDiff = date.difference(today).inDays;

    if (isDark) {
      // Dark mode: subtle gradient from black to dark gray
      if (daysDiff < 0) {
        // Past: fade to darker
        final opacity = (daysDiff.abs() / 30).clamp(0.0, 0.4);
        return Color.lerp(Colors.black, const Color(0xFF0A0A0A), opacity)!;
      } else if (daysDiff > 0) {
        // Future: fade to slightly lighter
        final opacity = (daysDiff / 30).clamp(0.0, 0.3);
        return Color.lerp(Colors.black, const Color(0xFF1A1A1A), opacity)!;
      }
      return Colors.black;
    } else {
      // Light mode: subtle gradient from white to light gray
      if (daysDiff < 0) {
        // Past: fade to warmer tone
        final opacity = (daysDiff.abs() / 30).clamp(0.0, 0.3);
        return Color.lerp(Colors.white, const Color(0xFFF5F5F5), opacity)!;
      } else if (daysDiff > 0) {
        // Future: fade to cooler tone
        final opacity = (daysDiff / 30).clamp(0.0, 0.25);
        return Color.lerp(Colors.white, const Color(0xFFFAFAFA), opacity)!;
      }
      return Colors.white;
    }
  }

  // Build all days with visual separators
  Widget _buildAllDaysList(bool isDark) {
    final totalDays = _latestDate.difference(_earliestDate).inDays + 1;
    final today = DateTime.now();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Ensure we don't build more than we have
          if (index >= totalDays) return null;
          final date = _earliestDate.add(Duration(days: index));
          final dayBookings = _confirmedBookings
              .where((b) => isSameDay(b.date, date))
              .toList();

          final isFirstDayOfMonth = date.day == 1;
          final isMonday = date.weekday == DateTime.monday;
          final isToday = isSameDay(date, today);

          return Column(
            children: [
              // Month separator (visual only, not sticky)
              if (isFirstDayOfMonth)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141414) : const Color(0xFFF0F0F0),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFDDDDDD),
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFDDDDDD),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 14,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMMM yyyy').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              // Week separator (on Mondays, except first day of month)
              if (isMonday && !isFirstDayOfMonth)
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (isDark ? Colors.white : Colors.black).withOpacity(0.0),
                        (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                        (isDark ? Colors.white : Colors.black).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              _buildDayCard(date, dayBookings, isDark),
            ],
          );
        },
        childCount: totalDays,
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadBookings,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Schedule Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  child: Text(
                    'My Schedule',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),

              // Sticky Month Header (single, global)
              SliverPersistentHeader(
                pinned: true,
                floating: false,
                delegate: _StickyMonthHeaderDelegate(
                  monthYear: _currentMonth,
                  isDark: isDark,
                ),
              ),

              // Timeline - All days
              _buildAllDaysList(isDark),
            ],
          ),
        ),

        // Floating "Today" button
        if (_showTodayButton)
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: () => _scrollToToday(animated: true),
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

  Widget _buildDayCard(
    DateTime date,
    List<Booking> bookings,
    bool isDark,
  ) {
    final isToday = isSameDay(date, DateTime.now());
    final isPast = date.isBefore(DateTime.now()) && !isToday;
    final gradientColor = _getGradientColor(date, isDark);

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F9FF))
            : gradientColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? const Color(0xFF27272A)
                : const Color(0xFFE5E7EB),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Column
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

            // Events Column
            Expanded(
              child: bookings.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        isPast ? '' : 'No appointments',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    )
                  : Column(
                      children: bookings
                          .map((b) => _buildEventCard(b, isDark))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Booking booking, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue[400] : Colors.blue[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
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
                    const SizedBox(height: 2),
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
            ],
          ),
        ],
      ),
    );
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// Sticky Month Header Delegate
class _StickyMonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String monthYear;
  final bool isDark;

  _StickyMonthHeaderDelegate({
    required this.monthYear,
    required this.isDark,
  });

  @override
  double get minExtent => 48.0;

  @override
  double get maxExtent => 48.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F8F8),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDDD),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 12),
            Text(
              monthYear.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyMonthHeaderDelegate oldDelegate) {
    return monthYear != oldDelegate.monthYear || isDark != oldDelegate.isDark;
  }
}
