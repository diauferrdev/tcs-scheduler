import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/ticket_chat_widget.dart';

// Helper to get full avatar URL
String _getAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return '';
  if (avatarUrl.startsWith('http')) return avatarUrl;
  return 'https://api.ppspsched.lat$avatarUrl';
}

class TicketsAdminView extends StatefulWidget {
  const TicketsAdminView({super.key});

  @override
  State<TicketsAdminView> createState() => _TicketsAdminViewState();
}

class _TicketsAdminViewState extends State<TicketsAdminView> {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final TextEditingController _searchController = TextEditingController();

  List<Ticket> _tickets = [];
  Ticket? _selectedTicket;
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint('[AdminTickets] 🟢 INIT - AdminView created, _selectedTicket: ${_selectedTicket?.id ?? "null"}');
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
        debugPrint('[AdminView] WS Message: $message');
        final type = message['type'] as String?;

        if (type == 'ticket_message') {
          // Handle ticket message - update locally for instant badge update
          final data = message['data'];
          if (data != null) {
            try {
              final newMessage = TicketMessage.fromJson(data);
              final ticketId = newMessage.ticketId;

              setState(() {
                final ticketIndex = _tickets.indexWhere((t) => t.id == ticketId);
                if (ticketIndex != -1) {
                  final oldTicket = _tickets[ticketIndex];
                  final messageExists = oldTicket.messages.any((m) => m.id == newMessage.id);

                  if (!messageExists) {
                    // Create NEW messages list with the new message added
                    final updatedMessages = List<TicketMessage>.from(oldTicket.messages)..add(newMessage);
                    updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                    // Create completely NEW ticket object to trigger rebuild
                    _tickets[ticketIndex] = Ticket(
                      id: oldTicket.id,
                      title: oldTicket.title,
                      description: oldTicket.description,
                      status: oldTicket.status,
                      priority: oldTicket.priority,
                      category: oldTicket.category,
                      platform: oldTicket.platform,
                      createdBy: oldTicket.createdBy,
                      assignedTo: oldTicket.assignedTo,
                      createdAt: oldTicket.createdAt,
                      updatedAt: oldTicket.updatedAt,
                      closedAt: oldTicket.closedAt,
                      messages: updatedMessages,
                      attachments: oldTicket.attachments,
                      messageCount: oldTicket.messageCount,
                      attachmentCount: oldTicket.attachmentCount,
                    );

                    // Re-sort all tickets to maintain proper order
                    _sortTickets();

                    debugPrint('[AdminView] ✅ Badge updated for ticket $ticketId - new message added');
                  }
                }
              });
            } catch (e) {
              debugPrint('[AdminView] Error parsing message: $e');
              // Fallback to reload
              _loadTickets();
            }
          }
        } else if (type == 'ticket_created' || type == 'ticket_updated') {
          _loadTickets();
        } else if (type == 'message_read') {
          // Real-time read receipt update for badge counter
          final data = message['data'];
          debugPrint('[AdminView] 📨 message_read received: $data');

          if (data != null) {
            final ticketId = data['ticketId'] as String?;
            final messageId = data['messageId'] as String?;
            final readAt = data['readAt'] as String?;

            if (ticketId != null && messageId != null && readAt != null) {
              setState(() {
                final ticketIndex = _tickets.indexWhere((t) => t.id == ticketId);
                debugPrint('[AdminView] Looking for ticket $ticketId, found at index: $ticketIndex');

                if (ticketIndex != -1) {
                  final oldTicket = _tickets[ticketIndex];
                  final msgIndex = oldTicket.messages.indexWhere((m) => m.id == messageId);
                  debugPrint('[AdminView] Looking for message $messageId in ticket, found at index: $msgIndex');

                  if (msgIndex != -1) {
                    // Create NEW messages list with updated readAt
                    final updatedMessages = List<TicketMessage>.from(oldTicket.messages);
                    updatedMessages[msgIndex] = TicketMessage(
                      id: updatedMessages[msgIndex].id,
                      content: updatedMessages[msgIndex].content,
                      isInternal: updatedMessages[msgIndex].isInternal,
                      ticketId: updatedMessages[msgIndex].ticketId,
                      author: updatedMessages[msgIndex].author,
                      createdAt: updatedMessages[msgIndex].createdAt,
                      updatedAt: updatedMessages[msgIndex].updatedAt,
                      readAt: DateTime.parse(readAt),
                      attachments: updatedMessages[msgIndex].attachments,
                    );

                    // Create completely NEW ticket object to trigger rebuild and badge update
                    _tickets[ticketIndex] = Ticket(
                      id: oldTicket.id,
                      title: oldTicket.title,
                      description: oldTicket.description,
                      status: oldTicket.status,
                      priority: oldTicket.priority,
                      category: oldTicket.category,
                      platform: oldTicket.platform,
                      createdBy: oldTicket.createdBy,
                      assignedTo: oldTicket.assignedTo,
                      createdAt: oldTicket.createdAt,
                      updatedAt: oldTicket.updatedAt,
                      closedAt: oldTicket.closedAt,
                      messages: updatedMessages,
                      attachments: oldTicket.attachments,
                      messageCount: oldTicket.messageCount,
                      attachmentCount: oldTicket.attachmentCount,
                    );

                    debugPrint('[AdminView] ✅ Badge updated for ticket $ticketId after marking message $messageId as read');
                  } else {
                    debugPrint('[AdminView] ⚠️ Message $messageId not found in ticket $ticketId messages');
                  }
                } else {
                  debugPrint('[AdminView] ⚠️ Ticket $ticketId not found in list');
                }
              });
            }
          }
        } else if (type == 'ticket_read') {
          // Update ticket locally to reflect read status changes (badge update)
          final data = message['data'];
          if (data != null) {
            try {
              final updatedTicket = Ticket.fromJson(data);
              setState(() {
                final ticketIndex = _tickets.indexWhere((t) => t.id == updatedTicket.id);
                if (ticketIndex != -1) {
                  // Update readAt timestamps in messages
                  for (final updatedMsg in updatedTicket.messages) {
                    final existingMsgIndex = _tickets[ticketIndex].messages.indexWhere((m) => m.id == updatedMsg.id);
                    if (existingMsgIndex != -1) {
                      _tickets[ticketIndex].messages[existingMsgIndex] = updatedMsg;
                    }
                  }
                  debugPrint('[AdminView] ✅ Updated readAt for ticket ${updatedTicket.id}');
                }
              });
            } catch (e) {
              debugPrint('[AdminView] Error updating ticket_read: $e');
            }
          }
        } else if (type == 'mark_as_read_success') {
          // Just log success, no action needed in admin view
          debugPrint('[AdminView] ✅ Messages marked as read');
        }
      });
    }
  }

  @override
  void dispose() {
    debugPrint('[AdminTickets] 🔴 DISPOSE - AdminView destroyed, _selectedTicket was: ${_selectedTicket?.id ?? "null"}');
    _wsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _sortTickets() {
    // Separate active and finished tickets
    final activeTickets = _tickets.where((t) =>
      t.status != TicketStatus.CLOSED && t.status != TicketStatus.RESOLVED
    ).toList();

    final finishedTickets = _tickets.where((t) =>
      t.status == TicketStatus.CLOSED || t.status == TicketStatus.RESOLVED
    ).toList();

    // Sort active tickets by last activity (most recent first)
    activeTickets.sort((a, b) {
      final aTime = a.messages.isNotEmpty ? a.messages.last.createdAt : a.createdAt;
      final bTime = b.messages.isNotEmpty ? b.messages.last.createdAt : b.createdAt;
      return bTime.compareTo(aTime); // Descending (newest first)
    });

    // Sort finished tickets by last activity (most recent first)
    finishedTickets.sort((a, b) {
      final aTime = a.messages.isNotEmpty ? a.messages.last.createdAt : a.createdAt;
      final bTime = b.messages.isNotEmpty ? b.messages.last.createdAt : b.createdAt;
      return bTime.compareTo(aTime); // Descending (newest first)
    });

    // Combine: active first, then finished
    _tickets = [...activeTickets, ...finishedTickets];
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;

    final isFirstLoad = _tickets.isEmpty;
    if (isFirstLoad) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final params = <String>[];
      if (_searchController.text.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(_searchController.text)}');
      }

      final queryString = params.isNotEmpty ? '?${params.join('&')}' : '';
      final response = await _api.get('/api/tickets$queryString');
      final List<dynamic> data = response is List ? response : (response['data'] ?? response);

      if (!mounted) return;

      setState(() {
        _tickets = data.map((json) => Ticket.fromJson(json)).toList();
        // Sort tickets: active first, then closed/resolved
        _sortTickets();
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

  int _getSeparatorCount(List<Ticket> tickets) {
    final activeCount = tickets.where((t) =>
      t.status != TicketStatus.CLOSED && t.status != TicketStatus.RESOLVED
    ).length;
    final finishedCount = tickets.length - activeCount;

    // Show separator only if both active and finished tickets exist
    return (activeCount > 0 && finishedCount > 0) ? 1 : 0;
  }

  Widget _buildSeparator(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.archive_outlined,
            size: 16,
            color: textColor.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 8),
          Text(
            'Archived Conversations',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _onTicketUpdated(Ticket updatedTicket) {
    if (mounted) {
      setState(() {
        // Update in list
        final index = _tickets.indexWhere((t) => t.id == updatedTicket.id);
        if (index != -1) {
          _tickets[index] = updatedTicket;
          _sortTickets();
        }
        // Update selected if it's the same ticket
        if (_selectedTicket?.id == updatedTicket.id) {
          _selectedTicket = updatedTicket;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: themeProvider.isDark ? Colors.black : Colors.white,
        body: Container(),
      );
    }

    final isDark = themeProvider.isDark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: isDesktop
          ? Row(
              children: [
                // LEFT: Tickets List (30%)
                Container(
                  width: MediaQuery.of(context).size.width * 0.3,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Search header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                          prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.6), size: 20),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _loadTickets(),
                      ),
                    ],
                  ),
                ),

                // Tickets List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                          : _tickets.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chat_bubble_outline, size: 64, color: textColor.withValues(alpha: 0.2)),
                                      const SizedBox(height: 16),
                                      Text('No tickets yet', style: TextStyle(color: textColor.withValues(alpha: 0.5))),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _tickets.length + _getSeparatorCount(_tickets),
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (context, index) {
                                    // Find separator position (between active and finished)
                                    final activeCount = _tickets.where((t) =>
                                      t.status != TicketStatus.CLOSED && t.status != TicketStatus.RESOLVED
                                    ).length;

                                    if (activeCount > 0 && index == activeCount) {
                                      // Separator between active and finished tickets
                                      return _buildSeparator(isDark, textColor);
                                    }

                                    // Adjust index if past separator
                                    final ticketIndex = index > activeCount ? index - 1 : index;
                                    final ticket = _tickets[ticketIndex];
                                    final isSelected = _selectedTicket?.id == ticket.id;
                                    return _buildTicketListItem(ticket, isSelected, isDark, user);
                                  },
                                ),
                ),
              ],
            ),
          ),

          // RIGHT: Chat Area (70%)
          Expanded(
            child: _selectedTicket == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined, size: 80, color: textColor.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'Select a ticket to view conversation',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : TicketChatWidget(
                    key: ValueKey(_selectedTicket!.id),
                    ticketId: _selectedTicket!.id,
                    onTicketUpdated: _onTicketUpdated,
                    isAdminView: true,
                    onBackPressed: () {
                      debugPrint('[AdminTickets] 🔙 Back pressed (desktop), deselecting ticket ${_selectedTicket?.id}');
                      setState(() {
                        _selectedTicket = null;
                      });
                      debugPrint('[AdminTickets] Selection is now: null');
                    },
                  ),
          ),
        ],
      )
          : _selectedTicket == null
              ? Column(
                  children: [
                    // Search header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Search...',
                              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                              prefixIcon: Icon(Icons.search, color: textColor.withValues(alpha: 0.6), size: 20),
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onSubmitted: (_) => _loadTickets(),
                          ),
                        ],
                      ),
                    ),

                    // Tickets List
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                              : _tickets.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.chat_bubble_outline, size: 64, color: textColor.withValues(alpha: 0.2)),
                                          const SizedBox(height: 16),
                                          Text('No tickets yet', style: TextStyle(color: textColor.withValues(alpha: 0.5))),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _tickets.length + _getSeparatorCount(_tickets),
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (context, index) {
                                        // Find separator position (between active and finished)
                                        final activeCount = _tickets.where((t) =>
                                          t.status != TicketStatus.CLOSED && t.status != TicketStatus.RESOLVED
                                        ).length;

                                        if (activeCount > 0 && index == activeCount) {
                                          // Separator between active and finished tickets
                                          return _buildSeparator(isDark, textColor);
                                        }

                                        // Adjust index if past separator
                                        final ticketIndex = index > activeCount ? index - 1 : index;
                                        final ticket = _tickets[ticketIndex];
                                        final isSelected = false; // No selection in mobile mode
                                        return _buildTicketListItem(ticket, isSelected, isDark, user, isMobile: true);
                                      },
                                    ),
                    ),
                  ],
                )
              : TicketChatWidget(
                  key: ValueKey(_selectedTicket!.id),
                  ticketId: _selectedTicket!.id,
                  onTicketUpdated: _onTicketUpdated,
                  isAdminView: true,
                  onBackPressed: () {
                    debugPrint('[AdminTickets] 🔙 Back pressed, deselecting ticket ${_selectedTicket?.id}');
                    setState(() {
                      _selectedTicket = null;
                    });
                    debugPrint('[AdminTickets] Selection is now: null');
                  },
                ),
    );
  }

  Widget _buildTicketListItem(Ticket ticket, bool isSelected, bool isDark, User user, {bool isMobile = false}) {
    final lastMessage = ticket.messages.isNotEmpty ? ticket.messages.last : null;

    // Show label based on attachment type
    String lastMessageText;
    if (lastMessage != null && lastMessage.attachments.isNotEmpty) {
      final attachment = lastMessage.attachments.first;

      // Recorded audio (fileName starts with "audio_") shows as [audio]
      // Everything else (uploaded via clip) shows as [attachment]
      if (attachment.mimeType.toLowerCase().startsWith('audio/') &&
          attachment.fileName.startsWith('audio_')) {
        lastMessageText = '[audio]';
      } else {
        lastMessageText = '[attachment]';
      }
    } else {
      lastMessageText = lastMessage?.content ?? ticket.description;
    }

    final lastMessageTime = lastMessage?.createdAt ?? ticket.createdAt;

    // Count ONLY unread messages from other users (not admins for this ticket)
    final unreadCount = ticket.messages.where((m) {
      // Only count messages from non-admin users that haven't been read yet
      return m.author.id != user.id && m.readAt == null;
    }).length;
    final hasUnread = unreadCount > 0;

    // Format time
    final now = DateTime.now();
    final diff = now.difference(lastMessageTime);
    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'now';
    } else if (diff.inHours < 1) {
      timeAgo = '${diff.inMinutes}m';
    } else if (diff.inDays < 1) {
      timeAgo = '${diff.inHours}h';
    } else if (diff.inDays == 1) {
      timeAgo = 'yesterday';
    } else if (diff.inDays < 7) {
      timeAgo = DateFormat('EEE').format(lastMessageTime);
    } else {
      timeAgo = DateFormat('MMM d').format(lastMessageTime);
    }

    return Material(
      color: isSelected
          ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          debugPrint('[AdminTickets] 🔘 Ticket tapped: ${ticket.id}, isMobile: $isMobile');
          debugPrint('[AdminTickets] Previous selection: ${_selectedTicket?.id ?? "null"}');
          setState(() {
            _selectedTicket = ticket;
          });
          debugPrint('[AdminTickets] New selection: ${_selectedTicket?.id}');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar with status badge
              _buildAvatar(ticket.createdBy.avatarUrl, ticket.createdBy.name, isDark, ticket.status),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticket.title,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: hasUnread
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.grey,
                            fontSize: 11,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Removed status badge from here - now it's on the avatar
                        Expanded(
                          child: Text(
                            lastMessageText,
                            style: TextStyle(
                              color: hasUnread
                                  ? (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.8))
                                  : Colors.grey,
                              fontSize: 13,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildAvatar(String? avatarUrl, String name, bool isDark, TicketStatus status) {
    final fullUrl = _getAvatarUrl(avatarUrl);

    Widget avatarWidget;
    if (fullUrl.isEmpty) {
      avatarWidget = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.white, Colors.grey.shade400]
                : [Colors.black, Colors.grey.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.black : Colors.white,
            ),
          ),
        ),
      );
    } else {
      avatarWidget = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
            width: 2,
          ),
          image: DecorationImage(
            image: NetworkImage(fullUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Add status badge overlay
    return Stack(
      children: [
        avatarWidget,
        Positioned(
          right: 0,
          bottom: 0,
          child: _buildStatusBadgeIconSmall(status),
        ),
      ],
    );
  }

  Widget _buildStatusBadgeIconSmall(TicketStatus status) {
    Color color = Colors.blue;
    IconData iconData = Icons.circle;

    if (status == TicketStatus.RESOLVED) {
      color = Colors.green;
      iconData = Icons.check_circle;
    } else if (status == TicketStatus.CLOSED) {
      color = Colors.grey;
      iconData = Icons.cancel;
    } else if (status == TicketStatus.WAITING_USER) {
      color = Colors.orange;
      iconData = Icons.schedule;
    } else if (status == TicketStatus.IN_PROGRESS) {
      color = Colors.purple;
      iconData = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        iconData,
        color: color,
        size: 14,
      ),
    );
  }

}
