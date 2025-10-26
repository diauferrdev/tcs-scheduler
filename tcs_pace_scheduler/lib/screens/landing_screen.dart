import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:tcs_pace_scheduler/widgets/device_3d_section.dart';
import 'package:tcs_pace_scheduler/widgets/animated_background.dart';
import 'package:tcs_pace_scheduler/widgets/landing_header.dart';
import 'package:tcs_pace_scheduler/widgets/scroll_reveal.dart';
import 'package:tcs_pace_scheduler/widgets/globe_section.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tcs_pace_scheduler/utils/responsive_helper.dart';
import 'package:tcs_pace_scheduler/providers/auth_provider.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  Map<String, dynamic>? _versionInfo;
  bool _loading = true;

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
    final authProvider = context.watch<AuthProvider>();
    final isLoggedIn = authProvider.isAuthenticated;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Animated background
          const Positioned.fill(child: AnimatedBackground()),

          // Content
          Column(
            children: [
              // Fixed header
              LandingHeader(isLoggedIn: isLoggedIn),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      ..._sections.asMap().entries.map((entry) {
                        final index = entry.key;
                        final section = entry.value;
                        return Device3DSection(
                          key: ValueKey('section_$index'),
                          index: index,
                          deviceType: section['deviceType'],
                          animation: section['animation'],
                          deviceOnLeft: section['deviceOnLeft'],
                          title: section['title'],
                          description: section['description'],
                          badge: section['badge'],
                          isHero: index == 0,
                        );
                      }),
                      const GlobeSection(
                        showAtmosphere: true,
                        enableRotation: true,
                      ),
                      _buildDownloadSection(),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiTenancySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 120),
      child: ScrollReveal(
        child: Column(
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'GLOBAL INFRASTRUCTURE',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'NeueHaasGrotesk',
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Title
            const Text(
              'One Platform,\nUnlimited Locations',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -1.5,
                fontFamily: 'HouskaPro',
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              'Built for TCS Pace São Paulo, ready for the world.\nOur multi-tenant architecture automatically detects your location\nand connects you to your local Pace Port office.',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white.withOpacity(0.7),
                height: 1.6,
                fontFamily: 'NeueHaasGrotesk',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 80),

            // Features grid
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildMultiTenancyFeature(
                      Icons.location_on,
                      'Auto-Detection',
                      'System automatically identifies your location and connects to the nearest Pace Port',
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: _buildMultiTenancyFeature(
                      Icons.public,
                      'Global Ready',
                      'Infrastructure ready to support Pace Ports worldwide with isolated data per location',
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: _buildMultiTenancyFeature(
                      Icons.swap_horiz,
                      'Easy Switching',
                      'Manual location selector available on login for users across multiple offices',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // Current location
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Currently serving: ',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontFamily: 'NeueHaasGrotesk',
                    ),
                  ),
                  const Text(
                    'TCS Pace São Paulo',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'HouskaPro',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiTenancyFeature(IconData icon, String title, String description) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Icon(
            icon,
            size: 32,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'HouskaPro',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.6),
            height: 1.6,
            fontFamily: 'NeueHaasGrotesk',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDownloadSection() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 60 : 120,
      ),
      child: Column(
        children: [
          ScrollReveal(
            child: Text(
              'Download for Your Platform',
              style: TextStyle(
                fontSize: isMobile ? 32 : 56,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: isMobile ? -0.8 : -1.5,
                fontFamily: 'HouskaPro',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          ScrollReveal(
            delay: const Duration(milliseconds: 200),
            child: Text(
              'One app, every device. Seamless synchronization across all platforms.',
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                color: Colors.white.withOpacity(0.7),
                height: 1.6,
                fontFamily: 'NeueHaasGrotesk',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isMobile ? 40 : 80),

          ScrollReveal(
            delay: const Duration(milliseconds: 400),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isMobile ? 1 : 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: isMobile ? 2.5 : 1.4,
                children: [
                  _buildPlatformCard(
                    'Web Application',
                    Icons.language,
                    'Access instantly from any browser',
                    '12.5 MB',
                    'Available Now',
                    true,
                    () => context.go('/login'),
                    isMobile,
                  ),
                  _buildPlatformCard(
                    'Windows',
                    Icons.window,
                    'Native desktop experience',
                    '85 MB',
                    'Windows 10+',
                    true,
                    () {},
                    isMobile,
                  ),
                  _buildPlatformCard(
                    'Android',
                    Icons.android,
                    'Download from Google Play',
                    '32 MB',
                    'Android 8.0+',
                    true,
                    () {},
                    isMobile,
                  ),
                  _buildPlatformCard(
                    'macOS',
                    Icons.laptop_mac,
                    'Coming soon to Mac',
                    'TBA',
                    'macOS 12+',
                    false,
                    null,
                    isMobile,
                  ),
                  _buildPlatformCard(
                    'Linux',
                    Icons.computer,
                    'AppImage & Snap packages',
                    '78 MB',
                    'Ubuntu 20.04+',
                    true,
                    () {},
                    isMobile,
                  ),
                  _buildPlatformCard(
                    'iOS',
                    Icons.apple,
                    'Coming soon to App Store',
                    'TBA',
                    'iOS 14+',
                    false,
                    null,
                    isMobile,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(
    String platform,
    IconData icon,
    String description,
    String size,
    String version,
    bool enabled,
    VoidCallback? onPressed,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.02),
        border: Border.all(
          color: enabled
              ? Colors.white.withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: isMobile
                ? Row(
                    children: [
                      Icon(
                        icon,
                        size: 32,
                        color: enabled
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(
                                  platform,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: enabled
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                                    fontFamily: 'HouskaPro',
                                  ),
                                ),
                                if (!enabled) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'SOON',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange.withOpacity(0.7),
                                        letterSpacing: 0.5,
                                        fontFamily: 'NeueHaasGrotesk',
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 12,
                                color: enabled
                                    ? Colors.white.withOpacity(0.6)
                                    : Colors.white.withOpacity(0.2),
                                height: 1.4,
                                fontFamily: 'NeueHaasGrotesk',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.file_download,
                                  size: 10,
                                  color: enabled
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  size,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: enabled
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.2),
                                    fontFamily: 'NeueHaasGrotesk',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.info_outline,
                                  size: 10,
                                  color: enabled
                                      ? Colors.white.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.2),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  version,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: enabled
                                        ? Colors.white.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.2),
                                    fontFamily: 'NeueHaasGrotesk',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 40,
                        color: enabled
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        platform,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: enabled
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          fontFamily: 'HouskaPro',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: enabled
                              ? Colors.white.withOpacity(0.6)
                              : Colors.white.withOpacity(0.2),
                          height: 1.4,
                          fontFamily: 'NeueHaasGrotesk',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.file_download,
                            size: 12,
                            color: enabled
                                ? Colors.white.withOpacity(0.5)
                                : Colors.white.withOpacity(0.2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            size,
                            style: TextStyle(
                              fontSize: 11,
                              color: enabled
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.2),
                              fontFamily: 'NeueHaasGrotesk',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.info_outline,
                            size: 12,
                            color: enabled
                                ? Colors.white.withOpacity(0.5)
                                : Colors.white.withOpacity(0.2),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            version,
                            style: TextStyle(
                              fontSize: 11,
                              color: enabled
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.2),
                              fontFamily: 'NeueHaasGrotesk',
                            ),
                          ),
                        ],
                      ),
                      if (!enabled) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'COMING SOON',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.withOpacity(0.7),
                              letterSpacing: 0.8,
                              fontFamily: 'NeueHaasGrotesk',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 32 : 40,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                // Brand and version
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/logos/tcs-pace-logo-w.svg',
                      height: 24,
                    ),
                    if (!_loading && _versionInfo != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'v${_versionInfo!['version']} • ${_versionInfo!['environment']}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'NeueHaasGrotesk',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Copyright
                Text(
                  '© 2025 Tata Consultancy Services',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                    fontFamily: 'NeueHaasGrotesk',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Internal Project',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                    fontFamily: 'NeueHaasGrotesk',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Brand and version
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/logos/tcs-pace-logo-w.svg',
                      height: 32,
                    ),
                    if (!_loading && _versionInfo != null) ...[
                      const SizedBox(width: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'v${_versionInfo!['version']} • ${_versionInfo!['environment']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'NeueHaasGrotesk',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Copyright
                Text(
                  '© 2025 Tata Consultancy Services - Internal Project',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.4),
                    fontFamily: 'NeueHaasGrotesk',
                  ),
                ),
              ],
            ),
    );
  }

}
