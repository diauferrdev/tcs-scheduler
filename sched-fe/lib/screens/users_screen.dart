import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../utils/toast_notification.dart';

class UsersScreen extends StatefulWidget {
  final bool skipLayout;

  const UsersScreen({super.key, this.skipLayout = false});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await _apiService.getUsers();
      final data = response is List ? response : (response['users'] as List? ?? response['data'] as List? ?? []);

      setState(() {
        _users = data.map((e) => User.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final nicknameController = TextEditingController();
    final currentUserRole = context.read<AuthProvider>().user?.role;

    // Default role based on current user
    // ADMIN can create any role, MANAGER can only create USER
    String selectedRole = currentUserRole == UserRole.ADMIN ? 'MANAGER' : 'USER';
    final formKey = GlobalKey<FormState>();
    final isDark = context.read<ThemeProvider>().isDark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Create New User',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: _inputDecoration('John Doe', isDark),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nickname
                  Text(
                    'Nickname (login)',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nicknameController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: _inputDecoration('e.g. john.doe', isDark),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nickname is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Nickname must be at least 2 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(value.trim())) {
                        return 'Only letters, numbers, dots and underscores';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Default password: Tata@123 (user must change on first login)',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                  ),
                  const SizedBox(height: 16),

                  // Role
                  Text(
                    'Role',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      // ADMIN can create all roles
                      if (currentUserRole == UserRole.ADMIN) ...[
                        const DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                        const DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                      ],
                      // MANAGER and ADMIN can create USER
                      const DropdownMenuItem(value: 'USER', child: Text('User')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _createUser(
                    name: nameController.text.trim(),
                    nickname: nicknameController.text.trim(),
                    role: selectedRole,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser({
    required String name,
    required String nickname,
    required String role,
  }) async {
    try {
      await _apiService.post('/api/auth/users', {
        'name': name,
        'nickname': nickname,
        'role': role,
      });

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'User created successfully!',
          type: ToastType.success,
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: e.toString(),
          type: ToastType.error,
        );
      }
    }
  }

  void _showDeleteConfirmation(User user) {
    final isDark = context.read<ThemeProvider>().isDark;
    final currentUser = context.read<AuthProvider>().user;

    if (currentUser?.id == user.id) {
      ToastNotification.show(
        context,
        message: 'You cannot delete your own account',
        type: ToastType.warning,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text(
          'Delete User',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to delete ${user.name}? This action cannot be undone.',
          style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(user.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await _apiService.deleteUser(userId);

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'User deleted successfully!',
          type: ToastType.success,
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: e.toString(),
          type: ToastType.error,
        );
      }
    }
  }

  void _showResetPasswordDialog(User user) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDark = context.read<ThemeProvider>().isDark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
        title: Text(
          'Reset Password',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset password for ${user.name}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Password',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: _inputDecoration('Min. 8 characters', isDark),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _resetPassword(user.id, passwordController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              foregroundColor: isDark ? Colors.black : Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(String userId, String newPassword) async {
    try {
      await _apiService.resetUserPassword(userId, newPassword);

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Password reset successfully!',
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: e.toString(),
          type: ToastType.error,
        );
      }
    }
  }

  void _showManageRolesDialog(User user) {
    final isDark = context.read<ThemeProvider>().isDark;
    final selectedRoles = Set<UserRole>.from(user.roles);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
          title: Text(
            'Manage Roles',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Roles for ${user.name}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 16),
              ...UserRole.values.map((role) {
                final isSelected = selectedRoles.contains(role);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selectedRoles.add(role);
                      } else {
                        if (selectedRoles.length > 1) {
                          selectedRoles.remove(role);
                        }
                      }
                    });
                  },
                  title: Text(
                    role.name,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  activeColor: isDark ? Colors.white : Colors.black,
                  checkColor: isDark ? Colors.black : Colors.white,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),
              const SizedBox(height: 8),
              Text(
                'At least one role must be selected.',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateUserRoles(user.id, selectedRoles.toList());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUserRoles(String userId, List<UserRole> roles) async {
    try {
      await _apiService.post('/api/auth/users/$userId/roles', {
        'roles': roles.map((r) => r.name).toList(),
      });

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Roles updated successfully!',
          type: ToastType.success,
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ToastNotification.show(
          context,
          message: e.toString(),
          type: ToastType.error,
        );
      }
    }
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final currentUser = context.watch<AuthProvider>().user;

    final content = Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      child: Column(
        children: [
          // Content
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadUsers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No users found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 24,
                                vertical: 8,
                              ),
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                return _buildUserCard(
                                  _users[index],
                                  isDark,
                                  isMobile,
                                  currentUser,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );

    final contentWithFab = Stack(
      children: [
        content,
        // Floating Action Button
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: _showCreateUserDialog,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.person_add),
            label: const Text(
              'New User',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            elevation: 4,
          ),
        ),
      ],
    );

    return widget.skipLayout ? contentWithFab : AppLayout(child: contentWithFab);
  }

  Widget _buildUserCard(User user, bool isDark, bool isMobile, User? currentUser) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isCurrentUser = currentUser?.id == user.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: _getRoleColor(user.role).withValues(alpha: 0.2),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(user.role),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name and Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.email.split('@').first}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

              // Role Badges
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: user.roles.length > 1
                    ? user.roles.map((role) {
                        final isActive = role == user.role;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getRoleColor(role).withValues(alpha: isActive ? 0.15 : 0.05),
                            borderRadius: BorderRadius.circular(4),
                            border: isActive
                                ? Border.all(color: _getRoleColor(role).withValues(alpha: 0.4), width: 1)
                                : null,
                          ),
                          child: Text(
                            role.name,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: _getRoleColor(role).withValues(alpha: isActive ? 1.0 : 0.6),
                            ),
                          ),
                        );
                      }).toList()
                    : [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRoleColor(user.role).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            user.role.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getRoleColor(user.role),
                            ),
                          ),
                        ),
                      ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
          const SizedBox(height: 12),

          // Created Date
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                'Joined ${dateFormat.format(user.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const Spacer(),

              // Actions
              if (!isCurrentUser) ...[
                if (currentUser?.isAdmin == true)
                  IconButton(
                    onPressed: () => _showManageRolesDialog(user),
                    icon: Icon(
                      Icons.admin_panel_settings,
                      size: 18,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                    tooltip: 'Manage Roles',
                  ),
                IconButton(
                  onPressed: () => _showResetPasswordDialog(user),
                  icon: Icon(
                    Icons.lock_reset,
                    size: 18,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  tooltip: 'Reset Password',
                ),
                IconButton(
                  onPressed: () => _showDeleteConfirmation(user),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  tooltip: 'Delete User',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.ADMIN:
        return Colors.purple;
      case UserRole.MANAGER:
        return Colors.blue;
      case UserRole.USER:
        return Colors.green;
    }
  }
}
