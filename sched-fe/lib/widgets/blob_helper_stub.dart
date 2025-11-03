import 'dart:typed_data';

/// Stub for non-web platforms
Future<Uint8List> blobUrlToBytes(String blobUrl) async {
  throw UnsupportedError('Blob conversion only supported on web');
}
