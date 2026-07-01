import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../utils/toast_notification.dart';

class RescheduleDialog extends StatefulWidget {
  final Booking booking;
  final VoidCallback onRescheduled;

  const RescheduleDialog({
    super.key,
    required this.booking,
    required this.onRescheduled,
  });

  @override
  State<RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<RescheduleDialog> {
  final ApiService _apiService = ApiService();

  DateTime? _selectedDate;
  String? _selectedTime;
  VisitDuration? _selectedDuration;

  bool _loading = false;
  bool _checkingAvailability = false;
  List<String> _availableTimeSlots = [];
  // Max duration per available time slot, keyed by "HH:mm", as returned by
  // the server in the same call that populates _availableTimeSlots. Using
  // this avoids a second (racy) network call when the user taps a slot.
  Map<String, int> _slotMaxDurations = {};
  int _maxDuration = 4;

  @override
  void initState() {
    super.initState();
    // Pre-select current values
    _selectedDate = widget.booking.date;
    _selectedTime = widget.booking.startTime;
    _selectedDuration = widget.booking.duration;
  }

  Future<void> _checkAvailability() async {
    if (_selectedDate == null) return;

    setState(() => _checkingAvailability = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final response = await _apiService.checkAvailability(dateStr);

      final slots = (response['availableTimeSlots'] as List?) ?? [];
      setState(() {
        _availableTimeSlots = slots
            .map((s) => s['time'] as String)
            .toList()
          ..sort();
        _slotMaxDurations = {
          for (final s in slots)
            s['time'] as String: (s['maxDuration'] as int?) ?? 4,
        };

        // If current time is not available, reset it
        if (_selectedTime != null && !_availableTimeSlots.contains(_selectedTime)) {
          _selectedTime = null;
          _selectedDuration = null;
        }

        // Update max duration if time is selected
        if (_selectedTime != null) {
          _maxDuration = _slotMaxDurations[_selectedTime] ?? 4;
        }

        _checkingAvailability = false;
      });
    } catch (e) {
      setState(() => _checkingAvailability = false);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Error checking availability: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleReschedule() async {
    if (_selectedDate == null || _selectedTime == null || _selectedDuration == null) {
      ToastNotification.show(
        context,
        message: 'Please select date, time, and duration',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      await _apiService.rescheduleBooking(
        widget.booking.id,
        dateStr,
        _selectedTime!,
        _selectedDuration!.name,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ToastNotification.show(
          context,
          message: 'Booking rescheduled successfully!',
          type: ToastType.success,
        );
        widget.onRescheduled();
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Error rescheduling: $e',
          type: ToastType.error,
        );
      }
    }
  }

  String _formatDuration(VisitDuration duration) {
    switch (duration) {
      case VisitDuration.ONE_HOUR:
        return '1 hour';
      case VisitDuration.TWO_HOURS:
        return '2 hours';
      case VisitDuration.THREE_HOURS:
        return '3 hours';
      case VisitDuration.FOUR_HOURS:
        return '4 hours';
      case VisitDuration.FIVE_HOURS:
        return '5 hours';
      case VisitDuration.SIX_HOURS:
        return '6 hours';
      case VisitDuration.SEVEN_HOURS:
        return '7 hours';
      case VisitDuration.EIGHT_HOURS:
        return '8 hours';
    }
  }

  List<VisitDuration> _getAvailableDurations() {
    final durations = <VisitDuration>[];
    if (_maxDuration >= 1) durations.add(VisitDuration.ONE_HOUR);
    if (_maxDuration >= 2) durations.add(VisitDuration.TWO_HOURS);
    if (_maxDuration >= 3) durations.add(VisitDuration.THREE_HOURS);
    if (_maxDuration >= 4) durations.add(VisitDuration.FOUR_HOURS);
    if (_maxDuration >= 5) durations.add(VisitDuration.FIVE_HOURS);
    if (_maxDuration >= 6) durations.add(VisitDuration.SIX_HOURS);
    return durations;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.event_repeat,
                  color: isDark ? Colors.white : Colors.black,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reschedule Booking',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Current booking info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.booking.companyName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 14,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Current: ${dateFormat.format(widget.booking.date)} at ${widget.booking.startTime}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Picker
                    Text(
                      'New Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _loading ? null : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _selectedTime = null;
                            _selectedDuration = null;
                            _availableTimeSlots = [];
                          });
                          await _checkAvailability();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDate != null
                                  ? dateFormat.format(_selectedDate!)
                                  : 'Select date',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Time Selection
                    Text(
                      'New Time',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_checkingAvailability)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      )
                    else if (_selectedDate == null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Select a date first',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_availableTimeSlots.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, size: 20, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No available time slots for this date',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Render exactly the slots the server offered for this
                      // date (previously a hardcoded 09:00-16:00 list, which
                      // meant valid server slots outside that window could
                      // never be selected).
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTimeSlots.map((time) {
                          final isSelected = _selectedTime == time;

                          return InkWell(
                            onTap: () {
                              // Max duration for every offered slot was
                              // already fetched in _checkAvailability(), so
                              // selecting a slot is purely local state — no
                              // extra network call, no race condition.
                              setState(() {
                                _selectedTime = time;
                                _selectedDuration = null;
                                _maxDuration = _slotMaxDurations[time] ?? 4;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black)
                                      : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected
                                      ? (isDark ? Colors.black : Colors.white)
                                      : (isDark ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),

                    // Duration Selection
                    Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_selectedTime == null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Select a time first',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: _getAvailableDurations().map((duration) {
                          final isSelected = _selectedDuration == duration;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => setState(() => _selectedDuration = duration),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? Colors.white : Colors.black)
                                        : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 20,
                                      color: isSelected
                                          ? (isDark ? Colors.black : Colors.white)
                                          : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _formatDuration(duration),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected
                                            ? (isDark ? Colors.black : Colors.white)
                                            : (isDark ? Colors.white : Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black,
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_loading || _selectedDate == null || _selectedTime == null || _selectedDuration == null)
                        ? null
                        : _handleReschedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Reschedule Booking'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
