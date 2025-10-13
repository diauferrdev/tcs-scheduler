import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import 'booking_status_stepper.dart';

/// Compact unified card for both My Bookings and Approvals pages
class BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Only pending cards are bright, others are darker
    final isPending = booking.status == BookingStatus.PENDING_APPROVAL;
    final backgroundColor = isPending
        ? (isDark ? const Color(0xFF18181B) : Colors.white)
        : (isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF3F4F6));
    final borderColor = isPending
        ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB))
        : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFD1D5DB));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First line: Info icon + Company name + Date/Time
            Row(
              children: [
                // Info icon to indicate clickable
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                // Company name
                Expanded(
                  child: Text(
                    booking.companyName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                const SizedBox(width: 12),
                // Date and time
                Text(
                  '${DateFormat('MMM d').format(booking.date)} • ${booking.startTime}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: false,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Second line: Stepper
            BookingStatusStepper(
              key: ValueKey('stepper_${booking.id}'),
              currentStatus: booking.status,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}
