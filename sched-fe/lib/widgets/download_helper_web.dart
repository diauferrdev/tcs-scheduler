// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation of download helper
Future<void> downloadFile(String url, String fileName, List<int> bytes) async {
  // Create blob from bytes
  final blob = html.Blob([bytes]);

  // Create download URL
  final downloadUrl = html.Url.createObjectUrlFromBlob(blob);

  // Create anchor element
  final anchor = html.AnchorElement(href: downloadUrl)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  // Add to DOM, click, and remove
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Revoke URL to free memory
  html.Url.revokeObjectUrl(downloadUrl);
}
