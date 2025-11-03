import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../screens/calendar_screen.dart';
import '../utils/toast_notification.dart';

/// Drawer for USER to reschedule booking when status is NEED_RESCHEDULE
/// Uses the EXACT SAME CalendarScreen as the main Calendar page
class RescheduleDrawer extends StatefulWidget {
  final Booking booking;
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const RescheduleDrawer({
    super.key,
    required this.booking,
    required this.onClose,
    required this.onSuccess,
  });

  @override
  State<RescheduleDrawer> createState() => _RescheduleDrawerState();
}

class _RescheduleDrawerState extends State<RescheduleDrawer> {
  final ApiService _apiService = ApiService();

  bool _loading = false;
  bool _submitting = false;

  Future<void> _handleDaySelected(DateTime day) async {
    setState(() {
      _loading = true;
    });

    try {
      final response = await _apiService.checkAvailability(
        DateFormat('yyyy-MM-dd').format(day),
        visitType: widget.booking.visitType.name,
      );

      if (mounted) {
        setState(() => _loading = false);

        // Immediately open slot picker drawer with availability
        final availability = DayAvailability.fromJson(response);
        final allPeriods = availability.allPeriods ?? [];

        if (allPeriods.isEmpty) {
          ToastNotification.show(
            context,
            message: 'No time slots available for this date',
            type: ToastType.warning,
          );
          return;
        }

        _openSlotPickerDrawer(day, allPeriods);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ToastNotification.show(
          context,
          message: 'Error loading availability: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _openSlotPickerDrawer(DateTime date, List<AvailablePeriod> allPeriods) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visitTypeLabel = widget.booking.visitType == VisitType.PACE_TOUR
        ? 'Pace Tour (2h)'
        : widget.booking.visitType == VisitType.PACE_EXPERIENCE
            ? 'Pace Experience (4h)'
            : 'Innovation Exchange (6h)';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => SlotPickerContent(
        date: date,
        allPeriods: allPeriods,
        visitTypeLabel: visitTypeLabel,
        selectedVisitType: widget.booking.visitType.name,
        isUserRole: true,
        isDark: isDark,
        onSlotSelected: (TimeOfDay startTime, int duration) async {
          // Format time as HH:mm
          final formattedTime = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

          // Immediately reschedule
          await _performReschedule(date, formattedTime);
        },
        onClose: () {
          // User cancelled selection
        },
      ),
    );
  }

  Future<void> _performReschedule(DateTime date, String timeSlot) async {
    if (_submitting) return; // Prevent double submission

    setState(() => _submitting = true);

    try {
      final duration = widget.booking.duration.name;

      await _apiService.userRescheduleBooking(
        widget.booking.id,
        DateFormat('yyyy-MM-dd').format(date),
        timeSlot,
        duration,
      );

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Booking rescheduled successfully! Status changed to Under Review.',
          type: ToastType.success,
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ToastNotification.show(
          context,
          message: 'Error rescheduling booking: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isDark),

              // Use CalendarScreen directly - the SAME component as the main Calendar page
              Expanded(
                child: CalendarScreen(
                  skipLayout: true, // Don't show AppLayout wrapper
                  onDaySelected: _handleDaySelected, // Callback when user clicks a day
                ),
              ),
            ],
          ),

          // Loading indicator overlay when loading availability or submitting
          if (_loading || _submitting)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose New Date',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Click on an available date to reschedule',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
