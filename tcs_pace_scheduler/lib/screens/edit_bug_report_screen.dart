import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bug_report.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

class EditBugReportScreen extends StatefulWidget {
  final BugReport bug;

  const EditBugReportScreen({super.key, required this.bug});

  @override
  State<EditBugReportScreen> createState() => _EditBugReportScreenState();
}

class _EditBugReportScreenState extends State<EditBugReportScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  String? _errorMessage;
  List<BugAttachment> _existingAttachments = [];
  List<String> _attachmentsToDelete = [];
  List<NewAttachment> _newAttachments = [];

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.bug.title;
    _descriptionController.text = widget.bug.description;
    _existingAttachments = List.from(widget.bug.attachments);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  int get _totalAttachments =>
      _existingAttachments.length - _attachmentsToDelete.length + _newAttachments.length;

  Future<void> _showAttachmentOptions() async {
    if (_totalAttachments >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 attachments allowed')),
      );
      return;
    }

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
    if (_totalAttachments >= 6) return;

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
          _newAttachments.add(NewAttachment(
            name: image.name,
            path: image.path,
            bytes: bytes,
            type: 'image/${image.path.split('.').last}',
          ));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    if (_totalAttachments >= 6) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();

        final isVideo = ['mp4', 'mov', 'avi'].contains(file.extension?.toLowerCase());
        final maxSize = isVideo ? 300 * 1024 * 1024 : 30 * 1024 * 1024;

        if (bytes.length > maxSize) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File must be less than ${isVideo ? "300MB" : "30MB"}')),
          );
          return;
        }

        setState(() {
          _newAttachments.add(NewAttachment(
            name: file.name,
            path: file.path ?? '',
            bytes: bytes,
            type: _getFileType(file.extension ?? ''),
          ));
        });
      }
    } catch (e) {
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

  void _removeExistingAttachment(String attachmentId) {
    setState(() {
      _attachmentsToDelete.add(attachmentId);
    });
  }

  void _removeNewAttachment(int index) {
    setState(() {
      _newAttachments.removeAt(index);
    });
  }

  Future<void> _submitEdit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Upload new attachments first
      final newAttachmentUrls = <String>[];
      for (final attachment in _newAttachments) {
        try {
          final response = await _api.uploadBugAttachment(
            attachment.bytes,
            attachment.name,
            attachment.type,
          );
          newAttachmentUrls.add(response['url']);
        } catch (e) {
          debugPrint('[EditBugReport] Error uploading attachment: $e');
          throw Exception('Failed to upload ${attachment.name}');
        }
      }

      // Prepare update data
      final updateData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      // Add attachments data if there are changes
      if (newAttachmentUrls.isNotEmpty) {
        updateData['attachments'] = newAttachmentUrls;
      }
      if (_attachmentsToDelete.isNotEmpty) {
        updateData['deleteAttachments'] = _attachmentsToDelete;
      }

      await _api.updateBugReport(widget.bug.id, updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bug report updated successfully')),
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
          'Edit Bug Report',
          style: TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can edit title, description, and manage attachments',
                      style: TextStyle(
                        color: AppTheme.primaryWhite.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
              maxLines: 12,
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
                        '$_totalAttachments/6 files',
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
                    'Add or remove attachments\nMax 6 files • Images up to 30MB • Videos up to 300MB',
                    style: TextStyle(
                      color: AppTheme.primaryWhite.withOpacity(0.5),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Add Attachment Button
                  OutlinedButton.icon(
                    onPressed: _totalAttachments < 6 ? _showAttachmentOptions : null,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_totalAttachments == 0 ? 'Add Attachment' : 'Add Another'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryWhite,
                      side: BorderSide(color: AppTheme.primaryWhite.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),

                  // Existing Attachments
                  if (_existingAttachments.where((a) => !_attachmentsToDelete.contains(a.id)).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Current Attachments',
                      style: TextStyle(
                        color: AppTheme.primaryWhite.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_existingAttachments
                        .where((a) => !_attachmentsToDelete.contains(a.id))
                        .map((attachment) => _buildExistingAttachmentTile(attachment))),
                  ],

                  // New Attachments
                  if (_newAttachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'New Attachments',
                      style: TextStyle(
                        color: Colors.green.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_newAttachments.length, (index) {
                      return _buildNewAttachmentTile(_newAttachments[index], index);
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitEdit,
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
                      'Save Changes',
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

  Widget _buildExistingAttachmentTile(BugAttachment attachment) {
    final isImage = attachment.fileType.startsWith('image/');
    final isVideo = attachment.fileType.startsWith('video/');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryWhite.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail/Icon
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                attachment.fileUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 56,
                  height: 56,
                  color: AppTheme.primaryWhite.withOpacity(0.1),
                  child: const Icon(Icons.broken_image, color: AppTheme.primaryWhite, size: 24),
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (isVideo ? Colors.red : Colors.orange).withOpacity(0.2),
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
                  attachment.fileName,
                  style: const TextStyle(
                    color: AppTheme.primaryWhite,
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
                        color: (isImage ? Colors.green : isVideo ? Colors.red : Colors.orange).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        isImage ? 'IMAGE' : isVideo ? 'VIDEO' : 'DOC',
                        style: TextStyle(
                          color: isImage ? Colors.green : isVideo ? Colors.red : Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatBytes(attachment.fileSize),
                      style: TextStyle(
                        color: AppTheme.primaryWhite.withOpacity(0.6),
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
            onPressed: () => _removeExistingAttachment(attachment.id),
            tooltip: 'Remove attachment',
          ),
        ],
      ),
    );
  }

  Widget _buildNewAttachmentTile(NewAttachment attachment, int index) {
    final isImage = attachment.type.startsWith('image/');
    final isVideo = attachment.type.startsWith('video/');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail/Icon for new attachments
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
                  color: Colors.green.withOpacity(0.2),
                  child: const Icon(Icons.broken_image, color: Colors.green, size: 24),
                ),
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (isVideo ? Colors.red : Colors.orange).withOpacity(0.2),
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
                  style: const TextStyle(
                    color: AppTheme.primaryWhite,
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
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isImage ? Colors.blue : isVideo ? Colors.red : Colors.orange).withOpacity(0.2),
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
                      _formatBytes(attachment.bytes.length),
                      style: TextStyle(
                        color: AppTheme.primaryWhite.withOpacity(0.6),
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
            onPressed: () => _removeNewAttachment(index),
            tooltip: 'Remove attachment',
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class NewAttachment {
  final String name;
  final String path;
  final Uint8List bytes;
  final String type;

  NewAttachment({
    required this.name,
    required this.path,
    required this.bytes,
    required this.type,
  });
}
