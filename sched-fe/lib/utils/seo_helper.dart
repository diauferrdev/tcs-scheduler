import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show document, querySelector, MetaElement;

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

    try {
      // Update page title
      html.document.title = title;

      // Update meta name="title"
      _updateMetaTag('name', 'title', title);

      // Update description
      if (description != null) {
        _updateMetaTag('name', 'description', description);
      }

      // Update keywords
      if (keywords != null) {
        _updateMetaTag('name', 'keywords', keywords);
      }

      // Update Open Graph tags
      _updateMetaTag('property', 'og:title', ogTitle ?? title);
      if (ogDescription != null) {
        _updateMetaTag('property', 'og:description', ogDescription);
      }
      if (ogImage != null) {
        _updateMetaTag('property', 'og:image', ogImage);
        _updateMetaTag('property', 'og:image:secure_url', ogImage);
      }

      // Update Twitter Card tags
      _updateMetaTag('property', 'twitter:title', ogTitle ?? title);
      if (ogDescription != null) {
        _updateMetaTag('property', 'twitter:description', ogDescription);
      }
      if (ogImage != null) {
        _updateMetaTag('property', 'twitter:image', ogImage);
      }
    } catch (e) {
      // Silently fail on non-web platforms or errors
      if (kDebugMode) {
        print('[SEO] Error updating meta tags: $e');
      }
    }
  }

  /// Update canonical URL
  static void updateCanonicalUrl(String url) {
    if (!kIsWeb) return;

    try {
      final canonical = html.document.querySelector('link[rel="canonical"]');
      if (canonical != null) {
        canonical.setAttribute('href', url);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SEO] Error updating canonical URL: $e');
      }
    }
  }

  /// Helper method to update or create a meta tag
  static void _updateMetaTag(String attribute, String attributeValue, String content) {
    if (!kIsWeb) return;

    try {
      // Try to find existing meta tag
      final selector = 'meta[$attribute="$attributeValue"]';
      var metaTag = html.document.querySelector(selector);

      if (metaTag != null) {
        // Update existing tag
        metaTag.setAttribute('content', content);
      } else {
        // Create new meta tag if it doesn't exist
        metaTag = html.MetaElement()
          ..setAttribute(attribute, attributeValue)
          ..content = content;
        html.document.head?.append(metaTag);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SEO] Error updating meta tag $attributeValue: $e');
      }
    }
  }

  /// Preset meta configurations for common pages
  static const Map<String, Map<String, String>> pageMeta = {
    'landing': {
      'title': 'TCS Pace Scheduler | Enterprise Office Visit Scheduling System',
      'description': 'Enterprise-grade scheduling system for TCS Pace São Paulo office visits. Manage bookings, invitations, and office capacity with real-time notifications across all platforms.',
      'keywords': 'TCS, Pace, Scheduler, Office Booking, Visit Management, Enterprise Scheduling, Calendar, Booking System, TCS São Paulo, Office Management, Capacity Planning',
    },
    'dashboard': {
      'title': 'Dashboard | TCS Pace Scheduler',
      'description': 'View analytics and insights for office visits. Monitor capacity utilization, booking trends, and real-time statistics.',
      'keywords': 'Dashboard, Analytics, Office Analytics, Capacity Management, Booking Statistics, TCS Pace',
    },
    'calendar': {
      'title': 'Calendar | TCS Pace Scheduler',
      'description': 'Smart calendar for managing office visit bookings. View availability, create bookings, and manage your schedule.',
      'keywords': 'Calendar, Office Calendar, Booking Calendar, Schedule Management, TCS Pace',
    },
    'my-bookings': {
      'title': 'My Bookings | TCS Pace Scheduler',
      'description': 'View and manage your office visit bookings. Check booking status, invitations, and visit history.',
      'keywords': 'My Bookings, Booking History, Office Visits, TCS Pace',
    },
    'invitations': {
      'title': 'Invitations | TCS Pace Scheduler',
      'description': 'Manage guest invitations for office visits. Send invitations, track responses, and generate QR badges.',
      'keywords': 'Invitations, Guest Management, QR Badges, Office Invitations, TCS Pace',
    },
    'users': {
      'title': 'User Management | TCS Pace Scheduler',
      'description': 'Manage system users, roles, and permissions. Add users, assign roles, and control access.',
      'keywords': 'User Management, Admin Panel, Role Management, Permissions, TCS Pace',
    },
    'approvals': {
      'title': 'Approvals | TCS Pace Scheduler',
      'description': 'Review and approve pending booking requests. Manage approval workflows and booking confirmations.',
      'keywords': 'Approvals, Booking Approval, Manager Approval, TCS Pace',
    },
    'activity-logs': {
      'title': 'Activity Logs | TCS Pace Scheduler',
      'description': 'View system activity logs and audit trail. Monitor user actions, bookings, and system events.',
      'keywords': 'Activity Logs, Audit Trail, System Logs, TCS Pace',
    },
    'bug-reports': {
      'title': 'Bug Reports | TCS Pace Scheduler',
      'description': 'Report issues and track bug reports. Help improve the TCS Pace Scheduler system.',
      'keywords': 'Bug Reports, Issue Tracking, Support, TCS Pace',
    },
    'login': {
      'title': 'Login | TCS Pace Scheduler',
      'description': 'Sign in to TCS Pace Scheduler. Access your office visit bookings and scheduling dashboard.',
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
