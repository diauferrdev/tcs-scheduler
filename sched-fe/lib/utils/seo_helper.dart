import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional import: only use dart:html on web platform
import 'seo_helper_stub.dart'
    if (dart.library.html) 'seo_helper_web.dart';

/// SEO Helper for Flutter Web
/// Provides utilities to dynamically update page title and meta tags for better SEO
/// This is crucial for Single Page Applications (SPAs) where content changes without page reloads
class SeoHelper {
  /// Update the page title and related meta tags
  ///
  /// Usage:
  /// ```dart
  /// SeoHelper.updatePageMeta(
  ///   title: 'Dashboard | Pace Scheduler',
  ///   description: 'View analytics and insights for office visits',
  /// );
  /// ```
  static void updatePageMeta({
    required String title,
    String? description,
    String? keywords,
    String? ogTitle,
    String? ogDescription,
    String? ogImage,
  }) {
    if (!kIsWeb) return;

    updatePageMetaImpl(
      title: title,
      description: description,
      keywords: keywords,
      ogTitle: ogTitle,
      ogDescription: ogDescription,
      ogImage: ogImage,
    );
  }

  /// Update canonical URL
  static void updateCanonicalUrl(String url) {
    if (!kIsWeb) return;
    updateCanonicalUrlImpl(url);
  }

  /// Preset meta configurations for common pages
  static const Map<String, Map<String, String>> pageMeta = {
    'landing': {
      'title': 'Pace Scheduler | Enterprise Office Visit Scheduling System',
      'description':
          'Enterprise-grade scheduling system for PacePort São Paulo office visits. Manage bookings, invitations, and office capacity with real-time notifications across all platforms.',
      'keywords':
          'Pace, Scheduler, Office Booking, Visit Management, Enterprise Scheduling, Calendar, Booking System, PacePort São Paulo, Office Management, Capacity Planning',
    },
    'dashboard': {
      'title': 'Dashboard | Pace Scheduler',
      'description':
          'View analytics and insights for office visits. Monitor capacity utilization, booking trends, and real-time statistics.',
      'keywords':
          'Dashboard, Analytics, Office Analytics, Capacity Management, Booking Statistics, Pace Scheduler',
    },
    'calendar': {
      'title': 'New Booking | Pace Scheduler',
      'description':
          'Create a new office visit booking. View availability, select dates, and schedule your visit.',
      'keywords': 'New Booking, Create Booking, Office Calendar, Schedule Management, Pace Scheduler',
    },
    'my-visits': {
      'title': 'My Visits | Pace Scheduler',
      'description':
          'View and manage your office visit bookings. Check booking status, invitations, and visit history.',
      'keywords': 'My Visits, Booking History, Office Visits, Pace Scheduler',
    },
    'invitations': {
      'title': 'Invitations | Pace Scheduler',
      'description':
          'Manage guest invitations for office visits. Send invitations, track responses, and generate QR badges.',
      'keywords': 'Invitations, Guest Management, QR Badges, Office Invitations, Pace Scheduler',
    },
    'users': {
      'title': 'User Management | Pace Scheduler',
      'description':
          'Manage system users, roles, and permissions. Add users, assign roles, and control access.',
      'keywords': 'User Management, Admin Panel, Role Management, Permissions, Pace Scheduler',
    },
    'approvals': {
      'title': 'Approvals | Pace Scheduler',
      'description':
          'Review and approve pending booking requests. Manage approval workflows and booking confirmations.',
      'keywords': 'Approvals, Booking Approval, Manager Approval, Pace Scheduler',
    },
    'activity-logs': {
      'title': 'Activity Logs | Pace Scheduler',
      'description':
          'View system activity logs and audit trail. Monitor user actions, bookings, and system events.',
      'keywords': 'Activity Logs, Audit Trail, System Logs, Pace Scheduler',
    },
    'bug-reports': {
      'title': 'Bug Reports | Pace Scheduler',
      'description': 'Report issues and track bug reports. Help improve the Pace Scheduler system.',
      'keywords': 'Bug Reports, Issue Tracking, Support, Pace Scheduler',
    },
    'login': {
      'title': 'Login | Pace Scheduler',
      'description':
          'Sign in to Pace Scheduler. Access your office visit bookings and scheduling dashboard.',
      'keywords': 'Login, Sign In, Authentication, Pace Scheduler',
    },
  };

  /// Quick method to update page meta using preset configurations
  ///
  /// Usage:
  /// ```dart
  /// SeoHelper.setPageMeta('dashboard');
  /// ```
  static void setPageMeta(String pageKey) {
    if (!kIsWeb) return;

    final meta = pageMeta[pageKey];
    if (meta == null) return;

    updatePageMeta(
      title: meta['title']!,
      description: meta['description'],
      keywords: meta['keywords'],
      ogTitle: meta['title'],
      ogDescription: meta['description'],
    );
  }
}
