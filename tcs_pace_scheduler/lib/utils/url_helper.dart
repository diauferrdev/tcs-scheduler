import '../config/api_config.dart';

/// Helper to convert relative URLs to absolute URLs
String getAbsoluteUrl(String? url) {
  if (url == null || url.isEmpty) return '';

  // Already absolute
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  // Remove leading slash if present
  final path = url.startsWith('/') ? url.substring(1) : url;

  // Return absolute URL
  return '${ApiConfig.baseUrl}/$path';
}
