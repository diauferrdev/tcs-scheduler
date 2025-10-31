import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/user.dart';
import '../services/unified_notification_service.dart';
import 'notification_bell.dart';
import 'profile_drawer.dart';

class AppLayout extends StatefulWidget {
  final Widget child;

  const AppLayout({super.key, required this.child});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  final UnifiedNotificationService _notificationService = UnifiedNotificationService();
  bool _initialized = false;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    if (_initialized) return;

    try {
      debugPrint('[AppLayout] Initializing notification system...');
      await _notificationService.initialize();
      _initialized = true;
      debugPrint('[AppLayout] Notification system initialized successfully');
    } catch (e) {
      debugPrint('[AppLayout] Error initializing notifications: $e');
    }
  }

  @override
  void dispose() {
    // Don't dispose the notification service - it's a singleton that lives for the entire app lifecycle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = themeProvider.isDark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        bottom: !isMobile, // Only apply bottom padding on desktop (mobile has bottomNavigationBar)
        child: Column(
          children: [
            // Header
            _buildHeader(context, user, isDark, themeProvider, isMobile),

            // Content
            Expanded(
              child: Row(
                children: [
                  // Sidebar (Desktop only)
                  if (!isMobile) _buildSidebar(context, user, isDark),

                  // Main Content
                  Expanded(
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation (Mobile only)
      bottomNavigationBar:
          isMobile ? SafeArea(child: _buildBottomNav(context, user, isDark)) : null,
    );
  }

  Widget _buildHeader(
    BuildContext context,
    User user,
    bool isDark,
    ThemeProvider themeProvider,
    bool isMobile,
  ) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Logo - New TCS Pace logo (already includes "Scheduler" text)
          SvgPicture.asset(
            isDark ? 'assets/logos/tcs-pace-logo-w.svg' : 'assets/logos/tcs-pace-logo-b.svg',
            height: 32,
          ),

          const Spacer(),

          // Notification Bell
          const NotificationBell(),

          const SizedBox(width: 8),

          // Theme Toggle
          IconButton(
            onPressed: themeProvider.toggleTheme,
            icon: Icon(
              isDark ? Icons.wb_sunny : Icons.nightlight_round,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),

          const SizedBox(width: 8),

          // User Profile Button with Avatar and Info
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                isDismissible: true,
                enableDrag: true,
                builder: (context) => const ProfileDrawer(),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                    child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              user.avatarUrl!.startsWith('http')
                                  ? user.avatarUrl!
                                  : 'https://api.ppspsched.lat${user.avatarUrl}',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to initials if image fails to load
                                return Center(
                                  child: Text(
                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 10),
                    // User Info
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.name.length > 15 ? '${user.name.substring(0, 15)}...' : user.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          _capitalizeRole(user.role.toString().split('.').last),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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

  Widget _buildSidebar(BuildContext context, User user, bool isDark) {
    final menuItems = _getMenuItems(user);
    final currentPath = GoRouterState.of(context).uri.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubicEmphasized,
      width: _sidebarCollapsed ? 64 : 205,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Menu items with overflow protection
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      maxWidth: constraints.maxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: menuItems.map((item) {
                          final isActive = currentPath == item['path'];
                          return _buildMenuItem(
                            context,
                            item['label'] as String,
                            item['icon'] as IconData,
                            item['path'] as String,
                            isActive,
                            isDark,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Toggle button at bottom
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _sidebarCollapsed = !_sidebarCollapsed;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 20,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, User user, bool isDark) {
    final menuItems = _getMenuItems(user);
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: menuItems.map((item) {
          final isActive = currentPath == item['path'];
          return _buildBottomNavItem(
            context,
            item['label'] as String,
            item['icon'] as IconData,
            item['path'] as String,
            isActive,
            isDark,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String label,
    IconData icon,
    String path,
    bool isActive,
    bool isDark,
  ) {
    final iconColor = isActive
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280));

    final bgColor = isActive
        ? (isDark ? Colors.white : Colors.black)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: _sidebarCollapsed ? label : '',
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => context.go(path),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubicEmphasized,
              height: 44,
              padding: EdgeInsets.symmetric(
                horizontal: _sidebarCollapsed ? 0 : 12,
                vertical: 0,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.hardEdge,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Show icon only if width is less than 90px (collapsed state + animation)
                  if (constraints.maxWidth < 90) {
                    return Center(
                      child: Icon(
                        icon,
                        size: 20,
                        color: iconColor,
                      ),
                    );
                  }
                  // Show full row when expanded - aligned to left
                  return Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: iconColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: iconColor,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    BuildContext context,
    String label,
    IconData icon,
    String path,
    bool isActive,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => context.go(path),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getMenuItems(User user) {
    // Order optimized by role priority (most important first for each role)
    final items = <Map<String, dynamic>>[
      // USER sees: Schedule → My Visits → Feedback (3 items)
      {'path': '/app/schedule', 'label': 'Schedule', 'icon': Icons.calendar_month, 'roles': [UserRole.USER], 'order': 1},
      {'path': '/app/my-visits', 'label': 'My Visits', 'icon': Icons.event_note, 'roles': [UserRole.USER], 'order': 2},

      // MANAGER sees: Pending → Agenda → Dashboard → Users → Feedback (5 items) - NO SCHEDULE
      {'path': '/app/pending', 'label': 'Pending', 'icon': Icons.pending_actions, 'roles': [UserRole.MANAGER], 'order': 1},
      {'path': '/app/agenda', 'label': 'Agenda', 'icon': Icons.view_timeline, 'roles': [UserRole.MANAGER], 'order': 2},
      {'path': '/app/dashboard', 'label': 'Dashboard', 'icon': Icons.dashboard, 'roles': [UserRole.MANAGER], 'order': 3},
      {'path': '/app/users', 'label': 'Users', 'icon': Icons.people, 'roles': [UserRole.MANAGER], 'order': 4},

      // ADMIN sees: Dashboard → Pending → Schedule → Agenda → Feedback → Users → Audit (7 items)
      {'path': '/app/dashboard', 'label': 'Dashboard', 'icon': Icons.dashboard, 'roles': [UserRole.ADMIN], 'order': 1},
      {'path': '/app/pending', 'label': 'Pending', 'icon': Icons.pending_actions, 'roles': [UserRole.ADMIN], 'order': 2},
      {'path': '/app/schedule', 'label': 'Schedule', 'icon': Icons.calendar_month, 'roles': [UserRole.ADMIN], 'order': 3},
      {'path': '/app/agenda', 'label': 'Agenda', 'icon': Icons.view_timeline, 'roles': [UserRole.ADMIN], 'order': 4},
      {'path': '/app/users', 'label': 'Users', 'icon': Icons.people, 'roles': [UserRole.ADMIN], 'order': 6},
      {'path': '/app/audit', 'label': 'Audit', 'icon': Icons.history, 'roles': [UserRole.ADMIN], 'order': 7},

      // Feedback - available to all roles (last position)
      {'path': '/app/feedback', 'label': 'Feedback', 'icon': Icons.feedback_outlined, 'roles': [UserRole.ADMIN, UserRole.MANAGER, UserRole.USER], 'order': 999},
    ];

    final filteredItems = items.where((item) {
      final roles = item['roles'] as List<UserRole>;
      return roles.contains(user.role);
    }).toList();

    // Sort by order to ensure correct display sequence
    filteredItems.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));

    return filteredItems;
  }

  String _capitalizeRole(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }
}
