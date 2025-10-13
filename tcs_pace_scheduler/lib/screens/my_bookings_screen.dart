import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/booking.dart';
import '../services/realtime_service.dart';
import '../services/drawer_service.dart';
import '../widgets/booking_card.dart';
import '../providers/auth_provider.dart';

class MyBookingsScreen extends StatefulWidget {
  final bool skipLayout;
  final String? initialBookingId;

  const MyBookingsScreen({
    super.key,
    this.skipLayout = false,
    this.initialBookingId,
  });

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final ApiService _apiService = ApiService();
  final RealtimeService _realtimeService = RealtimeService();
  List<Booking> _bookings = [];
  List<Booking> _filteredBookings = [];
  bool _isLoading = true;
  String? _error;
  BookingStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadBookings();
    _setupRealtimeUpdates();
    // No polling - fully real-time via WebSocket only

    // Open drawer if initialBookingId is provided
    if (widget.initialBookingId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInitialBooking();
      });
    }
  }

  void _openInitialBooking() {
    if (widget.initialBookingId == null) return;

    // Use DrawerService to open the booking details drawer
    DrawerService.instance.openDrawer(
      context,
      DrawerType.bookingDetails,
      params: {'bookingId': widget.initialBookingId!},
      updateUrl: false,
    );
  }

  void _setupRealtimeUpdates() {
    // Listen for booking updates
    _realtimeService.onBookingCreated = (bookingData) {
      _handleBookingUpdate(bookingData);
    };

    _realtimeService.onBookingUpdated = (bookingData) {
      _handleBookingUpdate(bookingData);
    };

    _realtimeService.onBookingApproved = (bookingData) {
      _handleBookingUpdate(bookingData);
    };

    _realtimeService.onBookingDeleted = (bookingId) {
      if (mounted) {
        setState(() {
          _bookings.removeWhere((b) => b.id == bookingId);
          _filterBookings();
        });
      }
    };
  }

  void _handleBookingUpdate(Map<String, dynamic> bookingData) {
    if (!mounted) return;

    try {
      final booking = Booking.fromJson(bookingData);
      final currentUserId = context.read<AuthProvider>().user?.id;

      // Check if booking already exists in list OR belongs to current user
      final existingIndex = _bookings.indexWhere((b) => b.id == booking.id);
      final belongsToUser = booking.createdById == currentUserId;

      // Only process if: 1) Already in our list (needs update) OR 2) Created by current user (new booking)
      if (existingIndex < 0 && !belongsToUser) {
        debugPrint('[MyBookings] Ignoring booking from another user: ${booking.id}');
        return;
      }

      setState(() {
        if (existingIndex >= 0) {
          // Update existing booking (even if created by another user - could be updated by admin)
          _bookings[existingIndex] = booking;
          debugPrint('[MyBookings] Updated existing booking: ${booking.id}');
        } else {
          // Add new booking (verified it belongs to current user above)
          _bookings.add(booking);
          debugPrint('[MyBookings] Added new booking: ${booking.id}');
        }
        _filterBookings();
      });
      debugPrint('[MyBookings] Updated booking list, total: ${_bookings.length}');
    } catch (e) {
      debugPrint('[MyBookings] Error handling booking update: $e');
    }
  }

  @override
  void dispose() {
    // Clear callbacks
    _realtimeService.onBookingCreated = null;
    _realtimeService.onBookingUpdated = null;
    _realtimeService.onBookingApproved = null;
    _realtimeService.onBookingDeleted = null;
    super.dispose();
  }

  Future<void> _loadBookings() async {
    // Only show loading on initial load, not on auto-refresh
    if (_bookings.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

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

    // Sort: pending bookings always at top, then by createdAt (newest first)
    _filteredBookings.sort((a, b) {
      // If one is pending and the other isn't, pending comes first
      if (a.status == BookingStatus.PENDING_APPROVAL && b.status != BookingStatus.PENDING_APPROVAL) {
        return -1;
      }
      if (b.status == BookingStatus.PENDING_APPROVAL && a.status != BookingStatus.PENDING_APPROVAL) {
        return 1;
      }
      // If both have the same status (both pending or both not pending), sort by createdAt
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void _changeFilter(BookingStatus? status) {
    setState(() {
      _selectedStatus = status;
      _filterBookings();
    });
  }

  Future<void> _handleCancelBooking(Booking booking) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Cancel Booking',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel this booking for ${booking.companyName}?',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Yes, cancel'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Close the drawer first
      Navigator.of(context).pop();

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Canceling booking...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Call API to delete booking
      await _apiService.deleteBooking(booking.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload bookings
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error canceling booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.DRAFT:
        return Colors.grey;
      case BookingStatus.PENDING_APPROVAL:
        return Colors.orange;
      case BookingStatus.APPROVED:
        return Colors.green;
      case BookingStatus.CANCELLED:
        return Colors.red;
    }
  }

  String _getStatusText(BookingStatus status) {
    switch (status) {
      case BookingStatus.DRAFT:
        return 'Draft';
      case BookingStatus.PENDING_APPROVAL:
        return 'Pending Approval';
      case BookingStatus.APPROVED:
        return 'Approved';
      case BookingStatus.CANCELLED:
        return 'Cancelled';
    }
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.DRAFT:
        return Icons.edit_note;
      case BookingStatus.PENDING_APPROVAL:
        return Icons.pending;
      case BookingStatus.APPROVED:
        return Icons.check_circle;
      case BookingStatus.CANCELLED:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      child: Column(
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : const Color(0xFFF9FAFB),
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
              color: const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Draft',
              isSelected: _selectedStatus == BookingStatus.DRAFT,
              onTap: () => _changeFilter(BookingStatus.DRAFT),
              isDark: isDark,
              color: const Color(0xFF6B7280),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Approved',
              isSelected: _selectedStatus == BookingStatus.APPROVED,
              onTap: () => _changeFilter(BookingStatus.APPROVED),
              isDark: isDark,
              color: const Color(0xFF10B981),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: 'Cancelled',
              isSelected: _selectedStatus == BookingStatus.CANCELLED,
              onTap: () => _changeFilter(BookingStatus.CANCELLED),
              isDark: isDark,
              color: const Color(0xFFEF4444),
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

  void _showBookingDetailsDrawer(Booking booking) {
    // Use DrawerService for consistent drawer experience
    DrawerService.instance.openDrawer(
      context,
      DrawerType.bookingDetails,
      params: {'bookingId': booking.id},
      updateUrl: false, // Don't update URL from My Bookings screen
    );
  }

  Widget _buildBookingCard(Booking booking, bool isDark) {
    return BookingCard(
      booking: booking,
      onTap: () => _showBookingDetailsDrawer(booking),
    );
  }

  void _handleContinueDraft(Booking booking) {
    // Navigate to calendar with the draft's date selected and open the form with draft data
    context.go('/calendar?draftId=${booking.id}');
  }

  /// CRITICAL: Handle draft deletion with confirmation dialog
  Future<void> _handleDeleteDraft(Booking booking) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Delete Draft?',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this draft booking for ${booking.companyName}? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      // Delete the draft booking
      await _apiService.deleteBooking(booking.id);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Reload bookings to update the list
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete draft: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
