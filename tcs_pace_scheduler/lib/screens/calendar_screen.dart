import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../services/navigation_service.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../widgets/access_badge.dart';
import '../utils/time_formatter.dart';
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
  String? _selectedSlot;
  Booking? _selectedBooking;
  bool _showDayBookings = false;
  bool _showBookingForm = false;
  bool _showCancelDialog = false;
  DateTime? _tappedDate;
  int _currentBadgeIndex = 0;
  CalendarViewType _viewType = CalendarViewType.month;

  // Availability state
  Map<String, DayAvailability> _availabilityCache = {};
  DayAvailability? _selectedDayAvailability;

  // Selected time and duration for booking
  String? _selectedStartTime;
  int? _selectedDuration;
  String? _selectedVisitType; // QUICK_TOUR or INNOVATION_EXCHANGE

  // Keep listener references for proper cleanup
  late final Function(Map<String, dynamic>) _onBookingCreatedListener;
  late final Function(Map<String, dynamic>) _onBookingUpdatedListener;
  late final Function(Map<String, dynamic>) _onBookingApprovedListener;
  late final Function(String) _onBookingDeletedListener;

  @override
  void initState() {
    super.initState();
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
      debugPrint('[Calendar] Error loading draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading draft: $e'),
            backgroundColor: Colors.red,
          ),
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
    final duration = durationMap[draft.duration] ?? 4;

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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      debugPrint('📡 [Calendar-WS-$timestamp] ========== BOOKING CREATED EVENT ==========');
      debugPrint('📡 [Calendar-WS-$timestamp] Booking: ${booking['title']}');
      debugPrint('📡 [Calendar-WS-$timestamp] ID: ${booking['id']}');
      debugPrint('📡 [Calendar-WS-$timestamp] Current _loading state: $_loading');
      debugPrint('📡 [Calendar-WS-$timestamp] Calling _loadBookings(showLoading: false)');
      _loadBookings(showLoading: false); // Silent refresh on WebSocket update
      debugPrint('📡 [Calendar-WS-$timestamp] ========== EVENT PROCESSED ==========\n');
    };

    _onBookingUpdatedListener = (booking) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      debugPrint('📡 [Calendar-WS-$timestamp] ========== BOOKING UPDATED EVENT ==========');
      debugPrint('📡 [Calendar-WS-$timestamp] Booking ID: ${booking['id']}');
      debugPrint('📡 [Calendar-WS-$timestamp] Current _loading state: $_loading');
      debugPrint('📡 [Calendar-WS-$timestamp] Calling _loadBookings(showLoading: false)');
      _loadBookings(showLoading: false); // Silent refresh on WebSocket update
      debugPrint('📡 [Calendar-WS-$timestamp] ========== EVENT PROCESSED ==========\n');
    };

    _onBookingApprovedListener = (booking) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      debugPrint('📡 [Calendar-WS-$timestamp] ========== BOOKING APPROVED EVENT ==========');
      debugPrint('📡 [Calendar-WS-$timestamp] Company: ${booking['companyName']}');
      debugPrint('📡 [Calendar-WS-$timestamp] Current _loading state: $_loading');
      debugPrint('📡 [Calendar-WS-$timestamp] Calling _loadBookings(showLoading: false)');
      _loadBookings(showLoading: false); // Silent refresh on WebSocket update
      debugPrint('📡 [Calendar-WS-$timestamp] ========== EVENT PROCESSED ==========\n');
    };

    _onBookingDeletedListener = (bookingId) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      debugPrint('📡 [Calendar-WS-$timestamp] ========== BOOKING DELETED EVENT ==========');
      debugPrint('📡 [Calendar-WS-$timestamp] Booking ID: $bookingId');
      debugPrint('📡 [Calendar-WS-$timestamp] Current _loading state: $_loading');
      debugPrint('📡 [Calendar-WS-$timestamp] Calling _loadBookings(showLoading: false)');
      _loadBookings(showLoading: false); // Silent refresh on WebSocket update
      debugPrint('📡 [Calendar-WS-$timestamp] ========== EVENT PROCESSED ==========\n');
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
    super.dispose();
  }

  Future<void> _loadBookings({bool showLoading = true}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('🔄 [Calendar-Load-$timestamp] ========== _loadBookings CALLED ==========');
    debugPrint('🔄 [Calendar-Load-$timestamp] showLoading parameter: $showLoading');
    debugPrint('🔄 [Calendar-Load-$timestamp] Current _loading state BEFORE: $_loading');

    try {
      if (showLoading) {
        debugPrint('🔄 [Calendar-Load-$timestamp] Setting _loading = true (showing spinner)');
        setState(() {
          _loading = true;
          _error = null;
        });
        debugPrint('✅ [Calendar-Load-$timestamp] _loading state set to true');
      } else {
        debugPrint('🔄 [Calendar-Load-$timestamp] Silent mode - NOT setting _loading = true');
        setState(() {
          _error = null;
        });
        debugPrint('✅ [Calendar-Load-$timestamp] Error cleared (silent mode)');
      }

      // Get user role to determine which endpoint to use
      final authProvider = context.read<AuthProvider>();
      final userRole = authProvider.user?.role;

      // ADMIN/MANAGER: Use availability-admin endpoint (shows PENDING + APPROVED)
      // USER: Use availability endpoint (shows only APPROVED bookings, not PENDING)
      debugPrint('🔄 [Calendar-Load-$timestamp] Fetching bookings from API (role: $userRole)...');
      final response = (userRole == UserRole.ADMIN || userRole == UserRole.MANAGER)
          ? await _apiService.getBookingsAvailabilityForAdmins(null)
          : await _apiService.getBookingsAvailability(null);
      final bookingsData = response['bookings'] as List;
      debugPrint('✅ [Calendar-Load-$timestamp] API returned ${bookingsData.length} bookings');

      debugPrint('🔄 [Calendar-Load-$timestamp] Updating state with bookings...');
      setState(() {
        _bookings = bookingsData.map((e) => Booking.fromJson(e)).toList();
        // Sort bookings by date, then by startTime (morning first, then afternoon)
        _bookings.sort((a, b) {
          final dateComparison = a.date.compareTo(b.date);
          if (dateComparison != 0) return dateComparison;
          // If same date, sort by startTime
          return a.startTime.compareTo(b.startTime);
        });
        if (showLoading) {
          _loading = false;
          debugPrint('✅ [Calendar-Load-$timestamp] _loading set to FALSE (spinner hidden)');
        } else {
          debugPrint('✅ [Calendar-Load-$timestamp] Silent mode - _loading NOT changed (currently: $_loading)');
        }
      });
      debugPrint('🟢 [Calendar-Load-$timestamp] ========== _loadBookings SUCCESS ==========\n');
    } catch (e) {
      debugPrint('🔴 [Calendar-Load-$timestamp] ========== _loadBookings ERROR ==========');
      debugPrint('🔴 [Calendar-Load-$timestamp] Error: $e');
      setState(() {
        _error = e.toString();
        if (showLoading) {
          _loading = false;
          debugPrint('✅ [Calendar-Load-$timestamp] _loading set to FALSE (error state)');
        }
      });
      debugPrint('🔴 [Calendar-Load-$timestamp] ========== _loadBookings ERROR END ==========\n');
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
    // PENDING_APPROVAL do not block periods
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

  List<Booking> _getBookingsForDay(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayBookings = _bookings.where((b) {
      final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);

      // Filter by date and not cancelled
      if (bookingDate != dateStr || b.status == BookingStatus.CANCELLED) {
        return false;
      }

      // HIDE pending approval bookings from calendar for ALL roles
      // Pending bookings only appear in:
      // - My Bookings (for USER who created)
      // - Approvals page (for ADMIN/MANAGER to approve)
      if (b.status == BookingStatus.PENDING_APPROVAL) {
        return false;
      }

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

  Color _getDayGradientColor(DateTime day, bool isDark) {
    final isWeekend = _isWeekend(day);
    final isBookable = _isDateBookable(day);

    // Weekend - show as CLEARLY disabled with strong gray
    if (isWeekend) {
      return isDark ? const Color(0xFF1C1C1C) : const Color(0xFFD1D5DB);
    }

    // Not bookable (past or within 7 business days) - show as CLEARLY disabled with red tint
    if (!isBookable) {
      return isDark ? const Color(0xFF3F1F1F) : const Color(0xFFFEE2E2);
    }

    // Get ONLY APPROVED bookings for this day (not PENDING_APPROVAL)
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final confirmedBookings = _bookings.where((b) {
      final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);
      return bookingDate == dateStr && b.status == BookingStatus.APPROVED;
    }).toList();

    final availability = _availabilityCache[dateStr];

    // If we have availability data from API, use it
    if (availability != null && availability.isFull) {
      return isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3); // Red - Full
    }

    // If there are APPROVED bookings, show yellow
    if (confirmedBookings.isNotEmpty) {
      return isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7); // Yellow - Has confirmed bookings
    }

    // Otherwise, available (green)
    return isDark ? const Color(0xFF14532D) : const Color(0xFFBBF7D0); // Green - Available
  }

  List<DateTime> _generateCalendarDays() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    // Start from Sunday of the week containing the first day
    int daysFromSunday = firstDay.weekday % 7;
    final startDate = firstDay.subtract(Duration(days: daysFromSunday));

    // Generate 35 days (5 weeks)
    return List.generate(35, (index) => startDate.add(Duration(days: index)));
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  /// Navigate to today's date with solid algorithm
  Future<void> _goToToday() async {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    setState(() {
      // Set current month to today's month
      _currentMonth = DateTime(today.year, today.month);
      // Select today's date
      _selectedDate = normalizedToday;
      // Clear any tapped date
      _tappedDate = null;
    });

    // Load availability for today
    await _loadDayAvailability(normalizedToday);

    debugPrint('[Calendar] Navigated to today: ${DateFormat('yyyy-MM-dd').format(normalizedToday)}');
  }

  Future<void> _handleDayClick(DateTime date) async {
    // If onDaySelected callback is provided (reschedule mode), use it instead
    if (widget.onDaySelected != null) {
      widget.onDaySelected!(date);
      return;
    }

    // Check if date is bookable (at least 7 business days from today, not weekend)
    if (!_isDateBookable(date)) {
      // Show appropriate message based on why the date is not bookable
      String message;
      if (_isWeekend(date)) {
        message = 'Weekends are not available for booking';
      } else {
        final minDate = _getMinimumBookableDate();
        final formattedMinDate = DateFormat('MMM dd, yyyy').format(minDate);
        message = 'Bookings must be made at least 7 business days in advance.\nEarliest available date: $formattedMinDate';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedDate = date;
      _tappedDate = date;
    });

    // Reset tap animation after a short delay
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _tappedDate = null);
      }
    });

    final dayBookings = _getBookingsForDay(date);
    final hasBookings = dayBookings.isNotEmpty;

    if (hasBookings) {
      _showDayBookingsDrawer(date);
    } else {
      // Show visit type selection dialog FIRST
      await _showVisitTypeSelectionDialog(date);
    }
  }

  Future<void> _loadDayAvailability(DateTime date, {String? visitType}) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final response = await _apiService.checkAvailability(dateStr, visitType: visitType);

      setState(() {
        final availability = DayAvailability.fromJson(response);
        _availabilityCache[dateStr] = availability;
        _selectedDayAvailability = availability;
      });
    } catch (e) {
      debugPrint('Failed to load availability: $e');
    }
  }

  void _showSlotPickerDrawer(DateTime date, {Function(TimeOfDay, int)? onSlotSelected}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final availability = _selectedDayAvailability;
    final allPeriods = availability?.allPeriods ?? [];
    final visitTypeLabel = _selectedVisitType == 'QUICK_TOUR' ? 'Quick Tour' : 'Innovation Exchange';

    // Check user role to determine if we should show block details
    final authProvider = context.read<AuthProvider>();
    final isUserRole = authProvider.user?.role == UserRole.USER;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => SlotPickerContent(
        date: date,
        allPeriods: allPeriods,
        visitTypeLabel: visitTypeLabel,
        selectedVisitType: _selectedVisitType,
        isUserRole: isUserRole,
        isDark: isDark,
        onSlotSelected: onSlotSelected,
        onClose: _closeSlotPickerAndClearCache,
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

  void _closeBookingFormAndClearCache() {
    if (_selectedDate != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      setState(() {
        _showBookingForm = false;
        _availabilityCache.remove(dateStr);
        _selectedDayAvailability = null;
        _selectedVisitType = null;
        _selectedStartTime = null;
        _selectedDuration = null;
      });
    } else {
      setState(() => _showBookingForm = false);
    }
  }

  Future<void> _showDayBookingsDrawer(DateTime date) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final authProvider = context.read<AuthProvider>();
    final isUserRole = authProvider.user?.role == UserRole.USER;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _buildDayBookingsOverlay(isDark, isMobile, isUserRole ?? false),
    );
  }

  Future<void> _showBookingFormDrawer(DateTime selectedDate, TimeOfDay startTime, int duration) async {
    // Use the new BookingFlowService to start the multi-drawer flow
    final flowService = BookingFlowService();
    flowService.startBookingFlow(
      context,
      selectedDate: selectedDate,
      startTime: startTime,
    );

    // Reload bookings after flow completes
    _loadBookings();
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
      showSlotPicker: (DateTime date, Function(TimeOfDay, int) onSlotSelected) {
        _showSlotPickerDrawer(date, onSlotSelected: onSlotSelected);
      },
    );
  }

  Widget _buildVisitTypeOption(
    BuildContext context,
    String value,
    String title,
    String description,
    IconData icon,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
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
    // PENDING_APPROVAL do not block slots
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

  String _formatTimeSlot(String startTime, VisitDuration duration) {
    final hours = {
      VisitDuration.ONE_HOUR: 1,
      VisitDuration.TWO_HOURS: 2,
      VisitDuration.THREE_HOURS: 3,
      VisitDuration.FOUR_HOURS: 4,
    }[duration] ?? 1;

    // Parse start time
    final parts = startTime.split(':');
    final startHour = int.parse(parts[0]);
    final startMinute = int.parse(parts[1]);

    // Calculate end time
    final endHour = startHour + hours;

    return '$startTime - ${endHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')} ($hours ${hours == 1 ? 'hour' : 'hours'})';
  }

  void _handleTimeAndDurationSelect(String startTime, int durationHours) async {
    setState(() {
      _selectedStartTime = startTime;
      _selectedDuration = durationHours;
    });

    // Convert String time to TimeOfDay
    final timeParts = startTime.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final timeOfDay = TimeOfDay(hour: hour, minute: minute);

    // Show booking form in drawer
    await _showBookingFormDrawer(_selectedDate!, timeOfDay, durationHours);

    // Clear availability cache to force fresh data
    _availabilityCache.clear();
    // Close the day bookings drawer before reloading
    setState(() {
      _showDayBookings = false;
    });
    await _loadBookings();
  }

  void _showDurationPicker(String startTime, int maxDuration, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text(
          'Select Duration',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Starting at $startTime',
              style: TextStyle(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(maxDuration, (index) {
              final duration = index + 1;
              final parts = startTime.split(':');
              final startHour = int.parse(parts[0]);
              final endHour = startHour + duration;
              final endTime = '${endHour.toString().padLeft(2, '0')}:00';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      _handleTimeAndDurationSelect(startTime, duration);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$duration ${duration == 1 ? 'hour' : 'hours'}',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$startTime - $endTime',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully')),
        );
        setState(() {
          _showCancelDialog = false;
          _selectedBooking = null;
        });
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCreateBooking(Map<String, dynamic> bookingData) async {
    try {
      final newBooking = await _apiService.createBooking(bookingData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking created successfully!')),
        );
        setState(() {
          _showBookingForm = false;
          _selectedBooking = Booking.fromJson(newBooking);
        });
        _showBookingDetailsDrawer();
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create booking: $e'), backgroundColor: Colors.red),
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
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                      Icon(Icons.error_outline, size: 64, color: Colors.red.withOpacity(0.5)),
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
                    // Compact calendar with indicators (55% of space - more room)
                    Expanded(
                      flex: 55,
                      child: _buildCompactCalendar(isDark, isMobile, authProvider),
                    ),
                    const SizedBox(height: 12),
                    // Events list for selected day (45% of space - scrollable if needed)
                    Expanded(
                      flex: 45,
                      child: _buildEventsSection(isDark, isMobile, isUserRole),
                    ),
                  ],
                ),
    );

    final wrapped = widget.skipLayout ? content : AppLayout(child: content);

    return Stack(
      children: [
        wrapped,
        // Cancel confirmation dialog
        if (_showCancelDialog)
          _buildCancelDialog(isDark),
      ],
    );
  }

  Widget _buildViewTypeButton(String label, CalendarViewType type, bool isDark) {
    final isSelected = _viewType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
            ? (isDark ? Colors.white : Colors.black)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected
              ? (isDark ? Colors.black : Colors.white)
              : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildLegendItem('Available', const Color(0xFFD1FAE5), const Color(0xFF052E16), isDark),
        _buildLegendItem('Partial', const Color(0xFFFEF3C7), const Color(0xFF422006), isDark),
        _buildLegendItem('Full', const Color(0xFFFECDD3), const Color(0xFF450A0A), isDark),
        _buildLegendItem('Past', const Color(0xFFE5E7EB), const Color(0xFF09090B), isDark),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color lightColor, Color darkColor, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isDark ? darkColor : lightColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCalendar(bool isDark, bool isMobile, AuthProvider authProvider) {
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = lastDayOfMonth.day;

    final weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Month navigation header (integrated)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left, size: 20),
                color: isDark ? Colors.white : Colors.black,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_currentMonth),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Today button
                    GestureDetector(
                      onTap: _goToToday,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right, size: 20),
                color: isDark ? Colors.white : Colors.black,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Week days header
          Row(
            children: weekDays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),

          // Calendar days grid - Fixed 5 rows
          Expanded(
            child: Column(
              children: List.generate(5, (weekIndex) {
                return Expanded(
                  child: Row(
                    children: List.generate(7, (dayIndex) {
                      final cellIndex = weekIndex * 7 + dayIndex;
                      final dayNumber = cellIndex - firstWeekday + 1;

                      // Only show days from current month
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const Expanded(child: SizedBox());
                      }

                      final day = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                      final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                      final isPast = day.isBefore(DateTime(today.year, today.month, today.day));
                      final isSelected = _selectedDate != null &&
                          _selectedDate!.year == day.year &&
                          _selectedDate!.month == day.month &&
                          _selectedDate!.day == day.day;

                      final dayBookings = _getBookingsForDay(day);
                      final availableSlots = _getAvailableSlots(day);

                      // Check for pending vs confirmed bookings
                      final hasPendingBookings = dayBookings.any((b) => b.status == BookingStatus.PENDING_APPROVAL);
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
                          // Has bookings OR IE blocks but NOT full - Yellow (partial)
                          indicatorColor = const Color(0xFFFBBF24); // Yellow - partial (has bookings/blocks but slots available)
                        }

                        // If not bookable (disabled day), apply darker tone to other indicators
                        if (indicatorColor != null && !isBookable) {
                          indicatorColor = indicatorColor.withOpacity(0.4);
                        }
                      }

                      // Allow ADMIN/MANAGER to click on disabled days to view events
                      // But full days are unclickable for everyone (unless ADMIN/MANAGER)
                      final canClickDay = (isBookable && !isFull) ||
                        (authProvider.user?.role == UserRole.ADMIN ||
                         authProvider.user?.role == UserRole.MANAGER);

                      return Expanded(
                        child: GestureDetector(
                          onTap: canClickDay ? () {
                            setState(() {
                              _selectedDate = day;
                            });
                          } : null,
                          child: Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: isSelected
                                ? (isDark ? Colors.white : Colors.black)
                                : isToday
                                  ? (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNumber',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: !isBookable || isFull
                                          ? const Color(0xFF9CA3AF) // Disabled (past, before 7 business days, or full)
                                          : isSelected
                                            ? (isDark ? Colors.black : Colors.white)
                                            : isDark
                                                ? Colors.white
                                                : Colors.black,
                                    ),
                                  ),
                                  if (indicatorColor != null)
                                    Container(
                                      width: hasPendingBookings && !hasConfirmedBookings ? 6 : 4,
                                      height: hasPendingBookings && !hasConfirmedBookings ? 6 : 4,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        color: hasPendingBookings && !hasConfirmedBookings
                                            ? Colors.transparent
                                            : indicatorColor,
                                        shape: BoxShape.circle,
                                        border: hasPendingBookings && !hasConfirmedBookings
                                            ? Border.all(
                                                color: indicatorColor!,
                                                width: 1.5,
                                              )
                                            : null,
                                      ),
                                    ),
                                ],
                              ),
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
      ),
    );
  }

  Widget _buildEventsSection(bool isDark, bool isMobile, bool isUserRole) {
    if (_selectedDate == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Center(
          child: Text(
            'Select a date',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      );
    }

    final bookingsList = _getBookingsForDay(_selectedDate!);
    final ieBlocks = _getIEBlocksForDay(_selectedDate!);
    final today = DateTime.now();
    final isPast = _selectedDate!.isBefore(DateTime(today.year, today.month, today.day));
    final availableSlots = _getAvailableSlots(_selectedDate!);
    final hasAvailableSlots = !isPast && availableSlots.isNotEmpty;

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
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
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
          // Events list
          Expanded(
            child: combinedEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasAvailableSlots)
                        GestureDetector(
                          onTap: () {
                            _handleDayClick(_selectedDate!);
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              size: 32,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        isPast
                          ? 'Past date'
                          : hasAvailableSlots
                            ? 'No events scheduled\nTap + to create booking'
                            : 'No events',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: combinedEvents.length + (hasAvailableSlots ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Show events in order
                    if (index < combinedEvents.length) {
                      final event = combinedEvents[index];
                      if (event['type'] == 'block') {
                        return _buildIEBlockCard(event['data'] as Map<String, String>, isDark, isUserRole);
                      } else {
                        return _buildColorfulEventCard(event['data'] as Booking, isDark, isUserRole);
                      }
                    }
                    // Finally show add button
                    else {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              _handleDayClick(_selectedDate!);
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white : Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add,
                                size: 24,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
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
              color: const Color(0xFF6B7280).withOpacity(0.6),
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
      case BookingStatus.DRAFT:
      case BookingStatus.CREATED:
        statusColor = const Color(0xFF6B7280); // Gray
        statusLabel = booking.status == BookingStatus.DRAFT ? 'DRAFT' : 'CREATED';
        break;
      case BookingStatus.PENDING_APPROVAL:
      case BookingStatus.UNDER_REVIEW:
      case BookingStatus.NEED_EDIT:
      case BookingStatus.NEED_RESCHEDULE:
        statusColor = const Color(0xFFF59E0B); // Amber/Yellow
        statusLabel = booking.status == BookingStatus.NEED_EDIT
            ? 'NEEDS EDIT'
            : booking.status == BookingStatus.NEED_RESCHEDULE
                ? 'NEEDS RESCHEDULE'
                : booking.status == BookingStatus.UNDER_REVIEW
                    ? 'UNDER REVIEW'
                    : 'PENDING';
        shouldPulse = true; // Animate for pending/review
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
              child: _StatusDot(color: statusColor, shouldPulse: shouldPulse),
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
                            color: statusColor.withOpacity(0.1),
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
  Widget _StatusDot({required Color color, required bool shouldPulse}) {
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
            color: color.withOpacity(value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(value * 0.5),
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
  Widget _StatusBadge({required Color color, required bool shouldPulse}) {
    if (!shouldPulse) {
      return Container(
        width: 4,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          ),
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
          width: 4,
          height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(value),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(value * 0.5),
                blurRadius: 8 * value,
                spreadRadius: 2 * value,
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

  Widget _buildCalendarGrid(bool isDark, bool isMobile) {
    // Switch between different view types
    switch (_viewType) {
      case CalendarViewType.month:
        return _buildMonthView(isDark, isMobile);
      case CalendarViewType.week:
        return _buildWeekView(isDark, isMobile);
      case CalendarViewType.day:
        return _buildDayView(isDark, isMobile);
    }
  }

  Widget _buildMonthView(bool isDark, bool isMobile) {
    final calendarDays = _generateCalendarDays();
    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Week days header
          Row(
            children: weekDays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar days grid
          Expanded(
            child: Column(
              children: List.generate(5, (weekIndex) {
                return Expanded(
                  child: Row(
                    children: List.generate(7, (dayIndex) {
                      final day = calendarDays[weekIndex * 7 + dayIndex];
                      final isCurrentMonth = day.month == _currentMonth.month;
                      final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                      final isBookable = _isDateBookable(day);
                      final dayBookings = _getBookingsForDay(day);

                      final isTapped = _tappedDate != null &&
                                       _tappedDate!.year == day.year &&
                                       _tappedDate!.month == day.month &&
                                       _tappedDate!.day == day.day;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: GestureDetector(
                            onTap: isBookable ? () => _handleDayClick(day) : null,
                            child: AnimatedScale(
                              scale: isTapped ? 0.95 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getDayGradientColor(day, isDark),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isToday
                                        ? (isDark ? Colors.white : Colors.black)
                                        : isDark
                                            ? const Color(0xFF27272A)
                                            : const Color(0xFFE5E7EB),
                                    width: isToday ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                  // Day number
                                  Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: isMobile ? 10 : 12,
                                        fontWeight: FontWeight.bold,
                                        color: !isCurrentMonth || !isBookable
                                            ? const Color(0xFF9CA3AF)
                                            : isDark
                                                ? Colors.white
                                                : Colors.black,
                                      ),
                                    ),
                                  ),

                                  // Bookings preview - show up to 3 bookings sorted by start time
                                  if (isBookable && dayBookings.isNotEmpty) ...[
                                    ...dayBookings.take(3).map((booking) =>
                                      _buildBookingChip(booking.companyName, booking.startTime, isDark, isMobile),
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildWeekView(bool isDark, bool isMobile) {
    final today = DateTime.now();
    // Get current week (Monday to Sunday)
    final startOfWeek = _currentMonth.subtract(Duration(days: _currentMonth.weekday - 1));
    final weekDays = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
    final displayHours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]; // Work hours

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Compact week days header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 50),
                ...weekDays.map((day) {
                  final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                  final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          weekdayNames[(day.weekday - 1) % 7],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          // Time slots grid
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time labels column
                  Container(
                    width: 50,
                    child: Column(
                      children: displayHours.map((hour) {
                        return Container(
                          height: 60,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Days columns with events
                  ...weekDays.map((day) {
                    return Expanded(
                      child: Column(
                        children: displayHours.map((hour) {
                          final dayBookings = _getBookingsForDay(day);
                          Booking? eventAtHour;

                          // Check if there's a booking starting at this hour
                          for (var booking in dayBookings) {
                            final bookingHour = int.parse(booking.startTime.split(':')[0]);
                            if (bookingHour == hour) {
                              eventAtHour = booking;
                              break;
                            }
                          }

                          return Container(
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  width: 0.5,
                                ),
                                bottom: BorderSide(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: eventAtHour != null
                              ? Container(
                                  margin: const EdgeInsets.all(2),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _getEventColor(eventAtHour, isDark),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        eventAtHour.companyName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        eventAtHour.startTime,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor(Booking booking, bool isDark) {
    final colorSchemes = {
      'HEALTH': {'light': const Color(0xFFDCFCE7), 'dark': const Color(0xFF14532D)},
      'TECHNOLOGY': {'light': const Color(0xFFDDD6FE), 'dark': const Color(0xFF4C1D95)},
      'BUSINESS': {'light': const Color(0xFFFED7AA), 'dark': const Color(0xFF7C2D12)},
      'EDUCATION': {'light': const Color(0xFFBAE6FD), 'dark': const Color(0xFF075985)},
    };

    final colorKey = colorSchemes.keys.firstWhere(
      (key) => booking.interestArea?.toUpperCase().contains(key) ?? false,
      orElse: () => 'TECHNOLOGY',
    );
    final colorScheme = colorSchemes[colorKey]!;
    return isDark ? colorScheme['dark'] as Color : colorScheme['light'] as Color;
  }

  Widget _buildDayView(bool isDark, bool isMobile) {
    final today = DateTime.now();
    final selectedDay = _selectedDate ?? _currentMonth;
    final displayHours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19];
    final dayBookings = _getBookingsForDay(selectedDay);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(selectedDay),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          // Time slots with events
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: displayHours.map((hour) {
                  Booking? eventAtHour;

                  // Check if there's a booking starting at this hour
                  for (var booking in dayBookings) {
                    final bookingHour = int.parse(booking.startTime.split(':')[0]);
                    if (bookingHour == hour) {
                      eventAtHour = booking;
                      break;
                    }
                  }

                  return Container(
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Time label
                        Container(
                          width: 70,
                          padding: const EdgeInsets.only(right: 12, top: 8),
                          alignment: Alignment.topRight,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        // Event slot
                        Expanded(
                          child: eventAtHour != null
                            ? Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getEventColor(eventAtHour, isDark),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      eventAtHour.companyName,
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
                                      '${eventAtHour.startTime} - ${eventAtHour.interestArea}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              )
                            : Container(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(DateTime day, bool isDark) {
    final bookingsList = _getBookingsForDay(day);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: bookingsList.isEmpty
              ? Center(
                  child: Text(
                    'No events',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: bookingsList.length,
                  itemBuilder: (context, index) {
                    final booking = bookingsList[index];
                    return _buildEventCard(booking, isDark);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Booking booking, bool isDark) {
    final colors = [
      {'light': const Color(0xFFDCFCE7), 'dark': const Color(0xFF14532D)},
      {'light': const Color(0xFFDDD6FE), 'dark': const Color(0xFF4C1D95)},
      {'light': const Color(0xFFFED7AA), 'dark': const Color(0xFF7C2D12)},
      {'light': const Color(0xFFBAE6FD), 'dark': const Color(0xFF075985)},
    ];
    final colorSet = colors[booking.id.hashCode % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? colorSet['dark'] : colorSet['light'],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.startTime,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            booking.companyName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            booking.interestArea ?? '',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingChip(String companyName, String time, bool isDark, bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            companyName,
            style: TextStyle(
              fontSize: isMobile ? 7 : 8,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: isMobile ? 6 : 7,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(
    AvailablePeriod period,
    bool isDark, {
    bool showBlockDetails = true,
    Function(TimeOfDay, int)? onSlotSelected,
  }) {
    final isAvailable = period.available;
    final willBlock = period.willBlock;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isAvailable ? () async {
            // Calculate duration based on visit type
            final duration = _selectedVisitType == 'QUICK_TOUR' ? 2 : 4;

            // Parse start time to TimeOfDay
            final timeParts = period.startTime.split(':');
            final startTime = TimeOfDay(
              hour: int.parse(timeParts[0]),
              minute: int.parse(timeParts[1]),
            );

            // If callback is provided (from booking flow service), use it
            if (onSlotSelected != null) {
              // Close the modal bottom sheet drawer only
              Navigator.of(context, rootNavigator: false).pop();

              // Call the callback
              onSlotSelected(startTime, duration);
            } else {
              // Close drawer for default flow
              Navigator.of(context).pop();

              // Use the default flow
              await _showBookingFormDrawer(_selectedDate!, startTime, duration);

              // ALWAYS clear cache after closing form
              final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
              setState(() {
                _availabilityCache.remove(dateStr);
                _selectedDayAvailability = null;
                _selectedVisitType = null;
                _selectedStartTime = null;
                _selectedDuration = null;
              });

              // Reload bookings
              await _loadBookings();
            }
          } : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isAvailable
                  ? (isDark ? const Color(0xFF18181B) : Colors.white)
                  : (isDark ? const Color(0xFF09090B) : const Color(0xFFF3F4F6)),
              border: Border.all(
                color: isAvailable
                    ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                    : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? (isDark ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF10B981).withValues(alpha: 0.1))
                            : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        period.period == 'MORNING' ? Icons.wb_sunny : Icons.nights_stay,
                        size: 24,
                        color: isAvailable
                            ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                            : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isAvailable
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                            ),
                          ),
                          if (showBlockDetails && !isAvailable && period.blockedBy != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.block,
                                  size: 14,
                                  color: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    period.blockedBy!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isAvailable)
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                      ),
                  ],
                ),

                // Show blocks for Innovation Exchange (only for ADMIN/MANAGER)
                if (showBlockDetails && isAvailable && willBlock != null && willBlock.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.1) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : const Color(0xFFF59E0B),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Periods that will be blocked:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...willBlock.map((block) => Padding(
                          padding: const EdgeInsets.only(left: 24, top: 4),
                          child: Text(
                            '• ${block.date}: ${block.period}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                            ),
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayBookingsOverlay(bool isDark, bool isMobile, bool isUserRole) {
    final dayBookings = _getBookingsForDay(_selectedDate!);
    final hasBookings = dayBookings.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75, // Standard 75% height
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
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                        tooltip: 'Close',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMMM d, yyyy').format(_selectedDate!),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              hasBookings && !isUserRole ? 'View and manage bookings' : 'Schedule new visit',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Only show existing bookings to ADMIN/MANAGER users
                        if (hasBookings && !isUserRole) ...[
                          Text(
                            'Existing Bookings',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...dayBookings.map((booking) => _buildBookingCard(booking, isDark, isUserRole)),
                          const SizedBox(height: 24),
                        ],
                        // Add New Booking Button
                        Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  // Close the day bookings drawer first
                                  Navigator.of(context).pop();
                                  // Wait a bit for animation
                                  await Future.delayed(const Duration(milliseconds: 300));
                                  // Show visit type selection dialog (new flow)
                                  await _showVisitTypeSelectionDialog(_selectedDate!);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.add_circle,
                                        color: isDark ? Colors.white : Colors.black,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Add New Booking',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Schedule a new visit',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            )
    );
  }

  Widget _buildBookingCard(Booking booking, bool isDark, bool isUserRole) {
    // Format time text based on actual start time and duration
    final timeText = _formatTimeSlot(booking.startTime, booking.duration);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(booking.id),
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleBookingClick(booking),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                border: Border.all(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isUserRole ? 'Occupied' : booking.companyName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      // Pending Approval Badge
                      if (booking.status == BookingStatus.PENDING_APPROVAL)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFF59E0B),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pending_actions,
                                size: 12,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBookingDetailsDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isUserRole = authProvider.user?.role == UserRole.USER;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                      tooltip: 'Close',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Booking Details',
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
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date & Time
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMMM d, yyyy').format(_selectedBooking!.date),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimeSlot(_selectedBooking!.startTime, _selectedBooking!.duration),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Company Info (hidden for USER role)
                      if (!isUserRole) ...[
                        _buildDetailSection('Company Information', isDark, [
                          _buildDetailItem('Account Name', _selectedBooking!.accountName, isDark),
                          _buildDetailItem('Company Name', _selectedBooking!.companyName, isDark),
                          if (_selectedBooking!.companySector != null)
                            _buildDetailItem('Sector', _selectedBooking!.companySector!, isDark),
                          if (_selectedBooking!.companyVertical != null)
                            _buildDetailItem('Vertical', _selectedBooking!.companyVertical!, isDark),
                          if (_selectedBooking!.companySize != null)
                            _buildDetailItem('Size', _selectedBooking!.companySize!, isDark),
                        ]),
                        const SizedBox(height: 24),
                      ],
                      // Visit Details (simplified for USER role)
                      _buildDetailSection('Visit Details', isDark, [
                        if (_selectedBooking!.venue != null)
                          _buildDetailItem('Venue', _selectedBooking!.venue!, isDark),
                        // USER role: only show status
                        if (isUserRole) ...[
                          _buildDetailItem('Status', _selectedBooking!.status.name, isDark),
                        ],
                        // ADMIN/MANAGER: show all details
                        if (!isUserRole) ...[
                          _buildDetailItem('Expected Attendees', '${_selectedBooking!.expectedAttendees}', isDark),
                          if (_selectedBooking!.overallTheme != null)
                            _buildDetailItem('Overall Theme', _selectedBooking!.overallTheme!, isDark),
                          if (_selectedBooking!.lastInnovationDay != null)
                            _buildDetailItem('Last Innovation Day', DateFormat('MMM d, yyyy').format(_selectedBooking!.lastInnovationDay!), isDark),
                          if (_selectedBooking!.eventType != null)
                            _buildDetailItem('Event Type', _selectedBooking!.eventType!.name, isDark),
                          if (_selectedBooking!.partnerName != null)
                            _buildDetailItem('Partner Name', _selectedBooking!.partnerName!, isDark),
                          if (_selectedBooking!.dealStatus != null)
                            _buildDetailItem('Deal Status', _selectedBooking!.dealStatus!.name, isDark),
                          _buildDetailItem('Attach Head Approval', _selectedBooking!.attachHeadApproval ? 'Yes' : 'No', isDark),
                          // Legacy fields
                          if (_selectedBooking!.interestArea != null)
                            _buildDetailItem('Interest Area', _selectedBooking!.interestArea!, isDark),
                          if (_selectedBooking!.businessGoal != null)
                            _buildDetailItem('Business Goal', _selectedBooking!.businessGoal!, isDark),
                          if (_selectedBooking!.additionalNotes != null)
                            _buildDetailItem('Additional Notes', _selectedBooking!.additionalNotes!, isDark),
                        ],
                      ]),
                      const SizedBox(height: 24),
                      // Attendees Carousel (hidden for USER role - personal data)
                      if (!isUserRole && _selectedBooking!.attendees != null && _selectedBooking!.attendees!.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Attendees (${_selectedBooking!.attendees!.length})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            if (_selectedBooking!.attendees!.length > 1)
                              Row(
                                children: [
                                  Icon(
                                    Icons.arrow_back_ios,
                                    size: 14,
                                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Swipe',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 462,
                          child: PageView.builder(
                            controller: PageController(viewportFraction: 0.9),
                            itemCount: _selectedBooking!.attendees!.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentBadgeIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final attendee = _selectedBooking!.attendees![index];
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: AccessBadge(
                                    attendeeName: attendee.name,
                                    attendeePosition: attendee.position,
                                    attendeeId: attendee.id,
                                    companyName: _selectedBooking!.companyName,
                                    date: _selectedBooking!.date,
                                    startTime: _selectedBooking!.startTime,
                                    duration: _selectedBooking!.duration.name,
                                    bookingId: _selectedBooking!.id,
                                    isDark: isDark,
                                    showActions: false,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final attendee = _selectedBooking!.attendees![_currentBadgeIndex];
                                    final badgeUrl = 'https://paceportsp.com.br/attendee/${attendee.id ?? _selectedBooking!.id}';
                                    try {
                                      await Share.share(
                                        'TCS PacePort Access Ticket\n${attendee.name} - ${_selectedBooking!.companyName}\n$badgeUrl',
                                        subject: 'TCS PacePort Access Ticket',
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error sharing: $e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.share, size: 16),
                                  label: const Text('Share', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : Colors.black,
                                    side: BorderSide(
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final attendee = _selectedBooking!.attendees![_currentBadgeIndex];
                                    final badgeUrl = 'https://paceportsp.com.br/attendee/${attendee.id ?? _selectedBooking!.id}';
                                    Clipboard.setData(ClipboardData(text: badgeUrl));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Link copied to clipboard'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.link, size: 16),
                                  label: const Text('Copy', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : Colors.black,
                                    side: BorderSide(
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final attendee = _selectedBooking!.attendees![_currentBadgeIndex];
                                    final badge = AccessBadge(
                                      attendeeName: attendee.name,
                                      attendeePosition: attendee.position,
                                      attendeeId: attendee.id,
                                      companyName: _selectedBooking!.companyName,
                                      date: _selectedBooking!.date,
                                      startTime: _selectedBooking!.startTime,
                                      duration: _selectedBooking!.duration.name,
                                      bookingId: _selectedBooking!.id,
                                      isDark: isDark,
                                    );
                                    await badge.showPrintPreview(context);
                                  },
                                  icon: const Icon(Icons.print, size: 16),
                                  label: const Text('Print', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark ? Colors.white : Colors.black,
                                    side: BorderSide(
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer with cancel button
              if (_selectedBooking!.status != BookingStatus.CANCELLED)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() => _showCancelDialog = true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF450A0A) : Colors.red[50],
                        foregroundColor: isDark ? Colors.red[400] : Colors.red[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF7F1D1D) : Colors.red[200]!,
                          ),
                        ),
                      ),
                      child: const Text('Cancel Booking'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, bool isDark, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingFormOverlay(bool isDark, bool isMobile) {
    // Prepare slot string for backward compatibility with BookingFormScreen
    final slotString = '$_selectedStartTime (${_selectedDuration}h)';

    return _BookingFormWidget(
      isDark: isDark,
      isMobile: isMobile,
      selectedDate: _selectedDate!,
      selectedSlot: slotString,
      selectedStartTime: _selectedStartTime!,
      selectedDuration: _selectedDuration!,
      selectedVisitType: _selectedVisitType!,
      onSubmit: _handleCreateBooking,
      onCancel: _closeBookingFormAndClearCache,
      showForm: _showBookingForm,
    );
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select Sector, Vertical, and Interest Area'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_attendees.isEmpty ||
        _attendees[0]['name']?.text.trim().isEmpty != false ||
        _attendees[0]['email']?.text.trim().isEmpty != false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('First attendee name and email are required'),
          backgroundColor: Colors.red,
        ),
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
                              value: _companySector,
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
                              value: _companyVertical,
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
                              value: _interestArea,
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
                            }).toList(),

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
                          Navigator.of(context).pop();
                          widget.onClose();
                        },
                        icon: Icon(Icons.close, color: widget.isDark ? Colors.white : Colors.black),
                        tooltip: 'Close',
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
              child: SingleChildScrollView(
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
                    ? Colors.black
                    : (isAvailable
                        ? (widget.isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                        : (widget.isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB))),
                width: isSelected ? 3 : 2,
              ),
              borderRadius: BorderRadius.circular(12),
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
    final duration = widget.selectedVisitType == 'QUICK_TOUR' ? 2 : 4;

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
