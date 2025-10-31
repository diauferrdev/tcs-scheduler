import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

// AppTheme is defined in theme_provider.dart
class AppTheme {
  static const Color primaryBlack = Color(0xFF000000);
  static const Color primaryWhite = Color(0xFFFFFFFF);
}

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final TextEditingController _searchController = TextEditingController();

  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String? _errorMessage;

  TicketStatus? _selectedStatus;
  TicketPriority? _selectedPriority;
  TicketCategory? _selectedCategory;

  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;

    if (userId != null) {
      _ws.connect(userId);
      _wsSubscription = _ws.messages.listen((message) {
        if (!mounted) return;
        final type = message['type'] as String?;
        if (type == 'ticket_created' || type == 'ticket_updated' || type == 'ticket_message') {
          _loadTickets();
        }
      });
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final params = <String>[];
      if (_selectedStatus != null) params.add('status=${_selectedStatus.toString().split('.').last}');
      if (_selectedPriority != null) params.add('priority=${_selectedPriority.toString().split('.').last}');
      if (_selectedCategory != null) params.add('category=${_selectedCategory.toString().split('.').last}');
      if (_searchController.text.isNotEmpty) params.add('search=${Uri.encodeComponent(_searchController.text)}');

      final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
      final response = await _api.get('/api/tickets$queryString');
      final List<dynamic> data = response is List ? response : (response['data'] ?? response);

      if (!mounted) return;

      setState(() {
        _tickets = data.map((json) => Ticket.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedPriority = null;
      _selectedCategory = null;
      _searchController.clear();
    });
    _loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = themeProvider.isDark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              // Search
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
                          hintText: 'Search tickets...',
                          hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.search, color: textColor),
                          filled: true,
                          fillColor: AppTheme.primaryWhite.withOpacity(0.1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _loadTickets(),
                      ),
                    ),
                    if (_selectedStatus != null || _selectedPriority != null || _selectedCategory != null) ...[
                      const SizedBox(width: 8),
                      IconButton(icon: Icon(Icons.filter_alt_off, color: textColor), onPressed: _clearFilters),
                    ],
                  ],
                ),
              ),

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryWhite))
                    : _errorMessage != null
                        ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                        : _tickets.isEmpty
                            ? Center(child: Icon(Icons.support_agent, size: 64, color: textColor.withOpacity(0.3)))
                            : RefreshIndicator(
                                onRefresh: _loadTickets,
                                color: AppTheme.primaryWhite,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _tickets.length,
                                  itemBuilder: (context, index) {
                                    final ticket = _tickets[index];
                                    return _buildTicketCard(ticket, isDark, user);
                                  },
                                ),
                              ),
              ),
            ],
          ),
          // Only show "New Ticket" button for non-admin users
          // Admins should only respond to tickets, not create them
          if (user.role != UserRole.ADMIN)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () => context.push('/app/support/create').then((_) => _loadTickets()),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.add),
                label: const Text('New Ticket', style: TextStyle(fontWeight: FontWeight.w600)),
                elevation: 4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(Ticket ticket, bool isDark, User user) {
    Color statusColor = Colors.blue;
    if (ticket.status == TicketStatus.RESOLVED) statusColor = Colors.green;
    if (ticket.status == TicketStatus.CLOSED) statusColor = Colors.grey;

    // Format date
    final now = DateTime.now();
    final diff = now.difference(ticket.createdAt);
    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'just now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      timeAgo = '${diff.inDays}d ago';
    } else {
      timeAgo = '${(diff.inDays / 7).floor()}w ago';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF18181B) : Colors.white,
      child: InkWell(
        onTap: () => context.push('/app/support/${ticket.id}').then((_) => _loadTickets()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text(ticket.getStatusLabel(), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(ticket.getCategoryLabel(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Text(ticket.title, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(ticket.description, style: const TextStyle(color: Colors.grey, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (ticket.createdBy.avatarUrl != null)
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: NetworkImage(ticket.createdBy.avatarUrl!),
                    ),
                  if (ticket.createdBy.avatarUrl == null)
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey.shade300,
                      child: Text(
                        ticket.createdBy.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    ticket.createdBy.name,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• $timeAgo',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
