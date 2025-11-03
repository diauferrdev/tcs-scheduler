import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/toast_notification.dart';

class AttachmentPickerDialog extends StatelessWidget {
  final Function(List<int> bytes, String fileName) onFilePicked;

  const AttachmentPickerDialog({
    super.key,
    required this.onFilePicked,
  });

  Future<void> _pickFile(
    BuildContext context,
    FileType fileType, {
    bool isGeneralFile = false,
    List<String>? allowedExtensions,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true, // Important for web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;

        if (bytes == null) {
          if (!context.mounted) return;
          _showError(context, 'Could not read file');
          return;
        }

        // Check file size
        // Videos: 300MB, Images/Audio: 30MB, Documents: 20MB, General Files: 1GB
        final maxSize = isGeneralFile
            ? 1024 * 1024 * 1024 // 1GB for general files (ZIP, RAR, EXE, APK, etc)
            : fileType == FileType.video
                ? 300 * 1024 * 1024
                : fileType == FileType.image || fileType == FileType.audio
                    ? 30 * 1024 * 1024
                    : 20 * 1024 * 1024; // 20MB for documents (PDF, Word, Excel, etc)

        if (bytes.length > maxSize) {
          if (!context.mounted) return;
          _showError(context, 'File too large. Maximum size is ${maxSize ~/ (1024 * 1024)}MB');
          return;
        }

        onFilePicked(bytes, file.name);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Error picking file: $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ToastNotification.show(context, message: message, type: ToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
      title: Text(
        'Attach File',
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            context,
            icon: Icons.image,
            label: 'Image',
            color: Colors.blue,
            onTap: () => _pickFile(context, FileType.image),
          ),
          const SizedBox(height: 12),
          _buildOption(
            context,
            icon: Icons.videocam,
            label: 'Video',
            color: Colors.red,
            onTap: () => _pickFile(context, FileType.video),
          ),
          const SizedBox(height: 12),
          _buildOption(
            context,
            icon: Icons.audiotrack,
            label: 'Audio',
            color: Colors.purple,
            onTap: () => _pickFile(context, FileType.audio),
          ),
          const SizedBox(height: 12),
          _buildOption(
            context,
            icon: Icons.description,
            label: 'Document',
            color: Colors.orange,
            onTap: () => _pickFile(context, FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv']),
          ),
          const SizedBox(height: 12),
          _buildOption(
            context,
            icon: Icons.folder_zip,
            label: 'Files',
            color: const Color(0xFF2563EB),
            onTap: () => _pickFile(context, FileType.any, isGeneralFile: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
