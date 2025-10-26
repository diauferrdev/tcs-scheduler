import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double offset;
  final bool fade;
  final bool slideUp;
  final bool slideLeft;
  final bool slideRight;

  const ScrollReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
    this.offset = 50.0,
    this.fade = true,
    this.slideUp = true,
    this.slideLeft = false,
    this.slideRight = false,
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _hasAnimated = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: widget.fade ? 0.0 : 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    double dx = 0.0;
    double dy = 0.0;

    if (widget.slideUp) {
      dy = widget.offset / 100;
    }
    if (widget.slideLeft) {
      dx = widget.offset / 100;
    }
    if (widget.slideRight) {
      dx = -widget.offset / 100;
    }

    _slideAnimation = Tween<Offset>(
      begin: Offset(dx, dy),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    if (_hasAnimated) return;

    _hasAnimated = true;
    setState(() => _isVisible = true);

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('scroll-reveal-${widget.hashCode}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction >= 0.2 && !_hasAnimated) {
          _triggerAnimation();
        }
      },
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
