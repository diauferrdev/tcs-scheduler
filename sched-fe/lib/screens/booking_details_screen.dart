import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../models/booking.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/booking_status_stepper.dart';
import '../widgets/booking_form_fields.dart';
import '../widgets/access_badge.dart';
import '../widgets/reschedule_drawer.dart';
import '../widgets/edit_booking_drawer.dart';
import '../utils/file_utils.dart';
import '../utils/document_opener.dart';
import '../utils/toast_notification.dart';
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
/// - USER: Can edit DRAFT, CREATED, NEED_EDIT, and NEED_RESCHEDULE bookings
/// - MANAGER: Can review, approve, reject, and request changes to bookings
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
  final PageController _badgePageController = PageController();

  Booking? _booking;
  BookingFormData? _formData;
  bool _isLoading = true;
  String? _error;
  bool _processing = false;
  bool _isEditing = false;
  int _currentBadgePage = 0;

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
      }
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _realtimeService.onBookingUpdated = null;
    _realtimeService.onBookingApproved = null;
    _realtimeService.onBookingDeleted = null;
    _formData?.dispose();
    _badgePageController.dispose();
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
      final response = await _apiService.getBookingById(widget.bookingId);

      if (mounted) {
        setState(() {
          _booking = Booking.fromJson(response);
          _isLoading = false;
        });
      }
    } catch (e) {
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

    // USER can ONLY edit when status = NEED_EDIT (manager requested edits)
    if (userRole == UserRole.USER) {
      final isOwner = _booking!.createdById == userId;
      final canEditStatus = _booking!.status == BookingStatus.NEED_EDIT;
      return isOwner && canEditStatus;
    }

    // MANAGER cannot edit bookings directly (they review/approve/reject)
    return false;
  }

  Future<void> _enterEditMode() async {
    if (!_canEdit()) return;

    // Open edit drawer (following app pattern)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return EditBookingDrawer(
          booking: _booking!,
          onClose: () => Navigator.of(context).pop(),
          onSuccess: () {
            Navigator.of(context).pop(); // Close edit drawer
            _loadBookingDetails(); // Reload booking details
          },
        );
      },
    );
  }

  int _getDurationFromEnum(String durationEnum) {
    switch (durationEnum) {
      case 'ONE_HOUR':
        return 1;
      case 'TWO_HOURS':
        return 2;
      case 'THREE_HOURS':
        return 3;
      case 'FOUR_HOURS':
        return 4;
      case 'FIVE_HOURS':
        return 5;
      case 'SIX_HOURS':
        return 6;
      case 'SEVEN_HOURS':
        return 7;
      default:
        return 2;
    }
  }

  Future<void> _shareBooking() async {
    if (_booking == null) return;

    try {
      final booking = _booking!;
      final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
      final timeFormat = DateFormat('HH:mm');

      // Create shareable deep link
      final bookingUrl = 'https://pacesched.com/#/app/booking/${booking.id}';

      // Get engagement type name
      final engagementTypeName = booking.engagementType?.name ?? 'Visit';

      // Get duration in hours
      final durationHours = _getDurationFromEnum(booking.duration.name);

      // Get status name
      final statusName = booking.status.name.replaceAll('_', ' ');

      // Format booking details
      final shareText = '''
📅 Pace Scheduler - Booking Details

$engagementTypeName
${booking.companyName}

📍 Date: ${dateFormat.format(booking.date)}
🕐 Time: ${timeFormat.format(DateTime(2024, 1, 1, int.parse(booking.startTime.split(':')[0]), int.parse(booking.startTime.split(':')[1])))}
⏱️ Duration: $durationHours hour(s)
👥 Attendees: ${(booking.attendees?.length ?? 0) + 1}

Status: $statusName

View full details: $bookingUrl

---
Pace Scheduler
Enterprise Office Visit Management
''';

      // Show share options
      // ignore: deprecated_member_use
      final result = await Share.share(
        shareText,
        subject: 'Booking: ${booking.companyName} - ${dateFormat.format(booking.date)}',
      );

      if (result.status == ShareResultStatus.success) {
        if (mounted) {
          ToastNotification.show(
            context,
            message: 'Booking shared successfully',
            type: ToastType.success,
            duration: const Duration(seconds: 2),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Failed to share booking',
          type: ToastType.error,
        );
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _formData?.dispose();
      _formData = null;
    });
  }

  Future<void> _submitForApproval() async {
    if (_booking == null || _formData == null) return;

    if (!_formKey.currentState!.validate()) {
      ToastNotification.show(
        context,
        message: 'Please fill in all required fields',
        type: ToastType.error,
      );
      return;
    }

    try {
      setState(() => _processing = true);

      final updateData = _formData!.toJson(
        DateFormat('yyyy-MM-dd').format(_booking!.date),
        _booking!.startTime,
      );

      // Set status to CREATED (submit for review)
      updateData['status'] = 'CREATED';

      await _apiService.updateBooking(_booking!.id, updateData);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _processing = false;
        });

        ToastNotification.show(
          context,
          message: 'Booking submitted for approval! Managers have been notified.',
          type: ToastType.success,
        );

        _loadBookingDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ToastNotification.show(
          context,
          message: 'Error submitting booking: $e',
          type: ToastType.error,
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
        ToastNotification.show(
          context,
          message: 'Booking approved successfully!',
          type: ToastType.success,
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
        ToastNotification.show(
          context,
          message: 'Error approving booking: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleRequestEdit() async {
    if (_booking == null) return;

    final messageController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Request Edit',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request the user to make edits to this booking.',
                style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'Explain what needs to be edited...',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Request Edit'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() => _processing = true);
      await _apiService.requestEdit(
        _booking!.id,
        message: messageController.text.isNotEmpty ? messageController.text : null,
      );

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Edit requested successfully',
          type: ToastType.warning,
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
        ToastNotification.show(
          context,
          message: 'Error requesting edit: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleRequestReschedule() async {
    if (_booking == null) return;

    final messageController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Request Reschedule',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Request the user to reschedule this booking to a different date/time.',
                style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'Explain why reschedule is needed...',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Request Reschedule'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() => _processing = true);
      await _apiService.requestReschedule(
        _booking!.id,
        message: messageController.text.isNotEmpty ? messageController.text : null,
      );

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Reschedule requested successfully',
          type: ToastType.warning,
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
        ToastNotification.show(
          context,
          message: 'Error requesting reschedule: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleReject() async {
    if (_booking == null) return;

    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Not Approve Booking',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Permanently reject this booking request. The user will be notified.',
                style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason*',
                  hintText: 'Explain why this booking is rejected...',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ToastNotification.show(
                    context,
                    message: 'Please provide a rejection reason',
                    type: ToastType.error,
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Not Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() => _processing = true);
      await _apiService.rejectBooking(_booking!.id, reasonController.text);

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Booking rejected',
          type: ToastType.error,
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
        ToastNotification.show(
          context,
          message: 'Error rejecting booking: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleCancel() async {
    if (_booking == null) return;

    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Cancel Booking',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cancel this booking. This can be used for approved bookings that need to be cancelled.',
                style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Cancellation Reason*',
                  hintText: 'Explain why this booking is cancelled...',
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                maxLines: 3,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ToastNotification.show(
                    context,
                    message: 'Please provide a cancellation reason',
                    type: ToastType.error,
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Booking'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() => _processing = true);
      await _apiService.cancelBooking(_booking!.id, reasonController.text);

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Booking cancelled',
          type: ToastType.error,
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
        ToastNotification.show(
          context,
          message: 'Error cancelling booking: $e',
          type: ToastType.error,
        );
      }
    }
  }

  /// USER: Handle reschedule when status is NEED_RESCHEDULE
  Future<void> _handleUserReschedule() async {
    if (_booking == null) return;

    // Open reschedule drawer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RescheduleDrawer(
          booking: _booking!,
          onClose: () => Navigator.of(context).pop(),
          onSuccess: () {
            Navigator.of(context).pop(); // Close reschedule drawer
            _loadBookingDetails(); // Reload booking details
          },
        );
      },
    );
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
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;
    final isOwner = _booking?.createdById == userId;

    // Check if user can reschedule
    final canReschedule = isOwner && _booking?.status == BookingStatus.NEED_RESCHEDULE;

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

          // Title with pencil icon for edit/reschedule
          Expanded(
            child: Row(
              children: [
                Text(
                  'Booking Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                // Share button
                IconButton(
                  onPressed: _shareBooking,
                  icon: Icon(
                    Icons.share_outlined,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  tooltip: 'Share Booking',
                  style: IconButton.styleFrom(
                    backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(width: 8),
                // Edit icon for NEED_EDIT (on the right side)
                if (canEdit) ...[
                  InkWell(
                    onTap: _enterEditMode,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF05E1B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF05E1B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Color(0xFFF05E1B),
                      ),
                    ),
                  ),
                ],
                // Calendar icon for NEED_RESCHEDULE (on the right side)
                if (canReschedule) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _handleUserReschedule,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF05E1B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF05E1B).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: Color(0xFFF05E1B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons for DRAFTS
          // Action buttons for non-drafts (only when in editing mode)
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
          ],
        ],
      ),
    );
  }

  Widget _buildViewMode(bool isDark) {
    final authProvider = context.read<AuthProvider>();
    final userRole = authProvider.user?.role;

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

        // Cancellation Reason (for CANCELLED bookings)
        if (_booking!.status == BookingStatus.CANCELLED && _booking!.cancellationReason != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cancel_outlined,
                  size: 24,
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancellation Reason',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _booking!.cancellationReason!,
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF991B1B),
                          height: 1.4,
                        ),
                      ),
                      if (_booking!.cancelledAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Cancelled on ${DateFormat('MMM d, yyyy - HH:mm').format(_booking!.cancelledAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF991B1B).withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Rejection Reason (for NOT_APPROVED bookings)
        if (_booking!.status == BookingStatus.NOT_APPROVED && _booking!.rejectionReason != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFEF4444),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cancel_outlined,
                  size: 24,
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rejection Reason',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _booking!.rejectionReason!,
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF991B1B),
                          height: 1.4,
                        ),
                      ),
                      if (_booking!.rejectedAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Rejected on ${DateFormat('MMM d, yyyy - HH:mm').format(_booking!.rejectedAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF991B1B).withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Edit Request Message (for NEED_EDIT bookings) - ALWAYS SHOW
        if (_booking!.status == BookingStatus.NEED_EDIT) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.15) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFF05E1B).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: const Color(0xFFF05E1B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change request from manager',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF05E1B) : const Color(0xFFF05E1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _booking!.editRequestMessage ?? 'Please review and make the necessary changes to this booking.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFF05E1B).withValues(alpha: 0.9) : const Color(0xFFF05E1B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Reschedule Request Message (for NEED_RESCHEDULE bookings) - ALWAYS SHOW
        if (_booking!.status == BookingStatus.NEED_RESCHEDULE) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.15) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFF05E1B).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: const Color(0xFFF05E1B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manager requested reschedule',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF05E1B) : const Color(0xFFF05E1B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _booking!.rescheduleRequestMessage ?? 'Please reschedule this booking to a different date/time.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFF05E1B).withValues(alpha: 0.9) : const Color(0xFFF05E1B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Removed: Large action buttons for NEED_EDIT and NEED_RESCHEDULE
        // Now using pencil icon in header instead

        // Requester Information
        _buildInfoSection(
          'Requester Information',
          [
            if (_booking!.requesterName != null && _booking!.requesterName!.isNotEmpty)
              _buildInfoRow(Icons.person, 'Name', _booking!.requesterName!, isDark),
            if (_booking!.employeeId != null && _booking!.employeeId!.isNotEmpty)
              _buildInfoRow(Icons.badge, 'Employee ID', _booking!.employeeId!, isDark),
            if (_booking!.vertical != null)
              _buildInfoRow(Icons.apartment, 'Vertical', _formatEnum(_booking!.vertical!.name), isDark),
          ],
          isDark,
        ),
        const SizedBox(height: 16),

        // Organization Information
        _buildInfoSection(
          'Organization Information',
          [
            if (_booking!.organizationName != null && _booking!.organizationName!.isNotEmpty)
              _buildInfoRow(Icons.business, 'Organization', _booking!.organizationName!, isDark),
            if (_booking!.organizationType != null)
              _buildInfoRow(Icons.category, 'Type', _formatEnum(_booking!.organizationType!.name), isDark),
            if (_booking!.organizationTypeOther != null && _booking!.organizationTypeOther!.isNotEmpty)
              _buildInfoRow(Icons.info_outline, 'Type (Other)', _booking!.organizationTypeOther!, isDark),
            if (_booking!.organizationDescription != null && _booking!.organizationDescription!.isNotEmpty)
              _buildInfoRow(Icons.description, 'Description', _booking!.organizationDescription!, isDark),
          ],
          isDark,
        ),
        const SizedBox(height: 16),

        // Engagement Details
        _buildInfoSection(
          'Engagement Details',
          [
            _buildInfoRow(
              Icons.handshake,
              'Engagement Type',
              _formatEnum(_booking!.engagementType?.name ?? 'Not specified'),
              isDark,
            ),
            _buildInfoRow(
              Icons.event,
              'Visit Type',
              _formatEnum(_booking!.visitType.name),
              isDark,
            ),
            if (_booking!.objectiveInterest != null && _booking!.objectiveInterest!.isNotEmpty)
              _buildInfoRow(Icons.flag, 'Objective / Interest', _booking!.objectiveInterest!, isDark),
            if (_booking!.targetAudience != null)
              _buildTargetAudienceRow(_booking!.targetAudience!, isDark),
          ],
          isDark,
        ),
        const SizedBox(height: 16),

        // Questionnaire Answers (if present)
        if (_booking!.questionnaireAnswers != null) ...[
          _buildInfoSection(
            'Questionnaire Answers',
            [
              _buildQuestionnaireAnswers(_booking!.questionnaireAnswers!, isDark),
            ],
            isDark,
          ),
          const SizedBox(height: 16),
        ],

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
              _buildInfoRow(Icons.wifi, 'WiFi Network', 'Pace-Guest', isDark),
              _buildInfoRow(Icons.lock, 'WiFi Password', 'Innovation2024', isDark),
              _buildInfoRow(
                Icons.location_on,
                'Location',
                'PacePort - Av. Paulista, 1374 - São Paulo',
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

          // Access Badges (for APPROVED bookings)
          // IMPORTANT: Creator always gets a badge, plus all attendees
          if (_booking!.status == BookingStatus.APPROVED) ...[
            Builder(
              builder: (context) {
                // Build list of all badge data
                final List<Map<String, dynamic>> badgeData = [];

                // 1. CREATOR BADGE (always first)
                // The creator (requester) ALWAYS gets a badge, even if not in attendees list
                if (_booking!.requesterName != null && _booking!.requesterName!.isNotEmpty) {
                  badgeData.add({
                    'name': _booking!.requesterName!,
                    'position': 'Requester',
                    'id': _booking!.createdById ?? 'CREATOR',
                  });
                }

                // 2. ATTENDEE BADGES
                if (_booking!.attendees != null && _booking!.attendees!.isNotEmpty) {
                  for (final attendee in _booking!.attendees!) {
                    badgeData.add({
                      'name': attendee.name,
                      'position': attendee.position,
                      'id': attendee.id,
                    });
                  }
                }

                // Only show section if we have at least one badge
                if (badgeData.isEmpty) {
                  return const SizedBox.shrink();
                }

                final multipleBadges = badgeData.length > 1;

                return Column(
                  children: [
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
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
                                      multipleBadges
                                          ? 'Swipe to see all ${badgeData.length} badges'
                                          : 'Print badge for requester',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (multipleBadges) ...[
                                const SizedBox(width: 12),
                                // Navigation buttons
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: _currentBadgePage > 0
                                          ? () {
                                              _badgePageController.previousPage(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                          : null,
                                      icon: Icon(
                                        Icons.chevron_left,
                                        color: _currentBadgePage > 0
                                            ? (isDark ? Colors.white : Colors.black)
                                            : Colors.grey,
                                      ),
                                      tooltip: 'Previous badge',
                                    ),
                                    IconButton(
                                      onPressed: _currentBadgePage < badgeData.length - 1
                                          ? () {
                                              _badgePageController.nextPage(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                          : null,
                                      icon: Icon(
                                        Icons.chevron_right,
                                        color: _currentBadgePage < badgeData.length - 1
                                            ? (isDark ? Colors.white : Colors.black)
                                            : Colors.grey,
                                      ),
                                      tooltip: 'Next badge',
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Badge carousel
                          SizedBox(
                            height: 520, // Fixed height for badge
                            child: PageView.builder(
                              controller: _badgePageController,
                              itemCount: badgeData.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentBadgePage = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final badge = badgeData[index];
                                return Center(
                                  child: AccessBadge(
                                    attendeeName: badge['name'],
                                    attendeePosition: badge['position'],
                                    attendeeId: badge['id'],
                                    companyName: _booking!.companyName,
                                    date: _booking!.date,
                                    startTime: _booking!.startTime,
                                    duration: _booking!.duration.name,
                                    bookingId: _booking!.id,
                                    isDark: isDark,
                                    showActions: true,
                                  ),
                                );
                              },
                            ),
                          ),
                          // Page indicators (dots)
                          if (multipleBadges) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                badgeData.length,
                                (index) => Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: index == _currentBadgePage ? 24 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: index == _currentBadgePage
                                        ? (isDark ? Colors.white : Colors.black)
                                        : (isDark ? Colors.grey[700] : Colors.grey[400]),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ],
        ],

        // Metadata (only for ADMIN)
        if (userRole == UserRole.ADMIN)
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

        // Manager/Admin Actions for Review Statuses
        if (_booking!.status == BookingStatus.CREATED ||
            _booking!.status == BookingStatus.UNDER_REVIEW ||
            _booking!.status == BookingStatus.NEED_EDIT ||
            _booking!.status == BookingStatus.NEED_RESCHEDULE) ...[
          const SizedBox(height: 20),
          Builder(
            builder: (context) {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final userRole = authProvider.user?.role;
              final isAdminOrManager =
                  userRole == UserRole.ADMIN || userRole == UserRole.MANAGER;

              if (!isAdminOrManager) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Action buttons for CREATED, UNDER_REVIEW
                  if (_booking!.status == BookingStatus.CREATED ||
                      _booking!.status == BookingStatus.UNDER_REVIEW) ...[
                    // First row: Change Request, Need Reschedule, Cancel
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing ? null : _handleRequestEdit,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(
                              'Change Request',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing ? null : _handleRequestReschedule,
                            icon: const Icon(Icons.calendar_month, size: 16),
                            label: const Text(
                              'Need Reschedule',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing ? null : _handleCancel,
                            icon: const Icon(Icons.block, size: 16),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Second row: Not Approve (red) and Approve (green)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _processing ? null : _handleReject,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text(
                              'Not Approve',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _processing ? null : _handleApprove,
                            icon: _processing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check, size: 16),
                            label: const Text(
                              'Approve',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF065F46) : const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // For NEED_EDIT and NEED_RESCHEDULE - Only show reject/cancel
                  if (_booking!.status == BookingStatus.NEED_EDIT ||
                      _booking!.status == BookingStatus.NEED_RESCHEDULE) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing ? null : _handleReject,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text(
                              'Not Approve',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _processing ? null : _handleCancel,
                            icon: const Icon(Icons.block, size: 16),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              side: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
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

          // Relationship
          if (attendee.tcsSupporter != null) ...[
            _buildAttendeeDetailRow(
              Icons.thumb_up,
              'Supporter Level',
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
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A66C2).withValues(alpha: 0.1) : const Color(0xFF0A66C2).withValues(alpha: 0.05),
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

  Widget _buildTargetAudienceRow(dynamic targetAudience, bool isDark) {
    List<String> audiences = [];

    if (targetAudience is List) {
      audiences = targetAudience.map((e) => e.toString()).toList();
    } else if (targetAudience is String) {
      try {
        // Try to parse as JSON if it's a string
        final parsed = jsonDecode(targetAudience);
        if (parsed is List) {
          audiences = parsed.map((e) => e.toString()).toList();
        }
      } catch (e) {
        audiences = [targetAudience];
      }
    }

    if (audiences.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.groups,
            size: 20,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Audience',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: audiences.map((audience) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        _formatEnum(audience),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireAnswers(dynamic questionnaireData, bool isDark) {
    Map<String, dynamic> answers = {};

    if (questionnaireData is Map) {
      answers = questionnaireData.cast<String, dynamic>();
    } else if (questionnaireData is String) {
      try {
        final parsed = jsonDecode(questionnaireData);
        if (parsed is Map) {
          answers = parsed.cast<String, dynamic>();
        }
      } catch (e) {
        return Text(
          'Error parsing questionnaire data',
          style: TextStyle(
            color: isDark ? Colors.red[400] : Colors.red[600],
            fontSize: 14,
          ),
        );
      }
    }

    if (answers.isEmpty) {
      return const Text('No questionnaire answers available');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: answers.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  entry.value.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
