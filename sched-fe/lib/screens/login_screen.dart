import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../utils/toast_notification.dart';
import '../utils/responsive_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Setup entrance animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        // Get user role to determine redirect destination
        final authProvider = context.read<AuthProvider>();
        final user = authProvider.user;

        String destination = '/app/calendar'; // Default for USER
        if (user != null) {
          switch (user.role.name) {
            case 'ADMIN':
            case 'MANAGER':
              destination = '/app/dashboard';
              break;
            case 'USER':
            default:
              destination = '/app/calendar';
          }
        }

        // Use router to navigate (no subdomain redirects)
        context.go(destination);
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: e.toString(),
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: _buildLoginForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo - New TCS Pace logo (already includes "Scheduler" text)
        SvgPicture.asset('assets/logos/tcs-pace-logo-w.svg', height: 48),

        const SizedBox(height: 32),

        // Login Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B), // zinc-900
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF27272A), // zinc-800
            ),
          ),
          child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email Field
                          const Text(
                            'Email',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_loading,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'admin@tcs.com',
                              hintStyle: const TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF09090B), // zinc-950
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email is required';
                              }
                              if (!value.contains('@')) {
                                return 'Invalid email format';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Password Field
                          const Text(
                            'Password',
                            style: TextStyle(fontSize: 14, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            enabled: !_loading,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: const TextStyle(
                                color: Color(0xFF6B7280),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF09090B),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF27272A),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Colors.white,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Login Button
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: const Color(
                                  0xFF52525B,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
      ],
    );
  }
}
