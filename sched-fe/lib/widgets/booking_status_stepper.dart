import 'package:flutter/material.dart';
import '../models/booking.dart';

/// A visual stepper that shows the progress of a booking through its lifecycle
/// with animated transitions and gradient lines
class BookingStatusStepper extends StatefulWidget {
  final BookingStatus currentStatus;
  final bool isDark;
  final bool showOnlyCurrentColor; // If true, only show current step color

  const BookingStatusStepper({
    super.key,
    required this.currentStatus,
    required this.isDark,
    this.showOnlyCurrentColor = true, // Default to simple mode
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

    // Only pulse if status is under review (UNDER_REVIEW, NEED_EDIT, NEED_RESCHEDULE)
    if (_isUnderReviewStatus(widget.currentStatus)) {
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
      if (_isUnderReviewStatus(widget.currentStatus)) {
        _pulseController.repeat();
      } else {
        _pulseController.stop();
      }
    }
  }

  /// Check if status is in "under review" phase (review, need edit, need reschedule)
  bool _isUnderReviewStatus(BookingStatus status) {
    return status == BookingStatus.UNDER_REVIEW ||
           status == BookingStatus.NEED_EDIT ||
           status == BookingStatus.NEED_RESCHEDULE;
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
    final isPending = isCurrent && _isUnderReviewStatus(widget.currentStatus);

    // Animated color transition
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        Color circleColor = _getCircleColor(stepIndex, isActive, isCurrent);

        // If status just changed, animate from previous color
        if (_transitionController.isAnimating && _previousStatus != null) {
          // Calculate if this step was current in the previous status
          int previousStepIndex = _getStepIndexForStatus(_previousStatus!);
          bool wasPreviousCurrent = stepIndex == previousStepIndex;
          Color previousColor = _getCircleColorForStatus(stepIndex, _previousStatus!, isCurrent: wasPreviousCurrent);
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
              color: circleColor, // Border matches the circle color
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
                    width: 70, // Increased width to fit longer labels like "Need Reschedule"
                    child: Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 9, // Slightly smaller to fit better
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrent
                            ? (widget.isDark ? Colors.white : Colors.black)
                            : (widget.isDark ? Colors.grey[600]! : Colors.grey[400]!),
                        height: 1.2, // Tighter line height
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2, // Allow 2 lines for longer labels
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
    return _getCircleColorForStatus(stepIndex, widget.currentStatus, isActive: isActive, isCurrent: isCurrent);
  }

  Color _getCircleColorForStatus(int stepIndex, BookingStatus status, {bool isActive = true, bool isCurrent = false}) {
    final currentStepIndex = _getStepIndexForStatus(status);

    // If showOnlyCurrentColor is true, only color the current step
    if (widget.showOnlyCurrentColor) {
      if (stepIndex != currentStepIndex) {
        // All non-current steps are grey
        return widget.isDark ? Colors.grey[700]! : Colors.grey[300]!;
      }

      // Current step gets its appropriate color
      return _getCurrentStepColor(status);
    }

    // Full color mode: show all colors up to current step
    // If this step hasn't been reached yet, make it grey
    if (stepIndex > currentStepIndex) {
      return widget.isDark ? Colors.grey[700]! : Colors.grey[300]!;
    }

    // For completed or current steps, use appropriate colors based on step position
    if (status == BookingStatus.CANCELLED || status == BookingStatus.NOT_APPROVED) {
      // Cancelled or Not Approved flow
      if (stepIndex == 0) {
        return const Color(0xFF6B7280); // Grey for Created
      } else if (stepIndex == 1) {
        return const Color(0xFFF05E1B); // Yellow for Review phase
      } else {
        return const Color(0xFFEF4444); // Red for final step (Cancelled/Not Approved)
      }
    } else {
      // Normal flow (Created → Review → Approved)
      if (stepIndex == 0) {
        return const Color(0xFF6B7280); // Grey for Created
      } else if (stepIndex == 1) {
        return const Color(0xFFF05E1B); // Yellow for Review phase
      } else {
        return const Color(0xFF10B981); // Green for Approved
      }
    }
  }

  /// Get the color for the current step based on status
  Color _getCurrentStepColor(BookingStatus status) {
    if (status == BookingStatus.CANCELLED || status == BookingStatus.NOT_APPROVED) {
      return const Color(0xFFEF4444); // Red
    } else if (status == BookingStatus.APPROVED) {
      return const Color(0xFF10B981); // Green
    } else if (status == BookingStatus.UNDER_REVIEW) {
      return const Color(0xFFF05E1B); // Yellow (for UNDER_REVIEW)
    } else if (status == BookingStatus.NEED_EDIT) {
      return const Color(0xFFEA580C); // Orange (needs edit)
    } else if (status == BookingStatus.NEED_RESCHEDULE) {
      return const Color(0xFF8B5CF6); // Purple (needs reschedule)
    } else {
      // CREATED or DRAFT
      return const Color(0xFF6B7280); // Grey
    }
  }

  Widget _buildConnectorLine({
    required int fromIndex,
    required int toIndex,
    required int currentStepIndex,
  }) {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        Color lineColor;

        if (widget.showOnlyCurrentColor) {
          // Simple mode: only color the line connected to current step
          if (toIndex == currentStepIndex) {
            // Line leading TO current step - use current step color
            lineColor = _getCurrentStepColor(widget.currentStatus);
          } else {
            // All other lines are grey
            lineColor = widget.isDark ? Colors.grey[800]! : Colors.grey[300]!;
          }
        } else {
          // Full color mode: color all lines up to current step
          final bool isLineActive = toIndex <= currentStepIndex;

          if (!isLineActive) {
            // Future line - grey
            lineColor = widget.isDark ? Colors.grey[800]! : Colors.grey[300]!;
          } else {
            // Active line - color based on destination step
            if (toIndex == 1) {
              // Line to Review step: Yellow/Orange
              lineColor = const Color(0xFFF05E1B);
            } else if (toIndex == 2) {
              // Line to Final step: Green or Red depending on status
              if (widget.currentStatus == BookingStatus.CANCELLED ||
                  widget.currentStatus == BookingStatus.NOT_APPROVED) {
                lineColor = const Color(0xFFEF4444); // Red for cancelled/not approved
              } else {
                lineColor = const Color(0xFF10B981); // Green for approved
              }
            } else {
              // Line from Created to Review (toIndex == 1 handled above)
              lineColor = const Color(0xFFF05E1B);
            }

            // Animate color transition when status changes
            if (_transitionController.isAnimating && _previousStatus != null) {
              int previousStepIndex = _getStepIndexForStatus(_previousStatus!);
              bool wasPreviousLineActive = toIndex <= previousStepIndex;

              Color previousColor;
              if (!wasPreviousLineActive) {
                previousColor = widget.isDark ? Colors.grey[800]! : Colors.grey[300]!;
              } else {
                if (toIndex == 1) {
                  previousColor = const Color(0xFFF05E1B);
                } else if (toIndex == 2) {
                  if (_previousStatus == BookingStatus.CANCELLED ||
                      _previousStatus == BookingStatus.NOT_APPROVED) {
                    previousColor = const Color(0xFFEF4444);
                  } else {
                    previousColor = const Color(0xFF10B981);
                  }
                } else {
                  previousColor = const Color(0xFFF05E1B);
                }
              }
              lineColor = Color.lerp(previousColor, lineColor, _transitionController.value) ?? lineColor;
            }
          }
        }

        // Animate line fill only if it's active (leads to current or past step)
        final isActive = toIndex <= currentStepIndex;

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
    // Middle step label depends on current review status
    String middleLabel;
    if (widget.currentStatus == BookingStatus.NEED_EDIT) {
      middleLabel = 'Change Request';
    } else if (widget.currentStatus == BookingStatus.NEED_RESCHEDULE) {
      middleLabel = 'Need Reschedule';
    } else {
      middleLabel = 'Under Review';
    }

    // Final step label depends on current status
    String finalLabel;
    if (widget.currentStatus == BookingStatus.CANCELLED) {
      finalLabel = 'Cancelled';
    } else if (widget.currentStatus == BookingStatus.NOT_APPROVED) {
      finalLabel = 'Not Approved';
    } else {
      finalLabel = 'Approved';
    }

    return [
      _StepInfo(label: 'Created'),
      _StepInfo(label: middleLabel),
      _StepInfo(label: finalLabel),
    ];
  }

  int _getCurrentStepIndex() {
    return _getStepIndexForStatus(widget.currentStatus);
  }

  int _getStepIndexForStatus(BookingStatus status) {
    switch (status) {
      // Step 0: Created
      case BookingStatus.CREATED:
        return 0;

      // Step 1: Under Review (includes review, need edit, need reschedule)
      case BookingStatus.UNDER_REVIEW:
      case BookingStatus.NEED_EDIT:
      case BookingStatus.NEED_RESCHEDULE:
        return 1;

      // Step 2: Final (approved, not approved, or cancelled)
      case BookingStatus.APPROVED:
      case BookingStatus.NOT_APPROVED:
      case BookingStatus.CANCELLED:
        return 2;
    }
  }
}

class _StepInfo {
  final String label;

  _StepInfo({required this.label});
}
