import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:giphy_get/giphy_get.dart';
import '../models/ticket.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/attachment_picker_dialog.dart';
import '../widgets/media_fullscreen_viewer.dart';
import '../widgets/ticket_details_drawer.dart';
import '../widgets/audio_message_player.dart';
import '../widgets/video_message_player.dart' as video_player;
import '../widgets/audio_recording_button.dart';
import '../widgets/blob_helper_stub.dart'
    if (dart.library.html) '../widgets/blob_helper_web.dart';

/// WhatsApp-style ticket chat widget
class TicketChatWidget extends StatefulWidget {
  final String ticketId;
  final Function(Ticket)? onTicketUpdated;
  final bool isAdminView;
  final VoidCallback? onBackPressed;

  const TicketChatWidget({
    super.key,
    required this.ticketId,
    this.onTicketUpdated,
    this.isAdminView = false,
    this.onBackPressed,
  });

  @override
  State<TicketChatWidget> createState() => _TicketChatWidgetState();
}

class _TicketChatWidgetState extends State<TicketChatWidget> {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final TextEditingController _messageController = TextEditingController();
  late final ScrollController _scrollController;
  final FocusNode _messageFocusNode = FocusNode();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Ticket? _ticket;
  List<TicketMessage> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _isSendingMessage = false;
  bool _isListViewReady = false;
  bool _uploadingAttachment = false;
  bool _hasText = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  Timer? _recordingKeepAliveTimer;
  Timer? _typingTimer;
  Timer? _typingKeepAliveTimer;
  String? _errorMessage;

  // Real-time indicators
  bool _otherUserTyping = false;
  bool _otherUserRecording = false;

  // Optimistic updates
  final List<Map<String, dynamic>> _optimisticMessages = [];

  // Pagination
  static const int _messagesPerPage = 50;
  int _currentOffset = 0;

  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize scroll controller with position 0 (which is bottom when reverse: true)
    _scrollController = ScrollController(
      initialScrollOffset: 0.0,
      keepScrollOffset: false,
    );
    _loadTicketAndMessages();
    _setupWebSocket();
    _setupScrollListener();

    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    _recordingKeepAliveTimer?.cancel();
    _typingTimer?.cancel();
    _typingKeepAliveTimer?.cancel();
    _sendTypingIndicator(false); // Stop typing on dispose
    _sendRecordingIndicator(false); // Stop recording on dispose
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // With reverse: true, load more when near the END (top visually)
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMoreMessages) {
        _loadMoreMessages();
      }
    });
  }

  void _setupWebSocket() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;

    if (userId != null) {
      _ws.connect(userId);
      _wsSubscription = _ws.messages.listen((message) {
        if (!mounted) return;

        final type = message['type'] as String?;
        if (type == 'ticket_message') {
          final data = message['data'];
          if (data != null && data['ticketId'] == widget.ticketId) {
            try {
              final newMessage = TicketMessage.fromJson(data);
              _addMessageToList(newMessage);

              // Auto-mark as read since we're in the chat
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              if (newMessage.author.id != authProvider.user?.id) {
                debugPrint('[TicketChat] 📖 Auto-marking new message as read');
                _markSingleMessageAsRead(newMessage.id);
              }
            } catch (e) {
              debugPrint('[TicketChat] Error parsing message: $e');
            }
          }
        } else if (type == 'message_read') {
          // Real-time read receipts
          debugPrint('[TicketChat] 🔔 Received message_read: $message');
          final data = message['data'];
          if (data != null && data['ticketId'] == widget.ticketId) {
            final messageId = data['messageId'] as String?;
            final readAt = data['readAt'] as String?;

            if (messageId != null && readAt != null) {
              debugPrint('[TicketChat] ✅ Updating message $messageId as read');
              setState(() {
                final index = _messages.indexWhere((m) => m.id == messageId);
                if (index != -1) {
                  debugPrint('[TicketChat] ✅ Found message at index $index, updating readAt');
                  _messages[index] = TicketMessage(
                    id: _messages[index].id,
                    content: _messages[index].content,
                    isInternal: _messages[index].isInternal,
                    ticketId: _messages[index].ticketId,
                    author: _messages[index].author,
                    createdAt: _messages[index].createdAt,
                    updatedAt: _messages[index].updatedAt,
                    readAt: DateTime.parse(readAt),
                    attachments: _messages[index].attachments,
                  );
                } else {
                  debugPrint('[TicketChat] ❌ Message $messageId not found in list');
                }
              });
            }
          } else {
            debugPrint('[TicketChat] ❌ message_read ignored (wrong ticket or null data)');
          }
        } else if (type == 'user_typing') {
          // Real-time typing indicator
          debugPrint('[TicketChat] 🔔 Received user_typing: $message');
          final data = message['data'];
          if (data != null && data['ticketId'] == widget.ticketId) {
            final isTyping = data['isTyping'] == true;
            final userName = data['userName'] as String?;
            debugPrint('[TicketChat] ✅ Typing indicator: $userName is ${isTyping ? "typing" : "stopped"}');
            setState(() {
              _otherUserTyping = isTyping;
            });
          } else {
            debugPrint('[TicketChat] ❌ Typing indicator ignored (wrong ticket)');
          }
        } else if (type == 'user_recording') {
          // Real-time recording indicator
          debugPrint('[TicketChat] 🔔 Received user_recording: $message');
          final data = message['data'];
          if (data != null && data['ticketId'] == widget.ticketId) {
            final isRecording = data['isRecording'] == true;
            final userName = data['userName'] as String?;
            debugPrint('[TicketChat] ✅ Recording indicator: $userName is ${isRecording ? "recording" : "stopped"}');
            setState(() {
              _otherUserRecording = isRecording;
            });
          } else {
            debugPrint('[TicketChat] ❌ Recording indicator ignored (wrong ticket)');
          }
        } else if (type == 'ticket_updated') {
          _loadTicketAndMessages();
        }
      });
    }
  }

  void _addMessageToList(TicketMessage message) {
    // Check if message already exists - avoid duplicates
    if (_messages.any((m) => m.id == message.id)) {
      return;
    }

    // With reverse: true, pixels close to 0 means user is at bottom
    bool shouldAutoScroll = false;
    if (_scrollController.hasClients) {
      shouldAutoScroll = _scrollController.position.pixels < 100;
    } else {
      shouldAutoScroll = true;
    }

    setState(() {
      // Remove optimistic message if it exists
      _optimisticMessages.removeWhere((m) =>
        m['fileName'] == message.attachments.firstOrNull?.fileName ||
        m['content'] == message.content
      );

      // Add message and sort
      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });

    // With reverse ListView, it auto-adjusts - no manual scroll needed
    // New messages appear at bottom automatically

    // Mark new message as read if it's from someone else
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    if (userId != null && message.author.id != userId && message.readAt == null) {
      _markAllMessagesAsRead();
    }
  }

  Future<void> _loadTicketAndMessages() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.get('/api/tickets/${widget.ticketId}');

      if (!mounted) return;

      final ticket = Ticket.fromJson(response);

      final messages = ticket.messages.length > _messagesPerPage
          ? ticket.messages.sublist(ticket.messages.length - _messagesPerPage)
          : ticket.messages;

      if (widget.onTicketUpdated != null) {
        widget.onTicketUpdated!(ticket);
      }

      // Set data but keep loading state
      setState(() {
        _ticket = ticket;
        _messages = messages;
        _hasMoreMessages = ticket.messages.length > _messagesPerPage;
        _currentOffset = messages.length;
      });

      // Wait for layout to complete, THEN show ListView
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isListViewReady = true;
          });
        }
      });

      // Mark messages as read when entering conversation
      _markAllMessagesAsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _ticket == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final allMessages = _ticket!.messages;
      final startIndex = allMessages.length - _currentOffset - _messagesPerPage;

      if (startIndex < 0) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingMore = false;
        });
        return;
      }

      final endIndex = allMessages.length - _currentOffset;
      final olderMessages = allMessages.sublist(
        startIndex > 0 ? startIndex : 0,
        endIndex,
      );

      setState(() {
        _messages.insertAll(0, olderMessages);
        _currentOffset += olderMessages.length;
        _hasMoreMessages = startIndex > 0;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('[TicketChat] Error loading more messages: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  bool _isTicketFinished() {
    return _ticket?.status == TicketStatus.CLOSED ||
           _ticket?.status == TicketStatus.RESOLVED;
  }

  Future<void> _markSingleMessageAsRead(String messageId) async {
    try {
      await _api.post('/api/tickets/${widget.ticketId}/read', {
        'messageIds': [messageId],
      });
      debugPrint('[TicketChat] ✅ Marked message $messageId as read');
    } catch (e) {
      debugPrint('[TicketChat] ❌ Error marking message as read: $e');
    }
  }

  Future<void> _markAllMessagesAsRead() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;

      if (userId == null) {
        debugPrint('[TicketChat] ❌ Cannot mark as read: userId is null');
        return;
      }

      // Find unread messages from other users
      final unreadMessages = _messages.where((m) =>
        m.author.id != userId && m.readAt == null
      ).toList();

      if (unreadMessages.isEmpty) {
        debugPrint('[TicketChat] ℹ️ No unread messages to mark');
        return;
      }

      debugPrint('[TicketChat] 📖 Marking ${unreadMessages.length} messages as read');

      // Mark as read via API
      await _api.post('/api/tickets/${widget.ticketId}/read', {
        'messageIds': unreadMessages.map((m) => m.id).toList(),
      });

      debugPrint('[TicketChat] ✅ Marked ${unreadMessages.length} messages as read successfully');
    } catch (e) {
      debugPrint('[TicketChat] ❌ Error marking messages as read: $e');
    }
  }

  Future<void> _sendTypingIndicator(bool isTyping) async {
    try {
      debugPrint('[TicketChat] 📤 Sending typing indicator: $isTyping for ticket ${widget.ticketId}');
      await _api.post('/api/tickets/${widget.ticketId}/typing', {
        'isTyping': isTyping,
      });
      debugPrint('[TicketChat] ✅ Typing indicator sent successfully');
    } catch (e) {
      debugPrint('[TicketChat] ❌ Error sending typing indicator: $e');
    }
  }

  Future<void> _sendRecordingIndicator(bool isRecording) async {
    try {
      debugPrint('[TicketChat] 📤 Sending recording indicator: $isRecording for ticket ${widget.ticketId}');
      await _api.post('/api/tickets/${widget.ticketId}/recording', {
        'isRecording': isRecording,
      });
      debugPrint('[TicketChat] ✅ Recording indicator sent successfully');
    } catch (e) {
      debugPrint('[TicketChat] ❌ Error sending recording indicator: $e');
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }

    // Send typing indicator periodically while text exists
    _typingTimer?.cancel();
    _typingKeepAliveTimer?.cancel();

    if (hasText) {
      // Send immediately
      _sendTypingIndicator(true);

      // Keep sending every 2 seconds while text exists
      _typingKeepAliveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _sendTypingIndicator(true);
      });

      // Stop after 3 seconds of no typing
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _typingKeepAliveTimer?.cancel();
        _sendTypingIndicator(false);
      });
    } else {
      _sendTypingIndicator(false);
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSendingMessage || _isTicketFinished()) return;

    // Cancel typing timers and send "stopped typing"
    _typingTimer?.cancel();
    _typingKeepAliveTimer?.cancel();
    _sendTypingIndicator(false);

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final body = {'content': content};
      await _api.post('/api/tickets/${widget.ticketId}/messages', body);

      if (!mounted) return;
      _messageController.clear();
      // reverse ListView auto-scrolls when new message added
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

  Future<void> _handleAttachment(List<int> bytes, String fileName) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // OPTIMISTIC UPDATE
    setState(() {
      _optimisticMessages.add({
        'id': tempId,
        'content': _messageController.text.isNotEmpty ? _messageController.text : '',
        'fileName': fileName,
        'bytes': bytes,
        'isUploading': true,
        'timestamp': DateTime.now(),
        'authorId': authProvider.user?.id,
        'authorName': authProvider.user?.name,
        'authorAvatar': authProvider.user?.avatarUrl,
      });
    });

    final messageText = _messageController.text;
    _messageController.clear();
    // reverse ListView auto-scrolls when optimistic message added

    try {
      final response = await _api.uploadAttachment(bytes, fileName);

      if (!mounted) return;

      // Duration will be extracted automatically by backend using ffprobe
      final body = <String, dynamic>{
        'content': messageText.isNotEmpty ? messageText : '',
        'attachments': [
          {
            'fileName': response['filename'],
            'fileUrl': response['url'],
            'fileSize': response['size'],
            'mimeType': response['type'],
          }
        ],
      };

      await _api.post('/api/tickets/${widget.ticketId}/messages', body);

      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m['id'] == tempId);
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        final index = _optimisticMessages.indexWhere((m) => m['id'] == tempId);
        if (index != -1) {
          _optimisticMessages[index]['isUploading'] = false;
          _optimisticMessages[index]['hasFailed'] = true;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );

      // Remove failed message after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _optimisticMessages.removeWhere((m) => m['id'] == tempId);
          });
        }
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        // Send recording indicator
        _sendRecordingIndicator(true);

        if (!kIsWeb) {
          final directory = await getTemporaryDirectory();
          final path = '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
            path: path,
          );
        } else {
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
            path: '',
          );
        }

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
            });
          }
        });

        // Send recording indicator periodically every 2 seconds
        _recordingKeepAliveTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          _sendRecordingIndicator(true);
        });
      }
    } catch (e) {
      debugPrint('[Recording] Error: $e');
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });
      _sendRecordingIndicator(false);
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      _recordingTimer?.cancel();
      _recordingKeepAliveTimer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });

      // Stop recording indicator
      _sendRecordingIndicator(false);

      if (path != null) {
        List<int> bytes;
        final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        if (kIsWeb) {
          // On web, use the blob URL and convert to bytes
          debugPrint('[Recording] Web audio path: $path');

          try {
            bytes = await blobUrlToBytes(path);
            debugPrint('[Recording] ✅ Converted blob to ${bytes.length} bytes');
          } catch (e) {
            debugPrint('[Recording] ❌ Error converting blob: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error processing audio: $e'), backgroundColor: Colors.red),
              );
            }
            return;
          }
        } else {
          final file = File(path);
          bytes = await file.readAsBytes();
        }

        setState(() => _uploadingAttachment = true);

        final response = await _api.uploadAttachment(bytes, fileName);

        setState(() => _uploadingAttachment = false);

        // Duration will be extracted automatically by backend using ffprobe
        final body = <String, dynamic>{
          'content': '',
          'attachments': [
            {
              'fileName': response['filename'],
              'fileUrl': response['url'],
              'fileSize': response['size'],
              'mimeType': response['type'],
            }
          ],
        };

        await _api.post('/api/tickets/${widget.ticketId}/messages', body);

        if (!kIsWeb) {
          try {
            final file = File(path);
            await file.delete();
          } catch (e) {
            debugPrint('[Recording] Error deleting temp file: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[Recording] Error: $e');
      setState(() {
        _isRecording = false;
        _uploadingAttachment = false;
      });
      _sendRecordingIndicator(false);
    }
  }

  void _cancelRecording() {
    _recordingTimer?.cancel();
    _recordingKeepAliveTimer?.cancel();
    _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
    _sendRecordingIndicator(false);
  }

  void _showAttachmentPicker() {
    showDialog(
      context: context,
      builder: (context) => AttachmentPickerDialog(
        onFilePicked: _handleAttachment,
      ),
    );
  }

  Future<void> _showGifPicker() async {
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
    }

    try {
      final gif = await GiphyGet.getGif(
        context: context,
        apiKey: 'mTxO7In1JTgjP7Sgncdid6R3TbGMFlPf',
      );

      if (gif != null && mounted) {
        final gifUrl = gif.images?.original?.url ?? gif.images?.downsized?.url;

        if (gifUrl != null) {
          setState(() {
            _isSendingMessage = true;
          });

          try {
            final body = <String, dynamic>{
              'content': _messageController.text.isNotEmpty ? _messageController.text : '',
              'attachments': [
                {
                  'fileName': 'giphy.gif',
                  'fileUrl': gifUrl,
                  'fileSize': 0,
                  'mimeType': 'image/gif',
                }
              ],
            };

            await _api.post('/api/tickets/${widget.ticketId}/messages', body);

            if (mounted) {
              _messageController.clear();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error sending GIF: $e'), backgroundColor: Colors.red),
              );
            }
          } finally {
            if (mounted) {
              setState(() {
                _isSendingMessage = false;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[GIF Picker] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }

    if (_ticket == null) {
      return const Center(child: Text('Ticket not found'));
    }

    // Chat colors from reference
    final bgColor = const Color(0xFF181818);
    final myBubbleColor = const Color(0xFF222222); // My messages (sent)
    final otherBubbleColor = const Color(0xFF2F2F2F); // Received messages
    final textColor = Colors.white;

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = MediaQuery.of(context).size.width < 800;

                return Row(
                  children: [
                    // Back button (mobile only)
                    if (isMobile)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          debugPrint('[TicketChat] Back button pressed');
                          if (widget.onBackPressed != null) {
                            widget.onBackPressed!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ticket!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getStatusLabel(_ticket!.status),
                        style: TextStyle(
                          color: _getStatusColor(_ticket!.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => TicketDetailsDrawer(
                            ticket: _ticket!,
                            onTicketUpdated: (updatedTicket) {
                              setState(() {
                                _ticket = updatedTicket;
                              });
                              widget.onTicketUpdated?.call(updatedTicket);
                            },
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),

          // Messages
          Expanded(
            child: !_isListViewReady
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && _optimisticMessages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      )
                    : ListView.builder(
                        key: ValueKey('chat-${widget.ticketId}-${_messages.length}'),
                        controller: _scrollController,
                        reverse: true,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        cacheExtent: 1000,
                        itemCount: (_isLoadingMore ? 1 : 0) + _messages.length + _optimisticMessages.length,
                        itemBuilder: (context, index) {
                      // Reverse order: optimistic at bottom (index 0), then messages, then loading at top
                      final totalOptimistic = _optimisticMessages.length;
                      final totalMessages = _messages.length;

                      if (index < totalOptimistic) {
                        final optimisticMsg = _optimisticMessages[totalOptimistic - 1 - index];
                        return _buildOptimisticMessage(optimisticMsg, myBubbleColor, textColor);
                      } else if (index < totalOptimistic + totalMessages) {
                        final messageIndex = totalMessages - 1 - (index - totalOptimistic);
                        final message = _messages[messageIndex];
                        final isCurrentUser = message.author.id == user?.id;
                        return _buildMessageBubble(message, isCurrentUser, myBubbleColor, otherBubbleColor, textColor);
                      } else {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                    },
                      ),
          ),

          // Typing/Recording Indicator
          if (_otherUserTyping || _otherUserRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: bgColor,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _otherUserRecording ? Colors.red : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _otherUserRecording
                        ? 'Recording audio...'
                        : 'Typing...',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _showEmojiPicker ? Icons.emoji_emotions : Icons.emoji_emotions_outlined,
                    color: _showEmojiPicker ? Colors.blue : Colors.grey,
                  ),
                  onPressed: _isTicketFinished() ? null : () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.gif_box_outlined, color: Colors.grey, size: 28),
                  onPressed: _isTicketFinished() ? null : _showGifPicker,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      enabled: !_isTicketFinished(),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: _isTicketFinished() ? 'Ticket closed' : 'Message',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: _isTicketFinished() ? null : (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey, size: 24),
                  onPressed: _isTicketFinished() ? null : _showAttachmentPicker,
                ),
                // Send button or Audio recording button
                if (_isSendingMessage || _uploadingAttachment)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00A884),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  )
                else if (_hasText)
                  // Send button
                  GestureDetector(
                    onTap: _isTicketFinished() ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isTicketFinished() ? Colors.grey : const Color(0xFF00A884),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  )
                else
                  // Audio recording button with gestures
                  AudioRecordingButton(
                    onStartRecording: _startRecording,
                    onStopAndSend: _stopRecordingAndSend,
                    onCancel: _cancelRecording,
                    recordingDuration: _recordingDuration,
                    isRecording: _isRecording,
                    isDisabled: _isTicketFinished(),
                  ),
              ],
            ),
          ),

          // Emoji Picker
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  final text = _messageController.text;
                  final selection = _messageController.selection;
                  final newText = text.replaceRange(selection.start, selection.end, emoji.emoji);
                  _messageController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: selection.start + emoji.emoji.length),
                  );
                },
                config: Config(
                  height: 256,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: const EmojiViewConfig(
                    emojiSizeMax: 28,
                    backgroundColor: Color(0xFF1C1C1C),
                    columns: 7,
                    buttonMode: ButtonMode.MATERIAL,
                  ),
                  skinToneConfig: const SkinToneConfig(),
                  categoryViewConfig: const CategoryViewConfig(
                    indicatorColor: Colors.blue,
                    iconColor: Colors.grey,
                    iconColorSelected: Colors.blue,
                    backspaceColor: Colors.blue,
                    backgroundColor: Color(0xFF1C1C1C),
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    backgroundColor: Color(0xFF1C1C1C),
                    buttonColor: Color(0xFF1C1C1C),
                    buttonIconColor: Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptimisticMessage(Map<String, dynamic> msg, Color bubbleColor, Color textColor) {
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].any(
      (ext) => msg['fileName'].toString().toLowerCase().endsWith('.$ext'),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(3), // Tail for user messages
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: Image.memory(
                              msg['bytes'],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      if (msg['content'] != null && msg['content'].toString().isNotEmpty) ...[
                        if (isImage) const SizedBox(height: 4),
                        Text(
                          msg['content'].toString(),
                          style: TextStyle(color: textColor, fontSize: 14.5),
                        ),
                      ],
                      if (msg['isUploading'] == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  textColor.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sending...',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (msg['hasFailed'] == true) ...[
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 12, color: Colors.red),
                            SizedBox(width: 4),
                            Text('Failed', style: TextStyle(color: Colors.red, fontSize: 11)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 4),
                  child: Text(
                    DateFormat('HH:mm').format(msg['timestamp']),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    TicketMessage message,
    bool isCurrentUser,
    Color myBubbleColor,
    Color otherBubbleColor,
    Color textColor,
  ) {
    final bubbleColor = isCurrentUser ? myBubbleColor : otherBubbleColor;
    final hasAttachments = message.attachments.isNotEmpty;
    final hasText = message.content.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Bubble
                Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: hasAttachments && !hasText ? EdgeInsets.zero : const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isCurrentUser ? 12 : 3),
                      bottomRight: Radius.circular(isCurrentUser ? 3 : 12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Attachments
                      if (hasAttachments)
                        ...message.attachments.map((attachment) => _buildAttachment(
                          attachment,
                          bubbleColor,
                          textColor,
                          isCurrentUser,
                          hasText,
                        )),

                      // Text
                      if (hasText)
                        Padding(
                          padding: hasAttachments ? const EdgeInsets.all(8) : EdgeInsets.zero,
                          child: Text(
                            message.content,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Timestamp + Read receipts
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt.toLocal()),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.done_all,
                            key: ValueKey(message.readAt != null),
                            size: 14,
                            color: message.readAt != null
                                ? const Color(0xFF4FC3F7) // Blue checkmark
                                : Colors.grey, // Gray checkmark
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachment(
    TicketAttachment attachment,
    Color bubbleColor,
    Color textColor,
    bool isCurrentUser,
    bool hasText,
  ) {
    final String fullUrl = attachment.fileUrl.startsWith('http')
        ? attachment.fileUrl
        : 'https://api.ppspsched.lat${attachment.fileUrl}';

    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].any(
      (ext) => attachment.fileName.toLowerCase().endsWith('.$ext'),
    );
    final isVideo = ['mp4', 'webm', 'ogg', 'mov', 'avi'].any(
      (ext) => attachment.fileName.toLowerCase().endsWith('.$ext'),
    );
    final isAudio = ['mp3', 'm4a', 'wav', 'ogg', 'aac'].any(
      (ext) => attachment.fileName.toLowerCase().endsWith('.$ext'),
    );

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaFullscreenViewer(
              url: fullUrl,
              fileName: attachment.fileName,
              mimeType: attachment.mimeType,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE (1:1 aspect ratio)
          if (isImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(hasText ? 6 : 12),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Image.network(
                  fullUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ),
          ]

          // VIDEO (1:1 aspect ratio)
          else if (isVideo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(hasText ? 6 : 12),
              child: SizedBox(
                width: 200,
                height: 200,
                child: video_player.VideoMessagePreview(
                  videoUrl: fullUrl,
                  fileName: attachment.fileName,
                  width: 200,
                  height: 200,
                  isCurrentUser: isCurrentUser,
                ),
              ),
            ),
          ]

          // AUDIO
          else if (isAudio) ...[
            Container(
              padding: const EdgeInsets.all(8),
              child: AudioMessagePlayer(
                audioUrl: fullUrl,
                fileName: attachment.fileName,
                durationMs: attachment.duration,
                isCurrentUser: isCurrentUser,
              ),
            ),
          ]

          // DOCUMENT
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getFileIcon(attachment.fileName), size: 32, color: textColor),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getAttachmentLabel(attachment.fileName),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFileSize(attachment.fileSize),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getAttachmentLabel(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) return '[image]';
    if (['mp4', 'webm', 'ogg', 'mov', 'avi', 'mkv'].contains(ext)) return '[video]';
    if (['mp3', 'm4a', 'wav', 'ogg', 'aac', 'flac'].contains(ext)) return '[audio]';
    if (['pdf'].contains(ext)) return '[document]';
    if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].contains(ext)) return '[document]';
    return '[attachment]';
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow;
    if (['txt'].contains(ext)) return Icons.text_snippet;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getStatusLabel(TicketStatus status) {
    switch (status) {
      case TicketStatus.OPEN:
        return 'Open';
      case TicketStatus.IN_PROGRESS:
        return 'In Progress';
      case TicketStatus.WAITING_USER:
        return 'Waiting User';
      case TicketStatus.WAITING_ADMIN:
        return 'Waiting Admin';
      case TicketStatus.RESOLVED:
        return 'Resolved';
      case TicketStatus.CLOSED:
        return 'Closed';
    }
  }

  Color _getStatusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.OPEN:
        return const Color(0xFF3B82F6);
      case TicketStatus.IN_PROGRESS:
        return const Color(0xFFF59E0B);
      case TicketStatus.WAITING_USER:
        return const Color(0xFF8B5CF6);
      case TicketStatus.WAITING_ADMIN:
        return const Color(0xFFEC4899);
      case TicketStatus.RESOLVED:
        return const Color(0xFF10B981);
      case TicketStatus.CLOSED:
        return const Color(0xFF6B7280);
    }
  }
}
