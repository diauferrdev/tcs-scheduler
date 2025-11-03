import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../models/invitation.dart';
import '../config/api_config.dart';
import '../utils/toast_notification.dart';

class InvitationsScreen extends StatefulWidget {
  final bool skipLayout;

  const InvitationsScreen({super.key, this.skipLayout = false});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  final ApiService _apiService = ApiService();
  List<Invitation> _invitations = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all, active, used, expired

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await _apiService.getInvitations();
      final data = response is List
          ? response
          : (response['invitations'] as List? ?? response['data'] as List? ?? []);

      setState(() {
        _invitations = data.map((e) => Invitation.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _createInvitation({String? email}) async {
    try {
      await _apiService.createInvitation(
        email: email,
        expiresInDays: 7,
      );

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Invitation created successfully!',
          type: ToastType.success,
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: e.toString(),
          type: ToastType.error,
        );
      }
    }
  }

  void _showCreateDialog() {
    final emailController = TextEditingController();
    final isDark = context.read<ThemeProvider>().isDark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text(
          'Create Invitation',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email (optional)',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'guest@example.com',
                hintStyle: TextStyle(
                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
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
            ),
            const SizedBox(height: 12),
            Text(
              'Expires in 7 days',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createInvitation(
                email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _copyInvitationLink(String token) {
    final link = '${ApiConfig.baseUrl}/guest-booking/$token';
    Clipboard.setData(ClipboardData(text: link));
    ToastNotification.show(
      context,
      message: 'Invitation link copied to clipboard!',
      type: ToastType.info,
      duration: const Duration(seconds: 2),
    );
  }

  List<Invitation> get _filteredInvitations {
    switch (_filter) {
      case 'active':
        return _invitations.where((i) => i.isActive && !i.isExpired && !i.isUsed).toList();
      case 'used':
        return _invitations.where((i) => i.isUsed).toList();
      case 'expired':
        return _invitations.where((i) => i.isExpired && !i.isUsed).toList();
      default:
        return _invitations;
    }
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invitations',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(isMobile ? 'New' : 'New Invitation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active', 'active', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Used', 'used', isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Expired', 'expired', isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
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
                              color: Colors.red.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadInvitations,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredInvitations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.link_off,
                                  size: 64,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No invitations found',
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
                            onRefresh: _loadInvitations,
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 24,
                                vertical: 8,
                              ),
                              itemCount: _filteredInvitations.length,
                              itemBuilder: (context, index) {
                                return _buildInvitationCard(
                                  _filteredInvitations[index],
                                  isDark,
                                  isMobile,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );

    return widget.skipLayout ? content : AppLayout(child: content);
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
      selectedColor: isDark ? Colors.white : Colors.black,
      labelStyle: TextStyle(
        color: isSelected
            ? (isDark ? Colors.black : Colors.white)
            : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
      ),
    );
  }

  Widget _buildInvitationCard(Invitation invitation, bool isDark, bool isMobile) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');

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
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(invitation).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  invitation.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(invitation),
                  ),
                ),
              ),
              const Spacer(),

              // Copy Button
              if (!invitation.isUsed && !invitation.isExpired)
                IconButton(
                  onPressed: () => _copyInvitationLink(invitation.token),
                  icon: Icon(
                    Icons.copy,
                    size: 18,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  tooltip: 'Copy Link',
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Token
          Row(
            children: [
              Icon(
                Icons.link,
                size: 16,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invitation.token,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Email (if present)
          if (invitation.email != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.email,
                  size: 16,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Text(
                  invitation.email!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
          const SizedBox(height: 12),

          // Dates
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(invitation.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.isUsed ? 'Used At' : 'Expires',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(invitation.isUsed ? invitation.usedAt! : invitation.expiresAt),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Created By
          if (invitation.createdBy != null) ...[
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
                  'Created by ${invitation.createdBy!.name}',
                  style: TextStyle(
                    fontSize: 12,
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

  Color _getStatusColor(Invitation invitation) {
    if (invitation.isUsed) return Colors.blue;
    if (invitation.isExpired) return Colors.red;
    if (invitation.isActive) return Colors.green;
    return Colors.grey;
  }
}
