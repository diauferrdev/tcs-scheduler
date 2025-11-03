import 'package:flutter/material.dart';
import '../models/booking.dart';
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
