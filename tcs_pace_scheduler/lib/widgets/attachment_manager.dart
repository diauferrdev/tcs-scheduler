import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/file_utils.dart';
import '../utils/document_opener.dart';
import '../screens/image_viewer_screen.dart';
import 'attachment_picker.dart';

/// Widget for managing attachments in booking form
/// Displays grid of attachments with add/remove functionality
class AttachmentManager extends StatefulWidget {
  final List<String> attachmentUrls;
  final List<File> localFiles;
  final Function(List<File> files) onFilesAdded;
  final Function(int index, bool isUrl) onFileRemoved;
  final Function() onClearAll;
  final int maxFiles;
  final bool readOnly;

  const AttachmentManager({
    super.key,
    required this.attachmentUrls,
    required this.localFiles,
    required this.onFilesAdded,
    required this.onFileRemoved,
    required this.onClearAll,
    this.maxFiles = 6,
    this.readOnly = false,
  });

  @override
  State<AttachmentManager> createState() => _AttachmentManagerState();
}

class _AttachmentManagerState extends State<AttachmentManager> {
  int get totalFiles => widget.attachmentUrls.length + widget.localFiles.length;
  bool get canAddMore => !widget.readOnly && totalFiles < widget.maxFiles;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and actions
        Row(
          children: [
            Text(
              'Attachments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            if (totalFiles > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalFiles / ${widget.maxFiles}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            const Spacer(),
            if (totalFiles > 0 && !widget.readOnly)
              TextButton.icon(
                onPressed: _showClearAllDialog,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid of attachments
        if (totalFiles > 0) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: totalFiles + (canAddMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == totalFiles && canAddMore) {
                return _buildAddButton(isDark);
              }

              // Determine if this is a URL or local file
              final isUrl = index < widget.attachmentUrls.length;
              if (isUrl) {
                final url = widget.attachmentUrls[index];
                return _buildAttachmentTile(url, index, true, isDark);
              } else {
                final fileIndex = index - widget.attachmentUrls.length;
                final file = widget.localFiles[fileIndex];
                return _buildLocalFileTile(file, fileIndex, isDark);
              }
            },
          ),
        ] else if (!widget.readOnly) ...[
          // Empty state with add button
          InkWell(
            onTap: _showAttachmentPicker,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                  style: BorderStyle.solid,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add Photos or Documents',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Up to ${widget.maxFiles} files',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAddButton(bool isDark) {
    return InkWell(
      onTap: _showAttachmentPicker,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add,
              size: 32,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 4),
            Text(
              'Add More',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentTile(String url, int index, bool isUrl, bool isDark) {
    final isImage = FileUtils.isImage(url);

    return Stack(
      children: [
        InkWell(
          onTap: () => _openAttachment(url, isImage),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
              ),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFileIcon(url, isDark);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  )
                : _buildFileIcon(url, isDark),
          ),
        ),
        if (!widget.readOnly)
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => widget.onFileRemoved(index, isUrl),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocalFileTile(File file, int fileIndex, bool isDark) {
    final isImage = FileUtils.isImage(file.path);

    return Stack(
      children: [
        InkWell(
          onTap: () {
            if (isImage) {
              // Show full screen for local image
              _showLocalImageViewer(file);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
              ),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFileIcon(file.path, isDark);
                      },
                    ),
                  )
                : _buildFileIcon(file.path, isDark),
          ),
        ),
        if (!widget.readOnly)
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => widget.onFileRemoved(fileIndex, false),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileIcon(String path, bool isDark) {
    return Center(
      child: Icon(
        FileUtils.getFileIcon(path),
        size: 40,
        color: FileUtils.getFileIconColor(path),
      ),
    );
  }

  void _openAttachment(String url, bool isImage) {
    if (isImage) {
      // Get all image URLs
      final imageUrls = widget.attachmentUrls.where(FileUtils.isImage).toList();
      final initialIndex = imageUrls.indexOf(url);

      ImageViewerScreen.show(
        context,
        imageUrls: imageUrls,
        initialIndex: initialIndex >= 0 ? initialIndex : 0,
      );
    } else {
      // Open document with external app
      DocumentOpener.openDocument(context, url);
    }
  }

  void _showLocalImageViewer(File file) {
    // For local files, we'll just show them in a simple dialog
    // since photo_view works with network images
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: Image.file(file),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentPicker() {
    final remaining = widget.maxFiles - totalFiles;

    AttachmentPicker.show(
      context,
      maxFiles: remaining,
      onFilesPicked: (files) {
        // Limit files to remaining slots
        final filesToAdd = files.take(remaining).toList();
        widget.onFilesAdded(filesToAdd);
      },
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Attachments'),
        content: const Text(
          'Are you sure you want to remove all attachments? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onClearAll();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
