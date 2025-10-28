import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
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
  late Animation<double> _scaleAnimation;
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[AnimatedSplash] ========================================');
    debugPrint('[AnimatedSplash] 🎬 Splash screen initializing...');

    // Animation controller for complete fade in -> hold -> fade out sequence
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3600), // Total animation time: 3.6s
      vsync: this,
    );

    // Scale animation (grows slightly during fade in with bounce effect)
    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutBack),
    ));

    // Listen to animation changes for debugging
    _controller.addListener(() {
      if (_controller.value == 0.0) {
        debugPrint('[AnimatedSplash] 🎬 Animation at START (0.0)');
      } else if (_controller.value >= 0.25 && _controller.value < 0.26) {
        debugPrint('[AnimatedSplash] ⏸️ Animation HOLD phase (${_controller.value})');
      } else if (_controller.value >= 0.75 && _controller.value < 0.76) {
        debugPrint('[AnimatedSplash] 🌇 Animation FADE OUT phase (${_controller.value})');
      } else if (_controller.value == 1.0) {
        debugPrint('[AnimatedSplash] ✅ Animation COMPLETE (1.0)');
      }
    });

    // Play sound effect (simple beep/chime)
    _playSound();

    // Start animation
    debugPrint('[AnimatedSplash] ▶️ Starting animation...');
    _controller.forward();
    debugPrint('[AnimatedSplash] ▶️ Animation started!');

    // Navigate after animation completes (4 seconds total)
    Timer(const Duration(milliseconds: 4000), () {
      debugPrint('[AnimatedSplash] ⏰ Timer completed (4s)');
      if (!_navigated && mounted) {
        debugPrint('[AnimatedSplash] 🚀 Navigating to main app...');
        _navigated = true;
        widget.onAnimationComplete?.call();

        // No need to call SplashMaster.resume() since we're not using it anymore
        debugPrint('[AnimatedSplash] ✅ Animation complete, switching to main app');

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
        debugPrint('[AnimatedSplash] 🎯 Navigation complete');
      }
    });
  }

  /// Play a simple sound effect for the splash screen
  Future<void> _playSound() async {
    try {
      // Only play sound on mobile/desktop (web can be problematic with autoplay)
      if (!kIsWeb) {
        await _audioPlayer.play(audio.AssetSource('sounds/splash.mp3'));
        debugPrint('[Splash] ✅ Sound playing');
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
    debugPrint('[AnimatedSplash] 🎨 Building splash screen...');
    return Scaffold(
      backgroundColor: Colors.black, // Black background matching TCS brand
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Calculate opacity based on controller progress
            // 0.0 - 0.25: fade in (0 -> 1)
            // 0.25 - 0.75: stay at 1
            // 0.75 - 1.0: fade out (1 -> 0)
            double opacity;
            final progress = _controller.value;

            if (progress < 0.25) {
              // Fade in phase
              opacity = progress / 0.25;
            } else if (progress < 0.75) {
              // Hold phase
              opacity = 1.0;
            } else {
              // Fade out phase
              opacity = 1.0 - ((progress - 0.75) / 0.25);
            }

            // Debug every 0.1 progress
            if ((progress * 10).round() % 2 == 0) {
              debugPrint('[AnimatedSplash] 📊 Progress: ${progress.toStringAsFixed(2)}, Opacity: ${opacity.toStringAsFixed(2)}, Scale: ${_scaleAnimation.value.toStringAsFixed(2)}');
            }

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Image.asset(
                  'assets/splash/tcs_logo_splash.png',
                  width: 262,  // 25% larger than original
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
