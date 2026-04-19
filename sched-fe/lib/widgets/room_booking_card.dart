import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Compact unified card for room bookings — visually identical to BookingCard
class RoomBookingCard extends StatefulWidget {
  final Map<String, dynamic> roomBooking;
  final VoidCallback onTap;

  const RoomBookingCard({
    super.key,
    required this.roomBooking,
    required this.onTap,
  });

  @override
  State<RoomBookingCard> createState() => _RoomBookingCardState();
}

class _RoomBookingCardState extends State<RoomBookingCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseScaleAnimation;
  late Animation<double> _pulseOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

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

    _animationController.forward();

    if (['PENDING', 'NEED_EDIT', 'NEED_RESCHEDULE'].contains(_status)) {
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String get _status => widget.roomBooking['status'] as String? ?? 'PENDING';

  Widget _buildReviewReasonBadge(String reason) {
    final (label, color) = switch (reason) {
      'NEW' => ('New', const Color(0xFF22C55E)),
      'RESCHEDULED' => ('Rescheduled', const Color(0xFF3B82F6)),
      'DATA_EDITED' => ('Edited', const Color(0xFFF97316)),
      'EDIT_RESPONSE' => ('Edit Response', const Color(0xFFF97316)),
      _ => (reason, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final status = _status;
    final isActive = ['PENDING', 'NEED_EDIT', 'NEED_RESCHEDULE'].contains(status);

    final backgroundColor = isActive
        ? (isDark ? const Color(0xFF18181B) : Colors.white)
        : (isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF3F4F6));
    final borderColor = isActive
        ? (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB))
        : (isDark ? const Color(0xFF1C1C1E) : const Color(0xFFD1D5DB));

    final roomName =
        (widget.roomBooking['room'] as String? ?? '').replaceAll('_', ' ');
    final purpose = widget.roomBooking['purpose'] as String? ?? '';
    final date = widget.roomBooking['date'] as String? ?? '';
    final startTime = widget.roomBooking['startTime'] as String? ?? '';
    final endTime = widget.roomBooking['endTime'] as String? ?? '';
    final reviewReason = widget.roomBooking['reviewReason'] as String?;

    String formattedDate = date;
    try {
      formattedDate = DateFormat('MMM d').format(DateTime.parse(date));
    } catch (_) {}

    final titleParts = <String>[roomName];
    if (purpose.isNotEmpty) titleParts.add(purpose);
    final title = titleParts.join(' \u2014 ');

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Icon + Room name + purpose | Date + time range
                Row(
                  children: [
                    Icon(
                      Icons.meeting_room,
                      size: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                    if (reviewReason != null) ...[
                      const SizedBox(width: 8),
                      _buildReviewReasonBadge(reviewReason),
                    ],
                    const SizedBox(width: 12),
                    Text(
                      '$formattedDate \u2022 $startTime\u2013$endTime',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Row 2: Inline 3-step stepper
                _buildStepper(isDark, status),
              ],
            ),
          ),
        ),
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
}
