import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:photo_view/photo_view.dart';
import 'package:http/http.dart' as http;
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_io.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'fullscreen_audio_player.dart';

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
    debugPrint('[MediaViewer] URL: ${widget.url}');
    debugPrint('[MediaViewer] FileName: ${widget.fileName}');
    debugPrint('[MediaViewer] MimeType: ${widget.mimeType}');
    debugPrint('[MediaViewer] isImage: $_isImage, isVideo: $_isVideo, isAudio: $_isAudio, isPdf: $_isPdf');

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
  bool get _isAudio => ['audio/mpeg', 'audio/mp3', 'audio/mp4', 'audio/m4a', 'audio/wav', 'audio/ogg', 'audio/aac'].contains(widget.mimeType.toLowerCase()) ||
                       ['mp3', 'm4a', 'wav', 'ogg', 'aac'].any((ext) => widget.fileName.toLowerCase().endsWith('.$ext'));
  bool get _isPdf => widget.mimeType.toLowerCase() == 'application/pdf' ||
                     widget.mimeType.toLowerCase().contains('pdf') ||
                     widget.fileName.toLowerCase().endsWith('.pdf');

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
        // Use platform-specific download
        await downloadFile(widget.url, widget.fileName, response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: ${widget.fileName}'),
              backgroundColor: const Color(0xFF2563EB),
              duration: const Duration(seconds: 2),
            ),
          );
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
    } else if (_isAudio) {
      // Audio player with waveform - centered and properly styled
      return Container(
        color: Colors.black,
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: FullscreenAudioPlayer(
              audioUrl: widget.url,
              fileName: widget.fileName,
            ),
          ),
        ),
      );
    } else if (_isPdf) {
      // PDF viewer using Syncfusion (100% local, no external APIs)
      return SfPdfViewer.network(
        widget.url,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
        enableTextSelection: true,
        headers: {
          'Accept': 'application/pdf',
        },
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          debugPrint('[PDF] ❌ Load failed!');
          debugPrint('[PDF] Error: ${details.error}');
          debugPrint('[PDF] Description: ${details.description}');
          debugPrint('[PDF] URL: ${widget.url}');

          // Show error to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load PDF: ${details.description}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        },
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          debugPrint('[PDF] ✅ Document loaded successfully!');
          debugPrint('[PDF] Pages: ${details.document.pages.count}');
        },
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
