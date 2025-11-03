import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/bug_report.dart' as model;
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/device_info_helper.dart';
import 'bug_detail_screen.dart';

class CreateBugReportScreen extends StatefulWidget {
  const CreateBugReportScreen({super.key});

  @override
  State<CreateBugReportScreen> createState() => _CreateBugReportScreenState();
}

class _CreateBugReportScreenState extends State<CreateBugReportScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  model.Platform? _selectedPlatform;
  Map<String, dynamic>? _deviceInfo;
  bool _isAutoDetectingPlatform = true;
  bool _isLoading = false;
  String? _errorMessage;

  final List<AttachmentFile> _attachments = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _autoDetectPlatform();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _autoDetectPlatform() async {
    try {
      _deviceInfo = await DeviceInfoHelper.getDeviceInfo();
      final platformName = _deviceInfo!['platform'] as String;
      setState(() {
        _selectedPlatform = model.Platform.values.firstWhere(
          (p) => p.name == platformName,
          orElse: () => model.Platform.WEB,
        );
        _isAutoDetectingPlatform = false;
      });
    } catch (e) {
      debugPrint('[CreateBugReport] Error auto-detecting platform: $e');
      setState(() {
        _selectedPlatform = model.Platform.WEB;
        _isAutoDetectingPlatform = false;
      });
    }
  }

  Future<void> _showAttachmentOptions() async {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final backgroundColor = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: textColor),
              title: Text('Choose from Gallery', style: TextStyle(color: textColor)),
              subtitle: Text(
                'Images and videos',
                style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: textColor),
              title: Text('Record Video', style: TextStyle(color: textColor)),
              subtitle: Text(
                'Up to 300MB',
                style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: Icon(Icons.insert_drive_file, color: textColor),
              title: Text('Choose File', style: TextStyle(color: textColor)),
              subtitle: Text(
                'Images, videos, documents',
                style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    if (_attachments.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 attachments allowed')),
      );
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        // Get file extension from name instead of path (works on web and native)
        final extension = image.name.split('.').last.toLowerCase();
        final mimeType = 'image/$extension';

        setState(() {
          _attachments.add(AttachmentFile(
            name: image.name,
            path: kIsWeb ? '' : image.path, // path only available on native platforms
            bytes: bytes,
            type: mimeType,
          ));
        });
      }
    } catch (e) {
      debugPrint('[CreateBugReport] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_attachments.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 attachments allowed')),
      );
      return;
    }

    try {
      final XFile? video = await _imagePicker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        final bytes = await video.readAsBytes();

        // Check file size (max 300MB)
        if (bytes.length > 300 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video must be less than 300MB')),
            );
          }
          return;
        }

        // Get file extension from name instead of path (works on web and native)
        final extension = video.name.split('.').last.toLowerCase();
        final mimeType = 'video/$extension';

        setState(() {
          _attachments.add(AttachmentFile(
            name: video.name,
            path: kIsWeb ? '' : video.path, // path only available on native platforms
            bytes: bytes,
            type: mimeType,
          ));
        });
      }
    } catch (e) {
      debugPrint('[CreateBugReport] Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    if (_attachments.length >= 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 6 attachments allowed')),
        );
      }
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi', 'pdf', 'doc', 'docx'],
        allowMultiple: false,
        withData: true, // Important - loads file as bytes on all platforms
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // With withData: true, bytes should always be available
        if (file.bytes == null) {
          throw Exception('File bytes not available. Please try again.');
        }

        final bytes = file.bytes!;

        // Check file size limits
        final isVideo = ['mp4', 'mov', 'avi'].contains(file.extension?.toLowerCase());
        final maxSize = isVideo ? 300 * 1024 * 1024 : 30 * 1024 * 1024;

        if (bytes.length > maxSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('File must be less than ${isVideo ? "300MB" : "30MB"}')),
            );
          }
          return;
        }

        // Get file extension from file.extension or extract from file.name
        String extension = file.extension ?? '';
        if (extension.isEmpty && file.name.contains('.')) {
          extension = file.name.split('.').last;
        }

        setState(() {
          _attachments.add(AttachmentFile(
            name: file.name,
            path: kIsWeb ? '' : (file.path ?? ''), // Don't access path on web - it throws an error
            bytes: bytes,
            type: _getFileType(extension),
          ));
        });
      }
    } catch (e) {
      debugPrint('[CreateBugReport] Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: ${e.toString()}')),
        );
      }
    }
  }

  String _getFileType(String extension) {
    final ext = extension.toLowerCase();

    // Image types
    if (['jpg', 'jpeg'].contains(ext)) return 'image/jpeg';
    if (ext == 'png') return 'image/png';
    if (ext == 'gif') return 'image/gif';
    if (ext == 'webp') return 'image/webp';
    if (ext == 'svg') return 'image/svg+xml';

    // Video types
    if (ext == 'mp4') return 'video/mp4';
    if (ext == 'mov') return 'video/quicktime';
    if (ext == 'avi') return 'video/x-msvideo';
    if (ext == 'webm') return 'video/webm';

    // Document types
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'doc') return 'application/msword';
    if (ext == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (ext == 'txt') return 'text/plain';
    if (ext == 'csv') return 'text/csv';

    return 'application/octet-stream';
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submitBugReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlatform == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a platform')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Upload attachments first and collect metadata
      final attachmentData = <Map<String, dynamic>>[];
      for (final attachment in _attachments) {
        try {
          final response = await _api.uploadBugAttachment(
            attachment.bytes,
            attachment.name,
            attachment.type,
          );
          // Send full metadata instead of just URL
          attachmentData.add({
            'url': response['url'],
            'fileName': response['filename'] ?? attachment.name,
            'fileSize': response['size'] ?? attachment.bytes.length,
            'fileType': response['type'] ?? attachment.type,
          });
        } catch (e) {
          debugPrint('[CreateBugReport] Error uploading attachment: $e');
          throw Exception('Failed to upload ${attachment.name}');
        }
      }

      // Create bug report with attachment metadata
      final createdBug = await _api.createBugReport(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        platform: _selectedPlatform!.name,
        deviceInfo: _deviceInfo,
        attachments: attachmentData.isNotEmpty ? attachmentData : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bug report submitted successfully')),
        );
        // Navigate to bug detail screen instead of going back to list
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BugDetailScreen(bugId: createdBug['id']),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Report Bug',
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isAutoDetectingPlatform
          ? Center(
              child: CircularProgressIndicator(color: textColor),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                      hintText: 'Brief description of the bug',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: textColor),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Title is required';
                      }
                      if (value.trim().length < 5) {
                        return 'Title must be at least 5 characters';
                      }
                      if (value.trim().length > 200) {
                        return 'Title must be less than 200 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: textColor),
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                      hintText: 'Detailed description of the bug...\n\nSteps to reproduce:\n1. ...\n2. ...',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: textColor),
                      ),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Description is required';
                      }
                      if (value.trim().length < 10) {
                        return 'Description must be at least 10 characters';
                      }
                      if (value.trim().length > 5000) {
                        return 'Description must be less than 5000 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Platform Selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Platform *',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green),
                              ),
                              child: const Text(
                                'Auto-detected',
                                style: TextStyle(color: Colors.green, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: model.Platform.values.map((platform) {
                            final isSelected = _selectedPlatform == platform;
                            return ChoiceChip(
                              label: Text(_getPlatformLabel(platform)),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() => _selectedPlatform = platform);
                              },
                              backgroundColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                              selectedColor: Colors.green.withValues(alpha: 0.15),
                              checkmarkColor: Colors.green,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.green : textColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected ? Colors.green : (isDark ? const Color(0xFF52525B) : const Color(0xFFD1D5DB)),
                                width: isSelected ? 2 : 1,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Attachments Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Attachments',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_attachments.length}/6 files',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Supported: Images, Videos, Documents\nMax size: 30MB per image, 300MB per video',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Single Add Attachment Button
                        OutlinedButton.icon(
                          onPressed: _attachments.length < 6 ? _showAttachmentOptions : null,
                          icon: const Icon(Icons.attach_file),
                          label: Text(_attachments.isEmpty ? 'Add Attachment' : 'Add Another'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textColor,
                            side: BorderSide(color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),

                        // Attachment List
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ..._attachments.asMap().entries.map((entry) {
                            return _buildAttachmentTile(entry.value, entry.key, isDark, textColor);
                          }),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitBugReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: isDark ? Colors.black : Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit Bug Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildAttachmentTile(AttachmentFile attachment, int index, bool isDark, Color textColor) {
    final isImage = attachment.type.startsWith('image/');
    final isVideo = attachment.type.startsWith('video/');
    final size = _formatBytes(attachment.bytes.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF52525B) : const Color(0xFFD1D5DB),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail/Icon
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                attachment.bytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 56,
                  height: 56,
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                  child: Icon(Icons.broken_image, color: textColor, size: 24),
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (isVideo ? Colors.red : Colors.orange).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isVideo ? Icons.videocam : Icons.insert_drive_file,
                color: isVideo ? Colors.red : Colors.orange,
                size: 28,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isImage ? Colors.blue : isVideo ? Colors.red : Colors.orange).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isImage ? 'IMAGE' : isVideo ? 'VIDEO' : 'DOC',
                        style: TextStyle(
                          color: isImage ? Colors.blue : isVideo ? Colors.red : Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      size,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
            onPressed: () => _removeAttachment(index),
            tooltip: 'Remove attachment',
          ),
        ],
      ),
    );
  }

  String _getPlatformLabel(model.Platform platform) {
    switch (platform) {
      case model.Platform.WINDOWS:
        return 'Windows';
      case model.Platform.LINUX:
        return 'Linux';
      case model.Platform.MACOS:
        return 'macOS';
      case model.Platform.ANDROID:
        return 'Android';
      case model.Platform.IOS:
        return 'iOS';
      case model.Platform.WEB:
        return 'Web';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class AttachmentFile {
  final String name;
  final String path;
  final Uint8List bytes;
  final String type;

  AttachmentFile({
    required this.name,
    required this.path,
    required this.bytes,
    required this.type,
  });
}
