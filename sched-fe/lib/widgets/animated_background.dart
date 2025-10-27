import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _BackgroundPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double animation;

  _BackgroundPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0A0A),
    );

    // Animated grid lines
    final gridSpacing = 100.0;
    final offset = animation * gridSpacing;

    paint.color = Colors.white.withOpacity(0.02);

    // Vertical lines
    for (double x = -gridSpacing + offset; x < size.width + gridSpacing; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (double y = -gridSpacing + offset; y < size.height + gridSpacing; y += gridSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Floating particles
    paint.style = PaintingStyle.fill;
    final random = math.Random(42); // Fixed seed for consistent positions

    for (int i = 0; i < 30; i++) {
      final x = size.width * random.nextDouble();
      final baseY = size.height * random.nextDouble();
      final floatOffset = math.sin(animation * 2 * math.pi + i) * 20;
      final y = baseY + floatOffset;

      final particleSize = 2.0 + random.nextDouble() * 2;
      paint.color = Colors.white.withOpacity(0.1);

      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) => true;
}
