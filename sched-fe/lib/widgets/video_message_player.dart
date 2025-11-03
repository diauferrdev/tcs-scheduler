import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'media_fullscreen_viewer.dart';

class VideoMessagePreview extends StatefulWidget {
  final String videoUrl;
  final String fileName;
  final double width;
  final double height;
  final bool isCurrentUser;

  const VideoMessagePreview({
    super.key,
    required this.videoUrl,
    required this.fileName,
    this.width = 264,
    this.height = 264,
    this.isCurrentUser = true,
  });

  @override
  State<VideoMessagePreview> createState() => _VideoMessagePreviewState();
}

class _VideoMessagePreviewState extends State<VideoMessagePreview> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPreview();
  }

  Future<void> _initializeVideoPreview() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _videoController!.initialize();
      // Seek to first frame to show thumbnail
      await _videoController!.seekTo(Duration.zero);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaFullscreenViewer(
          url: widget.videoUrl,
          fileName: widget.fileName,
          mimeType: 'video/mp4', // Default to mp4, works for most videos
        ),
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFullscreen,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: widget.isCurrentUser ? const Radius.circular(14) : const Radius.circular(0),
          bottomRight: widget.isCurrentUser ? const Radius.circular(0) : const Radius.circular(14),
        ),
        child: Container(
          width: widget.width,
          height: widget.height,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video thumbnail (first frame)
              if (_isInitialized && _videoController != null)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                )
              else if (_hasError)
                const Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 64,
                    color: Colors.grey,
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),

              // Play button overlay
              if (_isInitialized)
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Duration badge
              if (_isInitialized && _videoController != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_videoController!.value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
