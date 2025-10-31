import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bug_report.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/url_helper.dart';
import 'bug_detail_screen.dart';
import 'create_bug_report_screen.dart';

class BugReportsScreen extends StatefulWidget {
  const BugReportsScreen({super.key});

  @override
  State<BugReportsScreen> createState() => _BugReportsScreenState();
}

class _BugReportsScreenState extends State<BugReportsScreen> {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final TextEditingController _searchController = TextEditingController();

  List<BugReport> _bugReports = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String? _selectedStatus;
  String? _selectedPlatform;
  String _sortBy = 'likeCount';
  String _order = 'desc';

  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadBugReports();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;

    debugPrint('[BugReportsScreen] Setting up WebSocket for user: $userId');

    if (userId != null) {
      _ws.connect(userId);

      _wsSubscription = _ws.messages.listen(
        (message) {
          if (!mounted) {
            debugPrint('[BugReportsScreen] Not mounted, ignoring message');
            return;
          }

          final type = message['type'] as String?;
          debugPrint('[BugReportsScreen] 📨 WS Event: $type');
          debugPrint('[BugReportsScreen] 📦 Data: ${message['data']}');

          switch (type) {
            case 'bug_created':
              debugPrint('[BugReportsScreen] Handling bug_created');
              _handleBugCreated(message['data']);
              break;
            case 'bug_updated':
              debugPrint('[BugReportsScreen] Handling bug_updated');
              _handleBugUpdated(message['data']);
              break;
            case 'bug_deleted':
              debugPrint('[BugReportsScreen] Handling bug_deleted');
              _handleBugDeleted(message['data']);
              break;
            case 'bug_liked':
            case 'bug_unliked':
              debugPrint('[BugReportsScreen] Handling bug_liked/unliked');
              _handleBugLikeChanged(message['data']);
              break;
            case 'bug_comment_created':
            case 'bug_comment_updated':
            case 'bug_comment_deleted':
              debugPrint('[BugReportsScreen] Handling comment event');
              _handleCommentChanged(message['data']);
              break;
            default:
              debugPrint('[BugReportsScreen] Unknown event type: $type');
          }
        },
        onError: (error) {
          debugPrint('[BugReportsScreen] ❌ WS Error: $error');
        },
        onDone: () {
          debugPrint('[BugReportsScreen] WS stream closed');
        },
      );
      debugPrint('[BugReportsScreen] ✅ WebSocket listener set up');
    } else {
      debugPrint('[BugReportsScreen] ❌ No userId, cannot setup WebSocket');
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleBugCreated(dynamic data) {
    try {
      debugPrint('[BugReportsScreen] 🆕 Creating new bug from data');
      final newBug = BugReport.fromJson(data);
      debugPrint('[BugReportsScreen] ✅ Bug parsed: ${newBug.id} - ${newBug.title}');
      debugPrint('[BugReportsScreen] Current bugs count: ${_bugReports.length}');

      setState(() {
        _bugReports.add(newBug);
        _sortBugReports();
      });

      debugPrint('[BugReportsScreen] ✅ Bug added and sorted. New count: ${_bugReports.length}');
    } catch (e, stackTrace) {
      debugPrint('[BugReportsScreen] ❌ Error handling bug_created: $e');
      debugPrint('[BugReportsScreen] StackTrace: $stackTrace');
    }
  }

  void _handleBugUpdated(dynamic data) {
    try {
      debugPrint('[BugReportsScreen] 🔄 Updating bug from data');
      final updatedBug = BugReport.fromJson(data);
      debugPrint('[BugReportsScreen] ✅ Bug parsed: ${updatedBug.id}');

      setState(() {
        final index = _bugReports.indexWhere((b) => b.id == updatedBug.id);
        debugPrint('[BugReportsScreen] Found bug at index: $index');
        if (index != -1) {
          _bugReports[index] = updatedBug;
          debugPrint('[BugReportsScreen] ✅ Bug updated at index $index');
          // Reorder if needed (e.g., if updatedAt changed and we're sorting by updatedAt)
          _sortBugReports();
        } else {
          debugPrint('[BugReportsScreen] ⚠️ Bug not found in list, adding it');
          _bugReports.add(updatedBug);
          _sortBugReports();
        }
      });
    } catch (e, stackTrace) {
      debugPrint('[BugReportsScreen] ❌ Error handling bug_updated: $e');
      debugPrint('[BugReportsScreen] StackTrace: $stackTrace');
    }
  }

  void _sortBugReports() {
    debugPrint('[BugReportsScreen] 🔄 Sorting by: $_sortBy ($_order)');

    switch (_sortBy) {
      case 'likeCount':
        _bugReports.sort((a, b) {
          final comparison = a.likeCount.compareTo(b.likeCount);
          return _order == 'desc' ? -comparison : comparison;
        });
        break;
      case 'createdAt':
        _bugReports.sort((a, b) {
          final comparison = a.createdAt.compareTo(b.createdAt);
          return _order == 'desc' ? -comparison : comparison;
        });
        break;
      case 'updatedAt':
        _bugReports.sort((a, b) {
          final comparison = a.updatedAt.compareTo(b.updatedAt);
          return _order == 'desc' ? -comparison : comparison;
        });
        break;
    }

    debugPrint('[BugReportsScreen] ✅ Sorted successfully');
  }

  void _handleBugDeleted(dynamic data) {
    try {
      final bugId = data['id'] as String;
      debugPrint('[BugReportsScreen] 🗑️ Deleting bug: $bugId');

      setState(() {
        final removedCount = _bugReports.length;
        _bugReports.removeWhere((b) => b.id == bugId);
        debugPrint('[BugReportsScreen] ✅ Removed ${removedCount - _bugReports.length} bug(s)');
      });
    } catch (e, stackTrace) {
      debugPrint('[BugReportsScreen] ❌ Error handling bug_deleted: $e');
      debugPrint('[BugReportsScreen] StackTrace: $stackTrace');
    }
  }

  void _handleBugLikeChanged(dynamic data) {
    try {
      final bugId = data['bugId'] as String;
      final likeCount = data['likeCount'] as int;
      debugPrint('[BugReportsScreen] 👍 Like changed for bug: $bugId, new count: $likeCount');

      setState(() {
        final index = _bugReports.indexWhere((b) => b.id == bugId);
        if (index != -1) {
          _bugReports[index] = _bugReports[index].copyWith(likeCount: likeCount);
          debugPrint('[BugReportsScreen] Updated bug at index $index');

          // Reorder if sorting by likeCount
          if (_sortBy == 'likeCount') {
            debugPrint('[BugReportsScreen] Reordering by likeCount');
            _sortBugReports();
          }
        }
      });
    } catch (e, stackTrace) {
      debugPrint('[BugReportsScreen] ❌ Error handling like change: $e');
      debugPrint('[BugReportsScreen] StackTrace: $stackTrace');
    }
  }

  void _handleCommentChanged(dynamic data) {
    // Reload the specific bug to get updated comment count
    // For now, we'll just trigger a refresh of that specific bug
    try {
      final bugReportId = data['bugReportId'] as String? ?? data['bugId'] as String?;
      if (bugReportId != null) {
        // We could either refetch the entire list or just update comment count
        // For simplicity, let's just refetch
        _loadBugReports();
      }
    } catch (e) {
      print('[BugReportsScreen] Error handling comment change: $e');
    }
  }

  Future<void> _loadBugReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.getBugReports(
        status: _selectedStatus,
        platform: _selectedPlatform,
        search: _searchController.text.isEmpty ? null : _searchController.text,
        sortBy: _sortBy,
        order: _order,
      );

      final bugsList = response['bugs'] as List<dynamic>;
      if (mounted) {
        setState(() {
          _bugReports = bugsList.map((json) => BugReport.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load bug reports: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedPlatform = null;
      _searchController.clear();
      _sortBy = 'likeCount';
      _order = 'desc';
    });
    _loadBugReports();
  }

  Future<void> _navigateToCreateBug() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateBugReportScreen()),
    );
    if (result == true) {
      _loadBugReports();
    }
  }

  Future<void> _navigateToBugDetail(BugReport bug) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BugDetailScreen(bugId: bug.id)),
    );
    // Always reload to reflect any changes (upvotes, comments, edits, etc)
    _loadBugReports();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isAdmin = authProvider.user?.isAdmin ?? false;
    final isManager = authProvider.user?.isManager ?? false;

    final backgroundColor = themeProvider.isDark ? AppTheme.primaryBlack : const Color(0xFFF9FAFB);
    final textColor = themeProvider.isDark ? AppTheme.primaryWhite : Colors.black;
    final cardColor = themeProvider.isDark ? AppTheme.primaryWhite.withOpacity(0.05) : Colors.white;

    final bodyContent = Column(
      children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: backgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search by title or description...',
                      hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: textColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: textColor),
                        onPressed: () {
                          _searchController.clear();
                          _loadBugReports();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.primaryWhite.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _loadBugReports(),
                  ),
                ),
                if (_selectedStatus != null || _selectedPlatform != null)
                  const SizedBox(width: 8),
                if (_selectedStatus != null || _selectedPlatform != null)
                  IconButton(
                    icon: Icon(Icons.filter_alt_off, color: textColor),
                    onPressed: _clearFilters,
                    tooltip: 'Clear Filters',
                  ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // Status Filter
                _buildFilterChip(
                  label: _selectedStatus == null ? 'All Status' : _selectedStatus!,
                  isActive: _selectedStatus != null,
                  onTap: () => _showStatusFilter(),
                  isDark: themeProvider.isDark,
                ),
                const SizedBox(width: 8),

                // Platform Filter
                _buildFilterChip(
                  label: _selectedPlatform == null ? 'All Platforms' : _selectedPlatform!,
                  isActive: _selectedPlatform != null,
                  onTap: () => _showPlatformFilter(),
                  isDark: themeProvider.isDark,
                ),
                const SizedBox(width: 8),

                // Sort Filter
                _buildFilterChip(
                  label: _sortBy == 'likeCount' ? 'Most Liked' : _sortBy == 'createdAt' ? 'Newest' : 'Recent',
                  isActive: true,
                  onTap: () => _showSortOptions(),
                  isDark: themeProvider.isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Bug Reports List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryWhite),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadBugReports,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _bugReports.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bug_report_outlined,
                                  size: 64,
                                  color: AppTheme.primaryWhite.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No bug reports found',
                                  style: TextStyle(
                                    color: AppTheme.primaryWhite.withOpacity(0.5),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadBugReports,
                            color: AppTheme.primaryWhite,
                            backgroundColor: AppTheme.primaryBlack,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _bugReports.length,
                              itemBuilder: (context, index) {
                                final bug = _bugReports[index];
                                return _buildBugCard(bug, themeProvider.isDark);
                              },
                            ),
                          ),
          ),
        ],
      );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          bodyContent,
          // Floating Action Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: _navigateToCreateBug,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text(
                'Report Bug',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: isActive
            ? (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB))
            : (isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6)),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isActive
              ? (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF))
              : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB)),
          width: isActive ? 1.5 : 1,
        ),
      ),
    );
  }

  Widget _buildBugCard(BugReport bug, bool isDark) {
    final hasAttachments = bug.attachments.isNotEmpty;
    final commentCount = bug.commentCount ?? bug.comments?.length ?? 0;
    final timeAgo = _formatTimeAgo(bug.createdAt);

    // Theme-aware colors
    final cardColor = isDark ? AppTheme.primaryWhite.withOpacity(0.05) : Colors.white;
    final textColor = isDark ? AppTheme.primaryWhite : Colors.black87;
    final subtextColor = isDark ? AppTheme.primaryWhite.withOpacity(0.6) : Colors.black54;
    final borderColor = isDark ? AppTheme.primaryWhite.withOpacity(0.1) : Colors.grey.shade200;
    final badgeBgColor = isDark ? AppTheme.primaryWhite.withOpacity(0.1) : Colors.grey.shade100;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: () => _navigateToBugDetail(bug),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Status + Platform + Tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildStatusBadge(bug.status),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getPlatformIcon(bug.platform), size: 12, color: textColor),
                              const SizedBox(width: 4),
                              Text(
                                bug.platformDisplay,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasAttachments)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, size: 12, color: Colors.blue),
                                const SizedBox(width: 2),
                                Text(
                                  '${bug.attachments.length}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Title
                    Text(
                      bug.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Description preview (single line, remove line breaks)
                    Text(
                      bug.description.replaceAll('\n', ' ').replaceAll('\r', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Footer: Upvote → Messages → Author + Time
                    Row(
                      children: [
                        // Upvote counter (first)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: bug.likeCount > 0 ? Colors.orange.withOpacity(0.15) : badgeBgColor,
                            borderRadius: BorderRadius.circular(4),
                            border: bug.likeCount > 0
                                ? Border.all(color: Colors.orange.withOpacity(0.3))
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_upward,
                                size: 13,
                                color: bug.likeCount > 0
                                    ? Colors.orange
                                    : (isDark ? AppTheme.primaryWhite.withOpacity(0.5) : Colors.grey.shade600),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${bug.likeCount}',
                                style: TextStyle(
                                  color: bug.likeCount > 0
                                      ? Colors.orange
                                      : (isDark ? AppTheme.primaryWhite.withOpacity(0.7) : Colors.grey.shade700),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Comment count (second)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 13,
                                color: isDark ? AppTheme.primaryWhite.withOpacity(0.7) : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$commentCount',
                                style: TextStyle(
                                  color: isDark ? AppTheme.primaryWhite.withOpacity(0.8) : Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Author avatar (third) - rounded square
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.primaryWhite.withOpacity(0.2) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                            image: bug.reportedBy.avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(getAbsoluteUrl(bug.reportedBy.avatarUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: bug.reportedBy.avatarUrl == null
                              ? Center(
                                  child: Text(
                                    bug.reportedBy.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: isDark ? AppTheme.primaryWhite : Colors.grey.shade700,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        // Author name + time (last) - with Flexible to prevent overflow
                        Flexible(
                          child: Text(
                            '${_abbreviateName(bug.reportedBy.name)} • $timeAgo',
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Right: Thumbnail preview (if has image/video)
              if (hasAttachments && bug.attachments.isNotEmpty) ...[
                const SizedBox(width: 12),
                _buildThumbnail(_getPreferredThumbnailAttachment(bug.attachments)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Get the preferred attachment for thumbnail preview
  /// Priority: image > video > first attachment
  BugAttachment _getPreferredThumbnailAttachment(List<BugAttachment> attachments) {
    // Try to find an image first
    try {
      return attachments.firstWhere((a) => a.fileType.startsWith('image/'));
    } catch (_) {
      // If no image, try to find a video
      try {
        return attachments.firstWhere((a) => a.fileType.startsWith('video/'));
      } catch (_) {
        // If neither image nor video, return first attachment
        return attachments.first;
      }
    }
  }

  Widget _buildThumbnail(BugAttachment attachment) {
    final isImage = attachment.fileType.startsWith('image/');
    final isVideo = attachment.fileType.startsWith('video/');

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.primaryWhite.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryWhite.withOpacity(0.15),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: isImage
            ? Image.network(
                getAbsoluteUrl(attachment.fileUrl),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: AppTheme.primaryWhite.withOpacity(0.5),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('[Preview] Error loading image: $error');
                  return Center(
                    child: Icon(
                      Icons.broken_image,
                      color: AppTheme.primaryWhite.withOpacity(0.3),
                      size: 40,
                    ),
                  );
                },
              )
            : isVideo
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Colors.black87,
                      ),
                      Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          size: 36,
                          color: AppTheme.primaryWhite.withOpacity(0.9),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      Icons.attach_file,
                      color: AppTheme.primaryWhite.withOpacity(0.5),
                      size: 32,
                    ),
                  ),
      ),
    );
  }

  /// Abbreviate long names to prevent overflow on mobile
  String _abbreviateName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 1) return fullName;

    // If name is short enough, return as is
    if (fullName.length <= 20) return fullName;

    // Return first name + last initial (e.g., "John Doe" -> "John D.")
    final firstName = parts.first;
    final lastInitial = parts.last[0].toUpperCase();
    return '$firstName $lastInitial.';
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  Widget _buildStatusBadge(BugStatus status) {
    Color color;
    String label;

    switch (status) {
      case BugStatus.OPEN:
        color = Colors.green;
        label = 'OPEN';
        break;
      case BugStatus.IN_PROGRESS:
        color = Colors.orange;
        label = 'IN PROGRESS';
        break;
      case BugStatus.RESOLVED:
        color = Colors.blue;
        label = 'RESOLVED';
        break;
      case BugStatus.CLOSED:
        color = Colors.grey;
        label = 'CLOSED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getPlatformIcon(Platform platform) {
    switch (platform) {
      case Platform.WINDOWS:
        return Icons.desktop_windows;
      case Platform.MACOS:
        return Icons.laptop_mac;
      case Platform.LINUX:
        return Icons.computer;
      case Platform.ANDROID:
        return Icons.android;
      case Platform.IOS:
        return Icons.phone_iphone;
      case Platform.WEB:
        return Icons.web;
    }
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.primaryBlack,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Status',
              style: TextStyle(
                color: AppTheme.primaryWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusOption('All', null),
            _buildStatusOption('Open', 'OPEN'),
            _buildStatusOption('In Progress', 'IN_PROGRESS'),
            _buildStatusOption('Resolved', 'RESOLVED'),
            _buildStatusOption('Closed', 'CLOSED'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(String label, String? value) {
    final isSelected = _selectedStatus == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryWhite : AppTheme.primaryWhite.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryWhite) : null,
      onTap: () {
        setState(() => _selectedStatus = value);
        Navigator.pop(context);
        _loadBugReports();
      },
    );
  }

  void _showPlatformFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.primaryBlack,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Platform',
              style: TextStyle(
                color: AppTheme.primaryWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPlatformOption('All', null),
            _buildPlatformOption('Windows', 'WINDOWS'),
            _buildPlatformOption('Linux', 'LINUX'),
            _buildPlatformOption('macOS', 'MACOS'),
            _buildPlatformOption('Android', 'ANDROID'),
            _buildPlatformOption('iOS', 'IOS'),
            _buildPlatformOption('Web', 'WEB'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformOption(String label, String? value) {
    final isSelected = _selectedPlatform == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryWhite : AppTheme.primaryWhite.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryWhite) : null,
      onTap: () {
        setState(() => _selectedPlatform = value);
        Navigator.pop(context);
        _loadBugReports();
      },
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.primaryBlack,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(
                color: AppTheme.primaryWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption('Most Liked', 'likeCount', 'desc'),
            _buildSortOption('Newest First', 'createdAt', 'desc'),
            _buildSortOption('Oldest First', 'createdAt', 'asc'),
            _buildSortOption('Recently Updated', 'updatedAt', 'desc'),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String sortBy, String order) {
    final isSelected = _sortBy == sortBy && _order == order;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryWhite : AppTheme.primaryWhite.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryWhite) : null,
      onTap: () {
        setState(() {
          _sortBy = sortBy;
          _order = order;
        });
        Navigator.pop(context);
        _loadBugReports();
      },
    );
  }
}
