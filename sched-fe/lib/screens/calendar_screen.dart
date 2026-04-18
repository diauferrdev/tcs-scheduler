// ignore_for_file: constant_identifier_names

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/navigation_service.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../utils/time_formatter.dart';
import '../utils/toast_notification.dart';
import 'booking_form_screen.dart';
import '../services/booking_flow_service.dart';

enum CalendarViewType {
  month,
  week,
  day,
}

class CalendarScreen extends StatefulWidget {
  final bool skipLayout;
  final String? draftIdToEdit; // Optional draft ID to open for editing
  final Function(DateTime)? onDaySelected; // Optional callback when a day is clicked (for reschedule drawer)

  const CalendarScreen({
    super.key,
    this.skipLayout = false,
    this.draftIdToEdit,
    this.onDaySelected,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final RealtimeService _realtimeService = RealtimeService();

  List<Booking> _bookings = [];
  bool _loading = true;
  String? _error;
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  Booking? _selectedBooking;
  bool _showCancelDialog = false;
  String _selectedTab = 'Month';

  // PageView state for seamless month scrolling
  late PageController _pageController;
  int _currentPage = 12; // Start at index 12 (allows scrolling 12 months back)

  // PageView state for year scrolling
  late PageController _yearPageController;
  int _currentYearPage = 10; // Start at index 10 (allows scrolling back/forward)

  // Availability state
  final Map<String, DayAvailability> _availabilityCache = {};
  DayAvailability? _selectedDayAvailability;

  // Month/Year grid cache to prevent expensive rebuilds
  final Map<String, Widget> _monthGridCache = {};
  final Map<String, Widget> _yearGridCache = {};

  // Selected visit type for booking
  String? _selectedVisitType; // PACE_TOUR or INNOVATION_EXCHANGE

  // Keep listener references for proper cleanup
  late final Function(Map<String, dynamic>) _onBookingCreatedListener;
  late final Function(Map<String, dynamic>) _onBookingUpdatedListener;
  late final Function(Map<String, dynamic>) _onBookingApprovedListener;
  late final Function(String) _onBookingDeletedListener;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 1.0,
      keepPage: true,
    );
    _yearPageController = PageController(
      initialPage: _currentYearPage,
      viewportFraction: 1.0,
      keepPage: true,
    );
    _selectedDate = DateTime.now(); // Select current day by default
    _loadBookings();
    _loadDayAvailability(_selectedDate!); // Load availability for current day
    _setupRealtimeListeners();

    // If draftIdToEdit is provided, load and open the draft for editing
    if (widget.draftIdToEdit != null) {
      _loadAndOpenDraft(widget.draftIdToEdit!);
    }
  }

  /// Load draft booking and open form for editing
  Future<void> _loadAndOpenDraft(String draftId) async {
    try {
      final booking = await _apiService.getBookingById(draftId);
      final draftBooking = Booking.fromJson(booking);

      // Set the selected date to the draft's date
      setState(() {
        _selectedDate = draftBooking.date;
        _currentMonth = DateTime(draftBooking.date.year, draftBooking.date.month);
      });

      // Load availability for the draft's date
      await _loadDayAvailability(draftBooking.date);

      // Open booking form with draft data after a short delay to ensure UI is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showBookingFormWithDraft(draftBooking);
        }
      });
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Error loading draft: $e',
          type: ToastType.error,
        );
      }
    }
  }

  void _showBookingFormWithDraft(Booking draft) {
    // Parse start time to TimeOfDay
    final timeParts = draft.startTime.split(':');
    final startTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    // Calculate duration from the draft
    final durationMap = {
      'ONE_HOUR': 1,
      'TWO_HOURS': 2,
      'THREE_HOURS': 3,
      'FOUR_HOURS': 4,
      'FIVE_HOURS': 5,
      'SIX_HOURS': 6,
    };
    final duration = durationMap[draft.duration.name] ?? 4;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingFormScreen(
          selectedDate: draft.date,
          startTime: startTime,
          duration: duration,
          existingBooking: draft, // CRITICAL: Pass draft booking to prefill form
        ),
        fullscreenDialog: true,
      ),
    ).then((result) {
      if (result == true) {
        _loadBookings(); // Refresh bookings after form closes
      }
    });
  }

  /// Setup real-time listeners for calendar updates
  void _setupRealtimeListeners() {
    // Create listener references
    _onBookingCreatedListener = (booking) {
      _loadBookings(showLoading: false); // Silent refresh on WebSocket update
    };

    _onBookingUpdatedListener = (booking) {
      _loadBookings(showLoading: false); // Silent refresh on WebSocket update
    };

    _onBookingApprovedListener = (booking) {
      _loadBookings(showLoading: false); // Silent refresh on WebSocket update
    };

    _onBookingDeletedListener = (bookingId) {
      _loadBookings(showLoading: false); // Silent refresh on WebSocket update
    };

    // Add listeners to service
    _realtimeService.addBookingCreatedListener(_onBookingCreatedListener);
    _realtimeService.addBookingUpdatedListener(_onBookingUpdatedListener);
    _realtimeService.addBookingApprovedListener(_onBookingApprovedListener);
    _realtimeService.addBookingDeletedListener(_onBookingDeletedListener);
  }

  @override
  void dispose() {
    // Remove listeners to prevent memory leaks
    _realtimeService.removeBookingCreatedListener(_onBookingCreatedListener);
    _realtimeService.removeBookingUpdatedListener(_onBookingUpdatedListener);
    _realtimeService.removeBookingApprovedListener(_onBookingApprovedListener);
    _realtimeService.removeBookingDeletedListener(_onBookingDeletedListener);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings({bool showLoading = true}) async {
    try {
      if (showLoading) {
        setState(() {
          _loading = true;
          _error = null;
        });
      } else {
        setState(() {
          _error = null;
        });
      }

      // Get user role to determine which endpoint to use
      final authProvider = context.read<AuthProvider>();
      final userRole = authProvider.user?.role;

      // ADMIN/MANAGER: Use availability-admin endpoint (shows PENDING + APPROVED)
      // USER: Use availability endpoint (shows only APPROVED bookings, not PENDING)
      final response = (userRole == UserRole.ADMIN || userRole == UserRole.MANAGER)
          ? await _apiService.getBookingsAvailabilityForAdmins(null)
          : await _apiService.getBookingsAvailability(null);
      final bookingsData = response['bookings'] as List;


      // Check if still mounted before setState (WebSocket can trigger after navigation)
      if (!mounted) {
        return;
      }

      setState(() {
        _bookings = bookingsData.map((e) => Booking.fromJson(e)).toList();
        // Clear calendar caches when bookings change
        _monthGridCache.clear();
        _yearGridCache.clear();
        // Sort bookings by date, then by startTime (morning first, then afternoon)
        _bookings.sort((a, b) {
          final dateComparison = a.date.compareTo(b.date);
          if (dateComparison != 0) return dateComparison;
          // If same date, sort by startTime
          return a.startTime.compareTo(b.startTime);
        });
        if (showLoading) {
          _loading = false;
        } else {
        }
      });
    } catch (e) {

      // Check if still mounted before setState
      if (!mounted) {
        return;
      }

      setState(() {
        _error = e.toString();
        if (showLoading) {
          _loading = false;
        }
      });
    }
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Calculate the minimum bookable date (7 business days from today)
  /// If today is a weekend, starts counting from the next Monday
  DateTime _getMinimumBookableDate() {
    DateTime date = DateTime.now();

    // If today is weekend, skip to next Monday
    while (_isWeekend(date)) {
      date = date.add(const Duration(days: 1));
    }

    // Now count 7 business days from the first business day
    int businessDaysAdded = 0;
    while (businessDaysAdded < 7) {
      date = date.add(const Duration(days: 1));
      if (!_isWeekend(date)) {
        businessDaysAdded++;
      }
    }

    return DateTime(date.year, date.month, date.day);
  }

  /// Check if a date is valid for booking (at least 7 business days from today)
  bool _isDateBookable(DateTime date) {
    final userRole = context.read<AuthProvider>().user?.role;
    // MANAGER and ADMIN can book past dates (to register historical events)
    if (userRole == UserRole.MANAGER || userRole == UserRole.ADMIN) {
      return !_isWeekend(date);
    }
    final minDate = _getMinimumBookableDate();
    return !date.isBefore(minDate) && !_isWeekend(date);
  }

  /// Get previous business day (skip weekends)
  DateTime _getPreviousBusinessDay(DateTime date) {
    DateTime prevDay = date.subtract(const Duration(days: 1));
    while (_isWeekend(prevDay)) {
      prevDay = prevDay.subtract(const Duration(days: 1));
    }
    return prevDay;
  }

  /// Get next business day (skip weekends)
  DateTime _getNextBusinessDay(DateTime date) {
    DateTime nextDay = date.add(const Duration(days: 1));
    while (_isWeekend(nextDay)) {
      nextDay = nextDay.add(const Duration(days: 1));
    }
    return nextDay;
  }

  /// Calculate prep/teardown blocks for Innovation Exchange events
  /// Returns a map: {date: {morning: blocked, afternoon: blocked}}
  /// Only APPROVED bookings block periods (PENDING do not block)
  Map<String, Map<String, bool>> _calculateInnovationExchangeBlocks() {
    final blocks = <String, Map<String, bool>>{};

    // Find all APPROVED Innovation Exchange bookings
    // Only APPROVED bookings block periods
    final ieBookings = _bookings.where((b) =>
      b.visitType == VisitType.INNOVATION_EXCHANGE &&
      b.status == BookingStatus.APPROVED
    ).toList();

    for (final ie in ieBookings) {
      final eventDate = ie.date;
      final eventHour = int.parse(ie.startTime.split(':')[0]);
      final isMorning = eventHour < 13;

      final eventDateStr = DateFormat('yyyy-MM-dd').format(eventDate);

      if (isMorning) {
        // IE in MORNING:
        // - Prep: previous business day AFTERNOON
        // - Event: same day MORNING
        // - Teardown: same day AFTERNOON

        final prevDay = _getPreviousBusinessDay(eventDate);
        final prevDayStr = DateFormat('yyyy-MM-dd').format(prevDay);

        // Block previous day afternoon (prep)
        blocks[prevDayStr] = blocks[prevDayStr] ?? {'morning': false, 'afternoon': false};
        blocks[prevDayStr]!['afternoon'] = true;

        // Block event day morning (event) and afternoon (teardown)
        blocks[eventDateStr] = blocks[eventDateStr] ?? {'morning': false, 'afternoon': false};
        blocks[eventDateStr]!['morning'] = true;
        blocks[eventDateStr]!['afternoon'] = true;
      } else {
        // IE in AFTERNOON:
        // - Prep: same day MORNING
        // - Event: same day AFTERNOON
        // - Teardown: next business day MORNING

        final nextDay = _getNextBusinessDay(eventDate);
        final nextDayStr = DateFormat('yyyy-MM-dd').format(nextDay);

        // Block event day morning (prep) and afternoon (event)
        blocks[eventDateStr] = blocks[eventDateStr] ?? {'morning': false, 'afternoon': false};
        blocks[eventDateStr]!['morning'] = true;
        blocks[eventDateStr]!['afternoon'] = true;

        // Block next day morning (teardown)
        blocks[nextDayStr] = blocks[nextDayStr] ?? {'morning': false, 'afternoon': false};
        blocks[nextDayStr]!['morning'] = true;
      }
    }

    return blocks;
  }

  List<Booking> _getBookingsForDay(DateTime date, {bool filterForAdminManager = false}) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayBookings = _bookings.where((b) {
      final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);

      // Filter by date and not cancelled
      if (bookingDate != dateStr || b.status == BookingStatus.CANCELLED) {
        return false;
      }

      // For ADMIN/MANAGER: when clicking a day, show only UNDER_REVIEW and APPROVED
      if (filterForAdminManager) {
        return b.status == BookingStatus.UNDER_REVIEW ||
               b.status == BookingStatus.APPROVED;
      }

      // For other uses (calendar rendering, etc.): show all statuses
      return true;
    }).toList();

    // ALWAYS sort by startTime to ensure morning bookings come first
    dayBookings.sort((a, b) => a.startTime.compareTo(b.startTime));

    return dayBookings;
  }

  /// Get prep/teardown blocks for a specific day
  /// Only returns blocks for prep/teardown (NOT for the actual IE event)
  List<Map<String, String>> _getIEBlocksForDay(DateTime date) {
    final blocks = <Map<String, String>>[];
    final ieBlocks = _calculateInnovationExchangeBlocks();
    final dayStr = DateFormat('yyyy-MM-dd').format(date);

    if (ieBlocks.containsKey(dayStr)) {
      if (ieBlocks[dayStr]!['morning'] == true) {
        // Check if this is the actual IE event or prep/teardown
        final hasIEMorning = _bookings.any((b) {
          final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);
          final eventHour = int.parse(b.startTime.split(':')[0]);
          return bookingDate == dayStr &&
                 b.visitType == VisitType.INNOVATION_EXCHANGE &&
                 eventHour < 13 &&
                 b.status == BookingStatus.APPROVED;
        });

        // Only add block if it's prep/teardown (NOT the actual IE event)
        if (!hasIEMorning) {
          // Determine if it's prep or teardown by checking adjacent days
          String blockType = 'Reserved';

          // Check if there's an IE in the afternoon of same day (this would be prep for that IE)
          final hasIEAfternoonSameDay = _bookings.any((b) {
            final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);
            final eventHour = int.parse(b.startTime.split(':')[0]);
            return bookingDate == dayStr &&
                   b.visitType == VisitType.INNOVATION_EXCHANGE &&
                   eventHour >= 13 &&
                   b.status == BookingStatus.APPROVED;
          });

          if (hasIEAfternoonSameDay) {
            blockType = 'Prep for IE (same day afternoon)';
          } else {
            // Must be teardown from previous day IE
            blockType = 'Teardown from IE (previous day)';
          }

          blocks.add({
            'period': 'Morning',
            'label': blockType,
            'time': '09:00 - 13:00',
            'sortOrder': '0', // Morning first
          });
        }
      }

      if (ieBlocks[dayStr]!['afternoon'] == true) {
        // Check if this is the actual IE event or prep/teardown
        final hasIEAfternoon = _bookings.any((b) {
          final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);
          final eventHour = int.parse(b.startTime.split(':')[0]);
          return bookingDate == dayStr &&
                 b.visitType == VisitType.INNOVATION_EXCHANGE &&
                 eventHour >= 13 &&
                 b.status == BookingStatus.APPROVED;
        });

        // Only add block if it's prep/teardown (NOT the actual IE event)
        if (!hasIEAfternoon) {
          // Determine if it's prep or teardown by checking adjacent days
          String blockType = 'Reserved';

          // Check if there's an IE in the morning of same day (this would be teardown for that IE)
          final hasIEMorningSameDay = _bookings.any((b) {
            final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);
            final eventHour = int.parse(b.startTime.split(':')[0]);
            return bookingDate == dayStr &&
                   b.visitType == VisitType.INNOVATION_EXCHANGE &&
                   eventHour < 13 &&
                   b.status == BookingStatus.APPROVED;
          });

          if (hasIEMorningSameDay) {
            blockType = 'Teardown from IE (same day morning)';
          } else {
            // Must be prep for next day IE
            blockType = 'Prep for IE (next day)';
          }

          blocks.add({
            'period': 'Afternoon',
            'label': blockType,
            'time': '13:00 - 17:00',
            'sortOrder': '1', // Afternoon after morning
          });
        }
      }
    }

    return blocks;
  }

  Future<void> _loadDayAvailability(DateTime date, {String? visitType}) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // CRITICAL: Clear old data first to prevent race condition
      // This forces SlotPicker polling to wait for the new data with correct visitType
      setState(() {
        _selectedDayAvailability = null;
      });

      final response = await _apiService.checkAvailability(dateStr, visitType: visitType);

      setState(() {
        final availability = DayAvailability.fromJson(response);
        _availabilityCache[dateStr] = availability;
        _selectedDayAvailability = availability;

        // Debug: Print API response
        // Availability data loaded successfully
      });
    } catch (e) {
    }
  }

  void _showSlotPickerDrawer(DateTime date, {Function(TimeOfDay, int)? onSlotSelected, VoidCallback? onBack}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visitTypeLabel = _selectedVisitType == 'PACE_TOUR' ? 'Pace Tour' : 'Innovation Exchange';

    // Check user role to determine if we should show block details
    final authProvider = context.read<AuthProvider>();
    final isUserRole = authProvider.user?.role == UserRole.USER;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => SlotPickerContentWithLoading(
        date: date,
        visitTypeLabel: visitTypeLabel,
        selectedVisitType: _selectedVisitType,
        isUserRole: isUserRole,
        isDark: isDark,
        onSlotSelected: onSlotSelected,
        onClose: _closeSlotPickerAndClearCache,
        onBack: onBack,
        // Pass callback to get current availability
        getAvailability: () => _selectedDayAvailability,
      ),
    ).whenComplete(() => _closeSlotPickerAndClearCache());
  }

  void _closeSlotPickerAndClearCache() {
    if (_selectedDate != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      setState(() {
        _availabilityCache.remove(dateStr);
        _selectedDayAvailability = null;
        _selectedVisitType = null;
      });
    }
  }

  Future<void> _showVisitTypeSelectionDialog(DateTime date) async {
    // Start the new booking flow with engagement type selection
    // This will chain through: Engagement Type → Visit Type (if needed) → Period Selection → Base Info → Questionnaire (if needed)
    final flowService = BookingFlowService();

    await flowService.startBookingFlowWithPeriodSelection(
      context,
      selectedDate: date,
      onPeriodSelected: (startTime) {
        // Reload bookings after flow completes
        _loadBookings();
      },
      // Pass wrapper functions with correct signatures
      loadAvailability: (DateTime date, String visitType) {
        return _loadDayAvailability(date, visitType: visitType);
      },
      showSlotPicker: (DateTime date, Function(TimeOfDay, int) onSlotSelected, VoidCallback? onBack) {
        _showSlotPickerDrawer(date, onSlotSelected: onSlotSelected, onBack: onBack);
      },
    );
  }

  List<AvailableTimeSlot> _getAvailableSlots(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final availability = _availabilityCache[dateStr];

    if (availability != null) {
      return availability.availableTimeSlots;
    }

    // If not in cache, calculate based on existing bookings
    // Don't return empty - instead calculate what's likely available
    return _calculateAvailableSlotsFromBookings(date);
  }

  List<AvailableTimeSlot> _calculateAvailableSlotsFromBookings(DateTime date) {
    // Get ONLY APPROVED bookings for availability calculation
    // Only APPROVED bookings block slots
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final activeBookings = _bookings.where((b) {
      final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);
      return bookingDate == dateStr &&
             b.status == BookingStatus.APPROVED;
    }).toList();

    // Use period-based logic (MORNING: 9-13, AFTERNOON: 13-17)
    // Check which periods are occupied
    bool morningOccupied = false;
    bool afternoonOccupied = false;

    // 1. Check actual bookings
    for (final booking in activeBookings) {
      final startHour = int.parse(booking.startTime.split(':')[0]);
      final durationHours = {
        VisitDuration.ONE_HOUR: 1,
        VisitDuration.TWO_HOURS: 2,
        VisitDuration.THREE_HOURS: 3,
        VisitDuration.FOUR_HOURS: 4,
        VisitDuration.FIVE_HOURS: 5,
        VisitDuration.SIX_HOURS: 6,
      }[booking.duration] ?? 2;

      final endHour = startHour + durationHours;

      // Check if booking occupies morning period (9-13)
      if (startHour < 13 && endHour > 9) {
        morningOccupied = true;
      }

      // Check if booking occupies afternoon period (13-17)
      if (startHour < 17 && endHour > 13) {
        afternoonOccupied = true;
      }
    }

    // 2. Check Innovation Exchange prep/teardown blocks
    final ieBlocks = _calculateInnovationExchangeBlocks();
    if (ieBlocks.containsKey(dateStr)) {
      if (ieBlocks[dateStr]!['morning'] == true) {
        morningOccupied = true;
      }
      if (ieBlocks[dateStr]!['afternoon'] == true) {
        afternoonOccupied = true;
      }
    }

    // Return available periods
    final availableSlots = <AvailableTimeSlot>[];

    if (!morningOccupied) {
      availableSlots.add(AvailableTimeSlot(time: '09:00', maxDuration: 4));
    }

    if (!afternoonOccupied) {
      availableSlots.add(AvailableTimeSlot(time: '13:00', maxDuration: 4));
    }

    return availableSlots;
  }

  void _handleBookingClick(Booking booking) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.user?.role;
    final navigationService = NavigationService();

    // Navigate based on user role
    if (userRole == UserRole.USER) {
      // USER: Navigate to My Bookings with booking details
      navigationService.navigateToBookingDetails(booking.id);
    } else {
      // ADMIN/MANAGER: Navigate to Approvals with booking details
      navigationService.navigateToApprovalsWithBooking(booking.id);
    }
  }

  Future<void> _handleCancelBooking() async {
    if (_selectedBooking == null) return;

    try {
      await _apiService.deleteBooking(_selectedBooking!.id);

      if (mounted) {
        // Clear availability cache to force fresh data
        _availabilityCache.clear();

        ToastNotification.show(
          context,
          message: 'Booking cancelled successfully',
          type: ToastType.success,
        );
        setState(() {
          _showCancelDialog = false;
          _selectedBooking = null;
        });
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Failed to cancel booking: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isUserRole = authProvider.user?.isUser ?? false;

    final content = Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.white : Colors.black,
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBookings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Calendar container with fixed header and animated content
                    Expanded(
                      flex: _selectedTab == 'Year' ? 100 : 70,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.only(left: 0, right: 12, top: 12, bottom: 12),
                        child: Column(
                          children: [
                            // FIXED HEADER - stays the same for both views
                            _buildCalendarHeader(isDark),
                            const SizedBox(height: 12),
                            // CONTENT - cached views with smooth fade in
                            Expanded(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(_selectedTab),
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, opacity, child) {
                                  return Opacity(
                                    opacity: opacity,
                                    child: child,
                                  );
                                },
                                child: IndexedStack(
                                  index: _selectedTab == 'Month' ? 0 : 1,
                                  children: [
                                    _buildMonthContent(isDark, authProvider),
                                    _buildYearContent(isDark, authProvider),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Events section - only visible in Month view
                    if (_selectedTab != 'Year') ...[
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 30,
                        child: _buildEventsSection(isDark, isMobile, isUserRole),
                      ),
                    ],
                  ],
                ),
    );

    final wrapped = widget.skipLayout ? content : AppLayout(child: content);

    // Determine if FAB should be shown
    final userRole = authProvider.user?.role;
    final isManagerOrAdmin = userRole == UserRole.MANAGER || userRole == UserRole.ADMIN;
    final canCreateBooking = _selectedDate != null &&
        _isDateBookable(_selectedDate!) &&
        (isManagerOrAdmin || _getAvailableSlots(_selectedDate!).isNotEmpty) &&
        _selectedTab != 'Year';

    return Stack(
      children: [
        wrapped,
        // Cancel confirmation dialog
        if (_showCancelDialog)
          _buildCancelDialog(isDark),
        // Floating Action Button for creating new events - hidden in Year view
        if (canCreateBooking)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () {
                _showVisitTypeSelectionDialog(_selectedDate!);
              },
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_circle),
              label: const Text(
                'New Event',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              elevation: 4,
            ),
          ),
      ],
    );
  }

  /// Fixed header for both Month and Year views
  Widget _buildCalendarHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        // Calendar icon + date label with animated transition
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, -0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: Text(
                _selectedTab == 'Year'
                    ? DateFormat('yyyy').format(_currentMonth)
                    : DateFormat('yyyy/MM').format(_currentMonth),
                key: ValueKey('${_selectedTab}_${DateFormat(_selectedTab == 'Year' ? 'yyyy' : 'yyyy/MM').format(_currentMonth)}'),
                style: TextStyle(
                  fontFamily: 'BasisGrotesquePro',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
        // Month/Year tabs
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 'Month'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Month'
                      ? (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5))
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Month',
                  style: TextStyle(
                    fontFamily: 'BasisGrotesquePro',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == 'Month'
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 'Year'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _selectedTab == 'Year'
                      ? (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF5F5F5))
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Year',
                  style: TextStyle(
                    fontFamily: 'BasisGrotesquePro',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == 'Year'
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }

  /// Month view content (without header)
  Widget _buildMonthContent(bool isDark, AuthProvider authProvider) {
    return ScrollConfiguration(
      key: const ValueKey('month-content'),
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padEnds: false,
        pageSnapping: true,
        allowImplicitScrolling: true,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
            final monthOffset = page - 12;
            final now = DateTime.now();
            _currentMonth = DateTime(now.year, now.month + monthOffset, 1);
          });
        },
        itemBuilder: (context, index) {
          final monthOffset = index - 12;
          final now = DateTime.now();
          final month = DateTime(now.year, now.month + monthOffset, 1);
          final cacheKey = '${month.year}-${month.month}-$isDark';

          // Use cached widget if available
          if (!_monthGridCache.containsKey(cacheKey)) {
            _monthGridCache[cacheKey] = RepaintBoundary(
              child: _buildMonthGrid(month, isDark, authProvider),
            );
          }

          return _KeepAlivePage(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: _monthGridCache[cacheKey]!,
            ),
          );
        },
      ),
    );
  }

  /// Year view content (without header)
  Widget _buildYearContent(bool isDark, AuthProvider authProvider) {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return ScrollConfiguration(
      key: const ValueKey('year-content'),
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: PageView.builder(
        controller: _yearPageController,
        scrollDirection: Axis.vertical,
        physics: const PageScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padEnds: false,
        pageSnapping: true,
        allowImplicitScrolling: true,
        onPageChanged: (page) {
          setState(() {
            _currentYearPage = page;
            final yearOffset = page - 10;
            final now = DateTime.now();
            _currentMonth = DateTime(now.year + yearOffset, _currentMonth.month, 1);
          });
        },
        itemBuilder: (context, index) {
          final yearOffset = index - 10;
          final now = DateTime.now();
          final year = now.year + yearOffset;
          final cacheKey = '$year-$isDark';

          // Use cached widget if available
          if (!_yearGridCache.containsKey(cacheKey)) {
            _yearGridCache[cacheKey] = RepaintBoundary(
              child: _buildYearGrid(year, monthNames, isDark, authProvider),
            );
          }

          return _KeepAlivePage(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 6),
              child: _yearGridCache[cacheKey]!,
            ),
          );
        },
      ),
    );
  }

  /// Year view showing all 12 months in a grid with vertical scroll between years

  /// Build grid of 12 months for a specific year
  Widget _buildYearGrid(int year, List<String> monthNames, bool isDark, AuthProvider authProvider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final columns = isNarrow ? 2 : 3;
        final rows = isNarrow ? 6 : 4;
        final hGap = isNarrow ? 2.0 : 6.0;

        // Always scroll on narrow (mobile) screens, or when height is insufficient
        if (isNarrow || constraints.maxHeight < 800) {
          final rowHeight = isNarrow ? 130.0 : 150.0;
          return SingleChildScrollView(
            child: Column(
              children: List.generate(rows, (rowIndex) {
                return SizedBox(
                  height: rowHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: isNarrow ? 4.0 : 6.0),
                    child: Row(
                      children: List.generate(columns, (colIndex) {
                        final monthIndex = rowIndex * columns + colIndex;
                        if (monthIndex >= 12) return const Expanded(child: SizedBox());
                        final month = DateTime(year, monthIndex + 1, 1);
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: hGap),
                            child: _buildCompactMonthForYear(month, monthNames[monthIndex], isDark, authProvider),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              }),
            ),
          );
        }

        // Normal: existing Expanded layout
        return Column(
          children: List.generate(rows, (rowIndex) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: isNarrow ? 4.0 : 6.0),
                child: Row(
                children: List.generate(columns, (colIndex) {
                  final monthIndex = rowIndex * columns + colIndex;
                  if (monthIndex >= 12) return const Expanded(child: SizedBox());
                  final month = DateTime(year, monthIndex + 1, 1);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hGap),
                      child: _buildCompactMonthForYear(month, monthNames[monthIndex], isDark, authProvider),
                    ),
                  );
                }),
              ),
              ),
            );
          }),
        );
      },
    );
  }

  /// Build a compact month calendar for year view
  Widget _buildCompactMonthForYear(DateTime month, String monthName, bool isDark, AuthProvider authProvider) {
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = lastDayOfMonth.day;
    final isCurrentMonth = month.year == today.year && month.month == today.month;

    final isNarrow = MediaQuery.of(context).size.width < 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month name
        Padding(
          padding: EdgeInsets.only(left: 2, bottom: isNarrow ? 1 : 2),
          child: Text(
            monthName,
            style: TextStyle(
              fontFamily: 'HouschkaRoundedAlt',
              fontSize: isNarrow ? 13 : 28,
              fontWeight: FontWeight.w500,
              color: isCurrentMonth
                  ? const Color(0xFFF05E1B)
                  : (isDark ? Colors.white : Colors.black),
              height: 1.0,
              letterSpacing: 0.2,
            ),
          ),
        ),
        // Days grid (up to 6 weeks)
        Expanded(
          child: Column(
            children: List.generate(6, (weekIndex) {
              return Expanded(
                child: Row(
                  children: List.generate(7, (dayIndex) {
                    final cellIndex = weekIndex * 7 + dayIndex;
                    final dayNumber = cellIndex - firstWeekday + 1;

                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const Expanded(child: SizedBox());
                    }

                    final day = DateTime(month.year, month.month, dayNumber);
                    final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                    final isPast = day.isBefore(DateTime(today.year, today.month, today.day));
                    final dayBookings = _getBookingsForDay(day);
                    final availableSlots = _getAvailableSlots(day);
                    final isBookable = _isDateBookable(day);

                    // Determine indicator (similar to month view)
                    bool morningOccupied = false;
                    bool afternoonOccupied = false;

                    final confirmedBookings = dayBookings.where((b) => b.status == BookingStatus.APPROVED).toList();
                    for (final booking in confirmedBookings) {
                      final startHour = int.parse(booking.startTime.split(':')[0]);
                      if (startHour < 13) morningOccupied = true;
                      if (startHour >= 13) afternoonOccupied = true;
                    }

                    final isFull = morningOccupied && afternoonOccupied;
                    final isPartial = (morningOccupied || afternoonOccupied) && !isFull;
                    final hasAvailableSlots = availableSlots.isNotEmpty;

                    Color? indicatorColor;
                    // Only show indicator for bookable future days with available slots
                    if (isBookable && !isPast && hasAvailableSlots) {
                      if (isPartial) {
                        indicatorColor = const Color(0xFFF05E1B); // Ember for partial
                      } else {
                        indicatorColor = const Color(0xFF10B981); // Green for fully available
                      }
                    }

                    return Expanded(
                      child: GestureDetector(
                        onTap: (isBookable && !isPast && hasAvailableSlots) ? () {
                          // Zoom in to this month and select this day - only if clickable
                          setState(() {
                            _selectedTab = 'Month';
                            _selectedDate = day;
                            _currentMonth = DateTime(day.year, day.month, 1);
                            // Navigate PageView to this month
                            final now = DateTime.now();
                            final monthOffset = (day.year - now.year) * 12 + (day.month - now.month);
                            _pageController.jumpToPage(12 + monthOffset);
                          });
                        } : null,
                        child: Container(
                          margin: EdgeInsets.all(isNarrow ? 2.5 : 1.5),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Day number - centered (anchor)
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$dayNumber',
                                        style: TextStyle(
                                          fontFamily: 'BasisGrotesquePro',
                                          fontSize: isNarrow ? 12 : 14,
                                          height: 1.0,
                                          letterSpacing: 0,
                                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                                          color: isToday
                                              ? const Color(0xFFF05E1B)
                                              : !isBookable || isPast || !hasAvailableSlots
                                                  ? (isDark ? const Color(0xFF666666) : const Color(0xFFD1D5DB))
                                                  : (isDark ? Colors.white : Colors.black),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Indicator line - absolute overlay, anchored below number center (same as month view)
                                  if (indicatorColor != null)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: constraints.maxHeight / 2 + (isNarrow ? 4 : 6),
                                      child: Center(
                                        child: Container(
                                          width: isNarrow ? 7 : 10,
                                          height: isNarrow ? 1.0 : 1.5,
                                          decoration: BoxDecoration(
                                            color: indicatorColor,
                                            borderRadius: BorderRadius.circular(0.75),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  /// Helper method to build the month grid for a specific month
  Widget _buildMonthGrid(DateTime month, bool isDark, AuthProvider authProvider) {
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = lastDayOfMonth.day;

    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Column(
      children: [
        // Weekday header row
        SizedBox(
          height: 24,
          child: Row(
            children: weekDays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
                    fontFamily: 'BasisGrotesquePro',
                  ),
                ),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        ...List.generate(5, (weekIndex) {
        return Expanded(
          child: Row(
            children: List.generate(7, (dayIndex) {
              final cellIndex = weekIndex * 7 + dayIndex;
              final dayNumber = cellIndex - firstWeekday + 1;

              // Only show days from current month
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox());
              }

              final day = DateTime(month.year, month.month, dayNumber);
              final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == day.year &&
                  _selectedDate!.month == day.month &&
                  _selectedDate!.day == day.day;

              if (isSelected) {
              }

              final dayBookings = _getBookingsForDay(day);

              // Check for pending vs confirmed bookings
              final hasPendingBookings = dayBookings.any((b) => b.status == BookingStatus.UNDER_REVIEW || b.status == BookingStatus.CREATED || b.status == BookingStatus.NEED_EDIT || b.status == BookingStatus.NEED_RESCHEDULE);
              final hasConfirmedBookings = dayBookings.any((b) => b.status == BookingStatus.APPROVED);

              // Only APPROVED bookings block periods
              final confirmedBookings = dayBookings.where((b) =>
                b.status == BookingStatus.APPROVED
              ).toList();

              // Check if day is bookable (past or before minimum 7 business days)
              final isBookable = _isDateBookable(day);

              // Calculate period occupation for better color logic
              // Only APPROVED bookings occupy periods
              bool morningOccupied = false;
              bool afternoonOccupied = false;

              // 1. Check APPROVED bookings only
              for (final booking in confirmedBookings) {
                final startHour = int.parse(booking.startTime.split(':')[0]);
                final durationHours = {
                  VisitDuration.ONE_HOUR: 1,
                  VisitDuration.TWO_HOURS: 2,
                  VisitDuration.THREE_HOURS: 3,
                  VisitDuration.FOUR_HOURS: 4,
                  VisitDuration.FIVE_HOURS: 5,
                  VisitDuration.SIX_HOURS: 6,
                }[booking.duration] ?? 2;
                final endHour = startHour + durationHours;

                if (startHour < 13 && endHour > 9) morningOccupied = true;
                if (startHour < 17 && endHour > 13) afternoonOccupied = true;
              }

              // 2. Check Innovation Exchange prep/teardown blocks
              final ieBlocks = _calculateInnovationExchangeBlocks();
              final dayStr = DateFormat('yyyy-MM-dd').format(day);
              if (ieBlocks.containsKey(dayStr)) {
                if (ieBlocks[dayStr]!['morning'] == true) morningOccupied = true;
                if (ieBlocks[dayStr]!['afternoon'] == true) afternoonOccupied = true;
              }

              final isFull = morningOccupied && afternoonOccupied;
              final hasAnyOccupation = morningOccupied || afternoonOccupied;

              // Check if day is weekend (Saturday or Sunday)
              final isWeekend = _isWeekend(day);

              // Determine indicator color based on booking status and availability
              // Show indicators for ALL days (even non-bookable) to visualize occupation
              // BUT: Never show indicators on weekends (they're not countable days)
              Color? indicatorColor;

              // Only calculate indicator if NOT weekend
              if (!isWeekend) {
                // Calculate base color regardless of bookability
                if (hasPendingBookings && !hasConfirmedBookings) {
                  // Only pending bookings - orange
                  indicatorColor = const Color(0xFFF59E0B); // Orange - pending approval
                } else if (isFull) {
                  // Both periods occupied (bookings OR IE blocks) - 100% full
                  // NO DOT for full days - they will be greyed out via opacity below
                  indicatorColor = null; // No indicator for full days
                } else if (!hasAnyOccupation && dayBookings.isEmpty && isBookable) {
                  // No bookings AND no IE blocks at all AND is bookable
                  // Only show green dot on days that are actually available for booking
                  indicatorColor = const Color(0xFF10B981); // Green - available, no bookings
                } else if (hasAnyOccupation) {
                  // Has bookings OR IE blocks but NOT full - Ember (partial)
                  indicatorColor = const Color(0xFFF05E1B); // Ember - partial (has bookings/blocks but slots available)
                }

                // If not bookable (disabled day), apply darker tone to other indicators
                if (indicatorColor != null && !isBookable) {
                  indicatorColor = indicatorColor.withValues(alpha: 0.4);
                }
              }

              // Allow ADMIN/MANAGER to click on disabled days to view events
              // But full days are unclickable for everyone (unless ADMIN/MANAGER)
              final canClickDay = (isBookable && !isFull) ||
                (authProvider.user?.role == UserRole.ADMIN ||
                 authProvider.user?.role == UserRole.MANAGER);

              // Determine availability label
              String? availabilityLabel;
              Color? availabilityColor;
              if (!isWeekend && isBookable) {
                if (hasPendingBookings && !hasConfirmedBookings) {
                  availabilityLabel = 'Pending';
                  availabilityColor = const Color(0xFFF05E1B);
                } else if (!hasAnyOccupation && dayBookings.isEmpty) {
                  availabilityLabel = 'Available';
                  availabilityColor = const Color(0xFF10B981);
                } else if (hasAnyOccupation && !isFull) {
                  availabilityLabel = 'Partial';
                  availabilityColor = const Color(0xFFF05E1B);
                }
              }

              return Expanded(
                child: GestureDetector(
                  onTap: canClickDay ? () {
                    setState(() {
                      _selectedDate = day;
                      // Clear cache to force rebuild with new selection
                      _monthGridCache.clear();
                    });
                  } : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutQuad,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: Colors.transparent, // No background color for today
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Number - centered
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.center,
                                child: TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutQuad,
                                  tween: Tween(begin: 1.0, end: isSelected ? 1.10 : 1.0),
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: Text(
                                        '$dayNumber',
                                        style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                          color: !isBookable || isFull
                                              ? (isDark ? const Color(0xFF666666) : const Color(0xFFD1D5DB))
                                              : (isDark ? Colors.white : Colors.black),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Current day indicator - permanent line with lighter color
                            if (isToday)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: constraints.maxHeight / 2 + 6,
                                child: Center(
                                  child: Container(
                                    width: 32,
                                    height: 6.5,
                                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
                                  ),
                                ),
                              ),
                            // Selection indicator - animated line on top of current day indicator
                            if (isSelected)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: constraints.maxHeight / 2 + 6,
                                child: Center(
                                  child: SizedBox(
                                    width: 32,
                                    height: 6.5,
                                    child: TweenAnimationBuilder<double>(
                                      key: ValueKey('underline_$dayNumber'),
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      builder: (context, progress, child) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            width: 32 * progress,
                                            height: 6.5,
                                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.65 * progress),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            // Availability label - absolute overlay, anchored below indicators
                            if (availabilityLabel != null)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: constraints.maxHeight / 2 + 16,
                                child: Center(
                                  child: Text(
                                    availabilityLabel,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: availabilityColor,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
      ],
    );
  }

  Widget _buildEventsSection(bool isDark, bool isMobile, bool isUserRole) {
    if (_selectedDate == null) {
      return Container(
        color: isDark ? Colors.black : Colors.white,  // Same as calendar background
        child: Center(
          child: Text(
            'Select a date',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    // For ADMIN/MANAGER: show only UNDER_REVIEW and APPROVED in events section below calendar
    final bookingsList = _getBookingsForDay(_selectedDate!, filterForAdminManager: !isUserRole);
    final ieBlocks = _getIEBlocksForDay(_selectedDate!);
    final today = DateTime.now();
    final isPast = _selectedDate!.isBefore(DateTime(today.year, today.month, today.day));

    // Create combined and sorted list of events
    final combinedEvents = <Map<String, dynamic>>[];

    // Add IE blocks with sortOrder
    for (final block in ieBlocks) {
      combinedEvents.add({
        'type': 'block',
        'data': block,
        'sortOrder': block['sortOrder'] ?? '0',
      });
    }

    // Add bookings with sortOrder based on time
    for (final booking in bookingsList) {
      final startHour = int.parse(booking.startTime.split(':')[0]);
      final sortOrder = startHour < 13 ? '0' : '1'; // Morning = 0, Afternoon = 1
      combinedEvents.add({
        'type': 'booking',
        'data': booking,
        'sortOrder': sortOrder,
      });
    }

    // Sort by sortOrder (morning first, then afternoon), then by startTime within each period
    combinedEvents.sort((a, b) {
      final sortOrderComparison = a['sortOrder'].compareTo(b['sortOrder']);
      if (sortOrderComparison != 0) return sortOrderComparison;

      // If same period, sort by time (bookings have startTime, blocks don't need sub-sorting)
      if (a['type'] == 'booking' && b['type'] == 'booking') {
        final aBooking = a['data'] as Booking;
        final bBooking = b['data'] as Booking;
        return aBooking.startTime.compareTo(bBooking.startTime);
      }

      return 0;
    });

    return Container(
      color: isDark ? Colors.black : Colors.white,  // Same as calendar background, no border
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact header
          Text(
            DateFormat('EEE, MMM d').format(_selectedDate!),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          // Events list with animated transition when changing days
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                // Empty state: fade + scale animation (centered)
                // Events: fade + slide animation (from bottom)
                final isEmptyState = (child.key as ValueKey).value == 'empty';

                if (isEmptyState) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                } else {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                }
              },
              child: combinedEvents.isEmpty
                ? Center(
                    key: const ValueKey('empty'),  // Same key for all empty states - no animation
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isPast
                            ? 'Past date'
                            : 'No events',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    key: ValueKey('events_${_selectedDate!.toIso8601String()}'),
                    padding: EdgeInsets.zero,
                    itemCount: combinedEvents.length,
                    itemBuilder: (context, index) {
                      final event = combinedEvents[index];
                      if (event['type'] == 'block') {
                        return _buildIEBlockCard(event['data'] as Map<String, String>, isDark, isUserRole);
                      } else {
                        return _buildColorfulEventCard(event['data'] as Booking, isDark, isUserRole);
                      }
                    },
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build card for Innovation Exchange prep/teardown blocks
  Widget _buildIEBlockCard(Map<String, String> block, bool isDark, bool isUserRole) {
    // Simplify label for normal users
    final displayLabel = isUserRole ? 'Reserved' : block['label']!;

    // Format time with AM/PM
    final times = block['time']!.split(' - ');
    final formattedTime = times.length == 2
        ? TimeFormatter.formatTimeRange(times[0], times[1])
        : block['time']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          // Gray dot for blocked slots - centered vertically
          Container(
            margin: const EdgeInsets.only(right: 12),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280).withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Icon
                    Icon(
                      Icons.lock_clock,
                      size: 18,
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorfulEventCard(Booking booking, bool isDark, bool isUserRole) {
    // Get status color and label
    Color statusColor;
    String statusLabel;
    bool shouldPulse = false;

    switch (booking.status) {
      case BookingStatus.CREATED:
        statusColor = const Color(0xFF6B7280); // Gray
        statusLabel = 'CREATED';
        break;
      case BookingStatus.UNDER_REVIEW:
        statusColor = const Color(0xFFF05E1B); // Ember (orange)
        statusLabel = 'UNDER REVIEW';
        shouldPulse = true; // Animate for pending/review
        break;
      case BookingStatus.NEED_EDIT:
        statusColor = const Color(0xFFF59E0B); // Amber/Yellow - ONLY THIS ONE
        statusLabel = 'NEEDS EDIT';
        shouldPulse = true;
        break;
      case BookingStatus.NEED_RESCHEDULE:
        statusColor = const Color(0xFF8B5CF6); // Purple/Violet
        statusLabel = 'NEEDS RESCHEDULE';
        shouldPulse = true;
        break;
      case BookingStatus.APPROVED:
        statusColor = const Color(0xFF10B981); // Green
        statusLabel = 'APPROVED';
        break;
      case BookingStatus.NOT_APPROVED:
        statusColor = const Color(0xFFEF4444); // Red
        statusLabel = 'NOT APPROVED';
        break;
      case BookingStatus.CANCELLED:
        statusColor = const Color(0xFFEF4444); // Red
        statusLabel = 'CANCELLED';
        break;
    }

    // Format time with AM/PM
    final timeRange = TimeFormatter.formatBookingTimeSlot(
      booking.startTime,
      booking.duration.name,
    );

    return InkWell(
      onTap: () => _handleBookingClick(booking),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Status dot (colored circle) - centered vertically
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: _statusDot(color: statusColor, shouldPulse: shouldPulse),
            ),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row with two columns
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center, // Center vertically
                    children: [
                      // Left column: Company name / "Reserved" for users
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUserRole ? 'Reserved' : booking.companyName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeRange,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right column: Status badge (only show for admin/manager)
                      if (!isUserRole) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor, width: 1),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // ADMIN/MANAGER only: show interest area and attendees
                  if (!isUserRole && booking.interestArea != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            booking.interestArea!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (booking.expectedAttendees > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.people,
                            size: 12,
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${booking.expectedAttendees}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Status dot widget - replaces left border with circular indicator
  Widget _statusDot({required Color color, required bool shouldPulse}) {
    if (!shouldPulse) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    }

    // Pulsing animation for PENDING status
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: value * 0.5),
                blurRadius: 4 * value,
                spreadRadius: 1 * value,
              ),
            ],
          ),
        );
      },
      onEnd: () {
        // Restart animation by forcing rebuild
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() {});
          });
        }
      },
    );
  }

  // Legacy status badge widget (kept for compatibility but no longer used)



  Widget _buildCancelDialog(bool isDark) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancel Booking',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to cancel this booking? This action cannot be undone.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showCancelDialog = false),
                    child: Text(
                      'No, keep it',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _handleCancelBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Yes, cancel booking'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Constants
const List<String> SECTORS = [
  'Technology',
  'Financial Services',
  'Healthcare',
  'Retail',
  'Manufacturing',
  'Energy',
  'Telecommunications',
  'Government',
  'Education',
  'Other'
];

const List<String> VERTICALS = [
  'Banking',
  'Insurance',
  'Capital Markets',
  'Healthcare Provider',
  'Life Sciences',
  'Retail',
  'Manufacturing',
  'Energy & Utilities',
  'Public Sector',
  'Horizontal (Cross-industry)'
];

const List<String> INTEREST_AREAS = [
  'Artificial Intelligence',
  'Cloud Migration',
  'Digital Transformation',
  'Data Analytics',
  'Cybersecurity',
  'DevOps',
  'IoT',
  'Blockchain',
  'Automation',
  'Legacy Modernization',
  'Other'
];

// Booking Form Widget
class _BookingFormWidget extends StatefulWidget {
  final bool isDark;
  final bool isMobile;
  final DateTime selectedDate;
  final String selectedSlot; // For display only
  final String selectedStartTime;
  final int selectedDuration;
  final String selectedVisitType;
  final Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onCancel;
  final bool showForm;

  const _BookingFormWidget({
    required this.isDark,
    required this.isMobile,
    required this.selectedDate,
    required this.selectedSlot,
    required this.selectedStartTime,
    required this.selectedDuration,
    required this.selectedVisitType,
    required this.onSubmit,
    required this.onCancel,
    required this.showForm,
  });

  @override
  State<_BookingFormWidget> createState() => _BookingFormWidgetState();
}

class _BookingFormWidgetState extends State<_BookingFormWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Form fields
  final _companyNameController = TextEditingController();
  String? _companySector;
  String? _companyVertical;
  String? _interestArea;
  final _businessGoalController = TextEditingController();
  final _additionalNotesController = TextEditingController();

  // Attendees list
  final List<Map<String, TextEditingController>> _attendees = [
    {
      'name': TextEditingController(),
      'position': TextEditingController(),
      'email': TextEditingController(),
      'phone': TextEditingController(),
    }
  ];

  @override
  void dispose() {
    _companyNameController.dispose();
    _businessGoalController.dispose();
    _additionalNotesController.dispose();
    for (var attendee in _attendees) {
      attendee['name']?.dispose();
      attendee['position']?.dispose();
      attendee['email']?.dispose();
      attendee['phone']?.dispose();
    }
    super.dispose();
  }

  void _generateFakeData() {
    final random = Random();

    final companiesData = [
      {'name': 'Itaú Unibanco', 'sector': 'Financial Services', 'vertical': 'Banking'},
      {'name': 'Bradesco', 'sector': 'Financial Services', 'vertical': 'Banking'},
      {'name': 'Banco do Brasil', 'sector': 'Financial Services', 'vertical': 'Banking'},
      {'name': 'Santander Brasil', 'sector': 'Financial Services', 'vertical': 'Banking'},
      {'name': 'BTG Pactual', 'sector': 'Financial Services', 'vertical': 'Capital Markets'},
      {'name': 'SulAmérica', 'sector': 'Financial Services', 'vertical': 'Insurance'},
      {'name': 'Petrobras', 'sector': 'Energy', 'vertical': 'Energy & Utilities'},
      {'name': 'Eletrobras', 'sector': 'Energy', 'vertical': 'Energy & Utilities'},
      {'name': 'Vale', 'sector': 'Manufacturing', 'vertical': 'Manufacturing'},
      {'name': 'Gerdau', 'sector': 'Manufacturing', 'vertical': 'Manufacturing'},
      {'name': 'Ambev', 'sector': 'Manufacturing', 'vertical': 'Manufacturing'},
      {'name': 'JBS', 'sector': 'Manufacturing', 'vertical': 'Manufacturing'},
      {'name': 'Natura &Co', 'sector': 'Retail', 'vertical': 'Retail'},
      {'name': 'Magazine Luiza', 'sector': 'Retail', 'vertical': 'Retail'},
      {'name': 'Telefônica Brasil (Vivo)', 'sector': 'Telecommunications', 'vertical': 'Horizontal (Cross-industry)'},
      {'name': 'TIM Brasil', 'sector': 'Telecommunications', 'vertical': 'Horizontal (Cross-industry)'},
      {'name': 'Hapvida', 'sector': 'Healthcare', 'vertical': 'Healthcare Provider'},
    ];

    final firstNames = ['James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda', 'William', 'Elizabeth'];
    final lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis'];
    final positions = ['CEO', 'CTO', 'CFO', 'CIO', 'VP of Technology', 'VP of Innovation', 'IT Director', 'Innovation Director'];
    final goals = [
      'Accelerate digital transformation with AI and Cloud solutions',
      'Modernize legacy infrastructure and migrate to cloud',
      'Implement data strategy and advanced analytics',
      'Strengthen cybersecurity posture and compliance',
      'Transform customer experience with digital'
    ];
    final notes = [
      'Visit approved by executive committee. Interest in generative AI use cases.',
      'Q1 priority project. Cloud architecture demonstration required.',
      'Strategic meeting with C-Level. Present digital transformation cases.',
      'Interest in long-term strategic partnership.',
    ];

    final company = companiesData[random.nextInt(companiesData.length)];

    setState(() {
      _companyNameController.text = company['name']!;
      _companySector = company['sector'];
      _companyVertical = company['vertical'];
      _interestArea = INTEREST_AREAS[random.nextInt(INTEREST_AREAS.length)];
      _businessGoalController.text = goals[random.nextInt(goals.length)];
      _additionalNotesController.text = notes[random.nextInt(notes.length)];

      // Generate 2-5 attendees
      final numAttendees = random.nextInt(4) + 2;
      _attendees.clear();

      for (int i = 0; i < numAttendees; i++) {
        final firstName = firstNames[random.nextInt(firstNames.length)];
        final lastName = lastNames[random.nextInt(lastNames.length)];
        final name = '$firstName $lastName';
        final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@${company['name']!.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}.com';
        final position = positions[random.nextInt(positions.length)];
        final phone = '+55 11 ${random.nextInt(90000) + 10000}-${random.nextInt(9000) + 1000}';

        _attendees.add({
          'name': TextEditingController(text: name),
          'position': TextEditingController(text: position),
          'email': TextEditingController(text: email),
          'phone': TextEditingController(text: phone),
        });
      }
    });
  }

  void _addAttendee() {
    setState(() {
      _attendees.add({
        'name': TextEditingController(),
        'position': TextEditingController(),
        'email': TextEditingController(),
        'phone': TextEditingController(),
      });
    });
  }

  void _removeAttendee(int index) {
    if (_attendees.length > 1) {
      setState(() {
        _attendees[index]['name']?.dispose();
        _attendees[index]['position']?.dispose();
        _attendees[index]['email']?.dispose();
        _attendees[index]['phone']?.dispose();
        _attendees.removeAt(index);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields
    if (_companySector == null || _companyVertical == null || _interestArea == null) {
      ToastNotification.show(
        context,
        message: 'Please select Sector, Vertical, and Interest Area',
        type: ToastType.error,
      );
      return;
    }

    if (_attendees.isEmpty ||
        _attendees[0]['name']?.text.trim().isEmpty != false ||
        _attendees[0]['email']?.text.trim().isEmpty != false) {
      ToastNotification.show(
        context,
        message: 'First attendee name and email are required',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Prepare attendees data
      final attendeesData = _attendees
          .where((a) => a['name']?.text.trim().isNotEmpty == true)
          .map((a) => {
                'name': a['name']?.text.trim() ?? '',
                if (a['position']?.text.trim().isNotEmpty == true) 'position': a['position']!.text.trim(),
                if (a['email']?.text.trim().isNotEmpty == true) 'email': a['email']!.text.trim(),
                if (a['phone']?.text.trim().isNotEmpty == true) 'phone': a['phone']!.text.trim(),
              })
          .toList();

      // Convert duration to enum format
      String durationEnum;
      switch (widget.selectedDuration) {
        case 1:
          durationEnum = 'ONE_HOUR';
          break;
        case 2:
          durationEnum = 'TWO_HOURS';
          break;
        case 3:
          durationEnum = 'THREE_HOURS';
          break;
        case 4:
          durationEnum = 'FOUR_HOURS';
          break;
        case 5:
          durationEnum = 'FIVE_HOURS';
          break;
        case 6:
          durationEnum = 'SIX_HOURS';
          break;
        default:
          durationEnum = 'TWO_HOURS';
      }

      // Use first attendee as main contact
      final firstAttendee = _attendees[0];

      final bookingData = {
        'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'duration': durationEnum,
        'startTime': widget.selectedStartTime,
        'visitType': widget.selectedVisitType,
        'companyName': _companyNameController.text.trim(),
        'companySector': _companySector!,
        'companyVertical': _companyVertical!,
        'contactName': firstAttendee['name']?.text.trim() ?? '',
        'contactEmail': firstAttendee['email']?.text.trim() ?? '',
        if (firstAttendee['position']?.text.trim().isNotEmpty == true) 'contactPosition': firstAttendee['position']!.text.trim(),
        'contactPhone': firstAttendee['phone']?.text.trim() ?? '',
        'interestArea': _interestArea!,
        'expectedAttendees': _attendees.length,
        if (attendeesData.isNotEmpty) 'attendees': attendeesData,
        if (_businessGoalController.text.trim().isNotEmpty) 'businessGoal': _businessGoalController.text.trim(),
        if (_additionalNotesController.text.trim().isNotEmpty) 'additionalNotes': _additionalNotesController.text.trim(),
      };

      // Call onSubmit without managing loading state after
      // The parent will handle closing/unmounting this widget
      await widget.onSubmit(bookingData);
    } catch (e) {
      // Only reset loading on error, since widget is still mounted
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      rethrow;
    } finally {
      // Always try to reset loading if widget is still mounted
      // This handles the case where onSubmit doesn't unmount the widget
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getSlotLabel() {
    switch (widget.selectedSlot) {
      case 'morning':
        return 'Morning (09:00 - 12:00)';
      case 'afternoon':
        return 'Afternoon (14:00 - 17:00)';
      case 'full-day':
        return 'Full Day (09:00 - 15:00)';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onCancel,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: AnimatedSlide(
              offset: widget.showForm ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Booking',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat('MMM d, yyyy').format(widget.selectedDate)} • ${_getSlotLabel()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: widget.onCancel,
                          icon: Icon(
                            Icons.close,
                            color: widget.isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Generate Test Data Button
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: _generateFakeData,
                                icon: const Icon(Icons.auto_awesome, size: 18),
                                label: const Text('Generate Test Data'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: widget.isDark ? Colors.white : Colors.black,
                                  side: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Company Information Section
                            Text(
                              'Company Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Company Name
                            TextFormField(
                              controller: _companyNameController,
                              decoration: InputDecoration(
                                labelText: 'Company Name *',
                                filled: true,
                                fillColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? Colors.white : Colors.black,
                                    width: 2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Company name is required' : null,
                            ),
                            const SizedBox(height: 16),

                            // Sector Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _companySector,
                              decoration: InputDecoration(
                                labelText: 'Sector *',
                                filled: true,
                                fillColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? Colors.white : Colors.black,
                                    width: 2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              dropdownColor: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                              items: SECTORS.map((sector) {
                                return DropdownMenuItem(
                                  value: sector,
                                  child: Text(sector),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _companySector = value),
                            ),
                            const SizedBox(height: 16),

                            // Vertical Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _companyVertical,
                              decoration: InputDecoration(
                                labelText: 'Vertical *',
                                filled: true,
                                fillColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? Colors.white : Colors.black,
                                    width: 2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              dropdownColor: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                              items: VERTICALS.map((vertical) {
                                return DropdownMenuItem(
                                  value: vertical,
                                  child: Text(vertical),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _companyVertical = value),
                            ),
                            const SizedBox(height: 24),

                            // Business Information Section
                            Text(
                              'Business Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Interest Area Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _interestArea,
                              decoration: InputDecoration(
                                labelText: 'Interest Area *',
                                filled: true,
                                fillColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? Colors.white : Colors.black,
                                    width: 2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              dropdownColor: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                              items: INTEREST_AREAS.map((area) {
                                return DropdownMenuItem(
                                  value: area,
                                  child: Text(area),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _interestArea = value),
                            ),
                            const SizedBox(height: 24),

                            // Attendees Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Attendees * (${_attendees.length} ${_attendees.length == 1 ? 'person' : 'people'})',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _addAttendee,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Person'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: widget.isDark ? Colors.white : Colors.black,
                                    side: BorderSide(
                                      color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Attendees List
                            ..._attendees.asMap().entries.map((entry) {
                              final index = entry.key;
                              final attendee = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: widget.isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          index == 0 ? 'Main Contact' : 'Attendee ${index + 1}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                          ),
                                        ),
                                        if (_attendees.length > 1)
                                          IconButton(
                                            onPressed: () => _removeAttendee(index),
                                            icon: const Icon(Icons.close, size: 20),
                                            color: Colors.red,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: attendee['name'],
                                      decoration: InputDecoration(
                                        labelText: 'Full Name *',
                                        filled: true,
                                        fillColor: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: widget.isDark ? Colors.white : Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                        labelStyle: TextStyle(
                                          color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: attendee['position'],
                                      decoration: InputDecoration(
                                        labelText: 'Position/Title ${index == 0 ? '*' : '(Optional)'}',
                                        filled: true,
                                        fillColor: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: widget.isDark ? Colors.white : Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                        labelStyle: TextStyle(
                                          color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: attendee['email'],
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: 'Email ${index == 0 ? '*' : '(Optional)'}',
                                        filled: true,
                                        fillColor: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: widget.isDark ? Colors.white : Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                        labelStyle: TextStyle(
                                          color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                                      validator: index == 0
                                          ? (value) {
                                              if (value == null || value.trim().isEmpty) {
                                                return 'Email is required for main contact';
                                              }
                                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                              if (!emailRegex.hasMatch(value)) {
                                                return 'Invalid email format';
                                              }
                                              return null;
                                            }
                                          : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: attendee['phone'],
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        labelText: 'Phone (Optional)',
                                        filled: true,
                                        fillColor: widget.isDark ? const Color(0xFF18181B) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                            color: widget.isDark ? Colors.white : Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                        labelStyle: TextStyle(
                                          color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                      style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 8),

                            // Business Goal
                            TextFormField(
                              controller: _businessGoalController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Business Goal (Optional)',
                                filled: true,
                                fillColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? Colors.white : Colors.black,
                                    width: 2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                            ),
                            const SizedBox(height: 16),

                            // Additional Notes
                            TextFormField(
                              controller: _additionalNotesController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Additional Notes (Optional)',
                                filled: true,
                                fillColor: widget.isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: widget.isDark ? Colors.white : Colors.black,
                                    width: 2,
                                  ),
                                ),
                                labelStyle: TextStyle(
                                  color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : widget.onCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: widget.isDark ? Colors.white : Colors.black,
                              side: BorderSide(
                                color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: widget.isDark ? Colors.white : Colors.black,
                              foregroundColor: widget.isDark ? Colors.black : Colors.white,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Create Booking'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

// Wrapper widget that polls for availability updates
class SlotPickerContentWithLoading extends StatefulWidget {
  final DateTime date;
  final String visitTypeLabel;
  final String? selectedVisitType;
  final bool isUserRole;
  final bool isDark;
  final Function(TimeOfDay, int)? onSlotSelected;
  final VoidCallback onClose;
  final VoidCallback? onBack; // Optional back button callback
  final DayAvailability? Function() getAvailability;

  const SlotPickerContentWithLoading({
    super.key,
    required this.date,
    required this.visitTypeLabel,
    required this.selectedVisitType,
    required this.isUserRole,
    required this.isDark,
    this.onSlotSelected,
    required this.onClose,
    this.onBack,
    required this.getAvailability,
  });

  @override
  State<SlotPickerContentWithLoading> createState() => _SlotPickerContentWithLoadingState();
}

class _SlotPickerContentWithLoadingState extends State<SlotPickerContentWithLoading> {
  List<AvailablePeriod> _allPeriods = [];

  @override
  void initState() {
    super.initState();
    // Start polling for availability updates every 100ms until data arrives
    _pollForAvailability();
  }

  Future<void> _pollForAvailability() async {
    // Poll every 100ms for up to 30 seconds
    for (int i = 0; i < 300; i++) {
      if (!mounted) return;

      final availability = widget.getAvailability();

      // Log first few polls to debug
      if (i < 5 || (i % 10 == 0 && i < 50)) {
      }

      if (availability != null && availability.allPeriods?.isNotEmpty == true) {
        setState(() {
          _allPeriods = availability.allPeriods ?? [];
        });
        // Debug: Periods loaded successfully
        return; // Stop polling once we have data
      }

      await Future.delayed(const Duration(milliseconds: 100));
      // Poll count tracking removed
    }

  }

  @override
  Widget build(BuildContext context) {
    return SlotPickerContent(
      date: widget.date,
      allPeriods: _allPeriods,
      visitTypeLabel: widget.visitTypeLabel,
      selectedVisitType: widget.selectedVisitType,
      isUserRole: widget.isUserRole,
      isDark: widget.isDark,
      onSlotSelected: widget.onSlotSelected,
      onClose: widget.onClose,
      onBack: widget.onBack,
    );
  }
}

// Stateful widget for slot picker with confirmation button
// Made public to be reusable in reschedule_drawer.dart
class SlotPickerContent extends StatefulWidget {
  final DateTime date;
  final List<AvailablePeriod> allPeriods;
  final String visitTypeLabel;
  final String? selectedVisitType;
  final bool isUserRole;
  final bool isDark;
  final Function(TimeOfDay, int)? onSlotSelected;
  final VoidCallback onClose;
  final VoidCallback? onBack; // Optional back button callback

  const SlotPickerContent({
    super.key,
    required this.date,
    required this.allPeriods,
    required this.visitTypeLabel,
    required this.selectedVisitType,
    required this.isUserRole,
    required this.isDark,
    this.onSlotSelected,
    required this.onClose,
    this.onBack,
  });

  @override
  State<SlotPickerContent> createState() => _SlotPickerContentState();
}

class _SlotPickerContentState extends State<SlotPickerContent> {
  AvailablePeriod? _selectedPeriod;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF18181B) : Colors.white,
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
                color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (widget.onBack != null) {
                            // For back: First trigger back callback to show previous drawer,
                            // THEN close current drawer in next frame
                            widget.onBack!();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            });
                          } else {
                            // For close: just pop and call onClose
                            Navigator.of(context).pop();
                            widget.onClose();
                          }
                        },
                        icon: Icon(
                          widget.onBack != null ? Icons.arrow_back : Icons.close,
                          color: widget.isDark ? Colors.white : Colors.black,
                        ),
                        tooltip: widget.onBack != null ? 'Back' : 'Close',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Period',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.visitTypeLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: Text(
                        DateFormat('MMMM d, yyyy').format(widget.date),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: widget.allPeriods.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: widget.isDark ? Colors.white : Colors.black,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading available periods...',
                            style: TextStyle(
                              color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: widget.allPeriods.map((period) {
                          return _buildSelectablePeriodCard(period);
                        }).toList(),
                      ),
                    ),
            ),
            // Confirm button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: widget.isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: ElevatedButton(
                onPressed: _selectedPeriod != null ? _confirmSelection : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectablePeriodCard(AvailablePeriod period) {
    final isAvailable = period.available;
    final isSelected = _selectedPeriod == period;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable ? () {
            setState(() {
              _selectedPeriod = period;
            });
          } : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isAvailable
                  ? (widget.isDark ? const Color(0xFF18181B) : Colors.white)
                  : (widget.isDark ? const Color(0xFF09090B) : const Color(0xFFF3F4F6)),
              border: Border.all(
                color: isSelected
                    ? (widget.isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                    : (isAvailable
                        ? (widget.isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                        : (widget.isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB))),
                width: isSelected ? 3 : 2,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (widget.isDark ? const Color(0xFF10B981) : const Color(0xFF059669)).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? (widget.isDark ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF10B981).withValues(alpha: 0.1))
                        : (widget.isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    period.period == 'MORNING' ? Icons.wb_sunny : Icons.nights_stay,
                    size: 24,
                    color: isAvailable
                        ? (widget.isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                        : (widget.isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isAvailable
                              ? (widget.isDark ? Colors.white : Colors.black)
                              : (widget.isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      if (!isAvailable && period.blockedBy != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          period.blockedBy!,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Colors.black, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSelection() {
    if (_selectedPeriod == null) return;

    // Calculate duration based on visit type
    // PACE_TOUR: 2h, INNOVATION_EXCHANGE: 6h
    final duration = widget.selectedVisitType == 'PACE_TOUR' ? 2 : 6;

    // Parse start time to TimeOfDay
    final timeParts = _selectedPeriod!.startTime.split(':');
    final startTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    // Close the drawer
    Navigator.of(context, rootNavigator: false).pop();

    // Call the callback
    if (widget.onSlotSelected != null) {
      widget.onSlotSelected!(startTime, duration);
    }
  }
}

/// Helper widget to keep PageView pages alive and prevent rebuilds
class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Must call super for AutomaticKeepAliveClientMixin
    return widget.child;
  }
}
