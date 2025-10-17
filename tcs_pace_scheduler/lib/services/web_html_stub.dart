/// Stub for dart:html for non-web platforms
/// This file provides empty implementations for mobile/desktop

class Window {
  void addEventListener(String type, dynamic listener, [bool? useCapture]) {}
}

class CustomEvent {
  dynamic get detail => null;
}

class Event {}

final window = Window();
