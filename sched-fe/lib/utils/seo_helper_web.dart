// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// Web-specific implementation for SEO helper
void updatePageMetaImpl({
  required String title,
  String? description,
  String? keywords,
  String? ogTitle,
  String? ogDescription,
  String? ogImage,
}) {
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
    if (kDebugMode) {
    }
  }
}

void updateCanonicalUrlImpl(String url) {
  try {
    final canonical = html.document.querySelector('link[rel="canonical"]');
    if (canonical != null) {
      canonical.setAttribute('href', url);
    }
  } catch (e) {
    if (kDebugMode) {
    }
  }
}

/// Helper method to update or create a meta tag
void _updateMetaTag(String attribute, String attributeValue, String content) {
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
    }
  }
}
