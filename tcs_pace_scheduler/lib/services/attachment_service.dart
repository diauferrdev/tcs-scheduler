import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'token_storage.dart';

/// Service for uploading and managing booking attachments
class AttachmentService {
  static final AttachmentService _instance = AttachmentService._internal();
  factory AttachmentService() => _instance;
  AttachmentService._internal();

  final TokenStorage _tokenStorage = TokenStorage();
  String? _sessionCookie;
  bool _initialized = false;

  /// Initialize and load session cookie
  Future<void> initialize() async {
    if (_initialized) return;

    final savedCookie = await _tokenStorage.readSessionCookie();
    if (savedCookie != null) {
      _sessionCookie = savedCookie;
    }
    _initialized = true;
  }

  /// Upload a single attachment (image or document)
  /// Returns the URL of the uploaded file
  Future<Map<String, dynamic>> uploadAttachment(File file) async {
    await initialize();

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/attachment');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        ...ApiConfig.defaultHeaders,
        if (_sessionCookie != null) 'Cookie': _sessionCookie!,
      });
      request.headers.remove('Content-Type'); // Let http set it with boundary

      // Add file
      final fileName = file.path.split('/').last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ),
      );

      debugPrint('[AttachmentService] Uploading file: $fileName');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[AttachmentService] Upload successful: ${result['url']}');
        return result;
      } else {
        final error = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'error': 'Upload failed'};
        throw AttachmentUploadException(
          error['error']?.toString() ?? 'Upload failed',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[AttachmentService] Upload error: $e');
      rethrow;
    }
  }

  /// Upload multiple attachments (up to 6)
  /// Returns a list of uploaded file info
  Future<List<Map<String, dynamic>>> uploadMultipleAttachments(
    List<File> files,
  ) async {
    await initialize();

    if (files.isEmpty) {
      throw AttachmentUploadException('No files provided', 400);
    }

    if (files.length > 6) {
      throw AttachmentUploadException('Maximum 6 files allowed', 400);
    }

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/attachments');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        ...ApiConfig.defaultHeaders,
        if (_sessionCookie != null) 'Cookie': _sessionCookie!,
      });
      request.headers.remove('Content-Type'); // Let http set it with boundary

      // Add all files
      for (final file in files) {
        final fileName = file.path.split('/').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path,
            filename: fileName,
          ),
        );
      }

      debugPrint('[AttachmentService] Uploading ${files.length} files');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final filesList = result['files'] as List<dynamic>;
        debugPrint('[AttachmentService] Upload successful: ${filesList.length} files');
        return filesList.cast<Map<String, dynamic>>();
      } else {
        final error = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'error': 'Upload failed'};
        throw AttachmentUploadException(
          error['error']?.toString() ?? 'Upload failed',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[AttachmentService] Upload error: $e');
      rethrow;
    }
  }

  /// Upload avatar image
  /// Returns the URL of the uploaded avatar
  Future<String> uploadAvatar(File file) async {
    await initialize();

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/avatar');
      final request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        ...ApiConfig.defaultHeaders,
        if (_sessionCookie != null) 'Cookie': _sessionCookie!,
      });
      request.headers.remove('Content-Type'); // Let http set it with boundary

      // Add file
      final fileName = file.path.split('/').last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ),
      );

      debugPrint('[AttachmentService] Uploading avatar: $fileName');

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[AttachmentService] Avatar upload successful: ${result['url']}');
        return result['url'] as String;
      } else {
        final error = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'error': 'Upload failed'};
        throw AttachmentUploadException(
          error['error']?.toString() ?? 'Upload failed',
          response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('[AttachmentService] Avatar upload error: $e');
      rethrow;
    }
  }

  /// Get full URL for an attachment path
  String getAttachmentUrl(String path) {
    if (path.startsWith('http')) {
      return path;
    }
    return '${ApiConfig.baseUrl}$path';
  }
}

class AttachmentUploadException implements Exception {
  final String message;
  final int statusCode;

  AttachmentUploadException(this.message, this.statusCode);

  @override
  String toString() => message;
}
