import 'package:flutter/material.dart';
import '../services/permissions_service.dart';

class PermissionsWrapper extends StatefulWidget {
  final Widget child;

  const PermissionsWrapper({
    super.key,
    required this.child,
  });

  @override
  State<PermissionsWrapper> createState() => _PermissionsWrapperState();
}

class _PermissionsWrapperState extends State<PermissionsWrapper> {
  final PermissionsService _permissionsService = PermissionsService();
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    // Request permissions after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) return;

    setState(() {
      _permissionsRequested = true;
    });

    if (mounted) {
      await _permissionsService.requestInitialPermissions(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
