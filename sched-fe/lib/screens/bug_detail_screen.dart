import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final List<PlatformFile> _selectedFiles = [];
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
            _handleLikeChanged(data, type);
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
      debugPrint('[BugDetail] Error handling bug_updated: $e');
    }
  }

  void _handleLikeChanged(dynamic data, String? type) {
    try {
      final likeCount = data['likeCount'] as int;
      final userId = data['userId'] as String;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (mounted && _bug != null) {
        // Only update if the like was from ANOTHER user
        // (we already did optimistic update for current user)
        if (userId != authProvider.user?.id) {
          setState(() {
            _bug = _bug!.copyWith(likeCount: likeCount);
          });
        } else {
          // For current user, sync both the count AND the upvoted state from server
          // This ensures we're in sync even if there was a race condition
          setState(() {
            _bug = _bug!.copyWith(likeCount: likeCount);
            _isUpvoted = type == 'bug_liked';
          });
        }
      }
    } catch (e) {
      debugPrint('[BugDetail] Error handling like change: $e');
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
      debugPrint('[BugDetail] Error handling comment_created: $e');
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
      debugPrint('[BugDetail] Error handling comment_updated: $e');
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
      debugPrint('[BugDetail] Error handling comment_deleted: $e');
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

    // Optimistic update
    final wasUpvoted = _isUpvoted;
    setState(() {
      _isUpvoted = !_isUpvoted;
      _bug = _bug!.copyWith(
        likeCount: _isUpvoted ? _bug!.likeCount + 1 : _bug!.likeCount - 1,
      );
    });

    try {
      if (wasUpvoted) {
        await _api.unlikeBugReport(widget.bugId);
      } else {
        await _api.likeBugReport(widget.bugId);
      }
      // Success - WebSocket will confirm the change
    } catch (e) {
      // Rollback on error
      setState(() {
        _isUpvoted = wasUpvoted;
        _bug = _bug!.copyWith(
          likeCount: wasUpvoted ? _bug!.likeCount + 1 : _bug!.likeCount - 1,
        );
      });

      if (!mounted) return;
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

    setState(() {
      _isSubmittingComment = true;
      _isUploadingAttachments = _selectedFiles.isNotEmpty;
    });

    try {
      String? commentId;

      if (_editingCommentId != null) {
        // Update existing comment
        await _api.updateBugComment(_editingCommentId!, _commentController.text.trim());
        commentId = _editingCommentId;
        setState(() => _editingCommentId = null);

        // Upload attachments if any
        if (_selectedFiles.isNotEmpty && commentId != null) {
          try {
            await _api.uploadCommentAttachments(commentId, _selectedFiles);
          } catch (uploadError) {
            // For edits, attachment failure is not critical (comment already exists)
            debugPrint('[BugDetail] Attachment upload failed for edit: $uploadError');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Comment updated but attachment upload failed: $uploadError'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
            // Don't throw - comment edit succeeded
          }
        }
      } else {
        // Create new comment with device info
        final deviceInfo = await DeviceInfoHelper.getDeviceInfo();
        final comment = await _api.createBugComment(
          widget.bugId,
          _commentController.text.trim(),
          deviceInfo: deviceInfo,
        );
        commentId = comment['id'];

        // Upload attachments if any - CRITICAL for new comments
        if (_selectedFiles.isNotEmpty && commentId != null) {
          try {
            await _api.uploadCommentAttachments(commentId, _selectedFiles);
          } catch (uploadError) {
            debugPrint('[BugDetail] Attachment upload failed, rolling back comment creation');

            // ROLLBACK: Delete the comment since attachments failed
            try {
              await _api.deleteBugComment(commentId);
              debugPrint('[BugDetail] Successfully rolled back comment creation');
            } catch (deleteError) {
              debugPrint('[BugDetail] Failed to rollback comment: $deleteError');
            }

            // Rethrow to show error to user
            throw Exception('Failed to upload attachments. Comment not created.');
          }
        }
      }

      // Only clear and reload after EVERYTHING succeeded
      _commentController.clear();
      _selectedFiles.clear();
      await _loadBugDetails();

      // Scroll to bottom to show new comment
      if (_scrollController.hasClients) {
        await Future.delayed(const Duration(milliseconds: 100));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingCommentId != null ? 'Comment updated successfully' : 'Comment posted successfully'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[BugDetail] Error in _submitComment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmittingComment = false;
        _isUploadingAttachments = false;
      });
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
      if (!mounted) return;
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
              hintStyle: TextStyle(color: AppTheme.primaryWhite.withValues(alpha: 0.5)),
              filled: true,
              fillColor: AppTheme.primaryWhite.withValues(alpha: 0.05),
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
      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting bug report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
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
    final isDark = themeProvider.isDark;
    final backgroundColor = isDark ? AppTheme.primaryBlack : const Color(0xFFF9FAFB);
    final textColor = isDark ? AppTheme.primaryWhite : Colors.black;
    final cardColor = isDark ? const Color(0xFF18181B) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bug Details',
          style: TextStyle(color: textColor),
        ),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(Icons.edit, color: textColor),
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
              icon: Icon(Icons.admin_panel_settings, color: textColor),
              tooltip: 'Admin Actions',
              color: cardColor,
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
          ? Center(child: CircularProgressIndicator(color: textColor))
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
                  ? Center(child: Text('Bug not found', style: TextStyle(color: textColor)))
                  : RefreshIndicator(
                      onRefresh: _loadBugDetails,
                      color: textColor,
                      backgroundColor: backgroundColor,
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Upvote + Status Badge + Platform (all in same row)
                          Row(
                            children: [
                              // Upvote Button (first, same size as badges)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _toggleUpvote,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _isUpvoted
                                          ? Colors.orange.withValues(alpha: 0.15)
                                          : (themeProvider.isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6)),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _isUpvoted
                                            ? Colors.orange
                                            : (themeProvider.isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                                        width: _isUpvoted ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.arrow_upward,
                                          color: _isUpvoted
                                              ? Colors.orange
                                              : (themeProvider.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_bug!.likeCount}',
                                          style: TextStyle(
                                            color: _isUpvoted
                                                ? Colors.orange
                                                : (themeProvider.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(_bug!.status),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: themeProvider.isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: themeProvider.isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getPlatformIcon(_bug!.platform),
                                      size: 16,
                                      color: themeProvider.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _bug!.platformDisplay,
                                      style: TextStyle(
                                        color: themeProvider.isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Reporter Info - Enhanced with more metadata
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Rounded square avatar (like in bug list)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                                    borderRadius: BorderRadius.circular(10),
                                    image: _bug!.reportedBy.avatarUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(getAbsoluteUrl(_bug!.reportedBy.avatarUrl!)),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _bug!.reportedBy.avatarUrl == null
                                      ? Center(
                                          child: Text(
                                            _bug!.reportedBy.name[0].toUpperCase(),
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Name + Role Badge
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _bug!.reportedBy.name,
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(_bug!.reportedBy.role).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: _getRoleColor(_bug!.reportedBy.role),
                                              ),
                                            ),
                                            child: Text(
                                              _bug!.reportedBy.role.toUpperCase(),
                                              style: TextStyle(
                                                color: _getRoleColor(_bug!.reportedBy.role),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Email
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.email_outlined,
                                            size: 12,
                                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              _bug!.reportedBy.email,
                                              style: TextStyle(
                                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Reported date
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 12,
                                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Reported ${_formatDate(_bug!.createdAt)}',
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
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Title + Description (together)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                _bug!.title,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Description
                              Text(
                                _bug!.description,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),

                          // Attachments
                          if (_bug!.attachments.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.attach_file,
                                        color: textColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Attachments',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withValues(alpha: 0.2),
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
                            _buildDeviceInfo(themeProvider),
                          ],

                          // Resolution Notes
                          if (_bug!.status == BugStatus.RESOLVED && _bug!.resolutionNotes != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
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
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  ),
                                  if (_bug!.resolvedBy != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Resolved by ${_bug!.resolvedBy!.name} on ${_formatDate(_bug!.resolvedAt!)}',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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
                              Text(
                                'Comments',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_bug!.comments?.length ?? 0}',
                                  style: TextStyle(
                                    color: textColor,
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
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    size: 48,
                                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No comments yet',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Be the first to add more details',
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...?_bug!.comments?.map((comment) => _buildCommentCard(comment, authProvider, themeProvider)),

                          // Comment Input (if allowed)
                          if (canComment) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
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
                                    style: TextStyle(color: textColor),
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Add more details about this bug...',
                                      hintStyle: TextStyle(
                                        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
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
                                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                file.extension == 'pdf' ? Icons.picture_as_pdf :
                                                ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(file.extension)
                                                    ? Icons.image : Icons.videocam,
                                                size: 16,
                                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                              ),
                                              const SizedBox(width: 4),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 150),
                                                child: Text(
                                                  file.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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
                                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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
                                              ? (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF))
                                              : textColor,
                                        ),
                                        tooltip: _selectedFiles.length >= 6
                                            ? 'Maximum 6 files'
                                            : 'Attach files (max 6)',
                                      ),
                                      if (_selectedFiles.isNotEmpty)
                                        Text(
                                          '${_selectedFiles.length}/6',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                            fontSize: 12,
                                          ),
                                        ),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        onPressed: (_isSubmittingComment || _isUploadingAttachments) ? null : _submitComment,
                                        icon: (_isSubmittingComment || _isUploadingAttachments)
                                            ? SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: isDark ? Colors.black : Colors.white,
                                              ),
                                            )
                                          : Icon(_editingCommentId != null ? Icons.save : Icons.send),
                                        label: Text(
                                          _isUploadingAttachments && _isSubmittingComment
                                              ? 'Uploading...'
                                              : _editingCommentId != null
                                                  ? 'Update'
                                                  : 'Comment',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark ? Colors.white : Colors.black,
                                          foregroundColor: isDark ? Colors.black : Colors.white,
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

  Widget _buildCommentCard(BugComment comment, AuthProvider authProvider, ThemeProvider themeProvider) {
    final isOwner = authProvider.user?.id == comment.user.id;
    final isAdmin = authProvider.user?.isAdmin ?? false;
    final canEdit = (isOwner || isAdmin) && _bug!.status != BugStatus.CLOSED;
    final canDelete = (isOwner || isAdmin) && _bug!.status != BugStatus.CLOSED;
    final isDark = themeProvider.isDark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF18181B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rounded square avatar (consistent with bug reporter)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(8),
                  image: comment.user.avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(getAbsoluteUrl(comment.user.avatarUrl!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: comment.user.avatarUrl == null
                    ? Center(
                        child: Text(
                          comment.user.name[0].toUpperCase(),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Role Badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.user.name,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getRoleColor(comment.user.role).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _getRoleColor(comment.user.role),
                            ),
                          ),
                          child: Text(
                            comment.user.role.toUpperCase(),
                            style: TextStyle(
                              color: _getRoleColor(comment.user.role),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Email + Date + Device in one compact row
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 10,
                          color: (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            comment.user.email,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Date + Device
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 10,
                          color: (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatDate(comment.createdAt),
                          style: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontSize: 11,
                          ),
                        ),
                        if (comment.deviceInfo != null && _getDeviceInfoString(comment.deviceInfo).isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Icon(Icons.devices, size: 10, color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              _getDeviceInfoString(comment.deviceInfo),
                              style: TextStyle(
                                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                fontSize: 10,
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
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  color: isDark ? const Color(0xFF27272A) : Colors.white,
                  itemBuilder: (context) => [
                    if (canEdit)
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: isDark ? Colors.white : Colors.black),
                            const SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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
            style: TextStyle(
              color: textColor,
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
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (isImage)
                              CachedNetworkImage(
                                imageUrl: getAbsoluteUrl(attachment.fileUrl),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              )
                            else
                              Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  color: isDark ? Colors.white : Colors.black,
                                  size: 40,
                                ),
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
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            attachment.fileType == 'application/pdf'
                                ? Icons.picture_as_pdf
                                : Icons.insert_drive_file,
                            size: 20,
                            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              attachment.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
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
                  color: AppTheme.primaryWhite.withValues(alpha: 0.4),
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
        color = Colors.green;
        break;
      case BugStatus.IN_PROGRESS:
        color = Colors.orange;
        break;
      case BugStatus.RESOLVED:
        color = Colors.blue;
        break;
      case BugStatus.CLOSED:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
    if (_bug!.attachments.isEmpty) return const SizedBox.shrink();

    final allAttachments = _bug!.attachments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attachment header with count
        Row(
          children: [
            Icon(
              Icons.attachment,
              size: 16,
              color: AppTheme.primaryWhite.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              'Attachments (${allAttachments.length}/6)',
              style: TextStyle(
                color: AppTheme.primaryWhite.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Max: Images 30MB • Videos 300MB',
              style: TextStyle(
                color: AppTheme.primaryWhite.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Compact grid with all attachments (2 columns on mobile, 3 on larger screens)
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
            final itemWidth = (constraints.maxWidth - (8 * (crossAxisCount - 1))) / crossAxisCount;
            final itemHeight = itemWidth * 0.75; // 4:3 aspect ratio

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allAttachments.map((attachment) {
                return _buildAttachmentThumbnail(attachment, itemWidth, itemHeight);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttachmentThumbnail(BugAttachment attachment, double width, double height) {
    final isImage = attachment.fileType.startsWith('image/');
    final isVideo = attachment.fileType.startsWith('video/');

    return GestureDetector(
      onTap: () => MediaViewerDialog.show(
        context,
        mediaUrl: getAbsoluteUrl(attachment.fileUrl),
        fileName: attachment.fileName,
        fileType: attachment.fileType,
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.primaryWhite.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.primaryWhite.withValues(alpha: 0.15),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Content based on type
              if (isImage)
                CachedNetworkImage(
                  imageUrl: getAbsoluteUrl(attachment.fileUrl),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryWhite.withValues(alpha: 0.5),
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Icon(
                      Icons.broken_image,
                      color: AppTheme.primaryWhite.withValues(alpha: 0.4),
                      size: 32,
                    ),
                  ),
                )
              else if (isVideo)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 48,
                      color: AppTheme.primaryWhite.withValues(alpha: 0.9),
                    ),
                  ),
                )
              else
                Container(
                  color: AppTheme.primaryWhite.withValues(alpha: 0.08),
                  child: Center(
                    child: Icon(
                      _getDocumentIcon(attachment.fileType),
                      size: 40,
                      color: AppTheme.primaryWhite.withValues(alpha: 0.7),
                    ),
                  ),
                ),

              // Overlay with file info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attachment.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFileSize(attachment.fileSize),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Type badge (top-right)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isImage ? 'IMG' : isVideo ? 'VID' : 'DOC',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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

  IconData _getDocumentIcon(String fileType) {
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('word') || fileType.contains('doc')) return Icons.description;
    if (fileType.contains('excel') || fileType.contains('sheet')) return Icons.table_chart;
    if (fileType.contains('powerpoint') || fileType.contains('presentation')) return Icons.slideshow;
    if (fileType.contains('text')) return Icons.article;
    if (fileType.contains('zip') || fileType.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  Widget _buildDeviceInfo(ThemeProvider themeProvider) {
    if (_bug!.deviceInfo == null) return const SizedBox.shrink();

    final deviceInfo = _bug!.deviceInfo!;
    final isDark = themeProvider.isDark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF18181B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.devices, size: 16, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Text(
                'Device Information',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Device details in compact grid
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              // Platform
              if (deviceInfo.containsKey('platform'))
                _buildInfoChip(
                  icon: Icons.smartphone,
                  label: 'Platform',
                  value: deviceInfo['platform'].toString(),
                  isDark: isDark,
                ),

              // App Version
              if (deviceInfo.containsKey('appVersion'))
                _buildInfoChip(
                  icon: Icons.info_outline,
                  label: 'Version',
                  value: 'v${deviceInfo['appVersion']}',
                  isDark: isDark,
                ),

              // Build Number
              if (deviceInfo.containsKey('buildNumber'))
                _buildInfoChip(
                  icon: Icons.build,
                  label: 'Build',
                  value: deviceInfo['buildNumber'].toString(),
                  isDark: isDark,
                ),

              // WEB specific
              if (deviceInfo.containsKey('browserName'))
                _buildInfoChip(
                  icon: Icons.web,
                  label: 'Browser',
                  value: _formatBrowserName(deviceInfo['browserName'].toString()),
                  isDark: isDark,
                ),

              // Android specific
              if (deviceInfo.containsKey('manufacturer'))
                _buildInfoChip(
                  icon: Icons.business,
                  label: 'Manufacturer',
                  value: deviceInfo['manufacturer'].toString(),
                  isDark: isDark,
                ),

              if (deviceInfo.containsKey('model'))
                _buildInfoChip(
                  icon: Icons.phone_android,
                  label: 'Model',
                  value: deviceInfo['model'].toString(),
                  isDark: isDark,
                ),

              if (deviceInfo.containsKey('androidVersion'))
                _buildInfoChip(
                  icon: Icons.android,
                  label: 'Android',
                  value: deviceInfo['androidVersion'].toString(),
                  isDark: isDark,
                ),

              // iOS specific
              if (deviceInfo.containsKey('systemName'))
                _buildInfoChip(
                  icon: Icons.apple,
                  label: deviceInfo['systemName'].toString(),
                  value: deviceInfo['systemVersion']?.toString() ?? '',
                  isDark: isDark,
                ),

              // Windows specific
              if (deviceInfo.containsKey('computerName'))
                _buildInfoChip(
                  icon: Icons.computer,
                  label: 'Computer',
                  value: deviceInfo['computerName'].toString(),
                  isDark: isDark,
                ),

              if (deviceInfo.containsKey('productName'))
                _buildInfoChip(
                  icon: Icons.monitor,
                  label: 'OS',
                  value: '${deviceInfo['productName']} ${deviceInfo['displayVersion'] ?? ''}',
                  isDark: isDark,
                ),

              if (deviceInfo.containsKey('numberOfCores'))
                _buildInfoChip(
                  icon: Icons.memory,
                  label: 'CPU Cores',
                  value: deviceInfo['numberOfCores'].toString(),
                  isDark: isDark,
                ),

              if (deviceInfo.containsKey('systemMemoryInMegabytes'))
                _buildInfoChip(
                  icon: Icons.storage,
                  label: 'RAM',
                  value: '${(deviceInfo['systemMemoryInMegabytes'] / 1024).toStringAsFixed(1)} GB',
                  isDark: isDark,
                ),

              // Linux specific
              if (deviceInfo.containsKey('prettyName'))
                _buildInfoChip(
                  icon: Icons.desktop_windows,
                  label: 'OS',
                  value: deviceInfo['prettyName'].toString(),
                  isDark: isDark,
                ),

              // macOS specific
              if (deviceInfo.containsKey('hostName'))
                _buildInfoChip(
                  icon: Icons.laptop_mac,
                  label: 'Host',
                  value: deviceInfo['hostName'].toString(),
                  isDark: isDark,
                ),

              if (deviceInfo.containsKey('osRelease'))
                _buildInfoChip(
                  icon: Icons.info,
                  label: 'OS Release',
                  value: deviceInfo['osRelease'].toString(),
                  isDark: isDark,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    bool isDark = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBrowserName(String browserName) {
    // Clean up browser name (e.g., "BrowserName.chrome" -> "Chrome")
    final cleanName = browserName.contains('.')
        ? browserName.split('.').last
        : browserName;
    return cleanName.substring(0, 1).toUpperCase() + cleanName.substring(1);
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.orange;
      case 'employee':
        return Colors.blue;
      case 'visitor':
        return Colors.green;
      default:
        return Colors.grey;
    }
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
}
