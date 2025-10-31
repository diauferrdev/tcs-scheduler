import 'package:flutter/material.dart';

enum ToastType {
  success,
  error,
  info,
  warning,
}

class ToastNotification {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 6),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get color based on type
    Color backgroundColor;
    Color textColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case ToastType.success:
        backgroundColor = isDark ? const Color(0xFF14532D) : const Color(0xFFBBF7D0);
        textColor = isDark ? const Color(0xFFBBF7D0) : const Color(0xFF14532D);
        iconColor = isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);
        icon = Icons.check_circle;
        break;
      case ToastType.error:
        backgroundColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3);
        textColor = isDark ? const Color(0xFFFECDD3) : const Color(0xFF7F1D1D);
        iconColor = isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
        icon = Icons.error;
        break;
      case ToastType.warning:
        backgroundColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
        textColor = isDark ? const Color(0xFFFEF3C7) : const Color(0xFF78350F);
        iconColor = isDark ? const Color(0xFFF05E1B) : const Color(0xFFD97706);
        icon = Icons.warning;
        break;
      case ToastType.info:
      default:
        backgroundColor = isDark ? const Color(0xFF18181B) : Colors.white;
        textColor = isDark ? Colors.white : Colors.black;
        iconColor = isDark ? Colors.white : Colors.black;
        icon = Icons.info;
        break;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    late _ToastWidgetState toastState;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        iconColor: iconColor,
        icon: icon,
        isDark: isDark,
        onDismiss: () => overlayEntry.remove(),
        onStateCreated: (state) => toastState = state,
      ),
    );

    overlay.insert(overlayEntry);

    // Auto dismiss after duration with animation
    Future.delayed(duration, () async {
      if (overlayEntry.mounted) {
        await toastState.animateOut();
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final IconData icon;
  final bool isDark;
  final VoidCallback onDismiss;
  final Function(_ToastWidgetState) onStateCreated;

  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.icon,
    required this.isDark,
    required this.onDismiss,
    required this.onStateCreated,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.fastEaseInToSlowEaseOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.fastEaseInToSlowEaseOut,
    ));

    _controller.forward();
    widget.onStateCreated(this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> animateOut() async {
    await _controller.reverse();
  }

  void _dismiss() async {
    await animateOut();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.iconColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.textColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _dismiss,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: widget.textColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
