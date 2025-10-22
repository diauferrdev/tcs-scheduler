import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bug_report.dart' as model;
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/device_info_helper.dart';

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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.primaryBlack,
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
                color: AppTheme.primaryWhite.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryWhite),
              title: const Text('Choose from Gallery', style: TextStyle(color: AppTheme.primaryWhite)),
              subtitle: Text(
                'Images and videos',
                style: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.6)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: AppTheme.primaryWhite),
              title: const Text('Record Video', style: TextStyle(color: AppTheme.primaryWhite)),
              subtitle: Text(
                'Up to 300MB',
                style: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.6)),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppTheme.primaryWhite),
              title: const Text('Choose File', style: TextStyle(color: AppTheme.primaryWhite)),
              subtitle: Text(
                'Images, videos, documents',
                style: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.6)),
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
        setState(() {
          _attachments.add(AttachmentFile(
            name: image.name,
            path: image.path,
            bytes: bytes,
            type: 'image/${image.path.split('.').last}',
          ));
        });
      }
    } catch (e) {
      debugPrint('[CreateBugReport] Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video must be less than 300MB')),
          );
          return;
        }

        setState(() {
          _attachments.add(AttachmentFile(
            name: video.name,
            path: video.path,
            bytes: bytes,
            type: 'video/${video.path.split('.').last}',
          ));
        });
      }
    } catch (e) {
      debugPrint('[CreateBugReport] Error picking video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking video: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    if (_attachments.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 attachments allowed')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();

        // Check file size limits
        final isVideo = ['mp4', 'mov', 'avi'].contains(file.extension?.toLowerCase());
        final maxSize = isVideo ? 300 * 1024 * 1024 : 30 * 1024 * 1024;

        if (bytes.length > maxSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File must be less than ${isVideo ? "300MB" : "30MB"}')),
          );
          return;
        }

        setState(() {
          _attachments.add(AttachmentFile(
            name: file.name,
            path: file.path ?? '',
            bytes: bytes,
            type: _getFileType(file.extension ?? ''),
          ));
        });
      }
    } catch (e) {
      debugPrint('[CreateBugReport] Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  String _getFileType(String extension) {
    final ext = extension.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return 'image/$ext';
    } else if (['mp4', 'mov', 'avi'].contains(ext)) {
      return 'video/$ext';
    }
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
      // Upload attachments first
      final attachmentUrls = <String>[];
      for (final attachment in _attachments) {
        try {
          final response = await _api.uploadBugAttachment(
            attachment.bytes,
            attachment.name,
            attachment.type,
          );
          attachmentUrls.add(response['url']);
        } catch (e) {
          debugPrint('[CreateBugReport] Error uploading attachment: $e');
          throw Exception('Failed to upload ${attachment.name}');
        }
      }

      // Create bug report
      await _api.createBugReport(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        platform: _selectedPlatform!.name,
        deviceInfo: _deviceInfo,
        attachments: attachmentUrls.isNotEmpty ? attachmentUrls : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bug report submitted successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Report Bug',
          style: TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isAutoDetectingPlatform
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryWhite),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: AppTheme.primaryWhite),
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      labelStyle: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.7)),
                      hintText: 'Brief description of the bug',
                      hintStyle: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.5)),
                      filled: true,
                      fillColor: AppTheme.primaryWhite.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryWhite.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryWhite.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryWhite),
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
                    style: const TextStyle(color: AppTheme.primaryWhite),
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      labelStyle: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.7)),
                      hintText: 'Detailed description of the bug...\n\nSteps to reproduce:\n1. ...\n2. ...',
                      hintStyle: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.5)),
                      filled: true,
                      fillColor: AppTheme.primaryWhite.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryWhite.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primaryWhite.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryWhite),
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
                      color: AppTheme.primaryWhite.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryWhite.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Platform *',
                              style: TextStyle(
                                color: AppTheme.primaryWhite.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
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
                              backgroundColor: AppTheme.primaryWhite.withOpacity(0.1),
                              selectedColor: AppTheme.primaryWhite.withOpacity(0.3),
                              labelStyle: TextStyle(
                                color: AppTheme.primaryWhite,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryWhite : Colors.transparent,
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
                      color: AppTheme.primaryWhite.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryWhite.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Attachments',
                              style: TextStyle(
                                color: AppTheme.primaryWhite.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_attachments.length}/6 files',
                              style: TextStyle(
                                color: AppTheme.primaryWhite.withOpacity(0.6),
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
                            color: AppTheme.primaryWhite.withOpacity(0.5),
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
                            foregroundColor: AppTheme.primaryWhite,
                            side: BorderSide(color: AppTheme.primaryWhite.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),

                        // Attachment List
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ...List.generate(_attachments.length, (index) {
                            final attachment = _attachments[index];
                            return _buildAttachmentTile(attachment, index);
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
                      backgroundColor: AppTheme.primaryWhite,
                      foregroundColor: AppTheme.primaryBlack,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryBlack,
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
                        color: Colors.red.withOpacity(0.1),
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

  Widget _buildAttachmentTile(AttachmentFile attachment, int index) {
    final isVideo = attachment.type.startsWith('video/');
    final size = _formatBytes(attachment.bytes.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isVideo ? Icons.videocam : Icons.image,
            color: AppTheme.primaryWhite,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  style: const TextStyle(color: AppTheme.primaryWhite),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  size,
                  style: TextStyle(
                    color: AppTheme.primaryWhite.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
            onPressed: () => _removeAttachment(index),
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
