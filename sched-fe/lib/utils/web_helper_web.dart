// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;

/// Web-specific implementation
void signalAppReady() {
  try {
    html.window.dispatchEvent(html.CustomEvent('app-ready'));
  } catch (e) {
  }
}

bool pwaCanInstall() {
  try {
    return js.context.callMethod('pwaCanInstall') as bool;
  } catch (_) {
    return false;
  }
}

Future<bool> pwaInstall() async {
  try {
    final result = await js.context.callMethod('pwaInstall');
    return result == true;
  } catch (_) {
    return false;
  }
}
