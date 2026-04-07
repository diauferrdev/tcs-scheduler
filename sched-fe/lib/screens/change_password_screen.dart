import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/toast_notification.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

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

    _animationController.forward();

    _newPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasUppercase =>
      _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase =>
      _newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber =>
      _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _newPasswordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  bool get _allRequirementsMet =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar;

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allRequirementsMet) return;

    setState(() => _loading = true);

    try {
      final apiService = ApiService();
      await apiService.post('/api/auth/me/change-password', {
        'currentPassword': 'Tata@123',
        'newPassword': _newPasswordController.text,
      });

      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        authProvider.clearMustChangePassword();

        ToastNotification.show(
          context,
          message: 'Password set successfully',
          type: ToastType.success,
        );

        final user = authProvider.user;
        String destination = '/app/schedule';
        if (user != null) {
          switch (user.role.name) {
            case 'ADMIN':
            case 'MANAGER':
              destination = '/app/dashboard';
              break;
            case 'USER':
            default:
              destination = '/app/schedule';
          }
        }

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
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    final hasInput = _newPasswordController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            hasInput
                ? (met ? Icons.check_circle : Icons.cancel)
                : Icons.circle_outlined,
            size: 14,
            color: hasInput
                ? (met ? const Color(0xFF22C55E) : const Color(0xFFEF4444))
                : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: hasInput
                  ? (met ? const Color(0xFF22C55E) : const Color(0xFFEF4444))
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Welcome to Pace Scheduler',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please set a new password to continue',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF27272A),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'New Password',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  enabled: !_loading,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
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
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFF6B7280),
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (!_allRequirementsMet) {
                      return 'Password does not meet all requirements';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                _buildRequirement('At least 8 characters', _hasMinLength),
                _buildRequirement('One uppercase letter', _hasUppercase),
                _buildRequirement('One lowercase letter', _hasLowercase),
                _buildRequirement('One number', _hasNumber),
                _buildRequirement('One special character', _hasSpecialChar),

                const SizedBox(height: 16),

                const Text(
                  'Confirm Password',
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  enabled: !_loading,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Confirm new password',
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
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFF6B7280),
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFF52525B),
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
                            'Set Password',
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
