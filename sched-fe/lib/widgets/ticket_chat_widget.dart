import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:giphy_get/giphy_get.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../widgets/attachment_picker_dialog.dart';
import '../widgets/media_fullscreen_viewer.dart';

/// Shared ticket chat widget used by both user and admin views
class TicketChatWidget extends StatefulWidget {
  final String ticketId;
  final Function(Ticket)? onTicketUpdated;
  final bool isAdminView;

  const TicketChatWidget({
    super.key,
    required this.ticketId,
    this.onTicketUpdated,
    this.isAdminView = false,
  });

  @override
  State<TicketChatWidget> createState() => _TicketChatWidgetState();
}

class _TicketChatWidgetState extends State<TicketChatWidget> {
  final ApiService _api = ApiService();
  final WebSocketService _ws = WebSocketService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Ticket? _ticket;
  List<TicketMessage> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _isSendingMessage = false;
  bool _uploadingAttachment = false;
  bool _hasText = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _errorMessage;

  // Optimistic updates
  final List<Map<String, dynamic>> _optimisticMessages = [];

  // Pagination
  static const int _messagesPerPage = 50;
  int _currentOffset = 0;

  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadTicketAndMessages();
    _setupWebSocket();
    _setupScrollListener();

    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Load more messages when scrolling near top
      if (_scrollController.position.pixels < 200 &&
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
            } catch (e) {
              debugPrint('[TicketChat] Error parsing message: $e');
            }
          }
        } else if (type == 'ticket_updated') {
          _loadTicketAndMessages();
        }
      });
    }
  }

  void _addMessageToList(TicketMessage message) {
    setState(() {
      // Remove optimistic message if it exists
      _optimisticMessages.removeWhere((m) =>
        m['fileName'] == message.attachments.firstOrNull?.fileName ||
        m['content'] == message.content
      );

      // Check if message already exists
      if (!_messages.any((m) => m.id == message.id)) {
        _messages.add(message);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        // Scroll to bottom seamlessly (no animation)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

        // Mark messages as read when receiving new ones
        _markMessagesAsRead();
      }
    });
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

      // Get latest messages (lazy load)
      final messages = ticket.messages.length > _messagesPerPage
          ? ticket.messages.sublist(ticket.messages.length - _messagesPerPage)
          : ticket.messages;

      setState(() {
        _ticket = ticket;
        _messages = messages;
        _isLoading = false;
        _hasMoreMessages = ticket.messages.length > _messagesPerPage;
        _currentOffset = messages.length;
      });

      // Notify parent
      if (widget.onTicketUpdated != null) {
        widget.onTicketUpdated!(ticket);
      }

      // Mark as read
      _markMessagesAsRead();

      // Scroll to bottom immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
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
      // Load older messages
      final allMessages = _ticket!.messages;
      final startIndex = allMessages.length - _currentOffset - _messagesPerPage;

      if (startIndex < 0) {
        // No more messages
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

  Future<void> _markMessagesAsRead() async {
    try {
      await _api.post('/api/tickets/${widget.ticketId}/read', {});
    } catch (e) {
      debugPrint('[TicketChat] Error marking as read: $e');
    }
  }

  bool _isTicketFinished() {
    return _ticket?.status == TicketStatus.CLOSED ||
           _ticket?.status == TicketStatus.RESOLVED;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSendingMessage || _isTicketFinished()) return;

    setState(() {
      _isSendingMessage = true;
    });

    try {
      final body = {'content': content};
      await _api.post('/api/tickets/${widget.ticketId}/messages', body);

      if (!mounted) return;
      _messageController.clear();
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

    // OPTIMISTIC UPDATE: Add message immediately
    setState(() {
      _optimisticMessages.add({
        'id': tempId,
        'content': _messageController.text.isNotEmpty ? _messageController.text : '📎 $fileName',
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

    // Scroll to show new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final response = await _api.uploadAttachment(bytes, fileName);

      if (!mounted) return;

      final body = <String, dynamic>{
        'content': messageText.isNotEmpty ? messageText : '📎 $fileName',
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

      // Remove optimistic message (real one will come via WebSocket)
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
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

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
      }
    } catch (e) {
      debugPrint('[Recording] Error: $e');
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });

      if (path != null) {
        List<int> bytes;

        if (kIsWeb) {
          final file = File(path);
          bytes = await file.readAsBytes();
        } else {
          final file = File(path);
          bytes = await file.readAsBytes();
        }

        final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        setState(() => _uploadingAttachment = true);

        final response = await _api.uploadAttachment(bytes, fileName);

        setState(() => _uploadingAttachment = false);

        final body = <String, dynamic>{
          'content': '🎤 Audio message',
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
    }
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
    // Close emoji picker if open
    if (_showEmojiPicker) {
      setState(() {
        _showEmojiPicker = false;
      });
    }

    try {
      final gif = await GiphyGet.getGif(
        context: context,
        apiKey: 'mTxO7In1JTgjP7Sgncdid6R3TbGMFlPf', // Giphy API key
      );

      if (gif != null && mounted) {
        // Send GIF as a message
        final gifUrl = gif.images?.original?.url ?? gif.images?.downsized?.url;

        if (gifUrl != null) {
          setState(() {
            _isSendingMessage = true;
          });

          try {
            final body = <String, dynamic>{
              'content': _messageController.text.isNotEmpty ? _messageController.text : '🎬 GIF',
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('GIF sent!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open GIF picker: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDark;
    final textColor = isDark ? Colors.white : Colors.black;
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

    return Column(
      children: [
        // Messages list
        Expanded(
          child: _messages.isEmpty && _optimisticMessages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet. Start the conversation!',
                    style: TextStyle(color: textColor.withOpacity(0.6)),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: (_isLoadingMore ? 1 : 0) + _messages.length + _optimisticMessages.length,
                  itemBuilder: (context, index) {
                    // Loading indicator at top
                    if (_isLoadingMore && index == 0) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final adjustedIndex = _isLoadingMore ? index - 1 : index;

                    // Real messages
                    if (adjustedIndex < _messages.length) {
                      final message = _messages[adjustedIndex];
                      final isCurrentUser = message.author.id == user?.id;

                      return _buildMessageBubble(
                        message,
                        isCurrentUser,
                        isDark,
                        textColor,
                      );
                    } else {
                      // Optimistic message
                      final optimisticIndex = adjustedIndex - _messages.length;
                      final optimisticMsg = _optimisticMessages[optimisticIndex];
                      return _buildOptimisticMessage(optimisticMsg, isDark, textColor);
                    }
                  },
                ),
        ),

        // Message Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _showEmojiPicker ? Icons.emoji_emotions : Icons.emoji_emotions_outlined,
                  color: _showEmojiPicker ? Colors.blue : textColor.withOpacity(0.6),
                ),
                onPressed: _isTicketFinished() ? null : () {
                  setState(() {
                    _showEmojiPicker = !_showEmojiPicker;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.gif_box_outlined,
                  color: textColor.withOpacity(0.6),
                  size: 28,
                ),
                onPressed: _isTicketFinished() ? null : _showGifPicker,
                tooltip: 'Send GIF',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    enabled: !_isTicketFinished(),
                    style: TextStyle(color: textColor, fontSize: 15),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: _isTicketFinished() ? 'This ticket is closed' : 'Type a message',
                      hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onSubmitted: _isTicketFinished() ? null : (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.attach_file, color: textColor.withOpacity(0.6), size: 24),
                onPressed: _isTicketFinished() ? null : _showAttachmentPicker,
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isTicketFinished()
                      ? (isDark ? Colors.white : Colors.black).withOpacity(0.5)
                      : (isDark ? Colors.white : Colors.black),
                  shape: BoxShape.circle,
                ),
                child: _isSendingMessage || _uploadingAttachment
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      )
                    : _isRecording
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic, color: Colors.red, size: 20),
                                Text(
                                  '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontSize: 8,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _hasText
                            ? IconButton(
                                icon: Icon(Icons.send_rounded, color: isDark ? Colors.black : Colors.white, size: 20),
                                onPressed: _isTicketFinished() ? null : _sendMessage,
                              )
                            : IconButton(
                                icon: Icon(Icons.mic_outlined, color: isDark ? Colors.black : Colors.white, size: 20),
                                onPressed: _isTicketFinished() ? null : () {
                                  if (_isRecording) {
                                    _stopRecordingAndSend();
                                  } else {
                                    _startRecording();
                                  }
                                },
                              ),
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
                _messageFocusNode.requestFocus();
              },
              config: Config(
                height: 256,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                  backgroundColor: isDark ? Colors.black : Colors.white,
                  columns: 7,
                  buttonMode: ButtonMode.MATERIAL,
                ),
                skinToneConfig: const SkinToneConfig(),
                categoryViewConfig: CategoryViewConfig(
                  indicatorColor: Colors.blue,
                  iconColor: textColor.withOpacity(0.5),
                  iconColorSelected: Colors.blue,
                  backspaceColor: Colors.blue,
                  backgroundColor: isDark ? Colors.black : Colors.white,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  backgroundColor: isDark ? Colors.black : Colors.white,
                  buttonColor: isDark ? Colors.black : Colors.white,
                  buttonIconColor: textColor.withOpacity(0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOptimisticMessage(Map<String, dynamic> msg, bool isDark, Color textColor) {
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].any(
      (ext) => msg['fileName'].toString().toLowerCase().endsWith(ext),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(msg['bytes'], fit: BoxFit.cover, width: 250),
                    ),
                  if (msg['content'] != null && msg['content'].toString().isNotEmpty) ...[
                    if (isImage) const SizedBox(height: 6),
                    Text(
                      msg['content'].toString(),
                      style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 15),
                    ),
                  ],
                  if (msg['isUploading'] == true) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? Colors.black54 : Colors.white54,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Uploading...',
                          style: TextStyle(
                            color: (isDark ? Colors.black : Colors.white).withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (msg['hasFailed'] == true) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 14, color: Colors.red),
                        const SizedBox(width: 6),
                        const Text('Failed to send', style: TextStyle(color: Colors.red, fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    TicketMessage message,
    bool isCurrentUser,
    bool isDark,
    Color textColor,
  ) {
    final bubbleColor = isCurrentUser
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200);

    final messageTextColor = isCurrentUser
        ? (isDark ? Colors.black : Colors.white)
        : textColor;

    // Check if message has only media (no text)
    final hasAttachments = message.attachments.isNotEmpty;
    final hasText = message.content.trim().isNotEmpty &&
                    !message.content.startsWith('📎') &&
                    !message.content.startsWith('🎤') &&
                    !message.content.startsWith('🎬');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Attachments
                if (hasAttachments) ...[
                  ...message.attachments.map((attachment) => _buildAttachment(
                    attachment,
                    bubbleColor,
                    messageTextColor,
                    isDark,
                  )),
                ],

                // Text message (only show if there's actual text)
                if (hasText)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: messageTextColor,
                        fontSize: 15,
                      ),
                    ),
                  ),

                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: message.readAt != null
                              ? const Color(0xFF4FC3F7)
                              : Colors.grey.shade500,
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
    bool isDark,
  ) {
    final String fullUrl = attachment.fileUrl.startsWith('http')
        ? attachment.fileUrl
        : 'https://api.ppspsched.lat${attachment.fileUrl}';

    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].any(
      (ext) => attachment.fileName.toLowerCase().endsWith(ext),
    );
    final isVideo = ['mp4', 'webm', 'ogg', 'mov', 'avi'].any(
      (ext) => attachment.fileName.toLowerCase().endsWith(ext),
    );
    final isAudio = ['mp3', 'm4a', 'wav', 'ogg', 'aac'].any(
      (ext) => attachment.fileName.toLowerCase().endsWith(ext),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MediaFullscreenViewer(
                url: fullUrl,
                fileName: attachment.fileName,
                mimeType: attachment.mimeType ?? _getMimeType(attachment.fileName),
              ),
            ),
          );
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    fullUrl,
                    fit: BoxFit.cover,
                    width: 300,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.white.withOpacity(0.1),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: Colors.white.withOpacity(0.1),
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                )
              else if (isVideo)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.play_circle_outline, size: 64, color: Colors.white),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Video', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isAudio)
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.audiotrack, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.fileName,
                              style: TextStyle(color: textColor, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatFileSize(attachment.fileSize ?? 0),
                              style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.download, size: 20, color: textColor.withOpacity(0.6)),
                    ],
                  ),
                )
              else
                // Document or other file
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(_getFileIcon(attachment.fileName), size: 24, color: textColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.fileName,
                              style: TextStyle(color: textColor, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatFileSize(attachment.fileSize ?? 0),
                              style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.download, size: 20, color: textColor.withOpacity(0.6)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'webm': 'video/webm',
      'ogg': 'video/ogg',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'wav': 'audio/wav',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
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

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date.toLocal());
  }
}

