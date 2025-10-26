import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:splash_master/splash_master.dart';

/// Animated Splash Screen with TCS Pace logo
/// Uses custom SVG animation with CSS keyframes
/// Duration: ~3 seconds (0.8s delay + 2s animation)
class AnimatedSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final VoidCallback? onAnimationComplete;

  const AnimatedSplashScreen({
    super.key,
    required this.nextScreen,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Animation controller for additional Flutter-side effects
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    );

    // Fade in animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));

    // Subtle scale animation
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    // Start animation
    _controller.forward();

    // Navigate after animation completes (3 seconds total)
    Timer(const Duration(milliseconds: 3000), () {
      if (!_navigated && mounted) {
        _navigated = true;
        widget.onAnimationComplete?.call();

        // Resume Flutter frames to show next screen
        SplashMaster.resume();

        // Navigate to next screen with fade transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background as requested
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SvgPicture.asset(
                  'assets/splash/stpace-logo-animation.svg',
                  width: 246, // 2x original size (123 * 2)
                  height: 60, // 2x original size (30 * 2)
                  fit: BoxFit.contain,
                  // The SVG has embedded CSS animations that will play automatically
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
