import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

// Helper to get full avatar URL
String _getAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return '';
  if (avatarUrl.startsWith('http')) return avatarUrl;
  return 'https://api.ppspsched.lat$avatarUrl';
}

class AppTheme {
  static const Color primaryBlack = Color(0xFF000000);
  static const Color primaryWhite = Color(0xFFFFFFFF);
}

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
  final WebSocketService _ws = WebSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Ticket? _ticket;
  bool _isLoading = true;
  bool _isSendingMessage = false;
  String? _errorMessage;

  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadTicket();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;

    if (userId != null) {
      _ws.connect(userId);
      _wsSubscription = _ws.messages.listen((message) {
        if (!mounted) return;
        debugPrint('[TicketDetail] WS Message: $message');

        final type = message['type'] as String?;

        if (type == 'ticket_message') {
          final data = message['data'];
          final ticketId = data?['ticketId'] as String?;

          if (ticketId == widget.ticketId) {
            // Add message to the list in real-time without reloading
            try {
              final newMessage = TicketMessage.fromJson(data);
              setState(() {
                if (_ticket != null) {
                  // Check if message already exists to avoid duplicates
                  final exists = _ticket!.messages.any((m) => m.id == newMessage.id);
                  if (!exists) {
                    _ticket!.messages.add(newMessage);
                    // Auto-scroll to bottom
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          _scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                  }
                }
              });
            } catch (e) {
              debugPrint('[TicketDetail] Error parsing message: $e');
            }
          }
        } else if (type == 'ticket_updated') {
          // Reload full ticket for other updates
          _loadTicket();
        }
      });
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.get('/api/tickets/${widget.ticketId}');
      debugPrint('[TicketDetail] Response: $response');

      if (!mounted) return;

      try {
        final ticket = Ticket.fromJson(response);
        debugPrint('[TicketDetail] ✅ Ticket parsed successfully: ${ticket.id}');
        debugPrint('[TicketDetail] Messages count: ${ticket.messages.length}');

        setState(() {
          _ticket = ticket;
          _isLoading = false;
        });

        // Scroll to bottom after loading messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (parseError, stackTrace) {
        debugPrint('[TicketDetail] ❌ Parse error: $parseError');
        debugPrint('[TicketDetail] Stack trace: $stackTrace');
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error parsing ticket: $parseError';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[TicketDetail] ❌ API error: $e');
      debugPrint('[TicketDetail] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text;
    _messageController.clear();

    setState(() {
      _isSendingMessage = true;
    });

    try {
      await _api.post('/api/tickets/${widget.ticketId}/messages', {
        'content': messageText,
      });

      if (!mounted) return;

      // Message will arrive via WebSocket, no need to reload
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  Future<void> _updateTicketStatus(TicketStatus newStatus) async {
    try {
      await _api.patch('/api/tickets/${widget.ticketId}', {
        'status': newStatus.toString().split('.').last,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket status updated')),
      );

      await _loadTicket();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
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
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF18181B) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Ticket Details',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_ticket != null && user.role == UserRole.ADMIN)
            PopupMenuButton<TicketStatus>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: _updateTicketStatus,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: TicketStatus.OPEN,
                  child: Text('Mark as Open'),
                ),
                const PopupMenuItem(
                  value: TicketStatus.IN_PROGRESS,
                  child: Text('Mark as In Progress'),
                ),
                const PopupMenuItem(
                  value: TicketStatus.WAITING_USER,
                  child: Text('Waiting for User'),
                ),
                const PopupMenuItem(
                  value: TicketStatus.WAITING_ADMIN,
                  child: Text('Waiting for Support'),
                ),
                const PopupMenuItem(
                  value: TicketStatus.RESOLVED,
                  child: Text('Mark as Resolved'),
                ),
                const PopupMenuItem(
                  value: TicketStatus.CLOSED,
                  child: Text('Close Ticket'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryWhite))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _ticket == null
                  ? const Center(child: Text('Ticket not found'))
                  : Column(
                      children: [
                        // Ticket Header
                        Container(
                          padding: const EdgeInsets.all(24),
                          color: backgroundColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildStatusBadge(_ticket!.status, isDark),
                                  const SizedBox(width: 12),
                                  _buildPriorityBadge(_ticket!.priority),
                                  const Spacer(),
                                  Text(
                                    _ticket!.getCategoryLabel(),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _ticket!.title,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _ticket!.description,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Created ${_formatDate(_ticket!.createdAt)} by ${_ticket!.createdBy.name}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // Messages
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black : Colors.white,
                            ),
                            child: _ticket!.messages.isEmpty
                                ? Center(
                                    child: Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.5),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _ticket!.messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _ticket!.messages[index];
                                    final isCurrentUser = message.author.id == user.id;

                                    // Check if should show avatar (not grouped with previous)
                                    bool showAvatar = true;
                                    if (index > 0) {
                                      final prevMessage = _ticket!.messages[index - 1];
                                      final isSameAuthor = prevMessage.author.id == message.author.id;
                                      final timeDiff = message.createdAt.difference(prevMessage.createdAt);
                                      // Group if same author and within 5 minutes
                                      if (isSameAuthor && timeDiff.inMinutes < 5) {
                                        showAvatar = false;
                                      }
                                    }

                                    return _buildMessageBubble(
                                      message,
                                      isCurrentUser,
                                      isDark,
                                      showAvatar,
                                    );
                                  },
                                ),
                          ),
                        ),

                        // Message Input
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: TextStyle(color: textColor),
                                  maxLines: null,
                                  decoration: InputDecoration(
                                    hintText: 'Type a message...',
                                    hintStyle: TextStyle(
                                      color: textColor.withOpacity(0.5),
                                    ),
                                    filled: true,
                                    fillColor: backgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: _isSendingMessage
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.send,
                                          color: Colors.black,
                                        ),
                                  onPressed: _isSendingMessage ? null : _sendMessage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildMessageAvatar(String? avatarUrl, String name) {
    final fullUrl = _getAvatarUrl(avatarUrl);

    if (fullUrl.isEmpty) {
      return CircleAvatar(
        radius: 10,
        backgroundColor: Colors.grey.shade300,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      );
    }

    return CircleAvatar(
      radius: 10,
      backgroundImage: NetworkImage(fullUrl),
      onBackgroundImageError: (_, __) {},
      child: Container(),
    );
  }

  Widget _buildStatusBadge(TicketStatus status, bool isDark) {
    Color color = Colors.blue;
    if (status == TicketStatus.RESOLVED) color = Colors.green;
    if (status == TicketStatus.CLOSED) color = Colors.grey;
    if (status == TicketStatus.WAITING_USER) color = Colors.orange;
    if (status == TicketStatus.IN_PROGRESS) color = Colors.purple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _ticket!.getStatusLabel(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(TicketPriority priority) {
    Color color = Colors.grey;
    if (priority == TicketPriority.HIGH) color = Colors.orange;
    if (priority == TicketPriority.URGENT) color = Colors.red;
    if (priority == TicketPriority.MEDIUM) color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _ticket!.getPriorityLabel(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    TicketMessage message,
    bool isCurrentUser,
    bool isDark,
    bool showAvatar, // Whether to show avatar (first message in group)
  ) {
    // Strict black and white brand colors
    // Light mode: ALL messages = black background with white text
    // Dark mode: ALL messages = white background with black text
    final bubbleColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.black : Colors.white;

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: showAvatar ? 12 : 3,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Message bubble
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isCurrentUser ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isCurrentUser ? Radius.zero : const Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display attachments if any
                  if (message.attachments.isNotEmpty) ...[
                    ...message.attachments.map((attachment) =>
                      _buildAttachmentPreview(attachment, isDark)
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Message content
                  Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // Time and checkmarks OUTSIDE the bubble
            Padding(
              padding: EdgeInsets.only(
                top: 2,
                left: isCurrentUser ? 0 : 12,
                right: isCurrentUser ? 12 : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                  // Read receipts for all messages
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: message.readAt != null
                        ? Colors.blue
                        : Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(TicketAttachment attachment, bool isDark) {
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].any(
      (ext) => attachment.fileName.toLowerCase().endsWith(ext),
    );
    final isVideo = ['mp4', 'webm', 'mov'].any(
      (ext) => attachment.fileName.toLowerCase().endsWith(ext),
    );

    if (isImage) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        constraints: const BoxConstraints(maxHeight: 250, maxWidth: 250),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            _getAvatarUrl(attachment.fileUrl),
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: Colors.black12,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 100,
                color: Colors.black12,
                child: const Center(
                  child: Icon(Icons.broken_image, size: 32, color: Colors.black38),
                ),
              );
            },
          ),
        ),
      );
    }

    // For videos and other files, show a compact link
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.play_circle_filled : Icons.insert_drive_file,
            size: 18,
            color: Colors.black54,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              attachment.fileName,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'today at ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays == 1) {
      return 'yesterday at ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('MMM dd, HH:mm').format(date);
    }
  }
}
