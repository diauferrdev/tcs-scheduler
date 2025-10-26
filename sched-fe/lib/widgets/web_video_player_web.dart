// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

/// Web implementation using HTML5 video element
Widget createWebVideoPlayer(String videoUrl) {
  return _WebVideoPlayer(videoUrl: videoUrl);
}

class _WebVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _WebVideoPlayer({required this.videoUrl});

  @override
  State<_WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<_WebVideoPlayer> {
  final String _viewId = 'video-${DateTime.now().millisecondsSinceEpoch}';
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  void _registerView() {
    if (_registered) return;

    // Register the video element view factory
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final videoElement = html.VideoElement()
          ..src = widget.videoUrl
          ..controls = true
          ..autoplay = false
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'contain'
          ..style.backgroundColor = '#000000';

        // Add error handling
        videoElement.onError.listen((event) {
          print('[WebVideoPlayer] Error loading video');
        });

        return videoElement;
      },
    );

    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: HtmlElementView(
          viewType: _viewId,
        ),
      ),
    );
  }
}
