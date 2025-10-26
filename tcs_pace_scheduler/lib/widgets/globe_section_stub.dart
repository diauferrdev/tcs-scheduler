import 'package:flutter/material.dart';

/// Stub implementation of GlobeSection for non-web platforms
/// This widget is not used on mobile as the landing page is web-only
class GlobeSection extends StatelessWidget {
  final bool? showAtmosphere;
  final bool? enableRotation;

  const GlobeSection({
    super.key,
    this.showAtmosphere,
    this.enableRotation,
  });

  @override
  Widget build(BuildContext context) {
    // Return empty container as this is never used on mobile
    // Landing page is web-only
    return const SizedBox.shrink();
  }
}
