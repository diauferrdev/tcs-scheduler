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

      final st = response['status'] as String? ?? '';
      if (['PENDING', 'NEED_EDIT', 'NEED_RESCHEDULE'].contains(st)) {
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

  Future<void> _handleEdit() async {
    if (_roomBooking == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purposeController = TextEditingController(text: _roomBooking!['purpose'] as String? ?? '');
    final attendeesController = TextEditingController(text: '${_roomBooking!['attendees'] ?? 1}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text('Edit Room Booking', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: purposeController,
              decoration: InputDecoration(
                labelText: 'Purpose',
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              maxLines: 2,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: attendeesController,
              decoration: InputDecoration(
                labelText: 'Attendees',
                border: const OutlineInputBorder(),
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      final body = <String, dynamic>{};
      if (purposeController.text.isNotEmpty) body['purpose'] = purposeController.text;
      final att = int.tryParse(attendeesController.text);
      if (att != null && att > 0) body['attendees'] = att;

      await _apiService.patch('/api/rooms/${widget.roomBookingId}', body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room booking updated'), backgroundColor: Colors.green),
      );
      _loadRoomBooking();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleReschedule() async {
    if (_roomBooking == null) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    final startTimePicked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (startTimePicked == null || !mounted) return;

    final endTimePicked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startTimePicked.hour + 1, minute: startTimePicked.minute),
    );
    if (endTimePicked == null || !mounted) return;

    final dateStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    final startStr = '${startTimePicked.hour.toString().padLeft(2, '0')}:${startTimePicked.minute.toString().padLeft(2, '0')}';
    final endStr = '${endTimePicked.hour.toString().padLeft(2, '0')}:${endTimePicked.minute.toString().padLeft(2, '0')}';

    setState(() => _processing = true);
    try {
      await _apiService.post('/api/rooms/${widget.roomBookingId}/reschedule', {
        'date': dateStr,
        'startTime': startStr,
        'endTime': endStr,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room booking rescheduled'), backgroundColor: Colors.green),
      );
      _loadRoomBooking();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleRequestEdit() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text('Request Edit', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request the user to make edits to this booking.',
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700])),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Request Edit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await _apiService.post('/api/rooms/${widget.roomBookingId}/request-edit', {
        if (messageController.text.isNotEmpty) 'message': messageController.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Edit requested'), backgroundColor: Colors.orange),
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

  Future<void> _handleRequestReschedule() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text('Request Reschedule', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request the user to reschedule this booking to a different date/time.',
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700])),
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
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Request Reschedule'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      await _apiService.post('/api/rooms/${widget.roomBookingId}/request-reschedule', {
        if (messageController.text.isNotEmpty) 'message': messageController.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reschedule requested'), backgroundColor: Colors.orange),
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
    final isAdminOrManager = userRole == UserRole.ADMIN || userRole == UserRole.MANAGER;
    final userId = authProvider.user?.id;
    final bookedById = (_roomBooking!['bookedBy'] as Map?)?['id'] ?? _roomBooking!['bookedById'];
    final isOwner = userId == bookedById;
    final reviewReason = _roomBooking!['reviewReason'] as String?;
    final editRequestMessage = _roomBooking!['editRequestMessage'] as String?;
    final rescheduleRequestMessage = _roomBooking!['rescheduleRequestMessage'] as String?;
    final previousDate = _roomBooking!['previousDate'] as String?;
    final previousStartTime = _roomBooking!['previousStartTime'] as String?;
    final previousEndTime = _roomBooking!['previousEndTime'] as String?;

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

          // Review reason badge
          if (reviewReason != null) ...[
            _buildReviewReasonBadge(reviewReason),
            const SizedBox(height: 16),
          ],

          // Edit / Reschedule request messages
          if (editRequestMessage != null && editRequestMessage.isNotEmpty) ...[
            _buildMessageBanner(isDark, 'Edit Requested', editRequestMessage, Icons.edit_outlined, Colors.orange),
            const SizedBox(height: 12),
          ],
          if (rescheduleRequestMessage != null && rescheduleRequestMessage.isNotEmpty) ...[
            _buildMessageBanner(isDark, 'Reschedule Requested', rescheduleRequestMessage, Icons.event_repeat, Colors.orange),
            const SizedBox(height: 12),
          ],

          // Schedule
          _buildInfoSection(
            'Schedule',
            [
              if (previousDate != null || previousStartTime != null) ...[
                _buildStrikethroughRow(
                  Icons.calendar_today,
                  'Previous',
                  _formatPreviousSchedule(previousDate, previousStartTime, previousEndTime),
                  isDark,
                ),
              ],
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
          Builder(builder: (context) {
            Widget actionBtn(String label, IconData icon, VoidCallback? onTap, {Color? bg, Color? fg}) {
              final defBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6);
              final defFg = isDark ? Colors.white : Colors.black;
              return Expanded(
                child: Material(
                  color: bg ?? defBg,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _processing ? null : onTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 18, color: fg ?? defFg),
                          const SizedBox(height: 4),
                          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg ?? defFg), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            if (!isOwner && !isAdminOrManager) return const SizedBox.shrink();

            final actions = <Widget>[];

            // Owner actions
            if (isOwner && ['PENDING', 'APPROVED', 'NEED_EDIT', 'NEED_RESCHEDULE'].contains(status)) {
              actions.add(actionBtn('Edit', Icons.edit_outlined, _handleEdit));
              if (status != 'NEED_RESCHEDULE') {
                actions.add(actionBtn('Reschedule', Icons.calendar_month, _handleReschedule));
              }
              actions.add(actionBtn('Cancel', Icons.close, _cancelRoomBooking,
                bg: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2), fg: Colors.red));
            }

            // Manager/Admin actions on PENDING
            if (isAdminOrManager && status == 'PENDING') {
              actions.addAll([
                actionBtn('Ask Edit', Icons.edit_outlined, _handleRequestEdit),
                actionBtn('Ask Reschedule', Icons.event_repeat, _handleRequestReschedule),
                actionBtn('Reject', Icons.thumb_down_outlined, _rejectBooking,
                  bg: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2), fg: Colors.red),
                actionBtn('Approve', Icons.thumb_up_outlined, _approveBooking,
                  bg: isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7), fg: const Color(0xFF059669)),
              ]);
            }

            // Manager/Admin actions on APPROVED
            if (isAdminOrManager && status == 'APPROVED') {
              actions.addAll([
                actionBtn('Ask Edit', Icons.edit_outlined, _handleRequestEdit),
                actionBtn('Ask Reschedule', Icons.event_repeat, _handleRequestReschedule),
              ]);
            }

            // Manager/Admin actions on NEED_EDIT / NEED_RESCHEDULE
            if (isAdminOrManager && (status == 'NEED_EDIT' || status == 'NEED_RESCHEDULE')) {
              actions.addAll([
                actionBtn('Reject', Icons.thumb_down_outlined, _rejectBooking,
                  bg: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2), fg: Colors.red),
                actionBtn('Cancel', Icons.close, _cancelRoomBooking),
              ]);
            }

            if (actions.isEmpty) return const SizedBox.shrink();

            // Split into rows of 2
            final rows = <Widget>[];
            for (int i = 0; i < actions.length; i += 2) {
              final rowChildren = <Widget>[actions[i]];
              if (i + 1 < actions.length) {
                rowChildren.add(const SizedBox(width: 8));
                rowChildren.add(actions[i + 1]);
              }
              rows.add(Row(children: rowChildren));
              if (i + 2 < actions.length) rows.add(const SizedBox(height: 8));
            }

            return Column(children: rows);
          }),
          const SizedBox(height: 16),
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
    final isPulse = isCurrent && ['PENDING', 'NEED_EDIT', 'NEED_RESCHEDULE'].contains(status);

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
    } else if (status == 'NEED_EDIT') {
      finalLabel = 'Edit Needed';
    } else if (status == 'NEED_RESCHEDULE') {
      finalLabel = 'Reschedule Needed';
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
      case 'NEED_EDIT':
      case 'NEED_RESCHEDULE':
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
      case 'NEED_EDIT':
      case 'NEED_RESCHEDULE':
        return const Color(0xFFF97316);
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
      case 'NEED_EDIT':
        return 'Edit Requested';
      case 'NEED_RESCHEDULE':
        return 'Reschedule Requested';
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

  Widget _buildReviewReasonBadge(String reason) {
    final (label, color) = switch (reason) {
      'NEW' => ('New', const Color(0xFF22C55E)),
      'RESCHEDULED' => ('Rescheduled', const Color(0xFF3B82F6)),
      'DATA_EDITED' => ('Edited', const Color(0xFFF97316)),
      'EDIT_RESPONSE' => ('Edit Response', const Color(0xFFF97316)),
      _ => (reason, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMessageBanner(bool isDark, String title, String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrikethroughRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[400])),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPreviousSchedule(String? date, String? startTime, String? endTime) {
    final parts = <String>[];
    if (date != null) {
      try {
        parts.add(DateFormat('MMM d, yyyy').format(DateTime.parse(date)));
      } catch (_) {
        parts.add(date);
      }
    }
    if (startTime != null && endTime != null) {
      parts.add('$startTime \u2013 $endTime');
    }
    return parts.join(' \u2022 ');
  }
}
