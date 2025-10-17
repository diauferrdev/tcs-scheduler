import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../services/drawer_service.dart';
import 'booking_card.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onApproved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving booking: $e'),
            backgroundColor: Colors.red,
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking denied'),
            backgroundColor: Colors.red,
          ),
        );
        widget.onApproved(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error denying booking: $e'),
            backgroundColor: Colors.red,
          ),
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
