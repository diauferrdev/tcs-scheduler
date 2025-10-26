import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/drawer_service.dart';
import 'booking_card.dart';
import '../utils/toast_notification.dart';

class PendingApprovalCard extends StatefulWidget {
  final Booking booking;
  final VoidCallback onApproved;

  const PendingApprovalCard({
    super.key,
    required this.booking,
    required this.onApproved,
  });

  @override
  State<PendingApprovalCard> createState() => _PendingApprovalCardState();
}

class _PendingApprovalCardState extends State<PendingApprovalCard> {
  final ApiService _apiService = ApiService();
  bool _processing = false;

  Future<void> _handleApprove() async {
    try {
      setState(() => _processing = true);
      await _apiService.approveBooking(widget.booking.id);

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Booking approved successfully!',
          type: ToastType.success,
        );
        widget.onApproved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ToastNotification.show(
          context,
          message: 'Error approving booking: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleDeny() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny Booking'),
        content: const Text('Are you sure you want to deny this booking request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _processing = true);
      await _apiService.deleteBooking(widget.booking.id);

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Booking denied',
          type: ToastType.error,
        );
        widget.onApproved(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ToastNotification.show(
          context,
          message: 'Error denying booking: $e',
          type: ToastType.error,
        );
      }
    }
  }

  void _showDetailsDrawer() {
    // Use DrawerService for consistent drawer experience
    DrawerService.instance.openDrawer(
      context,
      DrawerType.bookingDetails,
      params: {'bookingId': widget.booking.id},
      updateUrl: false, // Don't update URL from Approvals screen
    );
  }

  @override
  Widget build(BuildContext context) {
    return BookingCard(
      booking: widget.booking,
      onTap: _showDetailsDrawer,
    );
  }
}
