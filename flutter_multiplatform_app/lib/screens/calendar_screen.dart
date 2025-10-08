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
import '../services/api_service.dart';
import '../models/booking.dart';
import '../widgets/access_badge.dart';

class CalendarScreen extends StatefulWidget {
  final bool skipLayout;

  const CalendarScreen({super.key, this.skipLayout = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<Booking> _bookings = [];
  bool _loading = true;
  String? _error;
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  String? _selectedSlot;
  Booking? _selectedBooking;
  bool _showSlotPicker = false;
  bool _showDayBookings = false;
  bool _showBookingDetails = false;
  bool _showBookingForm = false;
  bool _showCancelDialog = false;
  DateTime? _tappedDate;
  int _currentBadgeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await _apiService.getBookings();
      final data = response is List ? response : (response['data'] as List? ?? []);

      setState(() {
        _bookings = data.map((e) => Booking.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, Booking?> _getBookingsForDay(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayBookings = _bookings.where((b) {
      final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);
      return bookingDate == dateStr && b.status != BookingStatus.CANCELLED;
    }).toList();

    final fullDayBooking = dayBookings.where((b) => b.duration == VisitDuration.SIX_HOURS).firstOrNull;
    if (fullDayBooking != null) {
      return {
        'morning': null,
        'afternoon': null,
        'fullDay': fullDayBooking,
      };
    }

    final morningBooking = dayBookings.where((b) => b.startTime == '09:00').firstOrNull;
    final afternoonBooking = dayBookings.where((b) => b.startTime == '14:00').firstOrNull;

    return {
      'morning': morningBooking,
      'afternoon': afternoonBooking,
      'fullDay': null,
    };
  }

  Color _getDayGradientColor(DateTime day, bool isDark) {
    final today = DateTime.now();
    final isPast = day.isBefore(DateTime(today.year, today.month, today.day));

    if (isPast) {
      return isDark ? const Color(0xFF09090B) : const Color(0xFFE5E7EB);
    }

    final dayBookings = _getBookingsForDay(day);
    final hasFullDay = dayBookings['fullDay'] != null;
    final hasMorning = dayBookings['morning'] != null;
    final hasAfternoon = dayBookings['afternoon'] != null;

    // Fully booked - Red
    if (hasFullDay || (hasMorning && hasAfternoon)) {
      return isDark ? const Color(0xFF450A0A) : const Color(0xFFFECDD3);
    }

    // Partially booked - Yellow
    if (hasMorning || hasAfternoon) {
      return isDark ? const Color(0xFF422006) : const Color(0xFFFEF3C7);
    }

    // Available - Green
    return isDark ? const Color(0xFF052E16) : const Color(0xFFD1FAE5);
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

  void _handleDayClick(DateTime date) {
    final today = DateTime.now();
    final isPast = date.isBefore(DateTime(today.year, today.month, today.day));

    if (isPast) return;

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
    final hasBookings = dayBookings.values.any((b) => b != null);

    if (hasBookings) {
      _showDayBookingsDrawer(date);
    } else {
      _showSlotPickerDrawer(date);
    }
  }

  void _showSlotPickerDrawer(DateTime date) {
    setState(() => _showSlotPicker = true);
  }

  void _showDayBookingsDrawer(DateTime date) {
    setState(() => _showDayBookings = true);
  }

  List<String> _getAvailableSlots(DateTime date) {
    final dayBookings = _getBookingsForDay(date);
    final hasFullDay = dayBookings['fullDay'] != null;
    final hasMorning = dayBookings['morning'] != null;
    final hasAfternoon = dayBookings['afternoon'] != null;

    final slots = <String>[];
    if (!hasFullDay && !hasMorning) slots.add('morning');
    if (!hasFullDay && !hasAfternoon) slots.add('afternoon');
    if (!hasMorning && !hasAfternoon && !hasFullDay) slots.add('full-day');

    return slots;
  }

  void _handleSlotSelect(String slot) {
    setState(() {
      _selectedSlot = slot;
      _showSlotPicker = false;
      _showDayBookings = false;
      _showBookingForm = true;
    });
  }

  void _handleBookingClick(Booking booking) {
    setState(() {
      _selectedBooking = booking;
      _showDayBookings = false;
      _showBookingDetails = true;
    });
  }

  Future<void> _handleCancelBooking() async {
    if (_selectedBooking == null) return;

    try {
      await _apiService.deleteBooking(_selectedBooking!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully')),
        );
        setState(() {
          _showCancelDialog = false;
          _showBookingDetails = false;
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
          _showBookingDetails = true;
        });
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
    final isDark = themeProvider.isDark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final content = Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          // Header with month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ],
              ),
              if (!isMobile) _buildLegend(isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar Grid
          Expanded(
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
                    : _buildCalendarGrid(isDark, isMobile),
          ),

          // Mobile legend
          if (isMobile) ...[
            const SizedBox(height: 16),
            _buildLegend(isDark),
          ],
        ],
      ),
    );

    final wrapped = widget.skipLayout ? content : AppLayout(child: content);

    return Stack(
      children: [
        wrapped,
        // Slot picker drawer/bottom sheet - always in tree
        IgnorePointer(
          ignoring: !_showSlotPicker,
          child: AnimatedOpacity(
            opacity: _showSlotPicker ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _selectedDate != null ? _buildSlotPickerOverlay(isDark, isMobile) : const SizedBox.shrink(),
          ),
        ),
        // Day bookings drawer - always in tree
        IgnorePointer(
          ignoring: !_showDayBookings,
          child: AnimatedOpacity(
            opacity: _showDayBookings ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _selectedDate != null ? _buildDayBookingsOverlay(isDark, isMobile) : const SizedBox.shrink(),
          ),
        ),
        // Booking details drawer - always in tree
        IgnorePointer(
          ignoring: !_showBookingDetails,
          child: AnimatedOpacity(
            opacity: _showBookingDetails ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _selectedBooking != null ? _buildBookingDetailsOverlay(isDark, isMobile) : const SizedBox.shrink(),
          ),
        ),
        // Booking form - always in tree
        IgnorePointer(
          ignoring: !_showBookingForm,
          child: AnimatedOpacity(
            opacity: _showBookingForm ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: (_selectedDate != null && _selectedSlot != null) ? _buildBookingFormOverlay(isDark, isMobile) : const SizedBox.shrink(),
          ),
        ),
        // Cancel confirmation dialog
        if (_showCancelDialog)
          _buildCancelDialog(isDark),
      ],
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

  Widget _buildCalendarGrid(bool isDark, bool isMobile) {
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
                      final isPast = day.isBefore(DateTime(today.year, today.month, today.day));
                      final dayBookings = _getBookingsForDay(day);

                      final isTapped = _tappedDate != null &&
                                       _tappedDate!.year == day.year &&
                                       _tappedDate!.month == day.month &&
                                       _tappedDate!.day == day.day;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: GestureDetector(
                            onTap: () => _handleDayClick(day),
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
                                        color: !isCurrentMonth || isPast
                                            ? const Color(0xFF9CA3AF)
                                            : isDark
                                                ? Colors.white
                                                : Colors.black,
                                      ),
                                    ),
                                  ),

                                  // Bookings preview
                                  if (!isPast) ...[
                                    if (dayBookings['fullDay'] != null)
                                      _buildBookingChip(dayBookings['fullDay']!.companyName, 'Full', isDark, isMobile),
                                    if (dayBookings['morning'] != null)
                                      _buildBookingChip(dayBookings['morning']!.companyName, '09:00', isDark, isMobile),
                                    if (dayBookings['afternoon'] != null)
                                      _buildBookingChip(dayBookings['afternoon']!.companyName, '14:00', isDark, isMobile),
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

  Widget _buildSlotPickerOverlay(bool isDark, bool isMobile) {
    final availableSlots = _getAvailableSlots(_selectedDate!);

    return GestureDetector(
      onTap: () => setState(() => _showSlotPicker = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // Prevent dismiss when tapping content
            child: AnimatedSlide(
              offset: _showSlotPicker ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - 80),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Time Slot',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _showSlotPicker = false),
                        icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMMM d, yyyy').format(_selectedDate!),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...availableSlots.map((slot) {
                    String title, subtitle;
                    switch (slot) {
                      case 'morning':
                        title = 'Morning Session';
                        subtitle = '09:00 - 12:00 (3 hours)';
                        break;
                      case 'afternoon':
                        title = 'Afternoon Session';
                        subtitle = '14:00 - 17:00 (3 hours)';
                        break;
                      case 'full-day':
                        title = 'Full Day';
                        subtitle = '09:00 - 17:00 (6 hours)';
                        break;
                      default:
                        title = '';
                        subtitle = '';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleSlotSelect(slot),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
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
                    );
                  }).toList(),
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayBookingsOverlay(bool isDark, bool isMobile) {
    final dayBookings = _getBookingsForDay(_selectedDate!);
    final availableSlots = _getAvailableSlots(_selectedDate!);
    final hasBookings = dayBookings.values.any((b) => b != null);

    return GestureDetector(
      onTap: () => setState(() => _showDayBookings = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: AnimatedSlide(
              offset: _showDayBookings ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - 80),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
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
                          const SizedBox(height: 4),
                          Text(
                            'Bookings and available slots',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => setState(() => _showDayBookings = false),
                        icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (hasBookings) ...[
                    Text(
                      'Existing Bookings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (dayBookings['fullDay'] != null)
                      _buildBookingCard(dayBookings['fullDay']!, isDark),
                    if (dayBookings['morning'] != null)
                      _buildBookingCard(dayBookings['morning']!, isDark),
                    if (dayBookings['afternoon'] != null)
                      _buildBookingCard(dayBookings['afternoon']!, isDark),
                    const SizedBox(height: 24),
                  ],
                  if (availableSlots.isNotEmpty) ...[
                    Text(
                      'Available Slots',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...availableSlots.map((slot) {
                      String title, subtitle;
                      switch (slot) {
                        case 'morning':
                          title = 'Add Morning Session';
                          subtitle = '09:00 - 12:00 (3 hours)';
                          break;
                        case 'afternoon':
                          title = 'Add Afternoon Session';
                          subtitle = '14:00 - 17:00 (3 hours)';
                          break;
                        case 'full-day':
                          title = 'Add Full Day';
                          subtitle = '09:00 - 17:00 (6 hours)';
                          break;
                        default:
                          title = '';
                          subtitle = '';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _handleSlotSelect(slot),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitle,
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
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, bool isDark) {
    String timeText;
    if (booking.duration == VisitDuration.SIX_HOURS) {
      timeText = 'Full Day (09:00 - 17:00)';
    } else if (booking.startTime == '09:00') {
      timeText = 'Morning (09:00 - 12:00)';
    } else {
      timeText = 'Afternoon (14:00 - 17:00)';
    }

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
                  Text(
                    booking.companyName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
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

  Widget _buildBookingDetailsOverlay(bool isDark, bool isMobile) {
    return GestureDetector(
      onTap: () => setState(() => _showBookingDetails = false),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: AnimatedSlide(
              offset: _showBookingDetails ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - 80),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
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
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Booking Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _showBookingDetails = false),
                          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
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
                                      _selectedBooking!.duration == VisitDuration.SIX_HOURS
                                          ? 'Full Day (09:00-17:00)'
                                          : _selectedBooking!.startTime == '09:00'
                                              ? 'Morning (09:00-12:00)'
                                              : 'Afternoon (14:00-17:00)',
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
                          // Company Info
                          _buildDetailSection('Company Information', isDark, [
                            _buildDetailItem('Company Name', _selectedBooking!.companyName, isDark),
                            _buildDetailItem('Sector', _selectedBooking!.companySector, isDark),
                            _buildDetailItem('Vertical', _selectedBooking!.companyVertical, isDark),
                            if (_selectedBooking!.companySize != null)
                              _buildDetailItem('Size', _selectedBooking!.companySize!, isDark),
                          ]),
                          const SizedBox(height: 24),
                          // Visit Details
                          _buildDetailSection('Visit Details', isDark, [
                            _buildDetailItem('Interest Area', _selectedBooking!.interestArea, isDark),
                            _buildDetailItem('Expected Attendees', '${_selectedBooking!.expectedAttendees}', isDark),
                            if (_selectedBooking!.businessGoal != null)
                              _buildDetailItem('Business Goal', _selectedBooking!.businessGoal!, isDark),
                            if (_selectedBooking!.additionalNotes != null)
                              _buildDetailItem('Additional Notes', _selectedBooking!.additionalNotes!, isDark),
                          ]),
                          const SizedBox(height: 24),
                          // Attendees Carousel
                          if (_selectedBooking!.attendees != null && _selectedBooking!.attendees!.isNotEmpty) ...[
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
                          onPressed: () => setState(() => _showCancelDialog = true),
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
    return _BookingFormWidget(
      isDark: isDark,
      isMobile: isMobile,
      selectedDate: _selectedDate!,
      selectedSlot: _selectedSlot!,
      onSubmit: _handleCreateBooking,
      onCancel: () => setState(() => _showBookingForm = false),
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
  final String selectedSlot;
  final Function(Map<String, dynamic>) onSubmit;
  final VoidCallback onCancel;
  final bool showForm;

  const _BookingFormWidget({
    required this.isDark,
    required this.isMobile,
    required this.selectedDate,
    required this.selectedSlot,
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

      // Determine duration and start time based on slot
      String duration;
      String startTime;

      switch (widget.selectedSlot) {
        case 'morning':
          duration = 'THREE_HOURS';
          startTime = '09:00';
          break;
        case 'afternoon':
          duration = 'THREE_HOURS';
          startTime = '14:00';
          break;
        case 'full-day':
          duration = 'SIX_HOURS';
          startTime = '09:00';
          break;
        default:
          duration = 'THREE_HOURS';
          startTime = '09:00';
      }

      // Use first attendee as main contact
      final firstAttendee = _attendees[0];

      final bookingData = {
        'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        'duration': duration,
        'startTime': startTime,
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

      await widget.onSubmit(bookingData);
    } finally {
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
