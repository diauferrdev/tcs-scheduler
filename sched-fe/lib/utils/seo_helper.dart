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
  ///   title: 'Dashboard | TCS Pace Scheduler',
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
      'title': 'TCS Pace Scheduler | Enterprise Office Visit Scheduling System',
      'description':
          'Enterprise-grade scheduling system for TCS Pace São Paulo office visits. Manage bookings, invitations, and office capacity with real-time notifications across all platforms.',
      'keywords':
          'TCS, Pace, Scheduler, Office Booking, Visit Management, Enterprise Scheduling, Calendar, Booking System, TCS São Paulo, Office Management, Capacity Planning',
    },
    'dashboard': {
      'title': 'Dashboard | TCS Pace Scheduler',
      'description':
          'View analytics and insights for office visits. Monitor capacity utilization, booking trends, and real-time statistics.',
      'keywords':
          'Dashboard, Analytics, Office Analytics, Capacity Management, Booking Statistics, TCS Pace',
    },
    'calendar': {
      'title': 'New Booking | TCS Pace Scheduler',
      'description':
          'Create a new office visit booking. View availability, select dates, and schedule your visit.',
      'keywords': 'New Booking, Create Booking, Office Calendar, Schedule Management, TCS Pace',
    },
    'my-bookings': {
      'title': 'My Bookings | TCS Pace Scheduler',
      'description':
          'View and manage your office visit bookings. Check booking status, invitations, and visit history.',
      'keywords': 'My Bookings, Booking History, Office Visits, TCS Pace',
    },
    'invitations': {
      'title': 'Invitations | TCS Pace Scheduler',
      'description':
          'Manage guest invitations for office visits. Send invitations, track responses, and generate QR badges.',
      'keywords': 'Invitations, Guest Management, QR Badges, Office Invitations, TCS Pace',
    },
    'users': {
      'title': 'User Management | TCS Pace Scheduler',
      'description':
          'Manage system users, roles, and permissions. Add users, assign roles, and control access.',
      'keywords': 'User Management, Admin Panel, Role Management, Permissions, TCS Pace',
    },
    'approvals': {
      'title': 'Approvals | TCS Pace Scheduler',
      'description':
          'Review and approve pending booking requests. Manage approval workflows and booking confirmations.',
      'keywords': 'Approvals, Booking Approval, Manager Approval, TCS Pace',
    },
    'activity-logs': {
      'title': 'Activity Logs | TCS Pace Scheduler',
      'description':
          'View system activity logs and audit trail. Monitor user actions, bookings, and system events.',
      'keywords': 'Activity Logs, Audit Trail, System Logs, TCS Pace',
    },
    'bug-reports': {
      'title': 'Bug Reports | TCS Pace Scheduler',
      'description': 'Report issues and track bug reports. Help improve the TCS Pace Scheduler system.',
      'keywords': 'Bug Reports, Issue Tracking, Support, TCS Pace',
    },
    'login': {
      'title': 'Login | TCS Pace Scheduler',
      'description':
          'Sign in to TCS Pace Scheduler. Access your office visit bookings and scheduling dashboard.',
      'keywords': 'Login, Sign In, Authentication, TCS Pace',
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
