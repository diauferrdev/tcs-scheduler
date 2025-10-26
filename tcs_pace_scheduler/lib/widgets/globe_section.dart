// Conditional export - uses web implementation on web, stub on other platforms
export 'globe_section_web.dart' if (dart.library.io) 'globe_section_stub.dart';
