/// Stub implementation for non-web platforms (Android, iOS, etc.)
void signalAppReady() {}
bool pwaCanInstall() => false;
Future<bool> pwaInstall() async => false;
