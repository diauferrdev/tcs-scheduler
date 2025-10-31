import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/activity_log.dart';

class ActivityLogsScreen extends StatefulWidget {
  final bool skipLayout;

  const ActivityLogsScreen({super.key, this.skipLayout = false});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<ActivityLog> _logs = [];
  bool _loading = true;
  String? _error;
  int _total = 0;
  int _offset = 0;
  final int _limit = 20;

  String? _selectedAction;
  String? _selectedResource;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs({bool append = false}) async {
    try {
      setState(() {
        if (!append) {
          _loading = true;
          _offset = 0;
        }
        _error = null;
      });

      final response = await _apiService.getActivityLogs(
        action: _selectedAction,
        resource: _selectedResource,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        limit: _limit,
        offset: append ? _offset : 0,
      );

      final data = response is List
          ? response
          : (response['logs'] as List? ?? response['data'] as List? ?? []);
      final total = response is Map ? (response['total'] as int? ?? data.length) : data.length;

      final newLogs = data.map((e) => ActivityLog.fromJson(e)).toList();

      setState(() {
        if (append) {
          _logs.addAll(newLogs);
        } else {
          _logs = newLogs;
        }
        _total = total;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _loadMore() {
    if (_logs.length < _total && !_loading) {
      setState(() => _offset = _logs.length);
      _loadLogs(append: true);
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedAction = null;
      _selectedResource = null;
      _searchController.clear();
    });
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final content = Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedAction != null || _selectedResource != null || _searchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  ),

                // Search
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search by description...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadLogs();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _loadLogs(),
                ),
                const SizedBox(height: 16),

                // Filters
                Row(
                  children: [
                    // Action Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: DropdownButton<String?>(
                          value: _selectedAction,
                          hint: Text(
                            'Action',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          isExpanded: true,
                          underline: Container(),
                          dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'All Actions',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            ...ActivityAction.values.map((action) {
                              return DropdownMenuItem(
                                value: action.name,
                                child: Text(action.name),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedAction = value);
                            _loadLogs();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Resource Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: DropdownButton<String?>(
                          value: _selectedResource,
                          hint: Text(
                            'Resource',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          isExpanded: true,
                          underline: Container(),
                          dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                'All Resources',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            ...ActivityResource.values.map((resource) {
                              return DropdownMenuItem(
                                value: resource.name,
                                child: Text(resource.name),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedResource = value);
                            _loadLogs();
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Results count
                if (!_loading && _logs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Showing ${_logs.length} of $_total logs',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading && _logs.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadLogs,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _logs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 64,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No activity logs found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadLogs(),
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 24,
                                vertical: 8,
                              ),
                              itemCount: _logs.length + (_logs.length < _total ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _logs.length) {
                                  // Load more button
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: _loading
                                          ? CircularProgressIndicator(
                                              color: isDark ? Colors.white : Colors.black,
                                            )
                                          : ElevatedButton(
                                              onPressed: _loadMore,
                                              child: const Text('Load More'),
                                            ),
                                    ),
                                  );
                                }
                                return _buildLogCard(_logs[index], isDark, isMobile);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );

    return widget.skipLayout ? content : AppLayout(child: content);
  }

  Widget _buildLogCard(ActivityLog log, bool isDark, bool isMobile) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm:ss');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
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
              // Action Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getActionColor(log.action).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getActionIcon(log.action),
                      size: 14,
                      color: _getActionColor(log.action),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      log.action.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getActionColor(log.action),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Resource Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.resource.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),

              const Spacer(),

              // Timestamp
              Text(
                dateFormat.format(log.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            log.description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),

          // User info
          if (log.user != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  log.user!.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${log.user!.email})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ],

          // IP Address
          if (log.ipAddress != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  log.ipAddress!,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getActionColor(ActivityAction action) {
    switch (action) {
      case ActivityAction.CREATE:
        return Colors.green;
      case ActivityAction.UPDATE:
        return Colors.blue;
      case ActivityAction.DELETE:
        return Colors.red;
      case ActivityAction.LOGIN:
        return Colors.purple;
      case ActivityAction.LOGOUT:
        return Colors.orange;
      case ActivityAction.VIEW:
        return Colors.grey;
    }
  }

  IconData _getActionIcon(ActivityAction action) {
    switch (action) {
      case ActivityAction.CREATE:
        return Icons.add_circle;
      case ActivityAction.UPDATE:
        return Icons.edit;
      case ActivityAction.DELETE:
        return Icons.delete;
      case ActivityAction.LOGIN:
        return Icons.login;
      case ActivityAction.LOGOUT:
        return Icons.logout;
      case ActivityAction.VIEW:
        return Icons.visibility;
    }
  }
}
