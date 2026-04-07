import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'models/user.dart';
import 'widgets/app_layout.dart';
import 'widgets/permissions_wrapper.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/invitations_screen.dart';
import 'screens/users_screen.dart';
import 'screens/activity_logs_screen.dart';
import 'screens/approvals_screen.dart';
import 'screens/my_bookings_screen.dart';
import 'screens/tickets_screen.dart';
import 'screens/create_ticket_screen.dart';
import 'screens/ticket_detail_screen.dart';
import 'screens/drawer_route_screen.dart';
import 'screens/rooms_screen.dart';
import 'services/navigation_service.dart';
import 'services/drawer_service.dart';
import 'utils/seo_helper.dart';
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

/// Update SEO meta tags based on the current route
void _updateSeoForRoute(String path) {
  if (!kIsWeb) return;

  // Extract page key from path (e.g., /app/dashboard -> dashboard)
  String pageKey = 'landing';

  if (path.startsWith('/app/')) {
    final segments = path.split('/');
    if (segments.length >= 3) {
      pageKey = segments[2];
    }
  } else if (path == '/login') {
    pageKey = 'login';
  } else if (path == '/') {
    pageKey = 'landing';
  }

  // Update SEO using preset configurations
  SeoHelper.setPageMeta(pageKey);

  // Update canonical URL
  try {
    final fullUrl = 'https://pacesched.com$path';
    SeoHelper.updateCanonicalUrl(fullUrl);
  } catch (e) {
    // Silently fail
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
      final isChangePasswordRoute = currentPath == '/change-password';

      // Update SEO for current route (web only)
      _updateSeoForRoute(currentPath);

      // Wait for auth check to complete
      if (isLoading) {
        return null;
      }

      // Must-change-password redirect (all platforms)
      if (isAuthenticated && authProvider.mustChangePassword && !isChangePasswordRoute) {
        return '/change-password';
      }
      if (isAuthenticated && !authProvider.mustChangePassword && isChangePasswordRoute) {
        return _getMainScreenForRole(user?.role ?? UserRole.USER);
      }

      // NATIVE APPS (Android, iOS, Desktop)
      if (!kIsWeb) {
        // Landing page is not available on native apps
        if (isLandingRoute) {
          return isAuthenticated
            ? _getMainScreenForRole(user?.role ?? UserRole.USER)
            : '/login';
        }

        // If authenticated and trying to access login, redirect to main screen
        if (isAuthenticated && isLoginRoute) {
          return _getMainScreenForRole(user?.role ?? UserRole.USER);
        }

        // Redirect to login if not authenticated (except on login)
        if (!isAuthenticated && !isLoginRoute) {
          return '/login';
        }

        return null;
      }

      // WEB ROUTING (localhost or pacesched.com)
      final isLocalhost = _isLocalhost();

      // LOCALHOST: Allow all routes for development
      if (isLocalhost) {
        // If authenticated and trying to access login, redirect to app
        if (isAuthenticated && isLoginRoute) {
          return '/app';
        }

        // Redirect to login if not authenticated (except on landing/login)
        if (!isAuthenticated && !isLoginRoute && !isLandingRoute) {
          return '/login';
        }
        return null;
      }

      // PRODUCTION WEB (pacesched.com)
      // If authenticated and trying to access login, redirect to app
      if (isAuthenticated && isLoginRoute) {
        return '/app';
      }

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

      // Change password route (no AppLayout)
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      // Redirect /app to the appropriate screen based on user role
      GoRoute(
        path: '/app',
        redirect: (context, state) {
          final user = authProvider.user;
          if (user == null) {
            return '/login';
          }
          return _getMainScreenForRole(user.role);
        },
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
            path: '/app/schedule',
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
            path: '/app/audit',
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
                baseRoute: '/app/schedule',
              ),
            ),
          ),
          GoRoute(
            path: '/app/pending',
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
            path: '/app/my-visits',
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
            path: '/app/rooms',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const RoomsScreen(),
            ),
          ),
          GoRoute(
            path: '/app/support',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const TicketsScreen(),
            ),
          ),
          GoRoute(
            path: '/app/support/create',
            pageBuilder: (context, state) => _buildPageWithTransition(
              context,
              state,
              const CreateTicketScreen(),
            ),
          ),
          GoRoute(
            path: '/app/support/:id',
            pageBuilder: (context, state) {
              final ticketId = state.pathParameters['id'];
              if (ticketId == null) {
                throw Exception('Ticket ID is required');
              }
              return _buildPageWithTransition(
                context,
                state,
                TicketDetailScreen(ticketId: ticketId),
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
                  baseRoute: '/app/schedule',
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
      return '/app/schedule'; // User main screen
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
