import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

class RoomBookingDetailsScreen extends StatefulWidget {
  final String roomBookingId;
  final bool showScaffold;
  final ScrollController? scrollController;
  final VoidCallback? onClose;

  const RoomBookingDetailsScreen({
    super.key,
    required this.roomBookingId,
    this.showScaffold = false,
    this.scrollController,
    this.onClose,
  });

  @override
  State<RoomBookingDetailsScreen> createState() =>
      _RoomBookingDetailsScreenState();
}

class _RoomBookingDetailsScreenState extends State<RoomBookingDetailsScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _roomBooking;
  bool _isLoading = true;
  String? _error;
  bool _processing = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseScaleAnimation;
  late Animation<double> _pulseOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadRoomBooking();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomBooking() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response =
          await _apiService.get('/api/rooms/${widget.roomBookingId}');
      if (!mounted) return;

      setState(() {
        _roomBooking = response;
        _isLoading = false;
      });

      if ((response['status'] as String? ?? '') == 'PENDING') {
        _pulseController.repeat();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelRoomBooking() async {
    setState(() => _processing = true);
    try {
      await _apiService.post(
        '/api/rooms/${widget.roomBookingId}/cancel',
        {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room booking cancelled'),
          backgroundColor: Colors.orange,
        ),
      );
      widget.onClose?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _approveBooking() async {
    setState(() => _processing = true);
    try {
      await _apiService.post(
        '/api/rooms/${widget.roomBookingId}/approve',
        {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room booking approved'),
          backgroundColor: Colors.green,
        ),
      );
      // Close drawer to return to list (which auto-refreshes)
      if (widget.onClose != null) {
        widget.onClose!();
      } else if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _rejectBooking() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text(
          'Reject Room Booking',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Reason for rejection (optional)',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (reason == null || !mounted) return;

    setState(() => _processing = true);
    try {
      await _apiService.post(
        '/api/rooms/${widget.roomBookingId}/reject',
        {'rejectionReason': reason},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room booking rejected'),
          backgroundColor: Colors.red,
        ),
      );
      if (widget.onClose != null) {
        widget.onClose!();
      } else if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _shareBooking() {
    if (_roomBooking == null) return;
    final roomName =
        (_roomBooking!['room'] as String? ?? '').replaceAll('_', ' ');
    final date = _roomBooking!['date'] as String? ?? '';
    final startTime = _roomBooking!['startTime'] as String? ?? '';
    final endTime = _roomBooking!['endTime'] as String? ?? '';
    final purpose = _roomBooking!['purpose'] as String? ?? '';

    final text = 'Room Booking: $roomName\n'
        'Date: $date\n'
        'Time: $startTime - $endTime\n'
        '${purpose.isNotEmpty ? 'Purpose: $purpose\n' : ''}';

    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _roomBooking == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Colors.red.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Room booking not found',
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.user?.role;
    final status = _roomBooking!['status'] as String? ?? 'PENDING';
    final isPending = status == 'PENDING';
    final canManage =
        isPending && (userRole == UserRole.ADMIN || userRole == UserRole.MANAGER);
    final userId = authProvider.user?.id;
    final bookedById = (_roomBooking!['bookedBy'] as Map?)?['id'] ?? _roomBooking!['bookedById'];
    final isOwner = userId == bookedById;
    final canCancel = isOwner && (status == 'PENDING' || status == 'APPROVED');

    final roomName =
        (_roomBooking!['room'] as String? ?? '').replaceAll('_', ' ');
    final purpose = _roomBooking!['purpose'] as String? ?? '';
    final date = _roomBooking!['date'] as String? ?? '';
    final startTime = _roomBooking!['startTime'] as String? ?? '';
    final endTime = _roomBooking!['endTime'] as String? ?? '';
    final attendees = _roomBooking!['attendees'] as int? ?? 0;
    final vertical = _roomBooking!['vertical'] as String?;
    final capacity = _roomBooking!['capacity'] as int?;
    final bookedBy = _roomBooking!['bookedBy'] as Map<String, dynamic>?;
    final bookedByName = bookedBy?['name'] as String? ?? 'Unknown';
    final createdAt = _roomBooking!['createdAt'] as String?;

    String formattedDate = date;
    try {
      formattedDate =
          DateFormat('EEEE, MMM d, yyyy').format(DateTime.parse(date));
    } catch (_) {}

    String formattedCreated = '';
    if (createdAt != null) {
      try {
        formattedCreated = DateFormat('MMM d, yyyy \u2022 HH:mm')
            .format(DateTime.parse(createdAt));
      } catch (_) {}
    }

    final content = SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          _buildHeader(isDark, roomName),
          const SizedBox(height: 20),

          // Status stepper
          _buildStepper(isDark, status),
          const SizedBox(height: 20),

          // Room Information
          _buildInfoSection(
            'Room Information',
            [
              _buildInfoRow(Icons.meeting_room, 'Room', roomName, isDark),
              if (capacity != null)
                _buildInfoRow(
                    Icons.people_outline, 'Capacity', '$capacity', isDark),
            ],
            isDark,
          ),
          const SizedBox(height: 16),

          // Schedule
          _buildInfoSection(
            'Schedule',
            [
              _buildInfoRow(
                  Icons.calendar_today, 'Date', formattedDate, isDark),
              _buildInfoRow(Icons.access_time, 'Time',
                  '$startTime \u2013 $endTime', isDark),
            ],
            isDark,
          ),
          const SizedBox(height: 16),

          // Details
          _buildInfoSection(
            'Details',
            [
              if (purpose.isNotEmpty)
                _buildInfoRow(
                    Icons.description, 'Purpose', purpose, isDark),
              _buildInfoRow(Icons.group, 'Attendees', '$attendees', isDark),
              if (vertical != null && vertical.isNotEmpty)
                _buildInfoRow(Icons.apartment, 'Vertical', vertical, isDark),
            ],
            isDark,
          ),
          const SizedBox(height: 16),

          // Booking Info
          _buildInfoSection(
            'Booking Info',
            [
              _buildInfoRow(
                  Icons.person, 'Booked by', bookedByName, isDark),
              if (formattedCreated.isNotEmpty)
                _buildInfoRow(
                    Icons.schedule, 'Created', formattedCreated, isDark),
              _buildInfoRow(Icons.flag, 'Status', _statusLabel(status), isDark),
            ],
            isDark,
          ),
          const SizedBox(height: 24),

          // Action buttons
          if (canManage) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : _rejectBooking,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : _approveBooking,
                    icon: _processing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Owner cancel button
          if (canCancel && !canManage) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _processing ? null : _cancelRoomBooking,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel Booking'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );

    if (widget.showScaffold) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF9FAFB),
        body: SafeArea(child: content),
      );
    }

    return content;
  }

  Widget _buildHeader(bool isDark, String roomName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(Icons.close,
                color: isDark ? Colors.white : Colors.black),
            tooltip: 'Close',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              roomName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _shareBooking,
            icon: Icon(
              Icons.share_outlined,
              size: 20,
              color: isDark ? Colors.white : Colors.black,
            ),
            tooltip: 'Share',
            style: IconButton.styleFrom(
              backgroundColor:
                  (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(bool isDark, String status) {
    final currentStepIndex = _stepIndex(status);
    final steps = _stepLabels(status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _buildStepCircle(
              label: steps[i],
              stepIndex: i,
              currentStepIndex: currentStepIndex,
              status: status,
              isDark: isDark,
            ),
            if (i < steps.length - 1)
              Expanded(
                child: _buildConnectorLine(
                  toIndex: i + 1,
                  currentStepIndex: currentStepIndex,
                  status: status,
                  isDark: isDark,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCircle({
    required String label,
    required int stepIndex,
    required int currentStepIndex,
    required String status,
    required bool isDark,
  }) {
    final isCurrent = stepIndex == currentStepIndex;
    final isPulse = isCurrent && status == 'PENDING';

    final Color circleColor;
    if (stepIndex != currentStepIndex) {
      circleColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    } else {
      circleColor = _stepColor(status);
    }

    Widget staticCircle = Container(
      width: 12.8,
      height: 12.8,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
        border: Border.all(color: circleColor, width: 1.5),
      ),
    );

    Widget circle;
    if (isPulse) {
      circle = Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 12.8 * _pulseScaleAnimation.value,
                height: 12.8 * _pulseScaleAnimation.value,
                decoration: BoxDecoration(
                  color: circleColor.withValues(
                      alpha: _pulseOpacityAnimation.value),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          staticCircle,
        ],
      );
    } else {
      circle = staticCircle;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          height: 18,
          child: Center(child: circle),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: isCurrent
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectorLine({
    required int toIndex,
    required int currentStepIndex,
    required String status,
    required bool isDark,
  }) {
    final Color lineColor;
    if (toIndex == currentStepIndex) {
      lineColor = _stepColor(status);
    } else {
      lineColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20, left: 4, right: 4),
      height: 2,
      decoration: BoxDecoration(
        color: lineColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  List<String> _stepLabels(String status) {
    final String finalLabel;
    if (status == 'APPROVED') {
      finalLabel = 'Approved';
    } else if (status == 'REJECTED') {
      finalLabel = 'Rejected';
    } else if (status == 'CANCELLED') {
      finalLabel = 'Cancelled';
    } else {
      finalLabel = 'Approved';
    }
    return ['Submitted', 'Pending', finalLabel];
  }

  int _stepIndex(String status) {
    switch (status) {
      case 'PENDING':
        return 1;
      case 'APPROVED':
      case 'REJECTED':
      case 'CANCELLED':
        return 2;
      default:
        return 0;
    }
  }

  Color _stepColor(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'REJECTED':
        return const Color(0xFFEF4444);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      case 'PENDING':
        return const Color(0xFFF05E1B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      case 'PENDING':
        return 'Pending';
      default:
        return status;
    }
  }

  Widget _buildInfoSection(
      String title, List<Widget> children, bool isDark) {
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

  Widget _buildInfoRow(
      IconData icon, String label, String value, bool isDark) {
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
}
