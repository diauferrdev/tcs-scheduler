/// Stub for dart:html for non-web platforms
/// This file provides empty implementations for mobile/desktop
library;

class Location {
  String get hostname => '';
  String get href => '';
  set href(String value) {}
}

class Window {
  final Location location = Location();
  void addEventListener(String type, dynamic listener, [bool? useCapture]) {}
}

class CustomEvent {
  dynamic get detail => null;
}

class Event {}

final window = Window();
