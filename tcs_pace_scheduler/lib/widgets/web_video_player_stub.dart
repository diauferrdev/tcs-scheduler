import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

/// Stub implementation for non-web platforms
Widget createWebVideoPlayer(String videoUrl) {
  return const Center(
    child: Text(
      'Video playback not supported on this platform',
      style: TextStyle(color: AppTheme.primaryWhite),
    ),
  );
}
