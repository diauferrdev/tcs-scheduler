import 'package:flutter/material.dart';

/// Utility class for file type detection and icons
class FileUtils {
  /// Check if a file path/url is an image
  static bool isImage(String path) {
    final extension = path.toLowerCase().split('.').last.split('?').first;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  /// Check if a file path/url is a PDF
  static bool isPdf(String path) {
    final extension = path.toLowerCase().split('.').last.split('?').first;
    return extension == 'pdf';
  }

  /// Check if a file path/url is a Word document
  static bool isWordDocument(String path) {
    final extension = path.toLowerCase().split('.').last.split('?').first;
    return ['doc', 'docx'].contains(extension);
  }

  /// Check if a file path/url is an Excel spreadsheet
  static bool isExcelDocument(String path) {
    final extension = path.toLowerCase().split('.').last.split('?').first;
    return ['xls', 'xlsx', 'csv'].contains(extension);
  }

  /// Get appropriate icon for a file based on its extension
  static IconData getFileIcon(String path) {
    if (isImage(path)) {
      return Icons.image;
    } else if (isPdf(path)) {
      return Icons.picture_as_pdf;
    } else if (isWordDocument(path)) {
      return Icons.description;
    } else if (isExcelDocument(path)) {
      return Icons.table_chart;
    } else {
      return Icons.insert_drive_file;
    }
  }

  /// Get appropriate color for a file based on its extension
  static Color getFileIconColor(String path) {
    if (isImage(path)) {
      return Colors.purple;
    } else if (isPdf(path)) {
      return Colors.red;
    } else if (isWordDocument(path)) {
      return Colors.blue;
    } else if (isExcelDocument(path)) {
      return Colors.green;
    } else {
      return Colors.grey;
    }
  }

  /// Get file extension from path
  static String getExtension(String path) {
    return path.toLowerCase().split('.').last.split('?').first;
  }

  /// Get file name from path
  static String getFileName(String path) {
    return path.split('/').last.split('?').first;
  }

  /// Format file size in bytes to human readable string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get MIME type from file extension
  static String getMimeType(String path) {
    final extension = getExtension(path);

    switch (extension) {
      // Images
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';

      // Documents
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';

      default:
        return 'application/octet-stream';
    }
  }
}
