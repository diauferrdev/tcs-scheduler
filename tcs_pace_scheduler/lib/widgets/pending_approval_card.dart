import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

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

  void _showDetails() {
    showDialog(
      context: context,
      builder: (context) => _BookingDetailsDialog(booking: widget.booking),
    );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return InkWell(
      onTap: _showDetails,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF59E0B), // Orange border for pending
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header with status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pending_actions,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                dateFormat.format(widget.booking.date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Company name
          Text(
            widget.booking.companyName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),

          const SizedBox(height: 12),

          // Details grid
          _buildDetailRow(Icons.access_time, 'Time', widget.booking.startTime, isDark),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.schedule, 'Duration', _formatDuration(widget.booking.duration), isDark),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.people, 'Attendees', '${widget.booking.expectedAttendees} people', isDark),

          if (widget.booking.companySector != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(Icons.business, 'Sector', widget.booking.companySector!, isDark),
          ],

          if (widget.booking.overallTheme != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.topic, 'Theme', widget.booking.overallTheme!, isDark, fullWidth: true),
          ],

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              // Approve button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _handleApprove,
                  icon: _processing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Deny button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _handleDeny,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Deny'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark, {bool fullWidth = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        if (fullWidth)
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
      ],
    );
  }
}

// Booking Details Dialog
class _BookingDetailsDialog extends StatelessWidget {
  final Booking booking;

  const _BookingDetailsDialog({required this.booking});

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF18181B) : Colors.grey[100],
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Booking Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Company Information', [
                      _buildDetailItem('Company Name', booking.companyName, isDark),
                      if (booking.accountName != null)
                        _buildDetailItem('Account Name', booking.accountName!, isDark),
                      if (booking.companySector != null)
                        _buildDetailItem('Sector', booking.companySector!, isDark),
                      if (booking.companyVertical != null)
                        _buildDetailItem('Vertical', booking.companyVertical!, isDark),
                      if (booking.companySize != null)
                        _buildDetailItem('Company Size', booking.companySize!, isDark),
                    ], isDark),

                    const SizedBox(height: 24),

                    _buildSection('Visit Details', [
                      _buildDetailItem('Date', DateFormat('EEEE, MMMM dd, yyyy').format(booking.date), isDark),
                      _buildDetailItem('Time', booking.startTime, isDark),
                      _buildDetailItem('Duration', _formatDuration(booking.duration), isDark),
                      _buildDetailItem('Expected Attendees', '${booking.expectedAttendees} people', isDark),
                      if (booking.venue != null)
                        _buildDetailItem('Venue', booking.venue!, isDark),
                      if (booking.overallTheme != null)
                        _buildDetailItem('Overall Theme', booking.overallTheme!, isDark, fullWidth: true),
                    ], isDark),

                    const SizedBox(height: 24),

                    _buildSection('Event Information', [
                      _buildDetailItem('Event Type', booking.eventType == EventType.TCS ? 'TCS' : 'Partner', isDark),
                      if (booking.partnerName != null)
                        _buildDetailItem('Partner Name', booking.partnerName!, isDark),
                      _buildDetailItem('Deal Status', booking.dealStatus == DealStatus.WON ? 'WON' : 'SWON', isDark),
                      _buildDetailItem('Segment Head Approval', booking.segmentHeadApproval ? 'Yes' : 'No', isDark),
                    ], isDark),

                    if (booking.additionalNotes != null) ...[
                      const SizedBox(height: 24),
                      _buildSection('Additional Notes', [
                        _buildDetailItem('Notes', booking.additionalNotes!, isDark, fullWidth: true),
                      ], isDark),
                    ],

                    const SizedBox(height: 24),

                    _buildSection('Metadata', [
                      _buildDetailItem('Created', DateFormat('MMM dd, yyyy HH:mm').format(booking.createdAt), isDark),
                      _buildDetailItem('Status', booking.status.name.replaceAll('_', ' '), isDark),
                    ], isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, bool isDark, {bool fullWidth = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: fullWidth ? null : 150,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ),
          if (!fullWidth) const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
