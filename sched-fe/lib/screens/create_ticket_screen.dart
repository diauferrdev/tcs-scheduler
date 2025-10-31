import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ticket.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/device_info_helper.dart';
import '../widgets/attachment_picker.dart';

class AppTheme {
  static const Color primaryBlack = Color(0xFF000000);
  static const Color primaryWhite = Color(0xFFFFFFFF);
}

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  TicketCategory _selectedCategory = TicketCategory.QUESTION;
  TicketPriority _selectedPriority = TicketPriority.MEDIUM;
  Platform? _selectedPlatform;

  List<File> _selectedFiles = [];
  List<Map<String, dynamic>> _uploadedAttachments = [];
  bool _isSubmitting = false;
  bool _isUploadingFiles = false;
  bool _isAutoDetectingPlatform = true;
  Map<String, dynamic>? _deviceInfo;

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
        _selectedPlatform = Platform.values.firstWhere(
          (p) => p.name == platformName,
          orElse: () => Platform.WEB,
        );
        _isAutoDetectingPlatform = false;
      });
    } catch (e) {
      debugPrint('[CreateTicket] Error auto-detecting platform: $e');
      setState(() {
        _selectedPlatform = Platform.WEB;
        _isAutoDetectingPlatform = false;
      });
    }
  }

  void _fillMockData() {
    setState(() {
      _titleController.text = 'Dashboard metrics not loading properly';
      _descriptionController.text = 'When trying to access the metrics dashboard, the page stays in infinite loading and does not render the charts. Tested on different browsers and the problem persists. Console shows no errors.';
      _selectedCategory = TicketCategory.BUG;
      _selectedPriority = TicketPriority.HIGH;
    });
  }

  void _pickAttachments() {
    AttachmentPicker.show(
      context,
      onFilesPicked: (files) {
        setState(() {
          _selectedFiles.addAll(files);
          // Limit to 6 files max
          if (_selectedFiles.length > 6) {
            _selectedFiles = _selectedFiles.take(6).toList();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 6 files allowed')),
            );
          }
        });
      },
      maxFiles: 6,
      allowImages: true,
      allowDocuments: true,
    );
  }

  void _removeAttachment(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _uploadFiles() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploadingFiles = true;
    });

    try {
      _uploadedAttachments.clear();

      for (final file in _selectedFiles) {
        final bytes = await readFileBytes(file);
        final filename = file.path.split('/').last;

        final response = await _api.uploadAttachment(bytes, filename);

        _uploadedAttachments.add({
          'fileName': response['filename'],
          'fileUrl': response['url'],
          'fileSize': response['size'],
          'mimeType': response['type'],
        });
      }

      debugPrint('[CreateTicket] Uploaded ${_uploadedAttachments.length} files');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading files: $e')),
      );
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFiles = false;
        });
      }
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload files first if any selected
      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles();
      }

      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _selectedCategory.toString().split('.').last,
        'priority': _selectedPriority.toString().split('.').last,
        if (_selectedPlatform != null)
          'platform': _selectedPlatform.toString().split('.').last,
        if (_deviceInfo != null) 'deviceInfo': _deviceInfo,
        if (_uploadedAttachments.isNotEmpty)
          'attachments': _uploadedAttachments,
      };

      await _api.post('/api/tickets', data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket created successfully!')),
      );

      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating ticket: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF18181B) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create Support Ticket',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (kIsWeb || true) // Show mock button in development
            IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.amber),
              tooltip: 'Fill with mock data',
              onPressed: _fillMockData,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Title',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Brief summary of your issue',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Description
              Text(
                'Description',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                style: TextStyle(color: textColor),
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Detailed description of your issue',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Category
              Text(
                'Category',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TicketCategory>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: cardColor,
                    style: TextStyle(color: textColor),
                    items: TicketCategory.values.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(_getCategoryLabel(category)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Priority
              Text(
                'Priority',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TicketPriority>(
                    value: _selectedPriority,
                    isExpanded: true,
                    dropdownColor: cardColor,
                    style: TextStyle(color: textColor),
                    items: TicketPriority.values.map((priority) {
                      return DropdownMenuItem(
                        value: priority,
                        child: Text(_getPriorityLabel(priority)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedPriority = value;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Platform (Optional)
              Text(
                'Platform (Optional)',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Platform?>(
                    value: _selectedPlatform,
                    isExpanded: true,
                    dropdownColor: cardColor,
                    style: TextStyle(color: textColor),
                    items: [
                      DropdownMenuItem<Platform?>(
                        value: null,
                        child: Text('Not specified'),
                      ),
                      ...Platform.values.map((platform) {
                        return DropdownMenuItem(
                          value: platform,
                          child: Text(_getPlatformLabel(platform)),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPlatform = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Attachments Section
              Text(
                'Attachments (Optional)',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Add Attachments Button
              OutlinedButton.icon(
                onPressed: _selectedFiles.length < 6 ? _pickAttachments : null,
                icon: const Icon(Icons.attach_file),
                label: Text(_selectedFiles.isEmpty
                    ? 'Add Files (Images, Videos, Documents)'
                    : 'Add More Files (${_selectedFiles.length}/6)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: textColor.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Display selected files with preview
              if (_selectedFiles.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _selectedFiles.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildFilePreview(
                            _selectedFiles[i],
                            i,
                            textColor,
                            isDark,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _isUploadingFiles) ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: (_isSubmitting || _isUploadingFiles)
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _isUploadingFiles
                                  ? 'Uploading files...'
                                  : 'Creating ticket...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Submit Ticket',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryLabel(TicketCategory category) {
    switch (category) {
      case TicketCategory.BUG:
        return 'Bug';
      case TicketCategory.FEATURE_REQUEST:
        return 'Feature Request';
      case TicketCategory.QUESTION:
        return 'Question';
      case TicketCategory.IMPROVEMENT:
        return 'Improvement';
      case TicketCategory.OTHER:
        return 'Other';
    }
  }

  String _getPriorityLabel(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.LOW:
        return 'Low';
      case TicketPriority.MEDIUM:
        return 'Medium';
      case TicketPriority.HIGH:
        return 'High';
      case TicketPriority.URGENT:
        return 'Urgent';
    }
  }

  String _getPlatformLabel(Platform platform) {
    switch (platform) {
      case Platform.WINDOWS:
        return 'Windows';
      case Platform.LINUX:
        return 'Linux';
      case Platform.MACOS:
        return 'macOS';
      case Platform.ANDROID:
        return 'Android';
      case Platform.IOS:
        return 'iOS';
      case Platform.WEB:
        return 'Web';
    }
  }

  IconData _getFileIcon(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    // Images
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return Icons.image;
    }

    // Videos
    if (['mp4', 'webm', 'mov', 'avi'].contains(extension)) {
      return Icons.videocam;
    }

    // Documents
    if (extension == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(extension)) return Icons.description;
    if (['xls', 'xlsx', 'csv'].contains(extension)) return Icons.table_chart;

    // Default
    return Icons.attach_file;
  }

  Widget _buildFilePreview(File file, int index, Color textColor, bool isDark) {
    final fileName = file.path.split('/').last;
    final extension = fileName.toLowerCase().split('.').last;
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
    final isVideo = ['mp4', 'webm', 'mov', 'avi'].contains(extension);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File info row
        Row(
          children: [
            Icon(
              _getFileIcon(file.path),
              color: textColor.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fileName,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 20),
              onPressed: () => _removeAttachment(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        // Image preview
        if (isImage) ...[
          const SizedBox(height: 8),
          FutureBuilder<Uint8List>(
            future: readFileBytes(file),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    snapshot.data!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey.withOpacity(0.2),
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                );
              }
              return Container(
                height: 150,
                color: Colors.grey.withOpacity(0.1),
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ],
        // Video thumbnail placeholder
        if (isVideo) ...[
          const SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: textColor.withOpacity(0.2),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 48,
                color: textColor.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
