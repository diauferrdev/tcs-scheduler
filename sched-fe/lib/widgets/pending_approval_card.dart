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


  Future<void> _showDetailsDrawer() async {
    // Use DrawerService for consistent drawer experience. `openDrawer`
    // returns a Future that completes once the drawer/modal is dismissed
    // (approve, reject, edit, or a plain close all pop the same route), so
    // awaiting it lets us notify the parent list right after any of those
    // actions could have changed this booking's state.
    await DrawerService.instance.openDrawer(
      context,
      DrawerType.bookingDetails,
      params: {'bookingId': widget.booking.id},
      updateUrl: false, // Don't update URL from Approvals screen
    );

    // Refresh/remove this card from the parent list now that the drawer
    // closed. This mirrors the room-booking card's behavior in
    // ApprovalsScreen, which also unconditionally reloads on drawer close.
    if (mounted) {
      widget.onApproved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BookingCard(
      booking: widget.booking,
      onTap: _showDetailsDrawer,
    );
  }
}
