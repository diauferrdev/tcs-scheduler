import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:intl/intl.dart';

/// Calendar Service
/// Handles adding bookings to device calendar
class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  /// Add booking to device calendar
  /// Returns true if successful, false otherwise
  Future<bool> addBookingToCalendar({
    required String companyName,
    required String date,
    required String time,
    String? sector,
    int? expectedAttendees,
    String? eventType,
  }) async {
    try {

      // Parse date and time
      final DateTime? startDate = _parseDateTime(date, time);
      if (startDate == null) {
        return false;
      }

      // End time is 2 hours later (typical visit duration)
      final DateTime endDate = startDate.add(const Duration(hours: 2));

      // Build description
      final description = _buildDescription(
        sector: sector,
        expectedAttendees: expectedAttendees,
        eventType: eventType,
      );

      // Create calendar event
      final Event event = Event(
        title: '🏢 $companyName Visit',
        description: description,
        location: 'PacePort São Paulo',
        startDate: startDate,
        endDate: endDate,
        allDay: false,
        iosParams: const IOSParams(
          reminder: Duration(hours: 1), // Remind 1 hour before
          url: 'https://ppspsched.lat',
        ),
        androidParams: const AndroidParams(
          emailInvites: [], // Could add attendee emails here
        ),
      );


      // Add to calendar
      final bool result = await Add2Calendar.addEvent2Cal(event);

      if (result) {
      } else {
      }

      return result;
    } catch (e) {
      return false;
    }
  }

  /// Parse date and time strings into DateTime
  DateTime? _parseDateTime(String dateStr, String timeStr) {
    try {
      // Try common date formats
      final dateFormats = [
        'dd/MM/yyyy',
        'yyyy-MM-dd',
        'MMM d, yyyy',
        'd/M/yyyy',
      ];

      DateTime? parsedDate;
      for (final format in dateFormats) {
        try {
          parsedDate = DateFormat(format).parse(dateStr);
          break;
        } catch (_) {
          continue;
        }
      }

      if (parsedDate == null) {
        return null;
      }

      // Parse time (HH:mm or H:mm or HH:mm AM/PM)
      final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
      final match = timeRegex.firstMatch(timeStr);

      if (match == null) {
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 9, 0); // Default to 9 AM
      }

      int hour = int.parse(match.group(1)!);
      final int minute = int.parse(match.group(2)!);

      // Handle AM/PM
      if (timeStr.toUpperCase().contains('PM') && hour < 12) {
        hour += 12;
      } else if (timeStr.toUpperCase().contains('AM') && hour == 12) {
        hour = 0;
      }

      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        hour,
        minute,
      );
    } catch (e) {
      return null;
    }
  }

  /// Build event description
  String _buildDescription({
    String? sector,
    int? expectedAttendees,
    String? eventType,
  }) {
    final lines = <String>[
      '📍 Location: PacePort São Paulo',
      if (sector != null) '🏢 Sector: $sector',
      if (expectedAttendees != null) '👥 Expected Attendees: $expectedAttendees',
      if (eventType != null) '🎯 Type: $eventType',
      '',
      'This event was added from Pace Scheduler.',
    ];

    return lines.join('\n');
  }
}
