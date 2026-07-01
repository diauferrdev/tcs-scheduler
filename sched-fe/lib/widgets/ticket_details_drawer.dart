import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../utils/responsive_helper.dart';
import '../widgets/media_fullscreen_viewer.dart';

/// Drawer that shows ticket details (title, description, attachments, status selector for admin)
/// Following the profile drawer design pattern
class TicketDetailsDrawer extends StatefulWidget {
  final Ticket ticket;
  final Function(Ticket)? onTicketUpdated;

  const TicketDetailsDrawer({
    super.key,
    required this.ticket,
    this.onTicketUpdated,
  });

  @override
  State<TicketDetailsDrawer> createState() => _TicketDetailsDrawerState();
}

class _TicketDetailsDrawerState extends State<TicketDetailsDrawer> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final ScrollController _flatScrollController = ScrollController();
  final ApiService _api = ApiService();

  TicketStatus? _selectedStatus;
  bool _isUpdatingStatus = false;
  // Tracks which status row is currently being applied so we can show a
  // small inline spinner on that row instead of swapping out the whole list.
  TicketStatus? _pendingStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.ticket.status;
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _flatScrollController.dispose();
    super.dispose();
  }

  bool _isTerminalStatus(TicketStatus status) {
    return status == TicketStatus.CLOSED || status == TicketStatus.RESOLVED;
  }

  /// Handles a tap on a status row. Terminal statuses (CLOSED/RESOLVED)
  /// require explicit confirmation before being applied, since they end
  /// the conversation.
  Future<void> _onStatusTap(TicketStatus newStatus) async {
    if (_isUpdatingStatus || newStatus == _selectedStatus) return;

    if (_isTerminalStatus(newStatus)) {
      final confirmed = await _confirmTerminalStatusChange(newStatus);
      if (confirmed != true) return;
    }

    await _updateStatus(newStatus);
  }

  Future<bool?> _confirmTerminalStatusChange(TicketStatus newStatus) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDark;
    final label = _getStatusLabel(newStatus);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text(
          'Mark ticket as $label?',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'This will close the conversation. The ticket status will change to "$label".',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(label, style: TextStyle(color: _getStatusColor(newStatus))),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(TicketStatus newStatus) async {
    if (_isUpdatingStatus || newStatus == _selectedStatus) return;

    setState(() {
      _isUpdatingStatus = true;
      _pendingStatus = newStatus;
    });

    try {
      final response = await _api.patch('/api/tickets/${widget.ticket.id}', {
        'status': newStatus.toString().split('.').last,
      });

      if (!mounted) return;

      final updatedTicket = Ticket.fromJson(response);

      setState(() {
        _selectedStatus = newStatus;
        _isUpdatingStatus = false;
        _pendingStatus = null;
      });

      // Notify parent
      widget.onTicketUpdated?.call(updatedTicket);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status updated successfully'),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isUpdatingStatus = false;
        _pendingStatus = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        return const Color(0xFF3B82F6); // Blue
      case TicketStatus.IN_PROGRESS:
        return const Color(0xFFF59E0B); // Orange
      case TicketStatus.WAITING_USER:
        return const Color(0xFF8B5CF6); // Purple
      case TicketStatus.WAITING_ADMIN:
        return const Color(0xFFEC4899); // Pink
      case TicketStatus.RESOLVED:
        return const Color(0xFF10B981); // Green
      case TicketStatus.CLOSED:
        return const Color(0xFF6B7280); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDark;
    final user = authProvider.user;
    final isAdmin = user?.role == UserRole.ADMIN;

    // Hide the drag handle / draggable-sheet sizing when shown as a desktop modal.
    final isModal = !ResponsiveHelper.isMobile(context);

    if (isModal) {
      return _buildDrawerBody(context, isDark, isAdmin, _flatScrollController, isModal);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      controller: _sheetController,
      builder: (context, scrollController) =>
          _buildDrawerBody(context, isDark, isAdmin, scrollController, isModal),
    );
  }

  Widget _buildDrawerBody(
    BuildContext context,
    bool isDark,
    bool isAdmin,
    ScrollController scrollController,
    bool isModal,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar (mobile bottom-sheet only)
          if (!isModal)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                    tooltip: 'Close',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ticket Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Title',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.ticket.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.ticket.description,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Attachments (2 rows x 3 columns)
                    if (widget.ticket.attachments.isNotEmpty) ...[
                      Text(
                        'Attachments',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: widget.ticket.attachments.length > 6 ? 6 : widget.ticket.attachments.length,
                        itemBuilder: (context, index) {
                          final attachment = widget.ticket.attachments[index];
                          final String fullUrl = attachment.fileUrl.startsWith('http')
                              ? attachment.fileUrl
                              : 'https://api.pacesched.com${attachment.fileUrl}';

                          final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].any(
                            (ext) => attachment.fileName.toLowerCase().endsWith(ext),
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
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: isImage
                                    ? Image.network(
                                        fullUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Icon(
                                          _getFileIcon(attachment.fileName),
                                          size: 32,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Status Selector (Admin only)
                    if (isAdmin) ...[
                      Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        // Keep the status list visible while updating (inline/localized
                        // loading) instead of swapping it for a full-panel spinner,
                        // which would lose context of the current selection.
                        child: IgnorePointer(
                          ignoring: _isUpdatingStatus,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _isUpdatingStatus ? 0.6 : 1.0,
                            child: Column(
                                children: TicketStatus.values.map((status) {
                                  final isSelected = _selectedStatus == status;
                                  final statusColor = _getStatusColor(status);
                                  final isPending = _isUpdatingStatus && _pendingStatus == status;

                                  return InkWell(
                                    onTap: () => _onStatusTap(status),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? statusColor.withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? statusColor
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _getStatusLabel(status),
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isDark ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ),
                                          if (isPending)
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          else if (isSelected)
                                            Icon(
                                              Icons.check_circle,
                                              color: statusColor,
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                            ),
                          ),
                        ),
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

  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow;
    if (['txt'].contains(ext)) return Icons.text_snippet;
    if (['mp4', 'webm', 'mov', 'avi'].contains(ext)) return Icons.videocam;
    if (['mp3', 'm4a', 'wav', 'ogg'].contains(ext)) return Icons.audiotrack;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }
}
