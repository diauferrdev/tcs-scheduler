// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

class Device3DView extends StatefulWidget {
  final String deviceType; // 'phone' or 'notebook'
  final String? videoPath;
  final String? imagePath;
  final String entranceAnimation;
  final String loopAnimation;
  final double brightness;
  final String bodyColor;
  final bool enableGlow;
  final double? notebookAngle;
  final bool? rgbEnabled;
  final Map<String, double>? cameraPosition;

  const Device3DView({
    super.key,
    required this.deviceType,
    this.videoPath,
    this.imagePath,
    this.entranceAnimation = 'spiral',
    this.loopAnimation = 'float',
    this.brightness = 1.4,
    this.bodyColor = '#171717',
    this.enableGlow = false,
    this.notebookAngle,
    this.rgbEnabled,
    this.cameraPosition,
  });

  @override
  State<Device3DView> createState() => _Device3DViewState();
}

class _Device3DViewState extends State<Device3DView> {
  late String viewId;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    viewId = 'device-3d-${widget.deviceType}-${DateTime.now().millisecondsSinceEpoch}';
    _registerView();
  }

  void _registerView() {
    if (_isRegistered) return;

    debugPrint('[Device3DView] Registering view: $viewId');

    // Register the view factory
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewIdInt) {
        debugPrint('[Device3DView] Creating canvas for: $viewId');

        final canvas = html.CanvasElement()
          ..id = 'renderCanvas-$viewId'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'block'
          ..style.outline = 'none'
          ..style.backgroundColor = '#0A0A0A';

        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.position = 'relative'
          ..style.overflow = 'hidden'
          ..style.backgroundColor = '#0A0A0A'
          ..append(canvas);

        debugPrint('[Device3DView] Canvas created with ID: ${canvas.id}');

        // Initialize after a delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _initialize3DViewer(canvas.id);
        });

        return container;
      },
    );

    _isRegistered = true;
    debugPrint('[Device3DView] View registered successfully');
  }

  void _initialize3DViewer(String canvasId) {
    try {
      debugPrint('[Device3DView] Initializing 3D viewer for $canvasId');

      // Check if Babylon.js is loaded
      if (js.context['BABYLON'] == null) {
        debugPrint('[Device3DView] ❌ BABYLON.js not loaded!');
        return;
      }

      // Check if DeviceViewer class exists
      final deviceViewerClass = js.context['DeviceViewer'];
      if (deviceViewerClass == null) {
        debugPrint('[Device3DView] ❌ DeviceViewer class not found!');
        return;
      }

      debugPrint('[Device3DView] ✅ BABYLON.js and DeviceViewer found');

      // Create config object
      final config = js.JsObject.jsify({
        'canvasId': canvasId,
        'deviceType': widget.deviceType,
        'entranceAnimation': widget.entranceAnimation,
        'loopAnimation': widget.loopAnimation,
        'brightness': widget.brightness,
        'logoUrl': 'assets/Tata_logo.svg',
        'antialias': true,
        'enableGlow': widget.enableGlow,
        if (widget.deviceType == 'phone') ...{
          'phoneBodyColor': widget.bodyColor,
          'defaultVideoPath': widget.videoPath ?? 'assets/videos/phone-video.mp4',
          if (widget.cameraPosition != null) 'phoneCameraPosition': {
            'alpha': widget.cameraPosition!['alpha'] ?? 1.8935610276630728,
            'beta': widget.cameraPosition!['beta'] ?? 1.565868257398884,
            'radius': widget.cameraPosition!['radius'] ?? 4.634514487077737,
          },
        },
        if (widget.deviceType == 'notebook') ...{
          'notebookAngle': widget.notebookAngle ?? 100,
          'rgbEnabled': widget.rgbEnabled ?? false,
          'defaultVideoPath': widget.videoPath ?? 'assets/videos/notebook-video.mp4',
          if (widget.cameraPosition != null) 'notebookCameraPosition': {
            'alpha': widget.cameraPosition!['alpha'] ?? 1.9167978714315308,
            'beta': widget.cameraPosition!['beta'] ?? 1.1794037363153675,
            'radius': widget.cameraPosition!['radius'] ?? 16.28,
          },
        },
      });

      debugPrint('[Device3DView] Creating DeviceViewer instance...');

      // Create the DeviceViewer instance
      final viewer = js.JsObject(deviceViewerClass, [config]);

      debugPrint('[Device3DView] ✅ DeviceViewer instance created: $viewer');
    } catch (e, stackTrace) {
      debugPrint('[Device3DView] ❌ Error initializing 3D viewer: $e');
      debugPrint('[Device3DView] Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: viewId,
    );
  }
}
