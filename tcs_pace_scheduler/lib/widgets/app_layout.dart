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
          // Logo - "Scheduler" em destaque, logo TCS pequena abaixo
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Scheduler',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              SvgPicture.asset(
                isDark ? 'assets/logos/tcs-logo-w.svg' : 'assets/logos/tcs-logo-b.svg',
                height: 12,
              ),
            ],
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

          // User Profile Button
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                isDismissible: true,
                enableDrag: true,
                builder: (context) => const ProfileDrawer(),
              );
            },
            icon: Icon(
              Icons.person,
              color: isDark ? Colors.white : Colors.black,
            ),
            tooltip: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, User user, bool isDark) {
    final menuItems = _getMenuItems(user);
    final currentPath = GoRouterState.of(context).uri.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: _sidebarCollapsed ? 72 : 256,
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
          // Toggle button
          Container(
            padding: const EdgeInsets.all(8),
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
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _sidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                    size: 20,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Menu items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: menuItems.map((item) {
                  final isActive = currentPath == item['path'];
                  return _buildMenuItem(
                    context,
                    item['label'] as String,
                    item['icon'] as IconData,
                    item['path'] as String,
                    isActive,
                    isDark,
                    collapsed: _sidebarCollapsed,
                  );
                }).toList(),
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
    bool isDark, {
    bool collapsed = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: collapsed ? label : '',
          child: InkWell(
            onTap: () => context.go(path),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: collapsed
                  ? Icon(
                      icon,
                      size: 20,
                      color: isActive
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    )
                  : Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isActive
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive
                                  ? (isDark ? Colors.black : Colors.white)
                                  : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
    final items = <Map<String, dynamic>>[
      {'path': '/dashboard', 'label': 'Dashboard', 'icon': Icons.dashboard, 'roles': [UserRole.ADMIN, UserRole.MANAGER]},
      {'path': '/approvals', 'label': 'Bookings', 'icon': Icons.pending_actions, 'roles': [UserRole.ADMIN, UserRole.MANAGER]},
      {'path': '/calendar', 'label': 'Calendar', 'icon': Icons.calendar_month, 'roles': [UserRole.ADMIN, UserRole.USER]},
      {'path': '/agenda', 'label': 'Agenda', 'icon': Icons.view_timeline, 'roles': [UserRole.ADMIN, UserRole.MANAGER]},
      {'path': '/my-bookings', 'label': 'My Bookings', 'icon': Icons.event_note, 'roles': [UserRole.USER]},
      {'path': '/users', 'label': 'Users', 'icon': Icons.people, 'roles': [UserRole.ADMIN, UserRole.MANAGER]},
      {'path': '/activity-logs', 'label': 'Activity', 'icon': Icons.history, 'roles': [UserRole.ADMIN]},
    ];

    return items.where((item) {
      final roles = item['roles'] as List<UserRole>;
      return roles.contains(user.role);
    }).toList();
  }
}
