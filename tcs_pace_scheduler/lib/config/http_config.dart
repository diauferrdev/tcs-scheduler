// Conditional imports for platform-specific HTTP client
export 'http_config_stub.dart'
    if (dart.library.html) 'http_config_web.dart';
