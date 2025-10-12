import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/booking.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  final bool skipLayout;

  const BookingDetailsScreen({
    super.key,
    required this.bookingId,
    this.skipLayout = false,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final ApiService _apiService = ApiService();
  Booking? _booking;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('[BookingDetails] Loading booking: ${widget.bookingId}');
      final response = await _apiService.getBookingById(widget.bookingId);

      if (mounted) {
        setState(() {
          _booking = Booking.fromJson(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[BookingDetails] Error loading booking: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor() {
    if (_booking == null) return Colors.grey;

    switch (_booking!.status) {
      case BookingStatus.CONFIRMED:
        return Colors.green;
      case BookingStatus.PENDING_APPROVAL:
        return Colors.orange;
      case BookingStatus.CANCELLED:
        return Colors.red;
      case BookingStatus.RESCHEDULED:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    if (_booking == null) return '';

    switch (_booking!.status) {
      case BookingStatus.CONFIRMED:
        return 'Confirmed';
      case BookingStatus.PENDING_APPROVAL:
        return 'Pending Approval';
      case BookingStatus.CANCELLED:
        return 'Cancelled';
      case BookingStatus.RESCHEDULED:
        return 'Rescheduled';
      default:
        return _booking!.status.toString();
    }
  }

  IconData _getStatusIcon() {
    if (_booking == null) return Icons.info_outline;

    switch (_booking!.status) {
      case BookingStatus.CONFIRMED:
        return Icons.check_circle;
      case BookingStatus.PENDING_APPROVAL:
        return Icons.pending;
      case BookingStatus.CANCELLED:
        return Icons.cancel;
      case BookingStatus.RESCHEDULED:
        return Icons.event_repeat;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Booking Details'),
        elevation: 0,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Booking',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBookingDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_booking == null) {
      return Center(
        child: Text(
          'Booking not found',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookingDetails,
      color: isDark ? Colors.white : Colors.black,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            _buildStatusBadge(isDark),
            const SizedBox(height: 24),

            // Company Info
            _buildSection(
              'Company Information',
              [
                _buildInfoRow(
                  Icons.business,
                  'Company',
                  _booking!.companyName,
                  isDark,
                ),
                if (_booking!.accountName != null)
                  _buildInfoRow(
                    Icons.account_circle,
                    'Account',
                    _booking!.accountName!,
                    isDark,
                  ),
                if (_booking!.companySector != null)
                  _buildInfoRow(
                    Icons.category,
                    'Sector',
                    _booking!.companySector!,
                    isDark,
                  ),
                if (_booking!.companyVertical != null)
                  _buildInfoRow(
                    Icons.trending_up,
                    'Vertical',
                    _booking!.companyVertical!,
                    isDark,
                  ),
              ],
              isDark,
            ),
            const SizedBox(height: 16),

            // Visit Details
            _buildSection(
              'Visit Details',
              [
                _buildInfoRow(
                  Icons.calendar_today,
                  'Date',
                  DateFormat('EEEE, MMMM d, yyyy').format(_booking!.date),
                  isDark,
                ),
                _buildInfoRow(
                  Icons.access_time,
                  'Time',
                  _booking!.startTime,
                  isDark,
                ),
                _buildInfoRow(
                  Icons.timer,
                  'Duration',
                  _formatDuration(_booking!.duration.name),
                  isDark,
                ),
                _buildInfoRow(
                  Icons.event,
                  'Visit Type',
                  _formatVisitType(_booking!.visitType.name),
                  isDark,
                ),
                _buildInfoRow(
                  Icons.people,
                  'Expected Attendees',
                  '${_booking!.expectedAttendees} people',
                  isDark,
                ),
                if (_booking!.venue != null)
                  _buildInfoRow(
                    Icons.location_on,
                    'Venue',
                    _booking!.venue!,
                    isDark,
                  ),
              ],
              isDark,
            ),
            const SizedBox(height: 16),

            // Approval Info (if approved)
            if (_booking!.approvedById != null) ...[
              _buildSection(
                'Approval',
                [
                  if (_booking!.approvedAt != null)
                    _buildInfoRow(
                      Icons.schedule,
                      'Approved At',
                      DateFormat('MMM d, yyyy - HH:mm').format(_booking!.approvedAt!),
                      isDark,
                    ),
                ],
                isDark,
              ),
              const SizedBox(height: 16),
            ],

            // Additional Notes
            if (_booking!.additionalNotes != null && _booking!.additionalNotes!.isNotEmpty) ...[
              _buildSection(
                'Additional Notes',
                [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _booking!.additionalNotes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
                isDark,
              ),
              const SizedBox(height: 16),
            ],

            // Created Info
            _buildSection(
              'Created',
              [
                _buildInfoRow(
                  Icons.access_time,
                  'Created At',
                  DateFormat('MMM d, yyyy - HH:mm').format(_booking!.createdAt),
                  isDark,
                ),
              ],
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _booking!.companyName,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
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
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(String duration) {
    return duration.replaceAll('_', ' ').toLowerCase().split(' ').map((word) =>
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String _formatVisitType(String visitType) {
    return visitType.replaceAll('_', ' ').toLowerCase().split(' ').map((word) =>
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
}
