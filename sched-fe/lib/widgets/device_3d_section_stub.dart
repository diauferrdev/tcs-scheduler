import 'package:flutter/material.dart';

/// Stub implementation of Device3DSection for non-web platforms
/// This widget is not used on mobile as the landing page is web-only
class Device3DSection extends StatelessWidget {
  final int? index;
  final String? deviceType;
  final String? animation;
  final bool? deviceOnLeft;
  final String? title;
  final String? description;
  final String? badge;
  final bool? isHero;

  const Device3DSection({
    super.key,
    this.index,
    this.deviceType,
    this.animation,
    this.deviceOnLeft,
    this.title,
    this.description,
    this.badge,
    this.isHero,
  });

  @override
  Widget build(BuildContext context) {
    // Return empty container as this is never used on mobile
    // Landing page is web-only
    return const SizedBox.shrink();
  }
}
