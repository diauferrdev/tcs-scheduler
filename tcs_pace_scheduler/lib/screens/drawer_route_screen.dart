import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/drawer_service.dart';

/// Special screen that opens a drawer and then navigates back
///
/// This allows drawers to be opened via direct URLs (deep linking)
/// while maintaining proper navigation state.
///
/// Example: Navigating to `/booking/123` will show the calendar
/// screen with the booking details drawer open.
class DrawerRouteScreen extends StatefulWidget {
  final DrawerType drawerType;
  final Map<String, dynamic>? params;
  final String baseRoute;

  const DrawerRouteScreen({
    super.key,
    required this.drawerType,
    this.params,
    required this.baseRoute,
  });

  @override
  State<DrawerRouteScreen> createState() => _DrawerRouteScreenState();
}

class _DrawerRouteScreenState extends State<DrawerRouteScreen> {
  bool _drawerOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Open drawer once after first build
    if (!_drawerOpened && mounted) {
      _drawerOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDrawer();
      });
    }
  }

  Future<void> _openDrawer() async {
    if (!mounted) return;

    // First navigate to base route
    context.go(widget.baseRoute);

    // Wait a frame for navigation to complete
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;

    // Then open the drawer
    await DrawerService.instance.openDrawer(
      context,
      widget.drawerType,
      params: widget.params,
      updateUrl: false, // Don't update URL to avoid loop
    );

    // When drawer closes, ensure we stay on base route
    if (mounted) {
      context.go(widget.baseRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return empty container - this screen is just for navigation
    return const SizedBox.shrink();
  }
}
