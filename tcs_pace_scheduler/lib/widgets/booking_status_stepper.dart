import 'package:flutter/material.dart';
import '../models/booking.dart';

/// A visual stepper that shows the progress of a booking through its lifecycle
/// with animated transitions and gradient lines
class BookingStatusStepper extends StatefulWidget {
  final BookingStatus currentStatus;
  final bool isDark;

  const BookingStatusStepper({
    super.key,
    required this.currentStatus,
    required this.isDark,
  });

  @override
  State<BookingStatusStepper> createState() => _BookingStatusStepperState();
}

class _BookingStatusStepperState extends State<BookingStatusStepper>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _transitionController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  BookingStatus? _previousStatus;

  @override
  void initState() {
    super.initState();
    _previousStatus = widget.currentStatus;
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Only pulse if status is PENDING_APPROVAL
    if (widget.currentStatus == BookingStatus.PENDING_APPROVAL) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(BookingStatusStepper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect status change for animation
    if (oldWidget.currentStatus != widget.currentStatus) {
      _previousStatus = oldWidget.currentStatus;

      // Trigger transition animation
      _transitionController.forward(from: 0.0);

      // Restart pulse animation if needed
      if (widget.currentStatus == BookingStatus.PENDING_APPROVAL) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps();
    final currentStepIndex = _getCurrentStepIndex();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            // Step circle
            _buildStepCircle(
              steps[i],
              stepIndex: i,
              isActive: i <= currentStepIndex,
              isCurrent: i == currentStepIndex,
            ),
            // Connector line (except after last step)
            if (i < steps.length - 1)
              Expanded(
                child: _buildConnectorLine(
                  fromIndex: i,
                  toIndex: i + 1,
                  currentStepIndex: currentStepIndex,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCircle(_StepInfo step, {
    required int stepIndex,
    required bool isActive,
    required bool isCurrent,
  }) {
    final isPending = isCurrent && widget.currentStatus == BookingStatus.PENDING_APPROVAL;

    // Animated color transition
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        Color circleColor = _getCircleColor(stepIndex, isActive, isCurrent);

        // If status just changed, animate from previous color
        if (_transitionController.isAnimating && _previousStatus != null) {
          Color previousColor = _getCircleColorForStatus(stepIndex, _previousStatus!);
          circleColor = Color.lerp(previousColor, circleColor, _transitionController.value) ?? circleColor;
        }

        // Static circle (always visible)
        Widget staticCircle = Container(
          width: 12.8,
          height: 12.8,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? circleColor : (widget.isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: 1.5,
            ),
          ),
        );

        // Build double-circle with pulse effect for pending
        Widget circle;
        if (isPending) {
          circle = Stack(
            alignment: Alignment.center,
            children: [
              // Animated pulse circle (behind)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 12.8 * _scaleAnimation.value,
                    height: 12.8 * _scaleAnimation.value,
                    decoration: BoxDecoration(
                      color: circleColor.withValues(alpha: _opacityAnimation.value),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              // Static circle (on top)
              staticCircle,
            ],
          );
        } else {
          circle = staticCircle;
        }

        // Animate scale when status changes
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 500),
          tween: Tween(begin: 0.8, end: 1.0),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: isCurrent ? scale : 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Fixed height container to ensure all circles are at same vertical position
                  SizedBox(
                    width: 30,
                    height: 18, // Enough height for the circle with pulse animation (12.8 * 1.3 = 16.64)
                    child: Center(child: circle),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 50, // Fixed width to prevent layout shifts
                    child: Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive
                            ? (widget.isDark ? Colors.white : Colors.black)
                            : (widget.isDark ? Colors.grey[600]! : Colors.grey[400]!),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getCircleColor(int stepIndex, bool isActive, bool isCurrent) {
    return _getCircleColorForStatus(stepIndex, widget.currentStatus, isActive: isActive);
  }

  Color _getCircleColorForStatus(int stepIndex, BookingStatus status, {bool isActive = true}) {
    if (!isActive) {
      return widget.isDark ? Colors.grey[800]! : Colors.grey[200]!;
    }

    if (status == BookingStatus.CANCELLED) {
      // Cancelled state - red for final step
      if (stepIndex == 2) {
        return const Color(0xFFEF4444); // Red
      } else if (stepIndex == 1) {
        return const Color(0xFFF59E0B); // Yellow/Orange
      } else {
        return const Color(0xFF3B82F6); // Blue for Created
      }
    } else {
      // Normal flow
      if (stepIndex == 0) {
        // Created - Blue
        return const Color(0xFF3B82F6);
      } else if (stepIndex == 1) {
        // Pending - Yellow/Orange
        return const Color(0xFFF59E0B);
      } else {
        // Approved - Green
        return const Color(0xFF10B981);
      }
    }
  }

  Widget _buildConnectorLine({
    required int fromIndex,
    required int toIndex,
    required int currentStepIndex,
  }) {
    // Determine if this line segment should be active
    final isActive = fromIndex < currentStepIndex;

    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        // Get the color for this line segment
        Color lineColor;
        if (!isActive) {
          // Inactive line - grey
          lineColor = widget.isDark ? Colors.grey[800]! : Colors.grey[300]!;
        } else {
          // Active line - depends on which segment
          if (fromIndex == 0) {
            // First line (Created -> Pending): Always Yellow/Orange
            lineColor = const Color(0xFFF59E0B);
          } else {
            // Second line (Pending -> Final): Green or Red depending on status
            if (widget.currentStatus == BookingStatus.CANCELLED) {
              lineColor = const Color(0xFFEF4444); // Red for cancelled
            } else {
              lineColor = const Color(0xFF10B981); // Green for approved
            }

            // Animate color transition for the final line
            if (_transitionController.isAnimating && _previousStatus != null && fromIndex == 1) {
              Color previousColor;
              if (_previousStatus == BookingStatus.CANCELLED) {
                previousColor = const Color(0xFFEF4444);
              } else if (_previousStatus == BookingStatus.APPROVED) {
                previousColor = const Color(0xFF10B981);
              } else {
                previousColor = widget.isDark ? Colors.grey[800]! : Colors.grey[300]!;
              }
              lineColor = Color.lerp(previousColor, lineColor, _transitionController.value) ?? lineColor;
            }
          }
        }

        // Animate line fill
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: isActive ? 1.0 : 0.0),
          curve: Curves.easeInOut,
          builder: (context, progress, child) {
            return Container(
              // Align with center of circles: 9px from top = center of 18px circle container
              margin: const EdgeInsets.only(top: 8, bottom: 20, left: 4, right: 4),
              height: 2,
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          },
        );
      },
    );
  }

  List<_StepInfo> _getSteps() {
    if (widget.currentStatus == BookingStatus.CANCELLED) {
      return [
        _StepInfo(label: 'Created'),
        _StepInfo(label: 'Pending'),
        _StepInfo(label: 'Cancelled'),
      ];
    }

    return [
      _StepInfo(label: 'Created'),
      _StepInfo(label: 'Pending'),
      _StepInfo(label: 'Approved'),
    ];
  }

  int _getCurrentStepIndex() {
    switch (widget.currentStatus) {
      case BookingStatus.DRAFT:
        return 0; // Draft is the first step
      case BookingStatus.PENDING_APPROVAL:
        return 1;
      case BookingStatus.APPROVED:
        return 2; // Approved is the final step
      case BookingStatus.CANCELLED:
        return 2; // Cancelled is shown as the final step
    }
  }
}

class _StepInfo {
  final String label;

  _StepInfo({required this.label});
}
