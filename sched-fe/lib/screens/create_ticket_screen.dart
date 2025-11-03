import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/ticket.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/device_info_helper.dart';
import '../widgets/attachment_picker_dialog.dart';

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

  // Store files as bytes + filename instead of File objects
  List<Map<String, dynamic>> _selectedFiles = []; // { 'bytes': Uint8List, 'name': String }
  final List<Map<String, dynamic>> _uploadedAttachments = [];
  final Map<int, double> _uploadProgress = {}; // Progress for each file (0.0 - 1.0)
  final Map<int, bool> _uploadFailed = {}; // Track failed uploads
  bool _isSubmitting = false;
  bool _isUploadingFiles = false;
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
      });
    } catch (e) {
      debugPrint('[CreateTicket] Error auto-detecting platform: $e');
      setState(() {
        _selectedPlatform = Platform.WEB;
      });
    }
  }

  int _mockDataIndex = 0;
  final List<Map<String, dynamic>> _mockDataOptions = [
    {
      'title': 'Dashboard metrics not loading properly',
      'description': 'When trying to access the metrics dashboard, the page stays in infinite loading and does not render the charts. Tested on different browsers and the problem persists. Console shows no errors.',
      'category': TicketCategory.BUG,
      'priority': TicketPriority.HIGH,
    },
    {
      'title': 'Mobile app crashes on booking submission',
      'description': 'The mobile application crashes immediately after clicking the "Submit Booking" button. This happens consistently on both Android and iOS devices. Error logs show a null pointer exception in the booking service.',
      'category': TicketCategory.BUG,
      'priority': TicketPriority.URGENT,
    },
    {
      'title': 'Add dark mode support',
      'description': 'Request for dark mode theme support across the entire application. Many users prefer dark mode for reduced eye strain, especially when using the app during evening hours.',
      'category': TicketCategory.FEATURE_REQUEST,
      'priority': TicketPriority.MEDIUM,
    },
    {
      'title': 'How to export booking history?',
      'description': 'I need to export my booking history for the last 6 months in CSV or PDF format. Could you please guide me on how to do this or add this feature if it is not available?',
      'category': TicketCategory.QUESTION,
      'priority': TicketPriority.LOW,
    },
    {
      'title': 'Calendar integration with Google Calendar',
      'description': 'Would be great to have automatic sync with Google Calendar so bookings appear in my personal calendar. This would help avoid scheduling conflicts.',
      'category': TicketCategory.FEATURE_REQUEST,
      'priority': TicketPriority.MEDIUM,
    },
    {
      'title': 'Push notifications not working on iOS',
      'description': 'Not receiving push notifications on iPhone 14 Pro running iOS 17. Tried reinstalling the app and checking notification settings - everything is enabled. Android users report notifications are working fine.',
      'category': TicketCategory.BUG,
      'priority': TicketPriority.HIGH,
    },
  ];

  void _fillMockData() {
    final mock = _mockDataOptions[_mockDataIndex];
    setState(() {
      _titleController.text = mock['title'];
      _descriptionController.text = mock['description'];
      _selectedCategory = mock['category'];
      _selectedPriority = mock['priority'];
      // Cycle through mock data options
      _mockDataIndex = (_mockDataIndex + 1) % _mockDataOptions.length;
    });
  }

  void _pickAttachments() {
    // Check if we already have 6 files
    if (_selectedFiles.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 files allowed')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AttachmentPickerDialog(
        onFilePicked: (bytes, fileName) {
          setState(() {
            // Add file as bytes + name
            _selectedFiles.add({
              'bytes': Uint8List.fromList(bytes),
              'name': fileName,
            });

            // Limit to 6 files max
            if (_selectedFiles.length > 6) {
              _selectedFiles = _selectedFiles.take(6).toList();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Maximum 6 files allowed')),
              );
            }
          });
        },
      ),
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
      _uploadProgress.clear();
      _uploadFailed.clear();
    });

    try {
      _uploadedAttachments.clear();

      for (int i = 0; i < _selectedFiles.length; i++) {
        if (_uploadFailed[i] == true) continue; // Skip failed uploads

        try {
          setState(() {
            _uploadProgress[i] = 0.0;
          });

          final fileData = _selectedFiles[i];
          final bytes = fileData['bytes'] as Uint8List;
          final filename = fileData['name'] as String;

          // Simulate progress (in real app, you'd use progress callback from http)
          setState(() {
            _uploadProgress[i] = 0.3;
          });

          final response = await _api.uploadAttachment(bytes, filename);

          setState(() {
            _uploadProgress[i] = 1.0;
          });

          _uploadedAttachments.add({
            'fileName': response['filename'],
            'fileUrl': response['url'],
            'fileSize': response['size'],
            'mimeType': response['type'],
          });

          debugPrint('[CreateTicket] Uploaded file ${i + 1}/${_selectedFiles.length}: $filename');
        } catch (e) {
          debugPrint('[CreateTicket] Failed to upload file $i: $e');
          setState(() {
            _uploadFailed[i] = true;
          });

          if (!mounted) return;

          // Show error but continue with other files
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload ${_selectedFiles[i]['name']}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Remove failed uploads from the list with animation
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        final failedIndexes = _uploadFailed.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList()
          ..sort((a, b) => b.compareTo(a)); // Sort descending to remove from end

        for (final index in failedIndexes) {
          setState(() {
            _selectedFiles.removeAt(index);
            _uploadFailed.remove(index);
            _uploadProgress.remove(index);
          });
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      debugPrint('[CreateTicket] Successfully uploaded ${_uploadedAttachments.length} files');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading files: $e'), backgroundColor: Colors.red),
      );
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFiles = false;
          _uploadProgress.clear();
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
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
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
                  hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
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
                      }),
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
                    ? 'Add Media (Up to 6 files)'
                    : 'Add More (${_selectedFiles.length}/6)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: textColor.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Display selected files in 2x3 grid with preview
              if (_selectedFiles.isNotEmpty) ...[
                _buildAttachmentsGrid(isDark, textColor, cardColor),
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

  Widget _buildAttachmentsGrid(bool isDark, Color textColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 columns (2x3 grid for 6 items)
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          return _buildGridItem(_selectedFiles[index], index, isDark, textColor);
        },
      ),
    );
  }

  Widget _buildGridItem(Map<String, dynamic> fileData, int index, bool isDark, Color textColor) {
    final fileName = fileData['name'] as String;
    final bytes = fileData['bytes'] as Uint8List;
    final extension = fileName.toLowerCase().split('.').last;
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
    final isVideo = ['mp4', 'webm', 'mov', 'avi'].contains(extension);
    final isUploading = _uploadProgress.containsKey(index);
    final hasFailed = _uploadFailed[index] == true;
    final uploadProgress = _uploadProgress[index] ?? 0.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: hasFailed ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: hasFailed || isUploading ? null : () => _viewAttachmentFullscreen(bytes, fileName),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasFailed
                      ? Colors.red.withValues(alpha: 0.5)
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1)),
                  width: hasFailed ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isImage
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getFileIcon(fileName),
                              size: 32,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              extension.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // Upload progress overlay
            if (isUploading && !hasFailed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          value: uploadProgress,
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(uploadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Failed overlay
            if (hasFailed)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Upload Failed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Remove button (hide during upload)
            if (!isUploading)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeAttachment(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: hasFailed ? Colors.red.shade700 : Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),

            // Video play icon
            if (isVideo && !isUploading && !hasFailed)
              const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white,
                  size: 40,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _viewAttachmentFullscreen(Uint8List bytes, String fileName) async {
    final extension = fileName.toLowerCase().split('.').last;
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
    final isVideo = ['mp4', 'webm', 'mov', 'avi'].contains(extension);
    final isPdf = extension == 'pdf';

    if (!isImage && !isVideo && !isPdf) {
      // For non-media files, just show a dialog
      final fileSize = bytes.length;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(fileName),
          content: Text('File type: ${extension.toUpperCase()}\nSize: ${_formatFileSize(fileSize)}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    // For media files, show fullscreen viewer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AttachmentFullscreenViewer(
          bytes: bytes,
          fileName: fileName,
          isImage: isImage,
          isVideo: isVideo,
          isPdf: isPdf,
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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

    // Audio
    if (['mp3', 'wav', 'ogg', 'm4a', 'aac'].contains(extension)) {
      return Icons.audio_file;
    }

    // Documents
    if (extension == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(extension)) return Icons.description;
    if (['xls', 'xlsx', 'csv'].contains(extension)) return Icons.table_chart;

    // Archives
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(extension)) return Icons.folder_zip;

    // Executables
    if (['exe', 'apk', 'dmg'].contains(extension)) return Icons.apps;

    // Default
    return Icons.insert_drive_file;
  }

}

/// Fullscreen viewer for local file attachments
class _AttachmentFullscreenViewer extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  final bool isImage;
  final bool isVideo;
  final bool isPdf;

  const _AttachmentFullscreenViewer({
    required this.bytes,
    required this.fileName,
    required this.isImage,
    required this.isVideo,
    required this.isPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          fileName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: isImage
            ? InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(bytes),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isVideo ? Icons.videocam : Icons.insert_drive_file,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    fileName,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview not available',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }
}
