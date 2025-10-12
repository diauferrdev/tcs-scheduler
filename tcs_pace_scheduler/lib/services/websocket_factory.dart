/// WebSocket Factory - Conditional Exports
/// Provides platform-specific WebSocket channel creation
export 'websocket_factory_stub.dart'
    if (dart.library.html) 'websocket_factory_web.dart'
    if (dart.library.io) 'websocket_factory_io.dart';
