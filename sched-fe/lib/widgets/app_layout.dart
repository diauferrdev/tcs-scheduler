import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/user.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/unified_notification_service.dart';
import '../utils/adaptive_panel.dart';
import '../utils/web_helper.dart';
import 'notification_bell.dart';
import 'profile_drawer.dart';

class AppLayout extends StatefulWidget {
  final Widget child;

  const AppLayout({super.key, required this.child});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  final UnifiedNotificationService _notificationService =
      UnifiedNotificationService();
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
      await _notificationService.initialize();
      _initialized = true;
    } catch (e) { /* ignored: non-critical failure */ }
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
    final isDark = themeProvider.isDark;

    if (user == null) {
      // Don't show a loading indicator here - the native web splash screen
      // (index.html) already handles the initial loading state
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: Container(),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        bottom:
            !isMobile, // Only apply bottom padding on desktop (mobile has bottomNavigationBar)
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
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation (Mobile only)
      bottomNavigationBar: isMobile
          ? SafeArea(child: _buildBottomNav(context, user, isDark))
          : null,
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
          // Logo - Pace logo (already includes "Scheduler" text)
          SvgPicture.asset(
            isDark
                ? 'assets/logos/pace-scheduler-logo-w.svg'
                : 'assets/logos/pace-scheduler-logo-b.svg',
            height: 16,
          ),

          const Spacer(),

          // PWA Install Button (web only)
          if (kIsWeb && WebHelper.pwaCanInstall())
            IconButton(
              onPressed: () => WebHelper.pwaInstall(),
              icon: Icon(
                Icons.install_mobile,
                color: isDark ? Colors.white : Colors.black,
              ),
              tooltip: 'Install App',
            ),

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
              showAdaptiveSideSheet(
                context: context,
                isDismissible: true,
                side: AdaptiveSide.right,
                width: 380,
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
                    backgroundColor: isDark
                        ? const Color(0xFF27272A)
                        : const Color(0xFFF3F4F6),
                    child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              user.avatarUrl!.startsWith('http')
                                  ? user.avatarUrl!
                                  : 'https://api.pacesched.com${user.avatarUrl}',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                // Show a subtle loader while the avatar fetches,
                                // instead of a blank/flickering circle.
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isDark
                                            ? Colors.white.withValues(alpha: 0.6)
                                            : Colors.black.withValues(alpha: 0.4),
                                      ),
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to initials if image fails to load
                                return Center(
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : 'U',
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
                          user.name.length > 15
                              ? '${user.name.substring(0, 15)}...'
                              : user.name,
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
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
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
                  color: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFFE5E7EB),
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
                    color: (isDark
                        ? const Color(0xFF27272A)
                        : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _sidebarCollapsed
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      size: 20,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
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
    // Tighter horizontal padding when there are many items (e.g. ADMIN with
    // 8 tabs) so labels get more room and never force a RenderFlex overflow
    // on narrow (~360dp) phones.
    final horizontalPadding = menuItems.length > 5 ? 2.0 : 4.0;

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
          // Expanded so each tab shares the available width equally and can
          // never push the Row wider than the screen (fixes overflow with
          // up to 8 ADMIN items on narrow phones).
          return Expanded(
            child: _buildBottomNavItem(
              context,
              item['label'] as String,
              item['icon'] as IconData,
              item['path'] as String,
              isActive,
              isDark,
              horizontalPadding,
            ),
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
                      child: Icon(icon, size: 20, color: iconColor),
                    );
                  }
                  // Show full row when expanded - aligned to left
                  return Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20, color: iconColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w500,
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
    double horizontalPadding,
  ) {
    return InkWell(
      onTap: () => context.go(path),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                // Floor kept small enough that long labels (e.g. "My
                // Bookings") still fit an Expanded slot when 8 ADMIN items
                // share a 360dp-wide row.
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getMenuItems(User user) {
    // Order optimized by role priority (most important first for each role)
    final items = <Map<String, dynamic>>[
      // USER sees: Events → Rooms → My Bookings → Support
      {
        'path': '/app/schedule',
        'label': 'Events',
        'icon': Icons.event,
        'roles': [UserRole.USER],
        'order': 1,
      },
      {
        'path': '/app/rooms',
        'label': 'Rooms',
        'icon': Icons.meeting_room,
        'roles': [UserRole.USER],
        'order': 2,
      },
      {
        'path': '/app/my-bookings',
        'label': 'My Bookings',
        'icon': Icons.event_note,
        'roles': [UserRole.USER],
        'order': 3,
      },

      // MANAGER sees: Dashboard → Pending → Events → Rooms → My Bookings → Agenda → Users → Support
      {
        'path': '/app/dashboard',
        'label': 'Dashboard',
        'icon': Icons.dashboard,
        'roles': [UserRole.MANAGER],
        'order': 1,
      },
      {
        'path': '/app/pending',
        'label': 'Pending',
        'icon': Icons.pending_actions,
        'roles': [UserRole.MANAGER],
        'order': 2,
      },
      {
        'path': '/app/schedule',
        'label': 'Events',
        'icon': Icons.event,
        'roles': [UserRole.MANAGER],
        'order': 3,
      },
      {
        'path': '/app/rooms',
        'label': 'Rooms',
        'icon': Icons.meeting_room,
        'roles': [UserRole.MANAGER],
        'order': 4,
      },
      {
        'path': '/app/my-bookings',
        'label': 'My Bookings',
        'icon': Icons.event_note,
        'roles': [UserRole.MANAGER],
        'order': 5,
      },
      {
        'path': '/app/agenda',
        'label': 'Agenda',
        'icon': Icons.view_timeline,
        'roles': [UserRole.MANAGER],
        'order': 6,
      },
      {
        'path': '/app/users',
        'label': 'Users',
        'icon': Icons.people,
        'roles': [UserRole.MANAGER],
        'order': 7,
      },

      // ADMIN sees: Dashboard → Pending → Events → Rooms → My Bookings → Agenda → Users → Audit
      {
        'path': '/app/dashboard',
        'label': 'Dashboard',
        'icon': Icons.dashboard,
        'roles': [UserRole.ADMIN],
        'order': 1,
      },
      {
        'path': '/app/pending',
        'label': 'Pending',
        'icon': Icons.pending_actions,
        'roles': [UserRole.ADMIN],
        'order': 2,
      },
      {
        'path': '/app/schedule',
        'label': 'Events',
        'icon': Icons.event,
        'roles': [UserRole.ADMIN],
        'order': 3,
      },
      {
        'path': '/app/rooms',
        'label': 'Rooms',
        'icon': Icons.meeting_room,
        'roles': [UserRole.ADMIN],
        'order': 4,
      },
      {
        'path': '/app/my-bookings',
        'label': 'My Bookings',
        'icon': Icons.event_note,
        'roles': [UserRole.ADMIN],
        'order': 5,
      },
      {
        'path': '/app/agenda',
        'label': 'Agenda',
        'icon': Icons.view_timeline,
        'roles': [UserRole.ADMIN],
        'order': 6,
      },
      {
        'path': '/app/users',
        'label': 'Users',
        'icon': Icons.people,
        'roles': [UserRole.ADMIN],
        'order': 7,
      },
      {
        'path': '/app/audit',
        'label': 'Audit',
        'icon': Icons.history,
        'roles': [UserRole.ADMIN],
        'order': 8,
      },

      // Support - available to all roles (last position)
      {
        'path': '/app/support',
        'label': 'Support',
        'icon': Icons.support_agent,
        'roles': [UserRole.ADMIN, UserRole.MANAGER, UserRole.USER],
        'order': 999,
      },
    ];

    final filteredItems = items.where((item) {
      final roles = item['roles'] as List<UserRole>;
      return roles.contains(user.role);
    }).toList();

    // Sort by order to ensure correct display sequence
    filteredItems.sort(
      (a, b) => (a['order'] as int).compareTo(b['order'] as int),
    );

    return filteredItems;
  }

  String _capitalizeRole(String role) {
    if (role.isEmpty) return role;
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }
}
