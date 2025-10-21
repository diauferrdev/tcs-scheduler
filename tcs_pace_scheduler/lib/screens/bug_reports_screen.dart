import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bug_report.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/theme.dart';
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
    if (result == true) {
      _loadBugReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.user?.role == 'ADMIN';
    final isManager = authProvider.user?.role == 'MANAGER';

    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlack,
        elevation: 0,
        title: const Text(
          'Bug Reports',
          style: TextStyle(
            color: AppTheme.primaryWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryWhite),
            onPressed: _loadBugReports,
          ),
          if (_selectedStatus != null || _selectedPlatform != null || _searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: AppTheme.primaryWhite),
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
            color: AppTheme.primaryBlack,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.primaryWhite),
              decoration: InputDecoration(
                hintText: 'Search by title or description...',
                hintStyle: TextStyle(color: AppTheme.primaryWhite.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryWhite),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.primaryWhite),
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
    return Card(
      color: AppTheme.primaryWhite.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToBugDetail(bug),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status Badge + Platform
              Row(
                children: [
                  _buildStatusBadge(bug.status),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryWhite.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getPlatformIcon(bug.platform), size: 14, color: AppTheme.primaryWhite),
                        const SizedBox(width: 4),
                        Text(
                          bug.platformDisplay,
                          style: const TextStyle(
                            color: AppTheme.primaryWhite,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Like Count
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: bug.likeCount > 0 ? Colors.red : AppTheme.primaryWhite.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${bug.likeCount}',
                        style: TextStyle(
                          color: bug.likeCount > 0 ? Colors.red : AppTheme.primaryWhite.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                bug.title,
                style: const TextStyle(
                  color: AppTheme.primaryWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Description (truncated)
              Text(
                bug.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.primaryWhite.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 12),

              // Footer: Reporter + Date + Attachments
              Row(
                children: [
                  // Reporter
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primaryWhite.withOpacity(0.2),
                          backgroundImage: bug.reportedBy.avatarUrl != null
                              ? NetworkImage(bug.reportedBy.avatarUrl!)
                              : null,
                          child: bug.reportedBy.avatarUrl == null
                              ? Text(
                                  bug.reportedBy.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.primaryWhite,
                                    fontSize: 10,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            bug.reportedBy.name,
                            style: TextStyle(
                              color: AppTheme.primaryWhite.withOpacity(0.6),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Attachments count
                  if (bug.attachments.isNotEmpty) ...[
                    Icon(
                      Icons.attach_file,
                      size: 14,
                      color: AppTheme.primaryWhite.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${bug.attachments.length}',
                      style: TextStyle(
                        color: AppTheme.primaryWhite.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Date
                  Text(
                    _formatDate(bug.createdAt),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.name.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
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
