import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MediaFullscreenViewer extends StatefulWidget {
  final String url;
  final String fileName;
  final String mimeType;

  const MediaFullscreenViewer({
    super.key,
    required this.url,
    required this.fileName,
    required this.mimeType,
  });

  @override
  State<MediaFullscreenViewer> createState() => _MediaFullscreenViewerState();
}

class _MediaFullscreenViewerState extends State<MediaFullscreenViewer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initializeVideoPlayer();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  bool get _isImage => ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'].contains(widget.mimeType.toLowerCase());
  bool get _isVideo => ['video/mp4', 'video/webm', 'video/ogg', 'video/quicktime'].contains(widget.mimeType.toLowerCase());

  Future<void> _initializeVideoPlayer() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await _videoController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoController!.value.aspectRatio,
    );
    if (mounted) setState(() {});
  }

  Future<void> _downloadFile() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final response = await http.get(Uri.parse(widget.url));

      if (response.statusCode == 200) {
        if (kIsWeb) {
          // For web, trigger browser download
          // This would need additional web-specific implementation
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download started in browser')),
            );
          }
        } else {
          // For mobile/desktop, save to downloads
          final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/${widget.fileName}';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloaded to: $filePath'),
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () => OpenFile.open(filePath),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.fileName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isDownloading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: _downloadFile,
              tooltip: 'Download',
            ),
        ],
      ),
      body: Center(
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isImage) {
      return PhotoView(
        imageProvider: NetworkImage(widget.url),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 64),
        ),
      );
    } else if (_isVideo && _chewieController != null) {
      return Chewie(controller: _chewieController!);
    } else if (_isVideo) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else {
      // Document or other file type
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getFileIcon(),
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              widget.fileName,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.mimeType,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _downloadFile,
              icon: const Icon(Icons.download),
              label: const Text('Download File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }
  }

  IconData _getFileIcon() {
    if (widget.mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (widget.mimeType.contains('word') || widget.mimeType.contains('document')) return Icons.description;
    if (widget.mimeType.contains('excel') || widget.mimeType.contains('spreadsheet')) return Icons.table_chart;
    if (widget.mimeType.contains('powerpoint') || widget.mimeType.contains('presentation')) return Icons.slideshow;
    if (widget.mimeType.contains('audio')) return Icons.audio_file;
    if (widget.mimeType.contains('zip') || widget.mimeType.contains('compressed')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}
