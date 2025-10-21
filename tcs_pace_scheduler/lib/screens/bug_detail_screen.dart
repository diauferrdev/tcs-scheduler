import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/bug_report.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

class BugDetailScreen extends StatefulWidget {
  final String bugId;

  const BugDetailScreen({super.key, required this.bugId});

  @override
  State<BugDetailScreen> createState() => _BugDetailScreenState();
}

class _BugDetailScreenState extends State<BugDetailScreen> {
  final ApiService _api = ApiService();

  BugReport? _bug;
  bool _isLoading = true;
  bool _isLiked = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBugDetails();
  }

  Future<void> _loadBugDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.getBugReportById(widget.bugId);
      final liked = await _api.hasLikedBug(widget.bugId);

      setState(() {
        _bug = BugReport.fromJson(response);
        _isLiked = liked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bug report: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_bug == null) return;

    try {
      if (_isLiked) {
        await _api.unlikeBugReport(widget.bugId);
      } else {
        await _api.likeBugReport(widget.bugId);
      }

      setState(() {
        _isLiked = !_isLiked;
        _bug = BugReport(
          id: _bug!.id,
          title: _bug!.title,
          description: _bug!.description,
          platform: _bug!.platform,
          deviceInfo: _bug!.deviceInfo,
          status: _bug!.status,
          attachments: _bug!.attachments,
          likes: _bug!.likes,
          likeCount: _isLiked ? _bug!.likeCount + 1 : _bug!.likeCount - 1,
          reportedBy: _bug!.reportedBy,
          resolvedBy: _bug!.resolvedBy,
          resolvedAt: _bug!.resolvedAt,
          resolutionNotes: _bug!.resolutionNotes,
          createdAt: _bug!.createdAt,
          updatedAt: _bug!.updatedAt,
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateStatus(BugStatus newStatus) async {
    final resolutionController = TextEditingController();
    String? resolutionNotes;

    if (newStatus == BugStatus.RESOLVED) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.primaryBlack,
          title: const Text('Resolution Notes', style: TextStyle(color: AppTheme.primaryWhite)),
          content: TextField(
            controller: resolutionController,
            style: const TextStyle(color: AppTheme.primaryWhite),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe how this was resolved (optional)',
              hintStyle: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.5)),
              filled: true,
              fillColor: AppTheme.primaryWhite.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryWhite)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, resolutionController.text),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Mark as Resolved'),
            ),
          ],
        ),
      );

      if (result == null) return;
      resolutionNotes = result.isNotEmpty ? result : null;
    }

    try {
      await _api.updateBugReport(widget.bugId, {
        'status': newStatus.name,
        if (resolutionNotes != null) 'resolutionNotes': resolutionNotes,
      });

      _loadBugDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to ${newStatus.name}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  Future<void> _deleteBugReport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryBlack,
        title: const Text('Delete Bug Report', style: TextStyle(color: AppTheme.primaryWhite)),
        content: const Text(
          'Are you sure you want to delete this bug report? This action cannot be undone.',
          style: TextStyle(color: AppTheme.primaryWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryWhite)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteBugReport(widget.bugId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bug report deleted')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting bug report: $e')),
      );
    }
  }

  void _showAttachmentGallery(int initialIndex) {
    final imageAttachments = _bug!.attachments
        .where((a) => a.fileType.startsWith('image/'))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text('${initialIndex + 1} / ${imageAttachments.length}'),
          ),
          body: PhotoViewGallery.builder(
            itemCount: imageAttachments.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(imageAttachments[index].fileUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            pageController: PageController(initialPage: initialIndex),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.user?.role == 'ADMIN';
    final isManager = authProvider.user?.role == 'MANAGER';
    final canManage = isAdmin || isManager;

    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bug Details',
          style: TextStyle(color: AppTheme.primaryWhite),
        ),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteBugReport,
              tooltip: 'Delete Bug Report',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryWhite))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBugDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _bug == null
                  ? const Center(child: Text('Bug not found', style: TextStyle(color: AppTheme.primaryWhite)))
                  : RefreshIndicator(
                      onRefresh: _loadBugDetails,
                      color: AppTheme.primaryWhite,
                      backgroundColor: AppTheme.primaryBlack,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Status Badge + Platform
                          Row(
                            children: [
                              _buildStatusBadge(_bug!.status),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryWhite.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(_getPlatformIcon(_bug!.platform), size: 16, color: AppTheme.primaryWhite),
                                    const SizedBox(width: 6),
                                    Text(
                                      _bug!.platformDisplay,
                                      style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Title
                          Text(
                            _bug!.title,
                            style: const TextStyle(
                              color: AppTheme.primaryWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Reporter Info
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.primaryWhite.withOpacity(0.2),
                                backgroundImage: _bug!.reportedBy.avatarUrl != null
                                    ? NetworkImage(_bug!.reportedBy.avatarUrl!)
                                    : null,
                                child: _bug!.reportedBy.avatarUrl == null
                                    ? Text(
                                        _bug!.reportedBy.name[0].toUpperCase(),
                                        style: const TextStyle(color: AppTheme.primaryWhite),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _bug!.reportedBy.name,
                                      style: const TextStyle(
                                        color: AppTheme.primaryWhite,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Reported ${_formatDate(_bug!.createdAt)}',
                                      style: TextStyle(
                                        color: AppTheme.primaryWhite.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Like Button
                          GestureDetector(
                            onTap: _toggleLike,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryWhite.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isLiked ? Colors.red : AppTheme.primaryWhite.withOpacity(0.2),
                                  width: _isLiked ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: _isLiked ? Colors.red : AppTheme.primaryWhite,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isLiked ? 'You liked this' : 'Like this bug report',
                                    style: TextStyle(
                                      color: _isLiked ? Colors.red : AppTheme.primaryWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_bug!.likeCount}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Description
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryWhite.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    color: AppTheme.primaryWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _bug!.description,
                                  style: TextStyle(
                                    color: AppTheme.primaryWhite.withOpacity(0.8),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Attachments
                          if (_bug!.attachments.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Attachments',
                              style: TextStyle(
                                color: AppTheme.primaryWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildAttachmentGrid(),
                          ],

                          // Device Info
                          if (_bug!.deviceInfo != null) ...[
                            const SizedBox(height: 24),
                            _buildDeviceInfo(),
                          ],

                          // Resolution Notes
                          if (_bug!.status == BugStatus.RESOLVED && _bug!.resolutionNotes != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Resolution Notes',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _bug!.resolutionNotes!,
                                    style: const TextStyle(color: AppTheme.primaryWhite),
                                  ),
                                  if (_bug!.resolvedBy != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Resolved by ${_bug!.resolvedBy!.name} on ${_formatDate(_bug!.resolvedAt!)}',
                                      style: TextStyle(
                                        color: AppTheme.primaryWhite.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],

                          // Admin/Manager Actions
                          if (canManage && _bug!.status != BugStatus.CLOSED) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Actions',
                              style: TextStyle(
                                color: AppTheme.primaryWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_bug!.status == BugStatus.OPEN)
                                  _buildActionButton(
                                    'Mark In Progress',
                                    Colors.blue,
                                    () => _updateStatus(BugStatus.IN_PROGRESS),
                                  ),
                                if (_bug!.status != BugStatus.RESOLVED)
                                  _buildActionButton(
                                    'Mark Resolved',
                                    Colors.green,
                                    () => _updateStatus(BugStatus.RESOLVED),
                                  ),
                                if (_bug!.status == BugStatus.RESOLVED)
                                  _buildActionButton(
                                    'Close',
                                    Colors.grey,
                                    () => _updateStatus(BugStatus.CLOSED),
                                  ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStatusBadge(BugStatus status) {
    Color color;
    switch (status) {
      case BugStatus.OPEN:
        color = Colors.orange;
        break;
      case BugStatus.IN_PROGRESS:
        color = Colors.blue;
        break;
      case BugStatus.RESOLVED:
        color = Colors.green;
        break;
      case BugStatus.CLOSED:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        status.name.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAttachmentGrid() {
    final imageAttachments = _bug!.attachments
        .where((a) => a.fileType.startsWith('image/'))
        .toList();
    final videoAttachments = _bug!.attachments
        .where((a) => a.fileType.startsWith('video/'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageAttachments.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: imageAttachments.length,
            itemBuilder: (context, index) {
              final attachment = imageAttachments[index];
              return GestureDetector(
                onTap: () => _showAttachmentGallery(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    attachment.fileUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: AppTheme.primaryWhite.withOpacity(0.1),
                      child: const Icon(Icons.broken_image, color: AppTheme.primaryWhite),
                    ),
                  ),
                ),
              );
            },
          ),
        if (videoAttachments.isNotEmpty) ...[
          if (imageAttachments.isNotEmpty) const SizedBox(height: 12),
          ...videoAttachments.map((attachment) => _buildVideoTile(attachment)),
        ],
      ],
    );
  }

  Widget _buildVideoTile(BugAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.videocam, color: AppTheme.primaryWhite, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: const TextStyle(color: AppTheme.primaryWhite),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatBytes(attachment.fileSize),
                  style: TextStyle(
                    color: AppTheme.primaryWhite.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: AppTheme.primaryWhite),
            onPressed: () async {
              final uri = Uri.parse(attachment.fileUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device Information',
            style: TextStyle(
              color: AppTheme.primaryWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._bug!.deviceInfo!.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: AppTheme.primaryWhite.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        color: AppTheme.primaryWhite,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  IconData _getPlatformIcon(Platform platform) {
    switch (platform) {
      case Platform.WINDOWS:
        return Icons.laptop_windows;
      case Platform.LINUX:
        return Icons.laptop;
      case Platform.MACOS:
        return Icons.laptop_mac;
      case Platform.ANDROID:
        return Icons.phone_android;
      case Platform.IOS:
        return Icons.phone_iphone;
      case Platform.WEB:
        return Icons.web;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
