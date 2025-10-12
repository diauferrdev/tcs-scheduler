import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'widgets/app_layout.dart';
import 'widgets/permissions_wrapper.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/invitations_screen.dart';
import 'screens/users_screen.dart';
import 'screens/activity_logs_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/approvals_screen.dart';
import 'screens/booking_details_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'services/navigation_service.dart';

GoRouter createRouter(AuthProvider authProvider) {
  final navigationService = NavigationService();

  return GoRouter(
    navigatorKey: navigationService.navigatorKey,
    initialLocation: '/dashboard',
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

      // Redirect to dashboard if authenticated and trying to access login
      if (isAuthenticated && isLoginRoute) {
        return '/dashboard';
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
          return PermissionsWrapper(
            child: AppLayout(child: child),
          );
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
            path: '/agenda',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const AgendaScreen(),
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
          GoRoute(
            path: '/notifications',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const NotificationsScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/approvals',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const ApprovalsScreen(),
            ),
          ),
          GoRoute(
            path: '/my-bookings',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const MyBookingsScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/booking/:id',
            pageBuilder: (context, state) {
              final bookingId = state.pathParameters['id'];
              if (bookingId == null) {
                throw Exception('Booking ID is required');
              }
              return _buildPageWithTransition(
                context,
                state,
                BookingDetailsScreen(bookingId: bookingId, skipLayout: true),
              );
            },
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
