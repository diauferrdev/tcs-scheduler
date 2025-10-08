import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'widgets/app_layout.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/invitations_screen.dart';
import 'screens/users_screen.dart';
import 'screens/activity_logs_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/calendar',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.loading;
      final isLoginRoute = state.uri.path == '/login';

      // Wait for auth check to complete
      if (isLoading) {
        return null;
      }

      // Redirect to login if not authenticated
      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      // Redirect to calendar if authenticated and trying to access login
      if (isAuthenticated && isLoginRoute) {
        return '/calendar';
      }

      return null;
    },
    routes: [
      // Login route (no AppLayout)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Shell route with AppLayout for authenticated pages
      ShellRoute(
        builder: (context, state, child) {
          return AppLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const DashboardScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/calendar',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const CalendarScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/invitations',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const InvitationsScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const UsersScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/activity-logs',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const ActivityLogsScreen(skipLayout: true),
            ),
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage _buildPageWithTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.03, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;

      final tween = Tween(begin: begin, end: end).chain(
        CurveTween(curve: curve),
      );

      final offsetAnimation = animation.drive(tween);
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: curve,
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: offsetAnimation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 220),
  );
}
