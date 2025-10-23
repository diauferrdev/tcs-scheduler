import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bug_report.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import 'bug_detail_screen.dart';
import 'create_bug_report_screen.dart';

class BugReportsScreen extends StatefulWidget {
  const BugReportsScreen({super.key});

  @override
  State<BugReportsScreen> createState() => _BugReportsScreenState();
}

class _BugReportsScreenState extends State<BugReportsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<BugReport> _bugReports = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String? _selectedStatus;
  String? _selectedPlatform;
  String _sortBy = 'likeCount';
  String _order = 'desc';

  @override
  void initState() {
    super.initState();
    _loadBugReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      setState(() {
        _bugReports = bugsList.map((json) => BugReport.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load bug reports: $e';
        _isLoading = false;
      });
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
    final isAdmin = authProvider.user?.role == 'ADMIN';
    final isManager = authProvider.user?.role == 'MANAGER';

    final backgroundColor = themeProvider.isDark ? AppTheme.primaryBlack : const Color(0xFFF9FAFB);
    final textColor = themeProvider.isDark ? AppTheme.primaryWhite : Colors.black;
    final cardColor = themeProvider.isDark ? AppTheme.primaryWhite.withOpacity(0.05) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _loadBugReports,
          ),
          if (_selectedStatus != null || _selectedPlatform != null || _searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.filter_alt_off, color: textColor),
              onPressed: _clearFilters,
              tooltip: 'Clear Filters',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: backgroundColor,
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
                ),
                const SizedBox(width: 8),

                // Platform Filter
                _buildFilterChip(
                  label: _selectedPlatform == null ? 'All Platforms' : _selectedPlatform!,
                  isActive: _selectedPlatform != null,
                  onTap: () => _showPlatformFilter(),
                ),
                const SizedBox(width: 8),

                // Sort Filter
                _buildFilterChip(
                  label: _sortBy == 'likeCount' ? 'Most Liked' : _sortBy == 'createdAt' ? 'Newest' : 'Recent',
                  isActive: true,
                  onTap: () => _showSortOptions(),
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
                                return _buildBugCard(bug);
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateBug,
        backgroundColor: AppTheme.primaryWhite,
        foregroundColor: AppTheme.primaryBlack,
        icon: const Icon(Icons.add),
        label: const Text('Report Bug'),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(label),
        backgroundColor: isActive
            ? AppTheme.primaryWhite.withOpacity(0.2)
            : AppTheme.primaryWhite.withOpacity(0.1),
        labelStyle: TextStyle(
          color: AppTheme.primaryWhite,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isActive ? AppTheme.primaryWhite : Colors.transparent,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildBugCard(BugReport bug) {
    final hasAttachments = bug.attachments.isNotEmpty;
    final commentCount = bug.commentCount ?? bug.comments?.length ?? 0;
    final timeAgo = _formatTimeAgo(bug.createdAt);

    return Card(
      color: AppTheme.primaryWhite.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToBugDetail(bug),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Upvote column (Discord style)
              Column(
                children: [
                  Icon(
                    Icons.thumb_up,
                    size: 20,
                    color: bug.likeCount > 0 ? Colors.blue : AppTheme.primaryWhite.withOpacity(0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bug.likeCount}',
                    style: TextStyle(
                      color: bug.likeCount > 0 ? Colors.blue : AppTheme.primaryWhite.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // Middle: Content
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
                            color: AppTheme.primaryWhite.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getPlatformIcon(bug.platform), size: 12, color: AppTheme.primaryWhite),
                              const SizedBox(width: 4),
                              Text(
                                bug.platformDisplay,
                                style: const TextStyle(
                                  color: AppTheme.primaryWhite,
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
                              color: Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, size: 12, color: Colors.purple),
                                const SizedBox(width: 2),
                                Text(
                                  '${bug.attachments.length}',
                                  style: const TextStyle(
                                    color: Colors.purple,
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
                      style: const TextStyle(
                        color: AppTheme.primaryWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Description preview
                    Text(
                      bug.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.primaryWhite.withOpacity(0.6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Footer: Author + Time + Stats
                    Row(
                      children: [
                        // Author avatar
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppTheme.primaryWhite.withOpacity(0.2),
                          backgroundImage: bug.reportedBy.avatarUrl != null
                              ? NetworkImage(bug.reportedBy.avatarUrl!)
                              : null,
                          child: bug.reportedBy.avatarUrl == null
                              ? Text(
                                  bug.reportedBy.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.primaryWhite,
                                    fontSize: 9,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        // Author name + time
                        Text(
                          '${bug.reportedBy.name} • $timeAgo',
                          style: TextStyle(
                            color: AppTheme.primaryWhite.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // Comment count with icon (always visible, Discord style)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryWhite.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 14,
                                color: AppTheme.primaryWhite.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$commentCount',
                                style: TextStyle(
                                  color: AppTheme.primaryWhite.withOpacity(0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
      ),
    );
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
