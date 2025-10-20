import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'models/user.dart';
import 'widgets/app_layout.dart';
import 'widgets/permissions_wrapper.dart';
import 'screens/landing_screen.dart';
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
import 'screens/drawer_route_screen.dart';
import 'services/navigation_service.dart';
import 'services/drawer_service.dart';
import 'services/web_html_stub.dart'
    if (dart.library.html) 'dart:html' as html;

/// Helper function to check if running on localhost
bool _isLocalhost() {
  if (!kIsWeb) return false;
  try {
    final hostname = html.window.location.hostname;
    return hostname == 'localhost' || hostname == '127.0.0.1';
  } catch (e) {
    return false;
  }
}

GoRouter createRouter(AuthProvider authProvider) {
  final navigationService = NavigationService();

  return GoRouter(
    navigatorKey: navigationService.navigatorKey,
    initialLocation: kIsWeb ? '/' : '/login', // Web: landing, Native: login
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.loading;
      final user = authProvider.user;
      final currentPath = state.uri.path;
      final isLandingRoute = currentPath == '/';
      final isLoginRoute = currentPath == '/login';

      // Wait for auth check to complete
      if (isLoading) {
        return null;
      }

      // NATIVE APPS (Android, iOS, Desktop)
      if (!kIsWeb) {
        // Landing page is not available on native apps
        if (isLandingRoute) {
          return isAuthenticated
            ? _getMainScreenForRole(user?.role ?? UserRole.USER)
            : '/login';
        }

        // Redirect to login if not authenticated (except on login)
        if (!isAuthenticated && !isLoginRoute) {
          return '/login';
        }

        return null;
      }

      // WEB ROUTING (localhost or ppspsched.lat)
      final isLocalhost = _isLocalhost();

      // LOCALHOST: Allow all routes for development
      if (isLocalhost) {
        // Redirect to login if not authenticated (except on landing/login)
        if (!isAuthenticated && !isLoginRoute && !isLandingRoute) {
          return '/login';
        }
        return null;
      }

      // PRODUCTION WEB (ppspsched.lat)
      // Not authenticated: allow landing and login only
      if (!isAuthenticated) {
        if (!isLandingRoute && !isLoginRoute) {
          return '/';
        }
        return null;
      }

      // Authenticated on web: allow all routes
      // Role-based UI elements are handled by _getMenuItems in app_layout.dart
      return null;
    },
    routes: [
      // Landing page (only on main domain or mobile)
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),

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
            path: '/app/dashboard',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const DashboardScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/app/calendar',
            pageBuilder: (context, state) {
              final draftId = state.uri.queryParameters['draftId'];
              return _buildPageWithTransition(
                context,
                state,
                CalendarScreen(
                  skipLayout: true,
                  draftIdToEdit: draftId,
                ),
              );
            },
          ),
          GoRoute(
            path: '/app/agenda',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const AgendaScreen(),
            ),
          ),
          GoRoute(
            path: '/app/invitations',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const InvitationsScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/app/users',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const UsersScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/app/activity-logs',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const ActivityLogsScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/app/notifications',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const DrawerRouteScreen(
                drawerType: DrawerType.notifications,
                baseRoute: '/app/calendar',
              ),
            ),
          ),
          GoRoute(
            path: '/app/approvals',
            pageBuilder: (context, state) {
              final bookingId = state.uri.queryParameters['bookingId'];
              return _buildPageWithTransition(
                context,
                state,
                ApprovalsScreen(initialBookingId: bookingId),
              );
            },
          ),
          GoRoute(
            path: '/app/my-bookings',
            pageBuilder: (context, state) {
              final bookingId = state.uri.queryParameters['bookingId'];
              return _buildPageWithTransition(
                context,
                state,
                MyBookingsScreen(
                  skipLayout: true,
                  initialBookingId: bookingId,
                ),
              );
            },
          ),
          GoRoute(
            path: '/app/booking/:id',
            pageBuilder: (context, state) {
              final bookingId = state.pathParameters['id'];
              if (bookingId == null) {
                throw Exception('Booking ID is required');
              }
              return _buildPageWithTransition(
                context,
                state,
                DrawerRouteScreen(
                  drawerType: DrawerType.bookingDetails,
                  params: {'bookingId': bookingId},
                  baseRoute: '/app/calendar',
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
}

/// Get the main screen (first icon in navigation) for each role
String _getMainScreenForRole(UserRole role) {
  switch (role) {
    case UserRole.ADMIN:
      return '/app/dashboard'; // Admin main screen
    case UserRole.MANAGER:
      return '/app/dashboard'; // Manager main screen
    case UserRole.USER:
      return '/app/calendar'; // User main screen
  }
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
