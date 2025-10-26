import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;
import 'package:visibility_detector/visibility_detector.dart';
import 'package:sched_fe/widgets/scroll_reveal.dart';
import 'package:sched_fe/utils/responsive_helper.dart';

class GlobeSection extends StatefulWidget {
  final bool showAtmosphere;
  final bool enableRotation;

  const GlobeSection({
    super.key,
    this.showAtmosphere = true,
    this.enableRotation = true,
  });

  @override
  State<GlobeSection> createState() => _GlobeSectionState();
}

class _GlobeSectionState extends State<GlobeSection> {
  static const String viewId = 'globe-section-view';
  static const String canvasId = 'globeCanvas';
  bool _isRegistered = false;
  bool _viewerCreated = false;
  bool _isVisible = false;

  // TCS Pace Port locations with exact colors from globe-viewer
  final List<Map<String, dynamic>> offices = [
    {
      'name': 'São Paulo',
      'color': const Color.fromRGBO(0, 255, 127, 1), // Verde esmeralda
      'isCurrent': true,
    },
    {
      'name': 'Toronto',
      'color': const Color.fromRGBO(0, 255, 255, 1), // Ciano brilhante
      'isCurrent': false,
    },
    {
      'name': 'New York',
      'color': const Color.fromRGBO(255, 127, 0, 1), // Laranja vibrante
      'isCurrent': false,
    },
    {
      'name': 'Pittsburgh',
      'color': const Color.fromRGBO(127, 255, 0, 1), // Verde limão
      'isCurrent': false,
    },
    {
      'name': 'Tokyo',
      'color': const Color.fromRGBO(0, 76, 255, 1), // Azul royal
      'isCurrent': false,
    },
    {
      'name': 'Amsterdam',
      'color': const Color.fromRGBO(255, 76, 178, 1), // Rosa chiclete
      'isCurrent': false,
    },
    {
      'name': 'London',
      'color': const Color.fromRGBO(255, 204, 0, 1), // Amarelo ouro
      'isCurrent': false,
    },
    {
      'name': 'Paris',
      'color': const Color.fromRGBO(127, 0, 255, 1), // Roxo profundo
      'isCurrent': false,
    },
    {
      'name': 'Singapore',
      'color': const Color.fromRGBO(255, 0, 127, 1), // Magenta vibrante
      'isCurrent': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  void _registerView() {
    if (_isRegistered) return;

    debugPrint('[GlobeSection] Registering view: $viewId');

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

        debugPrint('[GlobeSection] Canvas created: $canvasId');
        return container;
      },
    );

    _isRegistered = true;
  }

  void _initialize3DViewer() {
    if (_viewerCreated) return;

    try {
      debugPrint('[GlobeSection] Initializing globe viewer for canvas: $canvasId');

      if (js.context['BABYLON'] == null) {
        debugPrint('[GlobeSection] ❌ BABYLON.js not loaded!');
        return;
      }

      final globeViewerClass = js.context['GlobeViewer'];
      if (globeViewerClass == null) {
        debugPrint('[GlobeSection] ❌ GlobeViewer class not found!');
        return;
      }

      final viewerManager = js.context['viewerManager'];
      if (viewerManager == null) {
        debugPrint('[GlobeSection] ⚠️ ViewerManager not found!');
      }

      final config = js.JsObject.jsify({
        'canvasId': canvasId,
        'radius': 1.0,
        'showAtmosphere': widget.showAtmosphere,
        'enableRotation': widget.enableRotation,
        'darkMode': false, // Use day texture (looks better)
      });

      final viewer = js.JsObject(globeViewerClass, [config]);
      _viewerCreated = true;

      // Register with ViewerManager for performance optimization
      if (viewerManager != null) {
        try {
          js.context.callMethod('eval', ['window.viewerManager.registerViewer("$canvasId", window["$canvasId"+"_viewer"])']);
          // Store viewer reference globally for manager access
          js.context[canvasId + '_viewer'] = viewer;
          debugPrint('[GlobeSection] ✅ Registered with ViewerManager: $canvasId');
        } catch (e) {
          debugPrint('[GlobeSection] ⚠️ Failed to register with ViewerManager: $e');
        }
      }

      debugPrint('[GlobeSection] ✅ Globe viewer created successfully');
    } catch (e, stackTrace) {
      debugPrint('[GlobeSection] ❌ Error initializing: $e');
      debugPrint('[GlobeSection] Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return VisibilityDetector(
      key: const Key('visibility-globe-section'),
      onVisibilityChanged: (info) {
        final wasVisible = _isVisible;
        final nowVisible = info.visibleFraction >= 0.3;

        // Update visibility state
        if (wasVisible != nowVisible) {
          setState(() {
            _isVisible = nowVisible;
          });
        }

        // Initialize viewer when visible
        if (nowVisible && !_viewerCreated) {
          debugPrint('[VisibilityDetector] Globe section is ${(info.visibleFraction * 100).toStringAsFixed(1)}% visible, initializing viewer');
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_viewerCreated) {
              _initialize3DViewer();
            }
          });
        }

        // Update ViewerManager with visibility status
        if (_viewerCreated) {
          try {
            final viewerManager = js.context['viewerManager'];
            if (viewerManager != null) {
              viewerManager.callMethod('updateVisibility', [canvasId, nowVisible, info.visibleFraction]);
            }
          } catch (e) {
            // Silently fail if ViewerManager not available
          }
        }
      },
      child: isMobile ? _buildMobileLayout(context) : _buildDesktopLayout(context),
    );
  }

  // Desktop layout: side-by-side with globe on left
  Widget _buildDesktopLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight,
      child: Stack(
        children: [
          // Globe viewer on the left side (50%) - Animated fade-in/fade-out
          Positioned(
            left: 0,
            top: 0,
            width: screenWidth * 0.5,
            height: screenHeight,
            child: AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              onEnd: () {
                // After fade-out completes, Babylon.js will stop rendering
              },
              child: const HtmlElementView(viewType: viewId),
            ),
          ),

          // Content on the right side (50%)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: Row(
                children: [
                  const Spacer(), // Left side for globe
                  // Text content on right
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: ScrollReveal(
                          delay: const Duration(milliseconds: 200),
                          slideRight: true,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  border: Border.all(color: Colors.white24, width: 1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Text(
                                  'GLOBAL INFRASTRUCTURE',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'NeueHaasGrotesk',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Title
                              const Text(
                                'One Platform,\nUnlimited Locations',
                                style: TextStyle(
                                  fontSize: 56,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -1.5,
                                  fontFamily: 'HouskaPro',
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Description
                              Text(
                                'Built for TCS Pace São Paulo, ready for the world. Our multi-tenant architecture automatically detects your location and connects you to your local Pace Port office.',
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.6,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'NeueHaasGrotesk',
                                ),
                              ),
                              const SizedBox(height: 48),

                              // Office locations legend (compact)
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                children: offices.map((office) => _buildOfficeChip(office)).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile layout: vertical stack with globe on top
  Widget _buildMobileLayout(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight,
      child: Column(
        children: [
          // Globe viewer at top (40% of screen)
          SizedBox(
            height: screenHeight * 0.4,
            child: AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              child: const HtmlElementView(viewType: viewId),
            ),
          ),

          // Text content below (60% of screen)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ScrollReveal(
                delay: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white24, width: 1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Text(
                        'GLOBAL INFRASTRUCTURE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'NeueHaasGrotesk',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    const Text(
                      'One Platform,\nUnlimited Locations',
                      style: TextStyle(
                        fontSize: 32,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.8,
                        fontFamily: 'HouskaPro',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'Built for TCS Pace São Paulo, ready for the world. Our multi-tenant architecture automatically detects your location and connects you to your local Pace Port office.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                        fontFamily: 'NeueHaasGrotesk',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Office locations legend (compact)
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: offices.map((office) => _buildOfficeChip(office, mobile: true)).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeChip(Map<String, dynamic> office, {bool mobile = false}) {
    final isCurrent = office['isCurrent'] as bool;
    final name = office['name'] as String;
    final color = office['color'] as Color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 10 : 12,
        vertical: mobile ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: isCurrent ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        border: Border.all(
          color: isCurrent ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: mobile ? 6 : 8,
            height: mobile ? 6 : 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: isCurrent ? [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
          ),
          SizedBox(width: mobile ? 6 : 8),
          Text(
            name,
            style: TextStyle(
              fontSize: mobile ? 11 : 13,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              color: isCurrent ? Colors.white : Colors.white.withOpacity(0.7),
              fontFamily: 'NeueHaasGrotesk',
            ),
          ),
        ],
      ),
    );
  }

}
