// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:sched_fe/widgets/scroll_reveal.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:sched_fe/utils/responsive_helper.dart';

class Device3DSection extends StatefulWidget {
  final int index;
  final String deviceType;
  final String animation;
  final bool deviceOnLeft;
  final String title;
  final String description;
  final String badge;
  final bool isHero;

  const Device3DSection({
    super.key,
    required this.index,
    required this.deviceType,
    required this.animation,
    required this.deviceOnLeft,
    required this.title,
    required this.description,
    required this.badge,
    this.isHero = false,
  });

  @override
  State<Device3DSection> createState() => _Device3DSectionState();
}

class _Device3DSectionState extends State<Device3DSection> {
  late String viewId;
  late String canvasId;
  bool _isRegistered = false;
  bool _viewerCreated = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    viewId = 'device-3d-section-${widget.index}';
    canvasId = 'canvas-${widget.index}';
    _registerView();
    // Viewer will be initialized when ScrollReveal detects visibility
  }

  void triggerAnimation() {
    if (!_viewerCreated && mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_viewerCreated) {
          _initialize3DViewer();
        }
      });
    }
  }

  void _registerView() {
    if (_isRegistered) return;

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewIdInt) {
        final canvas = html.CanvasElement()
          ..id = canvasId
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'block'
          ..style.outline = 'none'
          ..style.backgroundColor = 'transparent';

        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.position = 'relative'
          ..style.overflow = 'hidden'
          ..append(canvas);

        return container;
      },
    );

    _isRegistered = true;
  }

  void _initialize3DViewer() {
    if (_viewerCreated) return;

    try {
      if (js.context['BABYLON'] == null || js.context['DeviceViewer'] == null) {
        return;
      }

      final deviceViewerClass = js.context['DeviceViewer'];
      final viewerManager = js.context['viewerManager'];

      final isMobile = ResponsiveHelper.isMobile(context);

      final config = js.JsObject.jsify({
        'canvasId': canvasId,
        'deviceType': widget.deviceType,
        'entranceAnimation': widget.animation,
        'loopAnimation': 'float',
        'brightness': 1.4,
        'logoUrl': 'assets/Tata_logo.svg',
        'enableGlow': widget.deviceType == 'phone',
        'antialias': true,
        'enableInteraction': !isMobile, // Disable interaction on mobile
        'defaultVideoPath': widget.deviceType == 'phone'
            ? 'assets/videos/phone-video.mp4'
            : 'assets/videos/notebook-video.mp4',
        'rgbEnabled': widget.deviceType == 'notebook' ? false : null,
        if (widget.deviceType == 'phone') ...{
          'phoneCameraPosition': {
            'alpha': 1.8,
            'beta': 1.5,
            'radius': 1,
          },
          'phoneCameraTarget': {
            'x': 0,
            'y': 0,
            'z': 0,
          },
        },
        if (widget.deviceType == 'notebook') ...{
          'notebookCameraPosition': {
            'alpha': -5.1000000000000005,
            'beta': 1.1279966607226328,
            'radius': 16,
          },
          'notebookCameraTarget': {
            'x': 1,
            'y': 2.5,
            'z': 0,
          },
        },
      });

      final viewer = js.JsObject(deviceViewerClass, [config]);
      _viewerCreated = true;

      if (viewerManager != null) {
        try {
          js.context.callMethod('eval', ['window.viewerManager.registerViewer("$canvasId", window["$canvasId"+"_viewer"])']);
          js.context['${canvasId}_viewer'] = viewer;
        } catch (e) {
          // Silent fail
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return VisibilityDetector(
      key: Key('visibility-section-${widget.index}'),
      onVisibilityChanged: (info) {
        final wasVisible = _isVisible;
        final nowVisible = info.visibleFraction >= 0.3;

        if (wasVisible != nowVisible && mounted) {
          setState(() {
            _isVisible = nowVisible;
          });
        }

        if (nowVisible && !_viewerCreated) {
          triggerAnimation();
        }

        if (_viewerCreated) {
          try {
            final viewerManager = js.context['viewerManager'];
            if (viewerManager != null) {
              viewerManager.callMethod('updateVisibility', [canvasId, nowVisible, info.visibleFraction]);
            }
          } catch (e) {
            // Silently fail
          }
        }
      },
      child: isMobile ? _buildMobileLayout(context) : _buildDesktopLayout(context),
    );
  }

  // Desktop layout: side-by-side
  Widget _buildDesktopLayout(BuildContext context) {
    final deviceOnRight = widget.index % 2 == 0;

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Stack(
        children: [
          // 3D Viewer
          Positioned(
            top: 0,
            left: deviceOnRight ? null : 0,
            right: deviceOnRight ? 0 : null,
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height,
            child: AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              child: HtmlElementView(viewType: viewId),
            ),
          ),

          // Text content
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: Row(
                children: [
                  if (deviceOnRight) ...[
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: ScrollReveal(
                            delay: const Duration(milliseconds: 200),
                            slideLeft: true,
                            child: _buildTextContent(),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                  ] else ...[
                    const Spacer(),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: ScrollReveal(
                            delay: const Duration(milliseconds: 200),
                            slideRight: true,
                            child: _buildTextContent(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile layout: vertical stack
  Widget _buildMobileLayout(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight,
      child: Column(
        children: [
          // 3D Viewer at top (50% of screen for better model visibility)
          SizedBox(
            height: screenHeight * 0.5,
            child: AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              child: HtmlElementView(viewType: viewId),
            ),
          ),

          // Text content below (50% of screen with scrolling)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ScrollReveal(
                delay: const Duration(milliseconds: 200),
                child: _buildTextContent(mobile: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent({bool mobile = false}) {
    return Column(
      mainAxisAlignment: mobile ? MainAxisAlignment.start : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 10 : 16,
            vertical: mobile ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: Colors.white24, width: 1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            widget.badge,
            style: TextStyle(
              fontSize: mobile ? 9 : 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontFamily: 'NeueHaasGrotesk',
            ),
          ),
        ),
        SizedBox(height: mobile ? 16 : 32),

        // Title
        Text(
          widget.title,
          style: TextStyle(
            fontSize: mobile ? 28 : 56,
            height: mobile ? 1.2 : 1.1,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: mobile ? -0.5 : -1.5,
            fontFamily: 'HouskaPro',
          ),
        ),
        SizedBox(height: mobile ? 12 : 24),

        // Description
        Text(
          widget.description,
          style: TextStyle(
            fontSize: mobile ? 14 : 18,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
            fontFamily: 'NeueHaasGrotesk',
          ),
        ),
        SizedBox(height: mobile ? 20 : 40),

        // CTA Buttons (only on hero)
        if (widget.isHero) ...[
          mobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.rocket_launch, size: 18),
                      label: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'NeueHaasGrotesk',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text(
                        'Watch Demo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'NeueHaasGrotesk',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.rocket_launch, size: 20),
                      label: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'NeueHaasGrotesk',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text(
                        'Watch Demo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'NeueHaasGrotesk',
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24, width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ],
    );
  }
}
