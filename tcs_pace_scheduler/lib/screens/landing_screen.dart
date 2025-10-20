import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _versionInfo;
  bool _loading = true;
  late AnimationController _floatController;
  late AnimationController _rotateController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();

    // Float animation for 3D cards
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    // Rotation for 3D elements
    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Pulse for highlights
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.ppspsched.lat/api/version/current'),
      );

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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background grid
          _buildAnimatedBackground(),

          // Scrollable content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildHeroSection(),
                  _buildFeaturesSection(),
                  _buildDownloadSection(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _rotateController,
        builder: (context, child) {
          return CustomPaint(
            painter: GridBackgroundPainter(
              progress: _rotateController.value,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final user = authProvider.user;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF27272A), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Logo - New TCS Pace logo (already includes "Scheduler" text)
          SvgPicture.asset(
            'assets/logos/tcs-pace-logo-w.svg',
            height: 32,
          ),

          const Spacer(),

          // Action button
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.03),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isAuthenticated && user != null) {
                      // Go to their main screen based on role
                      switch (user.role.name) {
                        case 'ADMIN':
                        case 'MANAGER':
                          context.go('/app/dashboard');
                          break;
                        case 'USER':
                        default:
                          context.go('/app/calendar');
                      }
                    } else {
                      context.go('/login');
                    }
                  },
                  icon: Icon(
                    isAuthenticated ? Icons.dashboard_rounded : Icons.login,
                    size: 18,
                  ),
                  label: Text(
                    isAuthenticated ? 'Enter App' : 'Sign In',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 120),
      constraints: const BoxConstraints(maxWidth: 1400),
      child: Column(
        children: [
          // Floating 3D badge
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, math.sin(_floatController.value * math.pi) * 10),
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(math.sin(_floatController.value * math.pi) * 0.1)
                    ..rotateY(math.cos(_floatController.value * math.pi) * 0.1),
                  alignment: Alignment.center,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(color: Colors.white24, width: 1.5),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_center,
                            size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Internal Application',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),

          // Main title with gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFD1D5DB)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(bounds),
            child: const Text(
              'Simplified Office Visit\nScheduling',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -2,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Subtitle
          const Text(
            'Enterprise scheduling system for TCS Pace São Paulo.\nManage bookings, invitations, and office capacity with precision.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF9CA3AF),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),

          // CTA Buttons with 3D effect
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _build3DButton(
                label: 'Get Started',
                icon: Icons.arrow_forward,
                isPrimary: true,
                onPressed: () => context.go('/login'),
              ),
              _build3DButton(
                label: 'View Downloads',
                icon: Icons.download,
                isPrimary: false,
                onPressed: () {
                  // Scroll to downloads section
                },
              ),
            ],
          ),

          const SizedBox(height: 80),

          // 3D Floating cards preview
          _build3DCardsPreview(),
        ],
      ),
    );
  }

  Widget _build3DButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(math.sin(_floatController.value * math.pi) * 0.05),
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary ? Colors.white : const Color(0xFF18181B),
                foregroundColor: isPrimary ? Colors.black : Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isPrimary
                      ? BorderSide.none
                      : const BorderSide(color: Color(0xFF27272A), width: 1.5),
                ),
                elevation: isPrimary ? 8 : 0,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _build3DCardsPreview() {
    return SizedBox(
      height: 400,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Card 1 - Left
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..translate(
                    -200.0 + math.sin(_floatController.value * math.pi) * 20,
                    math.cos(_floatController.value * math.pi) * 15,
                    0.0,
                  )
                  ..rotateY(-0.3)
                  ..rotateZ(-0.05),
                alignment: Alignment.center,
                child: _build3DCard(
                  icon: Icons.calendar_today,
                  title: 'Smart Calendar',
                  color: Colors.white.withOpacity(0.1),
                ),
              );
            },
          ),

          // Card 2 - Center (larger)
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..translate(
                    0.0,
                    math.sin(_floatController.value * math.pi + 1) * 20,
                    50.0,
                  )
                  ..scale(1.2),
                alignment: Alignment.center,
                child: _build3DCard(
                  icon: Icons.notifications_active,
                  title: 'Real-time Notifications',
                  color: Colors.white.withOpacity(0.15),
                  highlight: true,
                ),
              );
            },
          ),

          // Card 3 - Right
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..translate(
                    200.0 - math.sin(_floatController.value * math.pi) * 20,
                    math.cos(_floatController.value * math.pi + 2) * 15,
                    0.0,
                  )
                  ..rotateY(0.3)
                  ..rotateZ(0.05),
                alignment: Alignment.center,
                child: _build3DCard(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  color: Colors.white.withOpacity(0.1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _build3DCard({
    required IconData icon,
    required String title,
    required Color color,
    bool highlight = false,
  }) {
    return Container(
      width: 200,
      height: 240,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? Colors.white38 : Colors.white24,
          width: highlight ? 2 : 1,
        ),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.black, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final features = [
      {
        'icon': Icons.calendar_today,
        'title': 'Smart Calendar',
        'description':
            'Intuitive calendar with real-time availability and capacity management.',
      },
      {
        'icon': Icons.notifications_active,
        'title': 'Instant Notifications',
        'description':
            'Push notifications for bookings, approvals, and updates across platforms.',
      },
      {
        'icon': Icons.people,
        'title': 'Guest Management',
        'description':
            'Invite external guests with QR badges and automated invitations.',
      },
      {
        'icon': Icons.admin_panel_settings,
        'title': 'Role-Based Access',
        'description':
            'Granular permissions with Admin, Manager, and User roles.',
      },
      {
        'icon': Icons.analytics,
        'title': 'Analytics Dashboard',
        'description':
            'Comprehensive insights on office utilization and booking patterns.',
      },
      {
        'icon': Icons.devices,
        'title': 'Cross-Platform',
        'description':
            'Web, Android, iOS, Windows, macOS, and Linux with synced data.',
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF27272A)),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Everything You Need',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Built for scale, designed for simplicity',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 64),
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              children: features.asMap().entries.map((entry) {
                final index = entry.key;
                final feature = entry.value;
                return AnimatedBuilder(
                  animation: _floatController,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final animation = (_floatController.value + delay) % 1.0;
                    return Transform.translate(
                      offset: Offset(0, math.sin(animation * math.pi * 2) * 8),
                      child: _buildFeatureCard(feature),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF18181B),
            const Color(0xFF18181B).withOpacity(0.8),
          ],
        ),
        border: Border.all(color: const Color(0xFF27272A), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature['icon'] as IconData,
              color: Colors.black,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            feature['title'] as String,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            feature['description'] as String,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadSection() {
    final downloads = [
      {
        'platform': 'Android',
        'icon': Icons.android,
        'description': 'APK for Android 5.0+',
        'url': _versionInfo?['downloadUrl']?['android'] ?? '',
        'available': (_versionInfo?['downloadUrl']?['android'] ?? '').isNotEmpty,
      },
      {
        'platform': 'iOS',
        'icon': Icons.apple,
        'description': 'TestFlight for iOS 13+',
        'url': _versionInfo?['downloadUrl']?['ios'] ?? '',
        'available': (_versionInfo?['downloadUrl']?['ios'] ?? '').isNotEmpty,
      },
      {
        'platform': 'Web',
        'icon': Icons.language,
        'description': 'Progressive Web App',
        'url': 'https://app.ppspsched.lat',
        'available': true,
      },
      {
        'platform': 'Windows',
        'icon': Icons.window,
        'description': 'Installer for Windows 10+',
        'url': _versionInfo?['downloadUrl']?['windows'] ?? '',
        'available': (_versionInfo?['downloadUrl']?['windows'] ?? '').isNotEmpty,
      },
      {
        'platform': 'macOS',
        'icon': Icons.laptop_mac,
        'description': 'DMG for macOS 11+',
        'url': _versionInfo?['downloadUrl']?['macos'] ?? '',
        'available': (_versionInfo?['downloadUrl']?['macos'] ?? '').isNotEmpty,
      },
      {
        'platform': 'Linux',
        'icon': Icons.computer,
        'description': 'AppImage for Linux',
        'url': _versionInfo?['downloadUrl']?['linux'] ?? '',
        'available': (_versionInfo?['downloadUrl']?['linux'] ?? '').isNotEmpty,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF27272A)),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Download Now',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          if (_versionInfo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Version ${_versionInfo!['version']} • Build ${_versionInfo!['buildNumber']}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 64),
          Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              children: downloads.asMap().entries.map((entry) {
                final index = entry.key;
                final download = entry.value;
                return AnimatedBuilder(
                  animation: _rotateController,
                  builder: (context, child) {
                    final rotation =
                        (_rotateController.value + index * 0.1) * 2 * math.pi;
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateY(math.sin(rotation) * 0.05),
                      alignment: Alignment.center,
                      child: _buildDownloadCard(download),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(Map<String, dynamic> download) {
    final available = download['available'] as bool;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: available
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF18181B),
                  const Color(0xFF18181B).withOpacity(0.9),
                ],
              )
            : null,
        color: available ? null : const Color(0xFF0A0A0A),
        border: Border.all(
          color: available ? const Color(0xFF27272A) : const Color(0xFF18181B),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: available
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Icon(
            download['icon'] as IconData,
            size: 48,
            color: available ? Colors.white : Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            download['platform'] as String,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: available ? Colors.white : Colors.white38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            download['description'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: available ? const Color(0xFF9CA3AF) : Colors.white24,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  available ? () => _launchUrl(download['url'] as String) : null,
              icon: Icon(
                available ? Icons.download : Icons.schedule,
                size: 18,
              ),
              label: Text(available ? 'Download' : 'Coming Soon'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    available ? Colors.white : const Color(0xFF27272A),
                foregroundColor: available ? Colors.black : Colors.white38,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF27272A)),
        ),
      ),
      child: Column(
        children: [
          SvgPicture.asset('assets/logos/tcs-pace-logo-w.svg', height: 32),
          const SizedBox(height: 16),
          const Text(
            'Internal application for TCS employees',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '© 2025 Tata Consultancy Services. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for animated background grid
class GridBackgroundPainter extends CustomPainter {
  final double progress;

  GridBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const gridSize = 50.0;
    final offset = progress * gridSize;

    // Draw vertical lines
    for (double x = -offset; x < size.width + gridSize; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Draw horizontal lines
    for (double y = -offset; y < size.height + gridSize; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw glowing dots at intersections
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    for (double x = -offset; x < size.width + gridSize; x += gridSize) {
      for (double y = -offset; y < size.height + gridSize; y += gridSize) {
        final distance = math.sqrt(
          math.pow((x - size.width / 2), 2) + math.pow((y - size.height / 2), 2),
        );
        final normalizedDistance = (distance / (size.width / 2)).clamp(0.0, 1.0);
        final opacity = (1 - normalizedDistance) * 0.3;

        canvas.drawCircle(
          Offset(x, y),
          2,
          Paint()
            ..color = Colors.white.withOpacity(opacity)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(GridBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
