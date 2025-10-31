import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ticket.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';

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

  List<XFile> _attachments = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> images = await picker.pickMultiImage();
      setState(() {
        _attachments.addAll(images);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking files: $e')),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _selectedCategory.toString().split('.').last,
        'priority': _selectedPriority.toString().split('.').last,
        if (_selectedPlatform != null)
          'platform': _selectedPlatform.toString().split('.').last,
      };

      await _api.post('/tickets', data);

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
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
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
}
