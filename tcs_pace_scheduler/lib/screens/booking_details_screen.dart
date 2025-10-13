import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/booking_status_stepper.dart';
import '../widgets/booking_form_fields.dart';
import '../widgets/access_badge.dart';
import '../utils/file_utils.dart';
import '../utils/document_opener.dart';
import 'image_viewer_screen.dart';

/// Booking Details Screen - Shows complete booking information
///
/// Can be used in two modes:
/// 1. Drawer mode (default): Used as bottom sheet drawer from calendar
/// 2. Standalone mode: Full screen with Scaffold wrapper
///
/// Features:
/// - View all booking details including attendees
/// - Edit booking (with permission checks)
/// - Approve/Deny bookings (ADMIN/MANAGER only)
/// - Save as draft or submit for approval
/// - Real-time updates via WebSocket
///
/// Permissions:
/// - ADMIN: Can always edit any booking
/// - USER: Can only edit DRAFT and PENDING_APPROVAL bookings (not APPROVED)
/// - MANAGER: Can approve/deny bookings
class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  final bool skipLayout;
  final bool showScaffold;
  final ScrollController? scrollController;
  final VoidCallback? onClose;

  const BookingDetailsScreen({
    super.key,
    required this.bookingId,
    this.skipLayout = false,
    this.showScaffold = false,
    this.scrollController,
    this.onClose,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final ApiService _apiService = ApiService();
  final RealtimeService _realtimeService = RealtimeService();
  final _formKey = GlobalKey<FormState>();

  Booking? _booking;
  BookingFormData? _formData;
  bool _isLoading = true;
  String? _error;
  bool _processing = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
    _setupRealtimeUpdates();
  }

  void _setupRealtimeUpdates() {
    _realtimeService.onBookingUpdated = (bookingData) {
      _handleBookingUpdate(bookingData);
    };

    _realtimeService.onBookingApproved = (bookingData) {
      _handleBookingUpdate(bookingData);
    };

    _realtimeService.onBookingDeleted = (bookingId) {
      if (mounted && _booking?.id == bookingId) {
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
    };
  }

  void _handleBookingUpdate(Map<String, dynamic> bookingData) {
    if (!mounted) return;

    try {
      final updatedBooking = Booking.fromJson(bookingData);

      if (updatedBooking.id == widget.bookingId) {
        setState(() {
          _booking = updatedBooking;
          if (_isEditing) {
            // Refresh form data with updated booking
            _formData = BookingFormData.fromBooking(updatedBooking);
          }
        });
        debugPrint('[BookingDetails] Updated booking via WebSocket');
      }
    } catch (e) {
      debugPrint('[BookingDetails] Error handling booking update: $e');
    }
  }

  @override
  void dispose() {
    _realtimeService.onBookingUpdated = null;
    _realtimeService.onBookingApproved = null;
    _realtimeService.onBookingDeleted = null;
    _formData?.dispose();
    super.dispose();
  }

  Future<void> _loadBookingDetails() async {
    if (_booking == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

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

  /// Check if current user can edit this booking
  bool _canEdit() {
    final authProvider = context.read<AuthProvider>();
    final userRole = authProvider.user?.role;
    final userId = authProvider.user?.id;

    if (_booking == null) return false;

    // ADMIN can always edit
    if (userRole == UserRole.ADMIN) return true;

    // USER can only edit their own DRAFT or PENDING_APPROVAL bookings
    if (userRole == UserRole.USER) {
      final isOwner = _booking!.createdById == userId;
      final canEditStatus = _booking!.status == BookingStatus.DRAFT ||
                            _booking!.status == BookingStatus.PENDING_APPROVAL;
      return isOwner && canEditStatus;
    }

    // MANAGER cannot edit bookings directly (they approve/deny)
    return false;
  }

  void _enterEditMode() {
    if (!_canEdit()) return;

    setState(() {
      _formData = BookingFormData.fromBooking(_booking!);
      _isEditing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _formData?.dispose();
      _formData = null;
    });
  }

  Future<void> _saveDraft() async {
    if (_booking == null || _formData == null) return;

    try {
      setState(() => _processing = true);

      final updateData = _formData!.toJson(
        DateFormat('yyyy-MM-dd').format(_booking!.date),
        _booking!.startTime,
      );

      // Add status to keep it as draft
      updateData['status'] = 'DRAFT';

      await _apiService.updateBooking(_booking!.id, updateData);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _processing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _loadBookingDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving draft: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForApproval() async {
    if (_booking == null || _formData == null) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _processing = true);

      final updateData = _formData!.toJson(
        DateFormat('yyyy-MM-dd').format(_booking!.date),
        _booking!.startTime,
      );

      // Set status to PENDING_APPROVAL
      updateData['status'] = 'PENDING_APPROVAL';

      await _apiService.updateBooking(_booking!.id, updateData);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _processing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking submitted for approval! Managers have been notified.'),
            backgroundColor: Colors.green,
          ),
        );

        _loadBookingDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleApprove() async {
    if (_booking == null) return;

    try {
      setState(() => _processing = true);
      await _apiService.approveBooking(_booking!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Just close the drawer/screen
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
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
    if (_booking == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Deny Booking',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Text(
            'Are you sure you want to deny this booking request?',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
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
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() => _processing = true);
      await _apiService.deleteBooking(_booking!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking denied'),
            backgroundColor: Colors.red,
          ),
        );

        // Just close the drawer/screen
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
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

  /// CRITICAL: Handle "Continue" for draft - navigate to calendar with draft
  void _handleContinueDraft() {
    if (_booking == null) return;

    // Close the drawer
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }

    // Navigate to calendar with the draft's date and draft ID
    context.go('/calendar?draftId=${_booking!.id}');
  }

  Future<void> _handleDelete() async {
    if (_booking == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            _booking!.status == BookingStatus.DRAFT ? 'Delete Draft?' : 'Delete Booking',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Text(
            _booking!.status == BookingStatus.DRAFT
                ? 'Are you sure you want to delete this draft booking for ${_booking!.companyName}? This action cannot be undone.'
                : 'Are you sure you want to delete this booking?',
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() => _processing = true);
      await _apiService.deleteBooking(_booking!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_booking!.status == BookingStatus.DRAFT
                ? 'Draft deleted successfully'
                : 'Booking deleted'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting ${_booking!.status == BookingStatus.DRAFT ? "draft" : "booking"}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor() {
    if (_booking == null) return Colors.grey;
    switch (_booking!.status) {
      case BookingStatus.DRAFT:
        return const Color(0xFF6B7280);
      case BookingStatus.PENDING_APPROVAL:
        return const Color(0xFFF59E0B);
      case BookingStatus.APPROVED:
        return const Color(0xFF10B981);
      case BookingStatus.CANCELLED:
        return const Color(0xFFEF4444);
    }
  }

  String _getStatusText() {
    if (_booking == null) return '';
    switch (_booking!.status) {
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

  IconData _getStatusIcon() {
    if (_booking == null) return Icons.info_outline;
    switch (_booking!.status) {
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
    final bodyContent = _buildBody(isDark);

    if (!widget.showScaffold) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Booking Details'),
        elevation: 0,
      ),
      body: bodyContent,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
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

    return Column(
      children: [
        // Header
        if (!widget.showScaffold) _buildDrawerHeader(isDark),

        // Body
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadBookingDetails,
            color: isDark ? Colors.white : Colors.black,
            child: SingleChildScrollView(
              controller: widget.scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _isEditing ? _buildEditMode(isDark) : _buildViewMode(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerHeader(bool isDark) {
    final canEdit = _canEdit();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          // Close button
          IconButton(
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
            tooltip: 'Close',
          ),
          const SizedBox(width: 8),

          // Title
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

          // Action buttons for DRAFTS
          if (_booking!.status == BookingStatus.DRAFT) ...[
            // "Use" button
            ElevatedButton(
              onPressed: _processing ? null : _handleContinueDraft,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Use',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Delete icon button
            IconButton(
              onPressed: _processing ? null : _handleDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                padding: const EdgeInsets.all(8),
              ),
              tooltip: 'Delete draft',
            ),
          ],

          // Action buttons for non-drafts
          if (_booking!.status != BookingStatus.DRAFT) ...[
            if (_isEditing) ...[
              // Cancel button
              IconButton(
                onPressed: _processing ? null : _cancelEdit,
                icon: Icon(
                  Icons.undo_rounded,
                  size: 22,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                tooltip: 'Cancel',
              ),
              const SizedBox(width: 8),

              // Save button
              IconButton(
                onPressed: _processing ? null : _submitForApproval,
                icon: _processing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.save,
                        size: 22,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                tooltip: 'Save changes',
              ),
            ] else if (canEdit) ...[
              // Edit button
              IconButton(
                onPressed: _enterEditMode,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit booking',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildViewMode(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Stepper
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
            ),
          ),
          child: BookingStatusStepper(
            currentStatus: _booking!.status,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 16),

        // Company Information
        _buildInfoSection(
          'Company Information',
          [
            _buildInfoRow(Icons.business, 'Company', _booking!.companyName, isDark),
            _buildInfoRow(Icons.account_circle, 'Account', _booking!.accountName!, isDark),
            if (_booking!.companySector != null)
              _buildInfoRow(Icons.category, 'Sector', _booking!.companySector!, isDark),
            if (_booking!.companyVertical != null)
              _buildInfoRow(Icons.trending_up, 'Vertical', _booking!.companyVertical!, isDark),
            if (_booking!.companySize != null)
              _buildInfoRow(Icons.business_center, 'Size', _booking!.companySize!, isDark),
          ],
          isDark,
        ),
        const SizedBox(height: 16),

        // Visit Details
        _buildInfoSection(
          'Visit Details',
          [
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              DateFormat('EEEE, MMMM d, yyyy').format(_booking!.date),
              isDark,
            ),
            _buildInfoRow(Icons.access_time, 'Time', _booking!.startTime, isDark),
            _buildInfoRow(
              Icons.timer,
              'Duration',
              _formatEnum(_booking!.duration.name),
              isDark,
            ),
            _buildInfoRow(
              Icons.event,
              'Visit Type',
              _formatEnum(_booking!.visitType.name),
              isDark,
            ),
            _buildInfoRow(
              Icons.people,
              'Expected Attendees',
              '${_booking!.expectedAttendees} people',
              isDark,
            ),
            if (_booking!.venue != null)
              _buildInfoRow(Icons.location_on, 'Venue', _booking!.venue!, isDark),
            if (_booking!.overallTheme != null)
              _buildInfoRow(Icons.lightbulb, 'Theme', _booking!.overallTheme!, isDark),
          ],
          isDark,
        ),
        const SizedBox(height: 16),

        // Event & Deal Information (if present)
        if (_booking!.eventType != null || _booking!.dealStatus != null) ...[
          _buildInfoSection(
            'Event & Deal Information',
            [
              if (_booking!.eventType != null)
                _buildInfoRow(
                  Icons.event_available,
                  'Event Type',
                  _formatEnum(_booking!.eventType!.name),
                  isDark,
                ),
              if (_booking!.partnerName != null)
                _buildInfoRow(Icons.handshake, 'Partner', _booking!.partnerName!, isDark),
              if (_booking!.dealStatus != null)
                _buildInfoRow(
                  Icons.trending_up,
                  'Deal Status',
                  _formatEnum(_booking!.dealStatus!.name),
                  isDark,
                ),
              _buildInfoRow(
                Icons.verified,
                'Attach Head Approval',
                _booking!.attachHeadApproval ? 'Required' : 'Not Required',
                isDark,
              ),
            ],
            isDark,
          ),
          const SizedBox(height: 16),
        ],

        // Attachments
        if (_booking!.attachments != null && _booking!.attachments!.isNotEmpty) ...[
          _buildInfoSection(
            'Attachments (${_booking!.attachments!.length})',
            [
              _buildAttachmentsGrid(_booking!.attachments!, isDark),
            ],
            isDark,
          ),
          const SizedBox(height: 16),
        ],

        // Attendees
        if (_booking!.attendees != null && _booking!.attendees!.isNotEmpty) ...[
          _buildInfoSection(
            'Attendees (${_booking!.attendees!.length})',
            _booking!.attendees!.map((a) => _buildAttendeeCard(a, isDark)).toList(),
            isDark,
          ),
          const SizedBox(height: 16),
        ],

        // Additional Notes
        if (_booking!.additionalNotes != null && _booking!.additionalNotes!.isNotEmpty) ...[
          _buildInfoSection(
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

        // Access Information (for APPROVED bookings)
        if (_booking!.status == BookingStatus.APPROVED) ...[
          _buildInfoSection(
            'Access Information',
            [
              _buildInfoRow(Icons.wifi, 'WiFi Network', 'TCS-PacePort-Guest', isDark),
              _buildInfoRow(Icons.lock, 'WiFi Password', 'Innovation2024', isDark),
              _buildInfoRow(
                Icons.location_on,
                'Location',
                'TCS PacePort - Av. Paulista, 1374 - São Paulo',
                isDark,
              ),
              _buildInfoRow(
                Icons.schedule,
                'Check-in',
                'Please arrive 15 minutes early',
                isDark,
              ),
              _buildInfoRow(Icons.phone, 'Reception', '+55 11 3254-0100', isDark),
            ],
            isDark,
          ),
          const SizedBox(height: 16),

          // Access Badges (for APPROVED bookings with attendees)
          if (_booking!.status == BookingStatus.APPROVED &&
              _booking!.attendees != null &&
              _booking!.attendees!.isNotEmpty) ...[
            Container(
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
                    'Access Badges',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Print badges for all attendees',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ..._booking!.attendees!.map((attendee) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: AccessBadge(
                          attendeeName: attendee.name,
                          attendeePosition: attendee.position,
                          attendeeId: attendee.id,
                          companyName: _booking!.companyName,
                          date: _booking!.date,
                          startTime: _booking!.startTime,
                          duration: _booking!.duration.name,
                          bookingId: _booking!.id,
                          isDark: isDark,
                          showActions: true,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],

        // Metadata
        _buildInfoSection(
          'Metadata',
          [
            _buildInfoRow(
              Icons.access_time,
              'Created',
              DateFormat('MMM d, yyyy - HH:mm').format(_booking!.createdAt),
              isDark,
            ),
            _buildInfoRow(
              Icons.update,
              'Updated',
              DateFormat('MMM d, yyyy - HH:mm').format(_booking!.updatedAt),
              isDark,
            ),
            if (_booking!.approvedAt != null)
              _buildInfoRow(
                Icons.check_circle,
                'Approved',
                DateFormat('MMM d, yyyy - HH:mm').format(_booking!.approvedAt!),
                isDark,
              ),
            _buildInfoRow(Icons.tag, 'ID', _booking!.id.substring(0, 8), isDark),
          ],
          isDark,
        ),

        // Approval Actions (for PENDING_APPROVAL)
        if (_booking!.status == BookingStatus.PENDING_APPROVAL) ...[
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final userRole = authProvider.user?.role;
              final isAdminOrManager =
                  userRole == UserRole.ADMIN || userRole == UserRole.MANAGER;

              if (!isAdminOrManager) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pending Approval',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review this booking and take action',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _processing ? null : _handleApprove,
                            icon: _processing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check, size: 20),
                            label: const Text(
                              'Approve',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing ? null : _handleDeny,
                            icon: const Icon(Icons.close, size: 20),
                            label: const Text(
                              'Deny',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildEditMode(bool isDark) {
    if (_formData == null) return const SizedBox.shrink();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Account & Company
          AccountCompanySection(
            formData: _formData!,
            onUpdate: (fn) => setState(fn),
            enabled: true,
          ),
          const SizedBox(height: 16),

          // Section 2: Visit Details
          VisitDetailsSection(
            formData: _formData!,
            onUpdate: (fn) => setState(fn),
            enabled: true,
          ),
          const SizedBox(height: 16),

          // Section 3: Event & Deal
          EventDealSection(
            formData: _formData!,
            onUpdate: (fn) => setState(fn),
            enabled: true,
          ),
          const SizedBox(height: 16),

          // Section 4: Attendees
          AttendeesSection(
            formData: _formData!,
            onUpdate: (fn) => setState(fn),
            enabled: true,
          ),
          const SizedBox(height: 16),

          // Section 5: Additional Notes
          AdditionalNotesSection(
            formData: _formData!,
            enabled: true,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, bool isDark) {
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

  Widget _buildAttendeeCard(Attendee attendee, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and email
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3F3F46) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF52525B) : const Color(0xFFD1D5DB),
                  ),
                ),
                child: Icon(
                  Icons.person,
                  size: 24,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attendee.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      attendee.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Show all attendee details
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Basic Info
          if (attendee.position != null) ...[
            _buildAttendeeDetailRow(Icons.work, 'Position', attendee.position!, isDark),
            const SizedBox(height: 12),
          ],
          if (attendee.role != null) ...[
            _buildAttendeeDetailRow(Icons.badge, 'Role', attendee.role!, isDark),
            const SizedBox(height: 12),
          ],

          // TCS Relationship
          if (attendee.tcsSupporter != null) ...[
            _buildAttendeeDetailRow(
              Icons.thumb_up,
              'TCS Supporter',
              _formatEnum(attendee.tcsSupporter!.name),
              isDark,
            ),
            const SizedBox(height: 12),
          ],
          if (attendee.yearsWorkingWithTCS != null) ...[
            _buildAttendeeDetailRow(
              Icons.calendar_today,
              'Years Working with TCS',
              '${attendee.yearsWorkingWithTCS} years',
              isDark,
            ),
            const SizedBox(height: 12),
          ],
          if (attendee.understandingOfTCS != null) ...[
            _buildAttendeeDetailRow(
              Icons.school,
              'Understanding of TCS',
              attendee.understandingOfTCS!,
              isDark,
            ),
            const SizedBox(height: 12),
          ],
          if (attendee.focusAreas != null) ...[
            _buildAttendeeDetailRow(
              Icons.interests,
              'Focus Areas',
              attendee.focusAreas!,
              isDark,
            ),
            const SizedBox(height: 12),
          ],

          // Professional Info
          if (attendee.educationalQualification != null) ...[
            _buildAttendeeDetailRow(
              Icons.school,
              'Educational Qualification',
              attendee.educationalQualification!,
              isDark,
            ),
            const SizedBox(height: 12),
          ],
          if (attendee.careerBackground != null) ...[
            _buildAttendeeDetailRow(
              Icons.business_center,
              'Career Background',
              attendee.careerBackground!,
              isDark,
            ),
            const SizedBox(height: 12),
          ],

          // LinkedIn
          if (attendee.linkedinProfile != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                // TODO: Open LinkedIn profile
                debugPrint('Opening LinkedIn: ${attendee.linkedinProfile}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A66C2).withOpacity(0.1) : const Color(0xFF0A66C2).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0A66C2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link,
                      size: 16,
                      color: Color(0xFF0A66C2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'View LinkedIn Profile',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0A66C2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendeeDetailRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
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
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendeeDetail(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEnum(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildAttachmentsGrid(List<String> attachments, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final url = attachments[index];
        final isImage = FileUtils.isImage(url);

        return InkWell(
          onTap: () => _openAttachment(url, isImage),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
              ),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFileIcon(url);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  )
                : _buildFileIcon(url),
          ),
        );
      },
    );
  }

  void _openAttachment(String url, bool isImage) {
    if (isImage) {
      // Get all image URLs from attachments
      final imageUrls = _booking!.attachments!.where(FileUtils.isImage).toList();
      final initialIndex = imageUrls.indexOf(url);

      ImageViewerScreen.show(
        context,
        imageUrls: imageUrls,
        initialIndex: initialIndex >= 0 ? initialIndex : 0,
      );
    } else {
      // Open document with external app
      DocumentOpener.openDocument(context, url);
    }
  }

  Widget _buildFileIcon(String url) {
    return Center(
      child: Icon(
        FileUtils.getFileIcon(url),
        size: 40,
        color: FileUtils.getFileIconColor(url),
      ),
    );
  }
}
