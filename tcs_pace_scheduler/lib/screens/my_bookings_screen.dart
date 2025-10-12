import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/booking.dart';
import '../services/navigation_service.dart';

class MyBookingsScreen extends StatefulWidget {
  final bool skipLayout;

  const MyBookingsScreen({
    super.key,
    this.skipLayout = false,
  });

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final ApiService _apiService = ApiService();
  List<Booking> _bookings = [];
  List<Booking> _filteredBookings = [];
  bool _isLoading = true;
  String? _error;
  BookingStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('[MyBookings] Loading user bookings');
      final response = await _apiService.getBookings();

      if (mounted) {
        setState(() {
          _bookings = (response['bookings'] as List)
              .map((json) => Booking.fromJson(json))
              .toList();
          _filterBookings();
          _isLoading = false;
        });
        debugPrint('[MyBookings] Loaded ${_bookings.length} bookings');
      }
    } catch (e) {
      debugPrint('[MyBookings] Error loading bookings: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _filterBookings() {
    if (_selectedStatus == null) {
      _filteredBookings = _bookings;
    } else {
      _filteredBookings = _bookings
          .where((booking) => booking.status == _selectedStatus)
          .toList();
    }

    // Sort by date (newest first)
    _filteredBookings.sort((a, b) => b.date.compareTo(a.date));
  }

  void _changeFilter(BookingStatus? status) {
    setState(() {
      _selectedStatus = status;
      _filterBookings();
    });
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.CONFIRMED:
        return Colors.green;
      case BookingStatus.PENDING_APPROVAL:
        return Colors.orange;
      case BookingStatus.CANCELLED:
        return Colors.red;
      case BookingStatus.RESCHEDULED:
        return Colors.blue;
    }
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.CONFIRMED:
        return 'Confirmed';
      case BookingStatus.PENDING_APPROVAL:
        return 'Pending Approval';
      case BookingStatus.CANCELLED:
        return 'Cancelled';
      case BookingStatus.RESCHEDULED:
        return 'Rescheduled';
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.CONFIRMED:
        return Icons.check_circle;
      case BookingStatus.PENDING_APPROVAL:
        return Icons.pending;
      case BookingStatus.CANCELLED:
        return Icons.cancel;
      case BookingStatus.RESCHEDULED:
        return Icons.event_repeat;
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
        title: const Text('My Bookings'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(isDark),

          // Bookings list
          Expanded(
            child: _buildBody(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: 'All',
              isSelected: _selectedStatus == null,
              onTap: () => _changeFilter(null),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Pending',
              isSelected: _selectedStatus == BookingStatus.PENDING_APPROVAL,
              onTap: () => _changeFilter(BookingStatus.PENDING_APPROVAL),
              isDark: isDark,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Confirmed',
              isSelected: _selectedStatus == BookingStatus.CONFIRMED,
              onTap: () => _changeFilter(BookingStatus.CONFIRMED),
              isDark: isDark,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Cancelled',
              isSelected: _selectedStatus == BookingStatus.CANCELLED,
              onTap: () => _changeFilter(BookingStatus.CANCELLED),
              isDark: isDark,
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Rescheduled',
              isSelected: _selectedStatus == BookingStatus.RESCHEDULED,
              onTap: () => _changeFilter(BookingStatus.RESCHEDULED),
              isDark: isDark,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    final chipColor = color ?? (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withOpacity(0.1)
              : (isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? chipColor
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
        ),
      ),
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
              'Error Loading Bookings',
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
              onPressed: _loadBookings,
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

    if (_filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedStatus == null ? 'No Bookings Yet' : 'No ${_getStatusText(_selectedStatus!)} Bookings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your bookings will appear here',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: isDark ? Colors.white : Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredBookings.length,
        itemBuilder: (context, index) {
          final booking = _filteredBookings[index];
          return _buildBookingCard(booking, isDark);
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, bool isDark) {
    return GestureDetector(
      onTap: () {
        NavigationService().navigateToBookingDetails(booking.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor(booking.status).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(booking.status),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(booking.status),
                        size: 16,
                        color: _getStatusColor(booking.status),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(booking.status),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(booking.status),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Company name
            Text(
              booking.companyName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Date and time
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(booking.date),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  '${booking.startTime} - ${_formatVisitType(booking.visitType.name)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),

            // Attendees count
            if (booking.expectedAttendees > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${booking.expectedAttendees} attendees',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatVisitType(String visitType) {
    return visitType.replaceAll('_', ' ').toLowerCase().split(' ').map((word) =>
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
}
