/// Stub implementation for non-web platforms
/// These functions do nothing on mobile/desktop platforms

void updatePageMetaImpl({
  required String title,
  String? description,
  String? keywords,
  String? ogTitle,
  String? ogDescription,
  String? ogImage,
}) {
  // No-op on non-web platforms
}

void updateCanonicalUrlImpl(String url) {
  // No-op on non-web platforms
}
