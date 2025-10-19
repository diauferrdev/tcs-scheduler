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

/// Helper function to check if current domain is the main domain (not app subdomain)
bool _isMainDomain() {
  if (!kIsWeb) return false;
  try {
    final hostname = html.window.location.hostname;
    return hostname == 'ppspsched.lat' || hostname == 'www.ppspsched.lat';
  } catch (e) {
    return false;
  }
}

/// Helper function to check if current domain is the app subdomain
bool _isAppDomain() {
  if (!kIsWeb) return true; // Mobile/desktop apps always use app logic
  try {
    final hostname = html.window.location.hostname;
    return hostname == 'app.ppspsched.lat';
  } catch (e) {
    return true;
  }
}

/// Helper function to redirect to app subdomain
void _redirectToAppDomain(String path) {
  if (!kIsWeb) return;
  try {
    final currentUrl = html.window.location.href;
    final newUrl = currentUrl.replaceFirst('ppspsched.lat', 'app.ppspsched.lat');
    html.window.location.href = newUrl;
  } catch (e) {
    // Ignore on non-web platforms
  }
}

GoRouter createRouter(AuthProvider authProvider) {
  final navigationService = NavigationService();

  return GoRouter(
    navigatorKey: navigationService.navigatorKey,
    initialLocation: '/', // Start at landing, redirect handles routing
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.loading;
      final user = authProvider.user;
      final currentPath = state.uri.path;
      final isLandingRoute = currentPath == '/';
      final isLoginRoute = currentPath == '/login';
      final isCalendarRoute = currentPath == '/calendar';
      final isDashboardRoute = currentPath == '/dashboard';

      // Wait for auth check to complete
      if (isLoading) {
        return null;
      }

      // DOMAIN-BASED ROUTING (Web only)
      if (kIsWeb) {
        final isLocalhost = _isLocalhost();
        final isMainDomain = _isMainDomain();
        final isAppDomain = _isAppDomain();

        // LOCALHOST: Allow all routes for development, no redirects
        if (isLocalhost) {
          // Localhost behaves like mobile/desktop - see MOBILE/DESKTOP ROUTING below
        } else {
          // Main domain (ppspsched.lat) logic
          if (isMainDomain) {
            // If authenticated and on landing page, redirect to app subdomain
            if (isAuthenticated && isLandingRoute) {
              _redirectToAppDomain('/calendar');
              return null;
            }

            // Not authenticated: allow landing and login only
            if (!isAuthenticated && !isLandingRoute && !isLoginRoute) {
              return '/';
            }

            // Block app routes on main domain (force them to use app subdomain)
            if (isAuthenticated && !isLandingRoute && !isLoginRoute) {
              _redirectToAppDomain(currentPath);
              return null;
            }
          }

          // App subdomain (app.ppspsched.lat) logic
          if (isAppDomain) {
            // Not authenticated: redirect to main domain login
            if (!isAuthenticated) {
              html.window.location.href = 'https://ppspsched.lat/login';
              return null;
            }

            // Don't allow landing page on app domain
            if (isLandingRoute) {
              return _getMainScreenForRole(user?.role ?? UserRole.USER);
            }
          }
        }
      }

      // MOBILE/DESKTOP/LOCALHOST ROUTING
      if (!kIsWeb || (kIsWeb && _isLocalhost())) {
        // Redirect to login if not authenticated (except on landing/login)
        if (!isAuthenticated && !isLoginRoute && !isLandingRoute) {
          return '/login';
        }

        // Redirect authenticated users from landing to their main screen
        if (isAuthenticated && isLandingRoute && user != null) {
          return _getMainScreenForRole(user.role);
        }
      }

      // Redirect authenticated users from login to their main screen
      if (isAuthenticated && isLoginRoute && user != null) {
        return _getMainScreenForRole(user.role);
      }

      // No route restrictions - all authenticated users can access all routes
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
            path: '/dashboard',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const DashboardScreen(skipLayout: true),
            ),
          ),
          GoRoute(
            path: '/calendar',
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
              const DrawerRouteScreen(
                drawerType: DrawerType.notifications,
                baseRoute: '/calendar',
              ),
            ),
          ),
          GoRoute(
            path: '/approvals',
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
            path: '/my-bookings',
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
            path: '/booking/:id',
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
                  baseRoute: '/calendar',
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
      return '/dashboard'; // Admin main screen
    case UserRole.MANAGER:
      return '/dashboard'; // Manager main screen
    case UserRole.USER:
      return '/calendar'; // User main screen
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
