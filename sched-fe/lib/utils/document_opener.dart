import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'file_utils.dart';

/// Utility class for opening documents with external apps
class DocumentOpener {
  /// Open a document from URL with external app
  /// Downloads the file to temp directory and opens it
  static Future<void> openDocument(
    BuildContext context,
    String url, {
    String? fileName,
  }) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Downloading document...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Download file to temporary directory
      final file = await _downloadFile(url, fileName);

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Open file with external app
      final result = await OpenFile.open(file.path);


      // Handle errors
      if (result.type != ResultType.done) {
        if (context.mounted) {
          _showErrorDialog(context, result.message);
        }
      }
    } catch (e) {

      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.pop(context);
        _showErrorDialog(context, 'Failed to open document: $e');
      }
    }
  }

  /// Download file from URL to temporary directory
  static Future<File> _downloadFile(String url, String? fileName) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();

      // Generate file name if not provided
      final name = fileName ?? FileUtils.getFileName(url);
      final filePath = '${tempDir.path}/$name';

      // Download file
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Check if a URL points to an openable document
  static bool isOpenableDocument(String url) {
    return FileUtils.isPdf(url) ||
        FileUtils.isWordDocument(url) ||
        FileUtils.isExcelDocument(url);
  }

  /// Get a preview widget for a document
  static Widget buildDocumentPreview(
    String url,
    BuildContext context, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = FileUtils.getFileIcon(url);
    final color = FileUtils.getFileIconColor(url);
    final fileName = FileUtils.getFileName(url);

    return InkWell(
      onTap: onTap ?? () => openDocument(context, url, fileName: fileName),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              fileName,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to open',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
