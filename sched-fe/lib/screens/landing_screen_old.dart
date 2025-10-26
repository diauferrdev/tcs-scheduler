import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  Map<String, dynamic>? _versionInfo;
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _sections = [
    {
      'deviceType': 'phone',
      'animation': 'zoomIn',
      'deviceOnLeft': false,
      'title': 'Simplify Your\nOffice Scheduling',
      'description': 'Enterprise-grade scheduling system for TCS Pace São Paulo.\nManage office visits, invitations, and capacity with real-time\nnotifications across all platforms.',
      'badge': 'Enterprise Solution',
    },
    {
      'deviceType': 'notebook',
      'animation': 'dramatic',
      'deviceOnLeft': true,
      'title': 'Smart Features\nfor Modern Teams',
      'description': 'Real-time availability, instant notifications, and\nintelligent scheduling powered by cutting-edge technology.',
      'badge': 'Feature Rich',
    },
    {
      'deviceType': 'phone',
      'animation': 'zoomIn',
      'deviceOnLeft': false,
      'title': 'Cross-Platform\nExperience',
      'description': 'Access from anywhere - Web, Windows, macOS, Linux,\niOS, and Android. Your schedule syncs seamlessly.',
      'badge': 'All Platforms',
    },
    {
      'deviceType': 'notebook',
      'animation': 'dramatic',
      'deviceOnLeft': true,
      'title': 'Built for\nCollaboration',
      'description': 'Invite guests, manage attendees, and coordinate\noffice visits with powerful team features.',
      'badge': 'Team Work',
    },
    {
      'deviceType': 'phone',
      'animation': 'zoomIn',
      'deviceOnLeft': false,
      'title': 'Insights &\nAnalytics',
      'description': 'Track office utilization, booking trends, and\noptimize capacity with powerful analytics.',
      'badge': 'Data Driven',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    _scrollController.addListener(_onScroll);

    // Initialize Babylon.js scene after a delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_babylonInitialized) {
        _initializeBabylon();
        _babylonInitialized = true;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isSnapping) return;

    final currentOffset = _scrollController.offset;
    final screenHeight = MediaQuery.of(context).size.height;

    // Detect scroll direction
    final isScrollingDown = currentOffset > _lastScrollPosition;
    _lastScrollPosition = currentOffset;

    // Calculate current section based on offset
    final currentSectionFromOffset = (currentOffset / screenHeight).round().clamp(0, _sections.length - 1);

    // If user scrolled enough (more than 50 pixels), snap to next/previous section
    final scrollDelta = (currentOffset - (_currentSection * screenHeight)).abs();

    if (scrollDelta > 50 && !_isSnapping) {
      int targetSection = _currentSection;

      if (isScrollingDown && _currentSection < _sections.length - 1) {
        targetSection = _currentSection + 1;
      } else if (!isScrollingDown && _currentSection > 0) {
        targetSection = _currentSection - 1;
      }

      if (targetSection != _currentSection) {
        _snapToSection(targetSection);
      }
    }
  }

  void _snapToSection(int targetSection) {
    if (_isSnapping) return;

    setState(() {
      _isSnapping = true;
      _currentSection = targetSection;
    });

    final screenHeight = MediaQuery.of(context).size.height;
    final targetOffset = targetSection * screenHeight;

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    ).then((_) {
      setState(() => _isSnapping = false);
      _switchDeviceAnimation();
    });
  }

  void _initializeBabylon() {
    try {
      // Create fixed background canvas - full screen with transparent background
      final canvas = html.CanvasElement()
        ..id = 'babylonCanvas'
        ..style.position = 'fixed'
        ..style.top = '0'
        ..style.left = '0'
        ..style.width = '100vw'
        ..style.height = '100vh'
        ..style.zIndex = '0' // Behind Flutter content
        ..style.pointerEvents = 'none'; // Let Flutter handle scroll

      html.document.body?.insertBefore(canvas, html.document.body?.firstChild);

      // Create interaction area for right half (where 3D is visible)
      final interactionArea = html.DivElement()
        ..id = 'babylonInteractionArea'
        ..style.position = 'fixed'
        ..style.top = '0'
        ..style.left = '50%'
        ..style.width = '50vw'
        ..style.height = '100vh'
        ..style.zIndex = '10'
        ..style.pointerEvents = 'auto'
        ..style.cursor = 'grab';

      html.document.body?.append(interactionArea);

      // Forward mouse events to Babylon canvas
      interactionArea.onMouseDown.listen((e) {
        canvas.style.pointerEvents = 'auto';
        interactionArea.style.cursor = 'grabbing';
      });

      interactionArea.onMouseUp.listen((e) {
        canvas.style.pointerEvents = 'none';
        interactionArea.style.cursor = 'grab';
      });

      // Initialize first device
      _switchDeviceAnimation();
    } catch (e) {
      debugPrint('[Landing] Error initializing Babylon: $e');
    }
  }

  void _switchDeviceAnimation() {
    try {
      final section = _sections[_currentSection];
      final deviceType = section['deviceType'];
      final animation = section['animation'];
      final deviceOnLeft = section['deviceOnLeft'];

      debugPrint('[Landing] Switching to: $deviceType, $animation, left: $deviceOnLeft');

      // Dispose existing viewer immediately (no animation)
      if (js.context.hasProperty('currentViewer') && js.context['currentViewer'] != null) {
        try {
          final currentViewer = js.context['currentViewer'];
          currentViewer.callMethod('dispose', []);
          js.context['currentViewer'] = null;
        } catch (e) {
          debugPrint('[Landing] Error disposing viewer: $e');
        }
      }

      // Create new viewer
      final config = {
        'canvasId': 'babylonCanvas',
        'deviceType': deviceType,
        'entranceAnimation': animation,
        'loopAnimation': deviceType == 'phone' ? 'float' : 'floatTilted',
        'brightness': 1.4,
        'logoUrl': 'assets/Tata_logo.svg',
        'enableGlow': deviceType == 'phone',
        'defaultVideoPath': deviceType == 'phone'
            ? 'assets/videos/phone-video.mp4'
            : 'assets/videos/notebook-video.mp4',
        'rgbEnabled': deviceType == 'notebook' ? false : null,
        if (deviceType == 'phone') ...{
          'phoneCameraPosition': {
            'alpha': 2.0,
            'beta': 1.5,
            'radius': 5.5,
          },
          'phoneCameraTarget': {
            'x': 1.7,
            'y': 0,
            'z': 0,
          },
        },
        if (deviceType == 'notebook') ...{
          'notebookCameraPosition': {
            'alpha': 7.3900000000000095,
            'beta': 1.227996660722633,
            'radius': 18.0,
          },
          'notebookCameraTarget': {
            'x': -3.5,
            'y': 1.5,
            'z': 0,
          },
        },
      };

      final deviceViewerClass = js.context['DeviceViewer'];
      if (deviceViewerClass != null) {
        final viewer = js.JsObject(deviceViewerClass, [js.JsObject.jsify(config)]);
        js.context['currentViewer'] = viewer;
        debugPrint('[Landing] ✅ Device viewer created');
      } else {
        debugPrint('[Landing] ❌ DeviceViewer class not found');
      }
    } catch (e) {
      debugPrint('[Landing] Error switching animation: $e');
    }
  }

  Future<void> _loadVersionInfo() async {
    try {
      const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'https://api.ppspsched.lat');
      final response = await http.get(Uri.parse('$apiUrl/version'));

      if (response.statusCode == 200) {
        setState(() {
          _versionInfo = json.decode(response.body);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            ..._sections.asMap().entries.map((entry) {
              final index = entry.key;
              final section = entry.value;
              return _buildSection(index: index, section: section);
            }),
            _buildDownloadSection(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required int index,
    required Map<String, dynamic> section,
  }) {
    final isActive = _currentSection == index;
    final deviceOnLeft = section['deviceOnLeft'] as bool;

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 80),
          child: Row(
            children: [
              if (!deviceOnLeft) ...[
                // Text on left side (50% width, centered within)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildTextContent(
                        badge: section['badge'],
                        title: section['title'],
                        description: section['description'],
                        isHero: index == 0,
                      ),
                    ),
                  ),
                ),
                const Spacer(), // Right side for device
              ] else ...[
                const Spacer(), // Left side for device
                // Text on right side (50% width, centered within)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildTextContent(
                        badge: section['badge'],
                        title: section['title'],
                        description: section['description'],
                        isHero: index == 0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent({
    required String badge,
    required String title,
    required String description,
    bool isHero = false,
  }) {
    return Column(
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
          child: Text(
            badge,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Title
        Text(
          title,
          style: const TextStyle(
            fontSize: 56,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 24),

        // Description
        Text(
          description,
          style: TextStyle(
            fontSize: 18,
            height: 1.6,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 40),

        // CTA Buttons (only on hero)
        if (isHero) ...[
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.rocket_launch, size: 20),
                label: const Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
                onPressed: () {
                  _scrollController.animateTo(
                    MediaQuery.of(context).size.height,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text(
                  'Watch Demo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

  Widget _buildDownloadSection() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.95),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Available on All Your Devices',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            'Download TCS Pace Scheduler for your preferred platform',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _buildDownloadButton('Web App', Icons.language, () => context.go('/login')),
              _buildDownloadButton('Android', Icons.android, () {}),
              _buildDownloadButton('iOS', Icons.apple, () {}),
              _buildDownloadButton('Windows', Icons.window, () {}),
              _buildDownloadButton('macOS', Icons.laptop_mac, () {}),
              _buildDownloadButton('Linux', Icons.computer, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white24, width: 1),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A).withOpacity(0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TCS Pace Scheduler',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!_loading && _versionInfo != null)
                Text(
                  'v${_versionInfo!['version']} • ${_versionInfo!['environment']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '© 2025 Tata Consultancy Services. All rights reserved.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
