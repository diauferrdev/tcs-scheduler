import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';

/// Reusable calendar month view widget
/// EXACTLY the same as calendar_screen.dart _buildMonthView
/// Extracted to be shared with RescheduleDrawer
class CalendarMonthWidget extends StatelessWidget {
  final DateTime currentMonth;
  final List<Booking> bookings;
  final Map<String, DayAvailability> availabilityCache;
  final DateTime? tappedDate;
  final Function(DateTime) onDayTap;
  final bool isMobile;

  const CalendarMonthWidget({
    super.key,
    required this.currentMonth,
    required this.bookings,
    required this.availabilityCache,
    required this.onDayTap,
    this.tappedDate,
    this.isMobile = false,
  });

  /// Check if a date is a weekend
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

  /// Get the gradient color for a day based on its status
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
    final confirmedBookings = bookings.where((b) {
      final bookingDate = DateFormat('yyyy-MM-dd').format(b.date);
      return bookingDate == dateStr && b.status == BookingStatus.APPROVED;
    }).toList();

    final availability = availabilityCache[dateStr];

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

  /// Generate calendar days for the current month (5 weeks = 35 days)
  List<DateTime> _generateCalendarDays() {
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);

    // Start from Sunday of the week containing the first day
    int daysFromSunday = firstDay.weekday % 7;
    final startDate = firstDay.subtract(Duration(days: daysFromSunday));

    // Generate 35 days (5 weeks)
    return List.generate(35, (index) => startDate.add(Duration(days: index)));
  }

  /// Get bookings for a specific day
  List<Booking> _getBookingsForDay(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayBookings = bookings.where((b) {
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

    // Sort by start time
    dayBookings.sort((a, b) => a.startTime.compareTo(b.startTime));
    return dayBookings;
  }

  /// Build a booking chip widget
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                      final isCurrentMonth = day.month == currentMonth.month;
                      final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                      final isBookable = _isDateBookable(day);
                      final dayBookings = _getBookingsForDay(day);

                      final isTapped = tappedDate != null &&
                                       tappedDate!.year == day.year &&
                                       tappedDate!.month == day.month &&
                                       tappedDate!.day == day.day;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: GestureDetector(
                            onTap: isBookable ? () => onDayTap(day) : null,
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
}
