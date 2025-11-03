import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Audio recording button with long-press and slide-to-cancel gesture
class AudioRecordingButton extends StatefulWidget {
  final VoidCallback onStartRecording;
  final VoidCallback onStopAndSend;
  final VoidCallback onCancel;
  final Duration recordingDuration;
  final bool isRecording;
  final bool isDisabled;

  const AudioRecordingButton({
    super.key,
    required this.onStartRecording,
    required this.onStopAndSend,
    required this.onCancel,
    required this.recordingDuration,
    required this.isRecording,
    this.isDisabled = false,
  });

  @override
  State<AudioRecordingButton> createState() => _AudioRecordingButtonState();
}

class _AudioRecordingButtonState extends State<AudioRecordingButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  double _dragOffset = 0.0;
  bool _shouldCancel = false;
  static const double _cancelThreshold = 150.0; // 150px to cancel
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.isDisabled) return;

    setState(() {
      _isPressed = true;
      _dragOffset = 0.0;
      _shouldCancel = false;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Start recording after minimal delay (feels instant but confirms hold)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isPressed && mounted) {
        widget.onStartRecording();
      }
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!widget.isRecording) return;

    setState(() {
      // Only track horizontal drag (to the left)
      _dragOffset = details.localPosition.dx < 0 ? details.localPosition.dx.abs() : 0;
      _shouldCancel = _dragOffset > _cancelThreshold;
    });

    // Haptic feedback when crossing cancel threshold
    if (_shouldCancel && _dragOffset > _cancelThreshold && _dragOffset < _cancelThreshold + 5) {
      HapticFeedback.heavyImpact();
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _isPressed = false;
    });

    if (_shouldCancel) {
      widget.onCancel();
      HapticFeedback.lightImpact();
    } else if (widget.isRecording) {
      widget.onStopAndSend();
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _dragOffset = 0.0;
      _shouldCancel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Recording indicator overlay (appears when recording)
        if (widget.isRecording)
          Positioned(
            right: 60,
            top: 0,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _shouldCancel ? Colors.red.withValues(alpha: 0.9) : const Color(0xFF222222),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cancel indicator (left arrow)
                  if (_dragOffset > 50)
                    AnimatedOpacity(
                      opacity: _shouldCancel ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.arrow_back,
                        color: _shouldCancel ? Colors.white : Colors.grey,
                        size: 20,
                      ),
                    ),
                  if (_dragOffset > 50) const SizedBox(width: 8),

                  // Recording pulse animation
                  if (!_shouldCancel)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.5 + (_pulseController.value * 0.5)),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),

                  const SizedBox(width: 8),

                  // Duration text
                  Text(
                    _formatDuration(widget.recordingDuration),
                    style: TextStyle(
                      color: _shouldCancel ? Colors.white : Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Cancel text (appears when dragging)
                  if (_shouldCancel)
                    const Text(
                      'Release to cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Main button
        GestureDetector(
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: _onLongPressEnd,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.isDisabled
                  ? Colors.grey
                  : widget.isRecording
                      ? Colors.red
                      : const Color(0xFF00A884),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Icon(
                  widget.isRecording ? Icons.mic : Icons.mic_outlined,
                  key: ValueKey(widget.isRecording),
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
