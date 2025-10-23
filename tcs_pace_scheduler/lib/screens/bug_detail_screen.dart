import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../models/bug_report.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/url_helper.dart';
import '../utils/device_info_helper.dart';
import '../widgets/media_viewer_dialog.dart';
import 'edit_bug_report_screen.dart';

class BugDetailScreen extends StatefulWidget {
  final String bugId;

  const BugDetailScreen({super.key, required this.bugId});

  @override
  State<BugDetailScreen> createState() => _BugDetailScreenState();
}

class _BugDetailScreenState extends State<BugDetailScreen> {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  BugReport? _bug;
  bool _isLoading = true;
  bool _isUpvoted = false;
  String? _errorMessage;
  bool _isSubmittingComment = false;
  String? _editingCommentId;
  StreamSubscription? _wsSubscription;

  // File attachments for comments
  List<PlatformFile> _selectedFiles = [];
  bool _isUploadingAttachments = false;

  @override
  void initState() {
    super.initState();
    _loadBugDetails();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    _wsSubscription = _ws.messages.listen((message) {
      if (!mounted) return;

      final type = message['type'] as String?;
      final data = message['data'];

      switch (type) {
        case 'bug_updated':
          if (data['id'] == widget.bugId) {
            _handleBugUpdated(data);
          }
          break;
        case 'bug_deleted':
          if (data['id'] == widget.bugId) {
            Navigator.pop(context);
          }
          break;
        case 'bug_liked':
        case 'bug_unliked':
          if (data['bugId'] == widget.bugId) {
            _handleLikeChanged(data);
          }
          break;
        case 'bug_comment_created':
          if (data['bugReportId'] == widget.bugId) {
            _handleCommentCreated(data);
          }
          break;
        case 'bug_comment_updated':
          if (data['bugReportId'] == widget.bugId) {
            _handleCommentUpdated(data);
          }
          break;
        case 'bug_comment_deleted':
          if (data['bugReportId'] == widget.bugId) {
            _handleCommentDeleted(data);
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleBugUpdated(dynamic data) {
    try {
      final updatedBug = BugReport.fromJson(data);
      if (mounted) {
        setState(() {
          _bug = updatedBug;
        });
      }
    } catch (e) {
      print('[BugDetail] Error handling bug_updated: $e');
    }
  }

  void _handleLikeChanged(dynamic data) {
    try {
      final likeCount = data['likeCount'] as int;
      final userId = data['userId'] as String;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (mounted && _bug != null) {
        setState(() {
          _bug = _bug!.copyWith(likeCount: likeCount);
          // Update _isUpvoted if the like/unlike was from current user
          if (userId == authProvider.user?.id) {
            _isUpvoted = data['type'] == 'bug_liked';
          }
        });
      }
    } catch (e) {
      print('[BugDetail] Error handling like change: $e');
    }
  }

  void _handleCommentCreated(dynamic data) {
    try {
      final comment = BugComment.fromJson(data);
      if (mounted && _bug != null) {
        setState(() {
          _bug = _bug!.copyWith(
            comments: [...?_bug!.comments, comment],
            commentCount: (_bug!.commentCount ?? 0) + 1,
          );
        });
        // Scroll to bottom to show new comment
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      print('[BugDetail] Error handling comment_created: $e');
    }
  }

  void _handleCommentUpdated(dynamic data) {
    try {
      final updatedComment = BugComment.fromJson(data);
      if (mounted && _bug != null && _bug!.comments != null) {
        setState(() {
          final comments = [..._bug!.comments!];
          final index = comments.indexWhere((c) => c.id == updatedComment.id);
          if (index != -1) {
            comments[index] = updatedComment;
            _bug = _bug!.copyWith(comments: comments);
          }
        });
      }
    } catch (e) {
      print('[BugDetail] Error handling comment_updated: $e');
    }
  }

  void _handleCommentDeleted(dynamic data) {
    try {
      final commentId = data['id'] as String;
      if (mounted && _bug != null && _bug!.comments != null) {
        setState(() {
          final comments = _bug!.comments!.where((c) => c.id != commentId).toList();
          _bug = _bug!.copyWith(
            comments: comments,
            commentCount: (_bug!.commentCount ?? 1) - 1,
          );
        });
      }
    } catch (e) {
      print('[BugDetail] Error handling comment_deleted: $e');
    }
  }

  Future<void> _loadBugDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.getBugReportById(widget.bugId);
      final upvoted = await _api.hasLikedBug(widget.bugId);

      setState(() {
        _bug = BugReport.fromJson(response);
        _isUpvoted = upvoted;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bug report: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleUpvote() async {
    if (_bug == null) return;

    try {
      if (_isUpvoted) {
        await _api.unlikeBugReport(widget.bugId);
      } else {
        await _api.likeBugReport(widget.bugId);
      }

      setState(() {
        _isUpvoted = !_isUpvoted;
        _bug = BugReport(
          id: _bug!.id,
          title: _bug!.title,
          description: _bug!.description,
          platform: _bug!.platform,
          deviceInfo: _bug!.deviceInfo,
          status: _bug!.status,
          attachments: _bug!.attachments,
          comments: _bug!.comments,
          likes: _bug!.likes,
          likeCount: _isUpvoted ? _bug!.likeCount + 1 : _bug!.likeCount - 1,
          reportedBy: _bug!.reportedBy,
          resolvedBy: _bug!.resolvedBy,
          resolvedAt: _bug!.resolvedAt,
          resolutionNotes: _bug!.resolutionNotes,
          closedBy: _bug!.closedBy,
          closedAt: _bug!.closedAt,
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

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'mp4', 'webm', 'pdf', 'txt', 'csv'],
        withData: true, // For web support
      );

      if (result != null) {
        final totalFiles = _selectedFiles.length + result.files.length;
        if (totalFiles > 6) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Maximum 6 files allowed. You have ${_selectedFiles.length} selected.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting files: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      String? commentId;

      if (_editingCommentId != null) {
        // Update existing comment (no device info update on edit)
        await _api.updateBugComment(_editingCommentId!, _commentController.text.trim());
        commentId = _editingCommentId;
        setState(() => _editingCommentId = null);
      } else {
        // Create new comment with device info
        final deviceInfo = await DeviceInfoHelper.getDeviceInfo();
        final comment = await _api.createBugComment(
          widget.bugId,
          _commentController.text.trim(),
          deviceInfo: deviceInfo,
        );
        commentId = comment['id'];
      }

      // Upload attachments if any (only for new comments or existing ones)
      if (_selectedFiles.isNotEmpty && commentId != null) {
        setState(() => _isUploadingAttachments = true);
        try {
          await _api.uploadCommentAttachments(commentId, _selectedFiles);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Comment posted but attachments failed: $e')),
            );
          }
        } finally {
          setState(() => _isUploadingAttachments = false);
        }
      }

      _commentController.clear();
      _selectedFiles.clear();
      await _loadBugDetails();

      // Scroll to bottom to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryBlack,
        title: const Text('Delete Comment', style: TextStyle(color: AppTheme.primaryWhite)),
        content: const Text(
          'Are you sure you want to delete this comment?',
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
      await _api.deleteBugComment(commentId);
      await _loadBugDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment deleted')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e')),
      );
    }
  }

  Future<void> _editBugReport() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditBugReportScreen(bug: _bug!),
      ),
    );
    if (result == true) {
      _loadBugDetails();
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.user?.isAdmin ?? false;
    final isOwner = _bug != null && authProvider.user?.id == _bug!.reportedBy.id;

    // Admin can edit any bug, owner can only edit if not resolved/closed
    final canEdit = _bug != null && (
      isAdmin ||
      (isOwner && _bug!.status != BugStatus.RESOLVED && _bug!.status != BugStatus.CLOSED)
    );
    // Admin can ALWAYS delete any bug, owner can delete only if not resolved/closed
    final canDelete = _bug != null && (
      isAdmin || // Admin can delete ANY bug regardless of status
      (isOwner && _bug!.status != BugStatus.RESOLVED && _bug!.status != BugStatus.CLOSED)
    );

    final canComment = _bug != null && _bug!.status != BugStatus.CLOSED;

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
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.primaryWhite),
              onPressed: _editBugReport,
              tooltip: 'Edit Bug Report',
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteBugReport,
              tooltip: 'Delete Bug Report',
            ),
          if (isAdmin && _bug != null && _bug!.status != BugStatus.CLOSED)
            PopupMenuButton(
              icon: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryWhite),
              tooltip: 'Admin Actions',
              color: AppTheme.primaryBlack,
              itemBuilder: (context) => [
                if (_bug!.status == BugStatus.OPEN)
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('Mark In Progress', style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                    onTap: () => Future.delayed(Duration.zero, () => _updateStatus(BugStatus.IN_PROGRESS)),
                  ),
                if (_bug!.status == BugStatus.IN_PROGRESS)
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Mark Resolved', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                    onTap: () => Future.delayed(Duration.zero, () => _updateStatus(BugStatus.RESOLVED)),
                  ),
                if (_bug!.status == BugStatus.RESOLVED)
                  PopupMenuItem(
                    child: Row(
                      children: [
                        Icon(Icons.lock, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text('Close Bug', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    onTap: () => Future.delayed(Duration.zero, () => _updateStatus(BugStatus.CLOSED)),
                  ),
              ],
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
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Status Badge + Platform + Upvote
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
                              const Spacer(),
                              // Upvote Button (Reddit style)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _toggleUpvote,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 80),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _isUpvoted
                                          ? Colors.orange.withOpacity(0.2)
                                          : AppTheme.primaryWhite.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _isUpvoted ? Colors.orange : AppTheme.primaryWhite.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.arrow_upward,
                                          color: _isUpvoted ? Colors.orange : AppTheme.primaryWhite,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_bug!.likeCount}',
                                          style: TextStyle(
                                            color: _isUpvoted ? Colors.orange : AppTheme.primaryWhite,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                                    ? NetworkImage(getAbsoluteUrl(_bug!.reportedBy.avatarUrl!))
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
                                    if (_bug!.deviceInfo != null && _getDeviceInfoString(_bug!.deviceInfo).isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.devices,
                                            size: 11,
                                            color: AppTheme.primaryWhite.withOpacity(0.5),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _getDeviceInfoString(_bug!.deviceInfo),
                                              style: TextStyle(
                                                color: AppTheme.primaryWhite.withOpacity(0.5),
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
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
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryWhite.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryWhite.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.attach_file,
                                        color: AppTheme.primaryWhite,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Attachments',
                                        style: TextStyle(
                                          color: AppTheme.primaryWhite,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_bug!.attachments.length}',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildAttachmentGrid(),
                                ],
                              ),
                            ),
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

                          // Comments Section
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              const Text(
                                'Comments',
                                style: TextStyle(
                                  color: AppTheme.primaryWhite,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryWhite.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_bug!.comments?.length ?? 0}',
                                  style: const TextStyle(
                                    color: AppTheme.primaryWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Comment List
                          if (_bug!.comments?.isEmpty ?? true)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryWhite.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    size: 48,
                                    color: AppTheme.primaryWhite.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No comments yet',
                                    style: TextStyle(
                                      color: AppTheme.primaryWhite.withOpacity(0.5),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Be the first to add more details',
                                    style: TextStyle(
                                      color: AppTheme.primaryWhite.withOpacity(0.3),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...?_bug!.comments?.map((comment) => _buildCommentCard(comment, authProvider)),

                          // Comment Input (if allowed)
                          if (canComment) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryWhite.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.primaryWhite.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_editingCommentId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit, size: 16, color: Colors.blue),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Editing comment',
                                            style: TextStyle(color: Colors.blue, fontSize: 12),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _editingCommentId = null;
                                                _commentController.clear();
                                              });
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  TextField(
                                    controller: _commentController,
                                    style: const TextStyle(color: AppTheme.primaryWhite),
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Add more details about this bug...',
                                      hintStyle: TextStyle(
                                        color: AppTheme.primaryWhite.withOpacity(0.5),
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),

                                  // Selected files preview
                                  if (_selectedFiles.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _selectedFiles.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final file = entry.value;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryWhite.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.primaryWhite.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                file.extension == 'pdf' ? Icons.picture_as_pdf :
                                                ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(file.extension)
                                                    ? Icons.image : Icons.videocam,
                                                size: 16,
                                                color: AppTheme.primaryWhite.withOpacity(0.7),
                                              ),
                                              const SizedBox(width: 4),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 150),
                                                child: Text(
                                                  file.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: AppTheme.primaryWhite.withOpacity(0.7),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              InkWell(
                                                onTap: () => _removeFile(index),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 16,
                                                  color: AppTheme.primaryWhite.withOpacity(0.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],

                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Attach files button
                                      IconButton(
                                        onPressed: _selectedFiles.length >= 6 ? null : _pickFiles,
                                        icon: Icon(
                                          Icons.attach_file,
                                          color: _selectedFiles.length >= 6
                                              ? AppTheme.primaryWhite.withOpacity(0.3)
                                              : AppTheme.primaryWhite,
                                        ),
                                        tooltip: _selectedFiles.length >= 6
                                            ? 'Maximum 6 files'
                                            : 'Attach files (max 6)',
                                      ),
                                      if (_selectedFiles.isNotEmpty)
                                        Text(
                                          '${_selectedFiles.length}/6',
                                          style: TextStyle(
                                            color: AppTheme.primaryWhite.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        onPressed: (_isSubmittingComment || _isUploadingAttachments) ? null : _submitComment,
                                        icon: (_isSubmittingComment || _isUploadingAttachments)
                                            ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.primaryBlack,
                                              ),
                                            )
                                          : Icon(_editingCommentId != null ? Icons.save : Icons.send),
                                        label: Text(_editingCommentId != null ? 'Update' : 'Comment'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryWhite,
                                          foregroundColor: AppTheme.primaryBlack,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildCommentCard(BugComment comment, AuthProvider authProvider) {
    final isOwner = authProvider.user?.id == comment.user.id;
    final isAdmin = authProvider.user?.isAdmin ?? false;
    final canEdit = (isOwner || isAdmin) && _bug!.status != BugStatus.CLOSED;
    final canDelete = (isOwner || isAdmin) && _bug!.status != BugStatus.CLOSED;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryWhite.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryWhite.withOpacity(0.2),
                backgroundImage: comment.user.avatarUrl != null
                    ? NetworkImage(getAbsoluteUrl(comment.user.avatarUrl!))
                    : null,
                child: comment.user.avatarUrl == null
                    ? Text(
                        comment.user.name[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.primaryWhite, fontSize: 12),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.user.name,
                          style: const TextStyle(
                            color: AppTheme.primaryWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (comment.user.role == 'ADMIN')
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(color: Colors.red, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _formatDate(comment.createdAt),
                          style: TextStyle(
                            color: AppTheme.primaryWhite.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        if (comment.deviceInfo != null && _getDeviceInfoString(comment.deviceInfo).isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: AppTheme.primaryWhite.withOpacity(0.4),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Icon(Icons.devices, size: 11, color: AppTheme.primaryWhite.withOpacity(0.4)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getDeviceInfoString(comment.deviceInfo),
                              style: TextStyle(
                                color: AppTheme.primaryWhite.withOpacity(0.4),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (canEdit || canDelete)
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: AppTheme.primaryWhite.withOpacity(0.6)),
                  color: AppTheme.primaryBlack,
                  itemBuilder: (context) => [
                    if (canEdit)
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: AppTheme.primaryWhite),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: AppTheme.primaryWhite)),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _editingCommentId = comment.id;
                            _commentController.text = comment.content;
                          });
                        },
                      ),
                    if (canDelete)
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        onTap: () => _deleteComment(comment.id),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: const TextStyle(
              color: AppTheme.primaryWhite,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          // Comment attachments
          if (comment.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: comment.attachments.map((attachment) {
                final isImage = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
                    .contains(attachment.fileType);
                final isVideo = attachment.fileType.startsWith('video/');

                if (isImage || isVideo) {
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => MediaViewerDialog(
                          mediaUrl: getAbsoluteUrl(attachment.fileUrl),
                          fileName: attachment.fileName,
                          fileType: attachment.fileType,
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryWhite.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryWhite.withOpacity(0.2)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (isImage)
                              Image.network(
                                getAbsoluteUrl(attachment.fileUrl),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image, color: AppTheme.primaryWhite),
                                ),
                              )
                            else
                              Center(
                                child: Icon(Icons.play_circle_outline, color: AppTheme.primaryWhite, size: 40),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                } else {
                  // Document/PDF
                  return GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(getAbsoluteUrl(attachment.fileUrl));
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryWhite.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryWhite.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            attachment.fileType == 'application/pdf'
                                ? Icons.picture_as_pdf
                                : Icons.insert_drive_file,
                            size: 20,
                            color: AppTheme.primaryWhite.withOpacity(0.7),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              attachment.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.primaryWhite.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }).toList(),
            ),
          ],

          if (comment.updatedAt.isAfter(comment.createdAt.add(const Duration(seconds: 1))))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Edited',
                style: TextStyle(
                  color: AppTheme.primaryWhite.withOpacity(0.4),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
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
    final documentAttachments = _bug!.attachments
        .where((a) => !a.fileType.startsWith('image/') && !a.fileType.startsWith('video/'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images Section
        if (imageAttachments.isNotEmpty) ...[
          Text(
            'Images (${imageAttachments.length})',
            style: TextStyle(
              color: AppTheme.primaryWhite.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: imageAttachments.map((attachment) {
              return GestureDetector(
                onTap: () => MediaViewerDialog.show(
                  context,
                  mediaUrl: getAbsoluteUrl(attachment.fileUrl),
                  fileName: attachment.fileName,
                  fileType: attachment.fileType,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryWhite.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryWhite.withOpacity(0.2),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          getAbsoluteUrl(attachment.fileUrl),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: AppTheme.primaryWhite,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) => const Center(
                            child: Icon(Icons.broken_image, color: AppTheme.primaryWhite, size: 32),
                          ),
                        ),
                        // Tap overlay with zoom icon
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                            ),
                          ),
                          child: const Align(
                            alignment: Alignment.bottomRight,
                            child: Padding(
                              padding: EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        // Videos Section
        if (videoAttachments.isNotEmpty) ...[
          if (imageAttachments.isNotEmpty) const SizedBox(height: 16),
          Text(
            'Videos (${videoAttachments.length})',
            style: TextStyle(
              color: AppTheme.primaryWhite.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...videoAttachments.map((attachment) => _buildVideoTile(attachment)),
        ],

        // Documents Section
        if (documentAttachments.isNotEmpty) ...[
          if (imageAttachments.isNotEmpty || videoAttachments.isNotEmpty) const SizedBox(height: 16),
          Text(
            'Documents (${documentAttachments.length})',
            style: TextStyle(
              color: AppTheme.primaryWhite.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...documentAttachments.map((attachment) => _buildDocumentTile(attachment)),
        ],
      ],
    );
  }

  Widget _buildVideoTile(BugAttachment attachment) {
    return GestureDetector(
      onTap: () => MediaViewerDialog.show(
        context,
        mediaUrl: getAbsoluteUrl(attachment.fileUrl),
        fileName: attachment.fileName,
        fileType: attachment.fileType,
      ),
      child: Container(
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_circle_fill,
                color: Colors.red,
                size: 32,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'VIDEO',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatBytes(attachment.fileSize),
                        style: TextStyle(
                          color: AppTheme.primaryWhite.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              color: AppTheme.primaryWhite.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile(BugAttachment attachment) {
    return GestureDetector(
      onTap: () async {
        // Open document externally (browser/file viewer)
        final uri = Uri.parse(getAbsoluteUrl(attachment.fileUrl));
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open ${attachment.fileName}')),
            );
          }
        }
      },
      child: Container(
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.insert_drive_file,
                color: Colors.orange,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'DOC',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatBytes(attachment.fileSize),
                        style: TextStyle(
                          color: AppTheme.primaryWhite.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              color: AppTheme.primaryWhite.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get succinct device info string
  String _getDeviceInfoString(Map<String, dynamic>? deviceInfo) {
    if (deviceInfo == null) return '';

    final parts = <String>[];

    // Get platform/OS
    if (deviceInfo.containsKey('platform')) {
      parts.add(deviceInfo['platform'].toString());
    }

    // Get browser name or model
    if (deviceInfo.containsKey('browserName')) {
      final browserName = deviceInfo['browserName'].toString();
      // Clean up browser name (e.g., "BrowserName.chrome" -> "Chrome")
      final cleanName = browserName.contains('.')
          ? browserName.split('.').last
          : browserName;
      parts.add(cleanName.substring(0, 1).toUpperCase() + cleanName.substring(1));
    } else if (deviceInfo.containsKey('model')) {
      parts.add(deviceInfo['model'].toString());
    }

    // Get app version
    if (deviceInfo.containsKey('appVersion') && deviceInfo['appVersion'] != null) {
      parts.add('v${deviceInfo['appVersion']}');
    }

    return parts.join(' • ');
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
          Row(
            children: [
              Icon(Icons.devices, size: 16, color: AppTheme.primaryWhite.withOpacity(0.7)),
              const SizedBox(width: 8),
              const Text(
                'Device Information',
                style: TextStyle(
                  color: AppTheme.primaryWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getDeviceInfoString(_bug!.deviceInfo),
            style: TextStyle(
              color: AppTheme.primaryWhite.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
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
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
