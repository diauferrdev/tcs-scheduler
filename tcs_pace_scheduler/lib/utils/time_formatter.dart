import 'package:intl/intl.dart';

/// Utility class for formatting time with Brazilian timezone and AM/PM format
class TimeFormatter {
  /// Format time string (HH:mm format) to AM/PM format
  /// Example: "14:30" -> "2:30 PM"
  static String formatToAMPM(String timeString) {
    try {
      // Parse time string (HH:mm format)
      final parts = timeString.split(':');
      if (parts.length != 2) return timeString;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Convert to 12-hour format
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

      // Format with leading zero for minutes
      final minuteStr = minute.toString().padLeft(2, '0');

      return '$hour12:$minuteStr $period';
    } catch (e) {
      return timeString; // Return original if parsing fails
    }
  }

  /// Format a time range (start - end)
  /// Example: "14:00" and "18:00" -> "2:00 PM - 6:00 PM"
  static String formatTimeRange(String startTime, String endTime) {
    return '${formatToAMPM(startTime)} - ${formatToAMPM(endTime)}';
  }

  /// Calculate end time based on start time and duration enum
  /// Example: "14:00" + FOUR_HOURS -> "18:00"
  static String calculateEndTime(String startTime, String durationEnum) {
    try {
      // Parse start time
      final parts = startTime.split(':');
      if (parts.length != 2) return startTime;

      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Get hours from duration enum
      int durationHours = 0;
      switch (durationEnum.toUpperCase()) {
        case 'ONE_HOUR':
          durationHours = 1;
          break;
        case 'TWO_HOURS':
          durationHours = 2;
          break;
        case 'THREE_HOURS':
          durationHours = 3;
          break;
        case 'FOUR_HOURS':
          durationHours = 4;
          break;
        case 'FIVE_HOURS':
          durationHours = 5;
          break;
        case 'SIX_HOURS':
          durationHours = 6;
          break;
        default:
          durationHours = 4; // Default fallback
      }

      // Calculate end time
      hour += durationHours;

      // Format back to HH:mm
      final endHour = hour.toString().padLeft(2, '0');
      final endMinute = minute.toString().padLeft(2, '0');

      return '$endHour:$endMinute';
    } catch (e) {
      return startTime;
    }
  }

  /// Format a booking's time slot with start and end
  /// Example: booking with "14:00" start and FOUR_HOURS duration -> "2:00 PM - 6:00 PM"
  static String formatBookingTimeSlot(String startTime, String durationEnum) {
    final endTime = calculateEndTime(startTime, durationEnum);
    return formatTimeRange(startTime, endTime);
  }

  /// Get simple text for user role based on occupation
  /// Returns "Full" instead of "Occupied"
  static String getSimpleOccupationText() {
    return 'Full';
  }

  /// Get detailed text for admin/manager roles
  static String getDetailedOccupationText(String companyName) {
    return companyName;
  }
}
