import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../widgets/ticket_chat_widget.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final ApiService _api = ApiService();
  Ticket? _ticket;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTicketHeader();
  }

  Future<void> _loadTicketHeader() async {
    try {
      final response = await _api.get('/api/tickets/${widget.ticketId}');
      if (!mounted) return;

      final ticket = Ticket.fromJson(response);
      setState(() {
        _ticket = ticket;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onTicketUpdated(Ticket updatedTicket) {
    if (mounted) {
      setState(() {
        _ticket = updatedTicket;
      });
    }
  }

  void _showTicketDetailsDrawer(BuildContext context) {
    if (_ticket == null) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: textColor, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Ticket Details',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                height: 1,
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Title
                    Text(
                      'Title',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ticket!.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    Text(
                      'Description',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ticket!.description,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Metadata chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoChip('Status', _getStatusLabel(_ticket!.status), isDark, textColor),
                        _buildInfoChip('Priority', _ticket!.priority.toString().split('.').last, isDark, textColor),
                        _buildInfoChip('Category', _ticket!.category.toString().split('.').last, isDark, textColor),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDark;
    final textColor = isDark ? Colors.white : Colors.black;
    final isAdmin = authProvider.user?.role == UserRole.ADMIN;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.go('/app/support'),
        ),
        title: _isLoading
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ticket?.title ?? 'Ticket',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _getStatusLabel(_ticket?.status),
                    style: TextStyle(
                      color: _getStatusColor(_ticket?.status),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: textColor),
            onPressed: () => _showTicketDetailsDrawer(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TicketChatWidget(
              ticketId: widget.ticketId,
              onTicketUpdated: _onTicketUpdated,
              isAdminView: isAdmin,
            ),
    );
  }

  Widget _buildInfoChip(String label, String value, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(TicketStatus? status) {
    if (status == null) return '';
    switch (status) {
      case TicketStatus.OPEN:
        return 'Open';
      case TicketStatus.IN_PROGRESS:
        return 'In Progress';
      case TicketStatus.WAITING_USER:
        return 'Waiting for You';
      case TicketStatus.WAITING_ADMIN:
        return 'Waiting for Support';
      case TicketStatus.RESOLVED:
        return 'Resolved';
      case TicketStatus.CLOSED:
        return 'Closed';
    }
  }

  Color _getStatusColor(TicketStatus? status) {
    if (status == null) return Colors.grey;
    switch (status) {
      case TicketStatus.OPEN:
        return Colors.blue;
      case TicketStatus.IN_PROGRESS:
        return Colors.orange;
      case TicketStatus.WAITING_USER:
        return Colors.amber;
      case TicketStatus.WAITING_ADMIN:
        return Colors.purple;
      case TicketStatus.RESOLVED:
        return Colors.green;
      case TicketStatus.CLOSED:
        return Colors.grey;
    }
  }

}
