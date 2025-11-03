import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

/// Convert blob URL to Uint8List for web
Future<Uint8List> blobUrlToBytes(String blobUrl) async {
  final completer = Completer<Uint8List>();

  final xhr = html.HttpRequest();
  xhr.open('GET', blobUrl);
  xhr.responseType = 'arraybuffer';

  xhr.onLoad.listen((_) {
    if (xhr.status == 200) {
      final buffer = xhr.response;
      if (buffer != null) {
        // Convert to Uint8List - response is already an ArrayBuffer/ByteBuffer
        final bytes = Uint8List.view(buffer as ByteBuffer);
        completer.complete(bytes);
      } else {
        completer.completeError('Response buffer is null');
      }
    } else {
      completer.completeError('Failed to load blob: ${xhr.status}');
    }
  });

  xhr.onError.listen((error) {
    completer.completeError('XHR error: $error');
  });

  xhr.send();

  return completer.future;
}
