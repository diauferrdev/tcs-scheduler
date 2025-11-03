import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

// Global storage for web file bytes (path -> bytes)
// This is needed because on web, File objects don't have real filesystem access
final Map<String, Uint8List> _webFileBytes = {};

/// Helper function to read file bytes (handles both web and mobile)
/// On web, checks the global storage first, falls back to File.readAsBytes()
Future<Uint8List> readFileBytes(File file) async {
  if (kIsWeb) {
    // Check if we have bytes stored for this file
    final bytes = _webFileBytes[file.path];
    if (bytes != null) {
      debugPrint('[readFileBytes] ✅ Found ${bytes.length} bytes for ${file.path}');
      return bytes;
    } else {
      debugPrint('[readFileBytes] ❌ No bytes found for ${file.path}');
      debugPrint('[readFileBytes] Available paths: ${_webFileBytes.keys.toList()}');
      throw Exception('File bytes not found in web storage for ${file.path}');
    }
  }
  // Fall back to normal file reading
  return await file.readAsBytes();
}

/// A bottom sheet widget for picking attachments from camera, gallery, or files
/// Works on Web, Mobile (iOS/Android), and Desktop
class AttachmentPicker extends StatelessWidget {
  final Function(List<File> files) onFilesPicked;
  final int maxFiles;
  final bool allowImages;
  final bool allowDocuments;

  const AttachmentPicker({
    super.key,
    required this.onFilesPicked,
    this.maxFiles = 6,
    this.allowImages = true,
    this.allowDocuments = true,
  });

  /// Show the attachment picker bottom sheet
  static Future<void> show(
    BuildContext context, {
    required Function(List<File> files) onFilesPicked,
    int maxFiles = 6,
    bool allowImages = true,
    bool allowDocuments = true,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentPicker(
        onFilesPicked: onFilesPicked,
        maxFiles: maxFiles,
        allowImages: allowImages,
        allowDocuments: allowDocuments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Add Attachments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Select up to $maxFiles items',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Options - Only show camera/gallery on mobile
              if (allowImages && !kIsWeb) ...[
                _buildOption(
                  context,
                  icon: Icons.camera_alt,
                  title: 'Take Photo',
                  subtitle: 'Use camera to take a photo',
                  onTap: () => _pickFromCamera(context),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildOption(
                  context,
                  icon: Icons.photo_library,
                  title: 'Choose from Gallery',
                  subtitle: 'Select photos from gallery',
                  onTap: () => _pickFromGallery(context),
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
              ],

              // File picker - works on all platforms
              if (allowDocuments)
                _buildOption(
                  context,
                  icon: Icons.attach_file,
                  title: 'Choose Files',
                  subtitle: kIsWeb
                      ? 'Select documents or images from your computer'
                      : 'Select documents or images',
                  onTap: () => _pickFiles(context),
                  isDark: isDark,
                ),
              const SizedBox(height: 12),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  /// Camera picker - Mobile only
  Future<void> _pickFromCamera(BuildContext context) async {
    Navigator.pop(context);

    try {
      // Check camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context, 'Camera');
        }
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        onFilesPicked([File(image.path)]);
      }
    } catch (e) {
      debugPrint('[AttachmentPicker] Camera error: $e');
      if (context.mounted) {
        _showErrorDialog(context, 'Failed to take photo: $e');
      }
    }
  }

  /// Gallery picker - Mobile only
  Future<void> _pickFromGallery(BuildContext context) async {
    Navigator.pop(context);

    try {
      // Check photos permission
      final photosStatus = await Permission.photos.request();
      if (!photosStatus.isGranted) {
        if (context.mounted) {
          _showPermissionDeniedDialog(context, 'Photos');
        }
        return;
      }

      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        if (images.length > maxFiles) {
          if (context.mounted) {
            _showErrorDialog(
              context,
              'You can only select up to $maxFiles images',
            );
          }
          return;
        }

        onFilesPicked(images.map((e) => File(e.path)).toList());
      }
    } catch (e) {
      debugPrint('[AttachmentPicker] Gallery error: $e');
      if (context.mounted) {
        _showErrorDialog(context, 'Failed to pick images: $e');
      }
    }
  }

  /// Universal file picker - Works on Web, Mobile, and Desktop
  Future<void> _pickFiles(BuildContext context) async {
    Navigator.pop(context);

    try {
      // Check storage permission on Android only
      if (!kIsWeb && Platform.isAndroid) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          if (context.mounted) {
            _showPermissionDeniedDialog(context, 'Storage');
          }
          return;
        }
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'webp', // Images
          'pdf', // PDF
          'doc', 'docx', // Word
          'xls', 'xlsx', 'csv', // Excel
        ],
        allowMultiple: true,
        withData: kIsWeb, // On web, we MUST use bytes
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      if (result.files.length > maxFiles) {
        if (context.mounted) {
          _showErrorDialog(
            context,
            'You can only select up to $maxFiles files',
          );
        }
        return;
      }

      // Process files based on platform
      final files = await _processPickedFiles(result.files);

      if (files.isNotEmpty && context.mounted) {
        onFilesPicked(files);
      }
    } catch (e) {
      debugPrint('[AttachmentPicker] File picker error: $e');
      if (context.mounted) {
        _showErrorDialog(context, 'Failed to pick files: $e');
      }
    }
  }

  /// Convert PlatformFile to File for all platforms
  Future<List<File>> _processPickedFiles(List<PlatformFile> platformFiles) async {
    final List<File> files = [];

    for (final platformFile in platformFiles) {
      try {
        if (kIsWeb) {
          // Web: Create file from bytes
          if (platformFile.bytes != null) {
            final file = await _createFileFromBytes(
              platformFile.bytes!,
              platformFile.name,
            );
            files.add(file);
          }
        } else {
          // Mobile/Desktop: Use path directly
          if (platformFile.path != null) {
            files.add(File(platformFile.path!));
          }
        }
      } catch (e) {
        debugPrint('[AttachmentPicker] Error processing file ${platformFile.name}: $e');
      }
    }

    return files;
  }

  /// Create a File from bytes (for web platform)
  Future<File> _createFileFromBytes(Uint8List bytes, String filename) async {
    // On web, create a virtual file path with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(filename);
    final baseName = path.basenameWithoutExtension(filename);
    final uniqueFilename = '${baseName}_$timestamp$extension';

    // Use a virtual path for web (no actual filesystem)
    final filePath = '/temp/$uniqueFilename';

    // Store bytes in global map for later retrieval
    _webFileBytes[filePath] = bytes;

    // Create file object reference (doesn't write to actual filesystem on web)
    final file = File(filePath);

    debugPrint('[AttachmentPicker] Web file created: $filePath (${bytes.length} bytes)');

    return file;
  }

  void _showPermissionDeniedDialog(BuildContext context, String permission) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Permission Required',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            '$permission permission is required to select files. Please grant permission in Settings.',
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Error',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
