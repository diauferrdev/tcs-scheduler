// Conditional export - uses web implementation on web, stub on other platforms
export 'device_3d_section_web.dart' if (dart.library.io) 'device_3d_section_stub.dart';
