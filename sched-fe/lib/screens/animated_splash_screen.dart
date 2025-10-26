import 'dart:async';
import 'package:flutter/material.dart';
import 'package:splash_master/splash_master.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Animated Splash Screen with TCS Pace logo
/// Features smooth fade-in, scale, and fade-out animations with sound effect
/// Duration: ~4 seconds (fade in 0.8s -> hold 2s -> fade out 0.8s + 0.4s buffer)
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
  late Animation<double> _fadeInAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _scaleAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Animation controller for complete fade in -> hold -> fade out sequence
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3600), // Total animation time
      vsync: this,
    );

    // Fade IN animation (0% -> 25% of timeline = 0-900ms)
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
    ));

    // Fade OUT animation (75% -> 100% of timeline = 2700-3600ms)
    _fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    ));

    // Subtle scale animation (grows slightly during fade in)
    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
    ));

    // Play sound effect (simple beep/chime)
    _playSound();

    // Start animation
    _controller.forward();

    // Navigate after animation completes (4 seconds total)
    Timer(const Duration(milliseconds: 4000), () {
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

  /// Play a simple sound effect for the splash screen
  Future<void> _playSound() async {
    try {
      // Only play sound on mobile/desktop (web can be problematic with autoplay)
      if (!kIsWeb) {
        // You can add a custom sound file here: assets/sounds/splash.mp3
        // For now, we'll use a system notification sound or skip if no file
        // await _audioPlayer.play(AssetSource('sounds/splash.mp3'));
        debugPrint('[Splash] Sound playback ready (add splash.mp3 to enable)');
      }
    } catch (e) {
      debugPrint('[Splash] Error playing sound: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background matching TCS brand
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Combine fade in and fade out animations
            final fadeValue = _fadeInAnimation.value * (1.0 - (_fadeOutAnimation.value - 1.0).abs());

            return Opacity(
              opacity: fadeValue,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Image.asset(
                  'assets/splash/tcs_logo_splash.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
