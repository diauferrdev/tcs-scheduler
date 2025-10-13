import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/navigation_service.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

/// AgendaScreen - Timeline view of confirmed/approved bookings
///
/// CRITICAL: This screen implements a strict no-infinite-loop architecture:
/// 1. API calls ONLY happen on: initial load, pull-to-refresh, lazy loading (prev/next month)
/// 2. WebSocket events update local state directly WITHOUT triggering API calls
/// 3. All state updates use proper mounted checks to prevent memory leaks
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
  final GlobalKey _todayKey = GlobalKey();

  List<Booking> _confirmedBookings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isNavigating = false;
  bool _isUpdatingState = false; // Prevents scroll triggers during state updates

  // Current month state
  DateTime _currentMonth = DateTime.now();
  String _displayMonth = '';

  // Date range for loaded data
  DateTime? _earliestLoadedMonth;
  DateTime? _latestLoadedMonth;

  // Show today button
  bool _showTodayButton = false;

  // Debouncing for scroll-triggered loads
  DateTime? _lastScrollLoad;
  final Duration _scrollLoadDebounce = const Duration(seconds: 2);

  // Track loaded months to prevent duplicate loads
  final Set<String> _loadedMonths = {};

  @override
  void initState() {
    super.initState();
    _displayMonth = DateFormat('MMMM yyyy').format(_currentMonth);
    _scrollController.addListener(_onScroll);
    _loadInitialMonth();
    _setupWebSocketCallbacks();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _clearWebSocketCallbacks();
    super.dispose();
  }

  /// Setup WebSocket callbacks - CRITICAL: These only update local state
  void _setupWebSocketCallbacks() {
    _realtimeService.onBookingCreated = (bookingData) {
      if (!mounted) return;
      debugPrint('[Agenda] WebSocket: booking_created received');
      _handleWebSocketBookingUpdate(bookingData);
    };

    _realtimeService.onBookingUpdated = (bookingData) {
      if (!mounted) return;
      debugPrint('[Agenda] WebSocket: booking_updated received');
      _handleWebSocketBookingUpdate(bookingData);
    };

    _realtimeService.onBookingDeleted = (bookingId) {
      if (!mounted) return;
      debugPrint('[Agenda] WebSocket: booking_deleted received - ID: $bookingId');
      _handleWebSocketBookingDelete(bookingId);
    };

    _realtimeService.onBookingApproved = (bookingData) {
      if (!mounted) return;
      debugPrint('[Agenda] WebSocket: booking_approved received');
      _handleWebSocketBookingUpdate(bookingData);
    };
  }

  /// Clear WebSocket callbacks on dispose
  void _clearWebSocketCallbacks() {
    _realtimeService.onBookingCreated = null;
    _realtimeService.onBookingUpdated = null;
    _realtimeService.onBookingDeleted = null;
    _realtimeService.onBookingApproved = null;
  }

  /// CRITICAL: Handle WebSocket booking create/update - ONLY updates local state
  /// This method NEVER calls any API - it directly modifies the _confirmedBookings list
  void _handleWebSocketBookingUpdate(Map<String, dynamic> bookingData) {
    if (!mounted) return;

    try {
      final booking = Booking.fromJson(bookingData);
      debugPrint('[Agenda] WEBSOCKET UPDATE - Processing booking: ${booking.id}, status: ${booking.status.name}');

      _isUpdatingState = true; // Prevent scroll listener from triggering during update
      setState(() {
        // Only show APPROVED bookings in agenda
        if (booking.status == BookingStatus.APPROVED) {
          final index = _confirmedBookings.indexWhere((b) => b.id == booking.id);
          if (index >= 0) {
            // Update existing booking
            _confirmedBookings[index] = booking;
            debugPrint('[Agenda] WEBSOCKET UPDATE - Updated existing booking in local state');
          } else {
            // Add new booking
            _confirmedBookings.add(booking);
            // Sort by date to maintain order
            _confirmedBookings.sort((a, b) => a.date.compareTo(b.date));
            debugPrint('[Agenda] WEBSOCKET UPDATE - Added new booking to local state');
          }
        } else {
          // If booking is not approved anymore, remove it
          _confirmedBookings.removeWhere((b) => b.id == booking.id);
          debugPrint('[Agenda] WEBSOCKET UPDATE - Removed non-approved booking from local state');
        }
      });

      // Reset flag after setState completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdatingState = false;
      });
    } catch (e) {
      debugPrint('[Agenda] ERROR parsing WebSocket booking data: $e');
      _isUpdatingState = false;
    }
  }

  /// CRITICAL: Handle WebSocket booking deletion - ONLY updates local state
  /// This method NEVER calls any API - it directly modifies the _confirmedBookings list
  void _handleWebSocketBookingDelete(String bookingId) {
    if (!mounted) return;

    _isUpdatingState = true; // Prevent scroll listener from triggering during update
    setState(() {
      final removedCount = _confirmedBookings.length;
      _confirmedBookings.removeWhere((b) => b.id == bookingId);
      final newCount = _confirmedBookings.length;

      if (removedCount != newCount) {
        debugPrint('[Agenda] WEBSOCKET DELETE - Removed booking $bookingId from local state');
      } else {
        debugPrint('[Agenda] WEBSOCKET DELETE - Booking $bookingId not found in local state');
      }
    });

    // Reset flag after setState completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isUpdatingState = false;
    });
  }

  void _onScroll() {
    // Check if we should show the "Today" button
    _checkShowTodayButton();

    // Check if we need to load more data (lazy loading)
    // CRITICAL: Don't trigger lazy loading during manual navigation OR state updates
    if (!_isLoadingMore && !_isNavigating && !_isUpdatingState && _scrollController.hasClients) {
      // DEBOUNCING: Check if enough time has passed since last scroll load
      final now = DateTime.now();
      if (_lastScrollLoad != null && now.difference(_lastScrollLoad!) < _scrollLoadDebounce) {
        debugPrint('[Agenda] SCROLL LOAD DEBOUNCED - too soon since last load');
        return;
      }

      final position = _scrollController.position;

      // Load previous month when scrolling near top
      if (position.pixels < 300 && _earliestLoadedMonth != null) {
        debugPrint('[Agenda] SCROLL LOAD TRIGGERED - Near top, loading previous month');
        _lastScrollLoad = now; // Update timestamp BEFORE calling load
        _loadPreviousMonth();
      }

      // Load next month when scrolling near bottom
      if (position.pixels > position.maxScrollExtent - 300 && _latestLoadedMonth != null) {
        debugPrint('[Agenda] SCROLL LOAD TRIGGERED - Near bottom, loading next month');
        _lastScrollLoad = now; // Update timestamp BEFORE calling load
        _loadNextMonth();
      }
    }
  }

  void _checkShowTodayButton() {
    // Check if today's date is visible in viewport
    final context = _todayKey.currentContext;
    if (context == null) {
      // Today is not rendered, show button
      if (!_showTodayButton && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _showTodayButton = true);
          }
        });
      }
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      if (!_showTodayButton && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _showTodayButton = true);
          }
        });
      }
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final viewportHeight = MediaQuery.of(this.context).size.height;

    // Check if today card is at least 30% visible in viewport
    final isVisible = position.dy > -renderBox.size.height * 0.7 &&
                      position.dy < viewportHeight * 0.7;

    // Only update if the state actually changed AND use post-frame callback
    final shouldShowButton = !isVisible;
    if (_showTodayButton != shouldShowButton && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showTodayButton != shouldShowButton) {
          setState(() => _showTodayButton = shouldShowButton);
        }
      });
    }
  }

  /// Load initial month on screen open - THIS IS AN API CALL
  Future<void> _loadInitialMonth() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final monthStr = DateFormat('yyyy-MM').format(_currentMonth);
      debugPrint('[Agenda] API CALL - Loading initial month: $monthStr');

      // Check if already loaded
      if (_loadedMonths.contains(monthStr)) {
        debugPrint('[Agenda] Month $monthStr already loaded, skipping API call');
        setState(() => _isLoading = false);
        return;
      }

      final response = await _apiService.getConfirmedBookings(month: monthStr);

      if (!mounted) return;

      final bookings = (response['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();

      // Sort by date
      bookings.sort((a, b) => a.date.compareTo(b.date));

      _isUpdatingState = true; // Prevent scroll listener during update
      setState(() {
        _confirmedBookings = bookings;
        _earliestLoadedMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
        _latestLoadedMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
        _loadedMonths.add(monthStr); // Track loaded month
        _isLoading = false;
      });

      debugPrint('[Agenda] Loaded ${bookings.length} bookings for $monthStr');

      // Scroll to today after initial load - with extra frame delay to ensure widget tree is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isUpdatingState = false;
        // Add an additional frame delay to ensure the widget tree is fully rendered
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Small delay to ensure render is complete
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _scrollToToday(animated: false);
            }
          });
        });
      });
    } catch (e) {
      debugPrint('[Agenda] ERROR loading initial month: $e');
      _isUpdatingState = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading schedule: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// Pull-to-refresh - THIS IS AN API CALL (manual refresh only)
  Future<void> _reloadCurrentMonth() async {
    if (!mounted) return;

    try {
      final monthStr = DateFormat('yyyy-MM').format(_currentMonth);
      debugPrint('[Agenda] Pull-to-refresh: reloading month $monthStr');

      final response = await _apiService.getConfirmedBookings(month: monthStr);

      if (!mounted) return;

      final newBookings = (response['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();

      // Merge with existing bookings from other months
      final otherMonthBookings = _confirmedBookings.where((b) {
        return b.date.year != _currentMonth.year || b.date.month != _currentMonth.month;
      }).toList();

      final allBookings = [...otherMonthBookings, ...newBookings];
      allBookings.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        setState(() {
          _confirmedBookings = allBookings;
        });
      }

      debugPrint('[Agenda] Pull-to-refresh completed: loaded ${newBookings.length} bookings');
    } catch (e) {
      debugPrint('[Agenda] ERROR during pull-to-refresh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing: $e')),
        );
      }
    }
  }

  /// Load previous month (lazy loading) - THIS IS AN API CALL
  Future<void> _loadPreviousMonth() async {
    if (_isLoadingMore || _earliestLoadedMonth == null || !mounted) return;

    setState(() => _isLoadingMore = true);

    try {
      final prevMonth = DateTime(
        _earliestLoadedMonth!.year,
        _earliestLoadedMonth!.month - 1,
        1,
      );
      final monthStr = DateFormat('yyyy-MM').format(prevMonth);
      debugPrint('[Agenda] API CALL - Lazy loading previous month: $monthStr');

      // Check if already loaded
      if (_loadedMonths.contains(monthStr)) {
        debugPrint('[Agenda] Month $monthStr already loaded, skipping API call');
        setState(() => _isLoadingMore = false);
        return;
      }

      final response = await _apiService.getConfirmedBookings(month: monthStr);

      if (!mounted) return;

      final bookings = (response['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();

      if (mounted) {
        _isUpdatingState = true; // Prevent scroll listener during update
        setState(() {
          _confirmedBookings = [...bookings, ..._confirmedBookings];
          _earliestLoadedMonth = prevMonth;
          _loadedMonths.add(monthStr); // Track loaded month
          _isLoadingMore = false;
        });

        // Reset flag after setState completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdatingState = false;
        });
      }

      debugPrint('[Agenda] Loaded ${bookings.length} bookings for previous month $monthStr');
    } catch (e) {
      debugPrint('[Agenda] ERROR loading previous month: $e');
      _isUpdatingState = false;
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// Load next month (lazy loading) - THIS IS AN API CALL
  Future<void> _loadNextMonth() async {
    if (_isLoadingMore || _latestLoadedMonth == null || !mounted) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextMonth = DateTime(
        _latestLoadedMonth!.year,
        _latestLoadedMonth!.month + 1,
        1,
      );
      final monthStr = DateFormat('yyyy-MM').format(nextMonth);
      debugPrint('[Agenda] API CALL - Lazy loading next month: $monthStr');

      // Check if already loaded
      if (_loadedMonths.contains(monthStr)) {
        debugPrint('[Agenda] Month $monthStr already loaded, skipping API call');
        setState(() => _isLoadingMore = false);
        return;
      }

      final response = await _apiService.getConfirmedBookings(month: monthStr);

      if (!mounted) return;

      final bookings = (response['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();

      if (mounted) {
        _isUpdatingState = true; // Prevent scroll listener during update
        setState(() {
          _confirmedBookings = [..._confirmedBookings, ...bookings];
          _latestLoadedMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0);
          _loadedMonths.add(monthStr); // Track loaded month
          _isLoadingMore = false;
        });

        // Reset flag after setState completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdatingState = false;
        });
      }

      debugPrint('[Agenda] Loaded ${bookings.length} bookings for next month $monthStr');
    } catch (e) {
      debugPrint('[Agenda] ERROR loading next month: $e');
      _isUpdatingState = false;
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  /// Navigate to previous month (manual button click) - THIS IS AN API CALL
  /// CRITICAL: This REPLACES the current view, does NOT append
  Future<void> _navigateToPreviousMonth() async {
    if (_isNavigating || !mounted) return;

    setState(() {
      _isNavigating = true;
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _displayMonth = DateFormat('MMMM yyyy').format(_currentMonth);
    });

    try {
      final monthStr = DateFormat('yyyy-MM').format(_currentMonth);
      debugPrint('[Agenda] MANUAL NAV TRIGGERED - Previous month: $monthStr');

      // Check if already loaded
      if (_loadedMonths.contains(monthStr)) {
        debugPrint('[Agenda] Month $monthStr already loaded, skipping API call');
        setState(() => _isNavigating = false);
        return;
      }

      final response = await _apiService.getConfirmedBookings(month: monthStr);

      if (!mounted) return;

      final bookings = (response['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();

      // Sort by date
      bookings.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        _isUpdatingState = true; // Prevent scroll listener during update
        setState(() {
          _confirmedBookings = bookings;
          _earliestLoadedMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
          _latestLoadedMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
          _loadedMonths.clear(); // Clear on manual navigation (replaces view)
          _loadedMonths.add(monthStr); // Track loaded month
          _isNavigating = false;
        });

        // Scroll to top after navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdatingState = false;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }

      debugPrint('[Agenda] Navigated to previous month: loaded ${bookings.length} bookings');
    } catch (e) {
      debugPrint('[Agenda] ERROR navigating to previous month: $e');
      _isUpdatingState = false;
      if (mounted) {
        setState(() => _isNavigating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading month: $e')),
        );
      }
    }
  }

  /// Navigate to next month (manual button click) - THIS IS AN API CALL
  /// CRITICAL: This REPLACES the current view, does NOT append
  Future<void> _navigateToNextMonth() async {
    if (_isNavigating || !mounted) return;

    setState(() {
      _isNavigating = true;
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _displayMonth = DateFormat('MMMM yyyy').format(_currentMonth);
    });

    try {
      final monthStr = DateFormat('yyyy-MM').format(_currentMonth);
      debugPrint('[Agenda] MANUAL NAV TRIGGERED - Next month: $monthStr');

      // Check if already loaded
      if (_loadedMonths.contains(monthStr)) {
        debugPrint('[Agenda] Month $monthStr already loaded, skipping API call');
        setState(() => _isNavigating = false);
        return;
      }

      final response = await _apiService.getConfirmedBookings(month: monthStr);

      if (!mounted) return;

      final bookings = (response['bookings'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();

      // Sort by date
      bookings.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
        _isUpdatingState = true; // Prevent scroll listener during update
        setState(() {
          _confirmedBookings = bookings;
          _earliestLoadedMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
          _latestLoadedMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
          _loadedMonths.clear(); // Clear on manual navigation (replaces view)
          _loadedMonths.add(monthStr); // Track loaded month
          _isNavigating = false;
        });

        // Scroll to top after navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isUpdatingState = false;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }

      debugPrint('[Agenda] Navigated to next month: loaded ${bookings.length} bookings');
    } catch (e) {
      debugPrint('[Agenda] ERROR navigating to next month: $e');
      _isUpdatingState = false;
      if (mounted) {
        setState(() => _isNavigating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading month: $e')),
        );
      }
    }
  }

  void _scrollToToday({bool animated = true}) {
    final context = _todayKey.currentContext;
    if (context == null) {
      // Today is not in the loaded range, need to reload
      final today = DateTime.now();
      setState(() {
        _currentMonth = today;
        _displayMonth = DateFormat('MMMM yyyy').format(today);
      });
      _loadInitialMonth();
      return;
    }

    // Scroll to today's card
    Scrollable.ensureVisible(
      context,
      duration: animated ? const Duration(milliseconds: 500) : Duration.zero,
      curve: Curves.easeInOutCubic,
      alignment: 0.2, // Position 20% from top of viewport
    );
  }

  void _onBookingTap(Booking booking) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;

    if (user == null) return;

    // Navigate based on user role
    if (user.role == UserRole.USER) {
      _navigationService.navigateToBookingDetails(booking.id);
    } else {
      // ADMIN or MANAGER
      _navigationService.navigateToApprovalsWithBooking(booking.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          debugPrint('[Agenda] Back button pressed - navigating back');
        }
      },
      child: Stack(
      children: [
        RefreshIndicator(
          onRefresh: _reloadCurrentMonth,
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
                      Row(
                        children: [
                          // Previous Month Button
                          IconButton(
                            onPressed: _isNavigating ? null : _navigateToPreviousMonth,
                            icon: Icon(
                              Icons.chevron_left,
                              color: _isNavigating
                                  ? (isDark ? Colors.grey[700] : Colors.grey[300])
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                            tooltip: 'Previous Month',
                          ),
                          Text(
                            _displayMonth,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          // Next Month Button
                          IconButton(
                            onPressed: _isNavigating ? null : _navigateToNextMonth,
                            icon: Icon(
                              Icons.chevron_right,
                              color: _isNavigating
                                  ? (isDark ? Colors.grey[700] : Colors.grey[300])
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                            tooltip: 'Next Month',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Timeline - Days grouped by month
              _buildDaysList(isDark),
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
      ),
    );
  }

  Widget _buildDaysList(bool isDark) {
    if (_earliestLoadedMonth == null || _latestLoadedMonth == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Build list of all days in loaded range
    final days = <DateTime>[];
    var currentDate = _earliestLoadedMonth!;
    final endDate = _latestLoadedMonth!;

    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      days.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= days.length) return null;

          final date = days[index];
          final dayBookings = _confirmedBookings
              .where((b) => _isSameDay(b.date, date))
              .toList();

          final isFirstDayOfMonth = date.day == 1;
          final isMonday = date.weekday == DateTime.monday;
          final isToday = _isSameDay(date, DateTime.now());

          return Column(
            key: isToday ? _todayKey : null,
            children: [
              // Month separator
              if (isFirstDayOfMonth)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                        size: 16,
                        color: isDark ? Colors.white60 : Colors.black45,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMMM yyyy').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              // Week separator (on Mondays, except first day of month)
              if (isMonday && !isFirstDayOfMonth)
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        childCount: days.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
      ),
    );
  }

  Widget _buildDayCard(
    DateTime date,
    List<Booking> bookings,
    bool isDark,
  ) {
    final isToday = _isSameDay(date, DateTime.now());
    final isPast = date.isBefore(DateTime.now()) && !isToday;

    return Container(
      decoration: BoxDecoration(
        color: isToday
            ? (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F9FF))
            : (isDark ? Colors.black : Colors.white),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
