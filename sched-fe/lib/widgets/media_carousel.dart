import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../models/bug_report.dart';
import '../providers/theme_provider.dart';
import '../utils/url_helper.dart';
import 'media_viewer_dialog.dart';

class MediaCarousel extends StatefulWidget {
  final List<BugAttachment> mediaAttachments; // images + videos
  final bool isDark;

  const MediaCarousel({
    super.key,
    required this.mediaAttachments,
    this.isDark = true,
  });

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.mediaAttachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMultiple = widget.mediaAttachments.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Carousel
        Stack(
          children: [
            CarouselSlider.builder(
              itemCount: widget.mediaAttachments.length,
              options: CarouselOptions(
                height: 250,
                viewportFraction: 1.0,
                enableInfiniteScroll: false,
                enlargeCenterPage: false,
                onPageChanged: (index, reason) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
              itemBuilder: (context, index, realIndex) {
                final attachment = widget.mediaAttachments[index];
                final isVideo = attachment.fileType.startsWith('video/');

                return GestureDetector(
                  onTap: () => MediaViewerDialog.show(
                    context,
                    mediaUrl: getAbsoluteUrl(attachment.fileUrl),
                    fileName: attachment.fileName,
                    fileType: attachment.fileType,
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppTheme.primaryWhite.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isDark
                            ? AppTheme.primaryWhite.withValues(alpha: 0.1)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isVideo
                          ? _buildVideoThumbnail(attachment)
                          : _buildImageThumbnail(attachment),
                    ),
                  ),
                );
              },
            ),

            // Media type badge (top-left)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.mediaAttachments[_currentIndex].fileType
                              .startsWith('video/')
                          ? Icons.play_circle_filled
                          : Icons.image,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.mediaAttachments[_currentIndex].fileType
                              .startsWith('video/')
                          ? 'VIDEO'
                          : 'IMAGE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Zoom icon (top-right)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.zoom_in,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),

            // Navigation arrows (if multiple)
            if (hasMultiple && _currentIndex > 0)
              Positioned(
                left: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = (_currentIndex - 1)
                            .clamp(0, widget.mediaAttachments.length - 1);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

            if (hasMultiple &&
                _currentIndex < widget.mediaAttachments.length - 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = (_currentIndex + 1)
                            .clamp(0, widget.mediaAttachments.length - 1);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        if (hasMultiple) ...[
          const SizedBox(height: 12),
          // Indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.mediaAttachments.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? (widget.isDark
                          ? AppTheme.primaryWhite
                          : Colors.black87)
                      : (widget.isDark
                          ? AppTheme.primaryWhite.withValues(alpha: 0.3)
                          : Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 8),

        // Current media info
        Row(
          children: [
            Expanded(
              child: Text(
                widget.mediaAttachments[_currentIndex].fileName,
                style: TextStyle(
                  color: widget.isDark
                      ? AppTheme.primaryWhite.withValues(alpha: 0.8)
                      : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (hasMultiple)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppTheme.primaryWhite.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_currentIndex + 1}/${widget.mediaAttachments.length}',
                  style: TextStyle(
                    color: widget.isDark
                        ? AppTheme.primaryWhite.withValues(alpha: 0.7)
                        : Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(BugAttachment attachment) {
    return CachedNetworkImage(
      imageUrl: getAbsoluteUrl(attachment.fileUrl),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: widget.isDark ? AppTheme.primaryWhite : Colors.black87,
        ),
      ),
      errorWidget: (context, url, error) => Center(
        child: Icon(
          Icons.broken_image,
          color: widget.isDark ? AppTheme.primaryWhite : Colors.grey.shade600,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(BugAttachment attachment) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video background placeholder
        Container(
          color: Colors.black87,
          child: Center(
            child: Icon(
              Icons.videocam,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
        // Play button overlay
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
        // File name at bottom
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              attachment.fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
