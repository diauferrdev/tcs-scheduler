import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
import '../widgets/svgator_splash_widget.dart';

/// Animated Splash Screen with SVGator animation
/// Features embedded SVGator player with sound effect
/// Duration: 11.2 seconds
/// Background: White with cover-fit animation
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

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> {
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  bool _navigated = false;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Sound disabled
    // _playSound();

    // Navigate after 11.2 seconds
    _navTimer = Timer(const Duration(milliseconds: 11200), () {
      if (!_navigated && mounted) {
        _navigated = true;
        widget.onAnimationComplete?.call();

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
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
    _navTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: const Center(
        child: Untitled(
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
