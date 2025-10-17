import 'package:flutter/material.dart';

/// A standardized bottom drawer component with consistent styling and behavior
///
/// Features:
/// - 75% initial height (configurable)
/// - Draggable with min/max bounds
/// - Theme-aware colors
/// - Optional subtitle
/// - Optional footer with buttons
/// - Automatic handle bar and close button
///
/// Example usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (context) => StandardDrawer(
///     title: 'My Drawer',
///     subtitle: 'Optional subtitle',
///     content: MyContentWidget(),
///     footer: MyFooterWidget(),
///   ),
/// );
/// ```
class StandardDrawer extends StatelessWidget {
  /// The main title displayed in the drawer header
  final String title;

  /// Optional subtitle displayed below the title
  final String? subtitle;

  /// The main content widget to display
  final Widget content;

  /// Optional footer widget (typically contains action buttons)
  final Widget? footer;

  /// Called when the drawer should be closed
  /// If not provided, uses Navigator.pop
  final VoidCallback? onClose;

  /// Initial size as fraction of screen height (default: 0.75 = 75%)
  final double initialChildSize;

  /// Minimum size as fraction of screen height (default: 0.5 = 50%)
  final double minChildSize;

  /// Maximum size as fraction of screen height (default: 0.9 = 90%)
  final double maxChildSize;

  /// Whether to show the handle bar at the top (default: true)
  final bool showHandleBar;

  /// Whether to show the close button in header (default: true)
  final bool showCloseButton;

  const StandardDrawer({
    super.key,
    required this.title,
    required this.content,
    this.subtitle,
    this.footer,
    this.onClose,
    this.initialChildSize = 0.75,
    this.minChildSize = 0.5,
    this.maxChildSize = 0.9,
    this.showHandleBar = true,
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            if (showHandleBar)
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (showCloseButton)
                    IconButton(
                      onPressed: () {
                        if (onClose != null) {
                          onClose!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                      tooltip: 'Close',
                    )
                  else
                    const SizedBox(width: 8),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: content,
              ),
            ),

            // Footer (if provided)
            if (footer != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                    ),
                  ),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show a StandardDrawer
///
/// This is a convenience function that wraps showModalBottomSheet
/// with the correct parameters for StandardDrawer.
///
/// Example:
/// ```dart
/// showStandardDrawer(
///   context: context,
///   title: 'My Drawer',
///   content: MyContentWidget(),
/// );
/// ```
Future<T?> showStandardDrawer<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  String? subtitle,
  Widget? footer,
  VoidCallback? onClose,
  double initialChildSize = 0.75,
  double minChildSize = 0.5,
  double maxChildSize = 0.9,
  bool showHandleBar = true,
  bool showCloseButton = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: (context) => StandardDrawer(
      title: title,
      subtitle: subtitle,
      content: content,
      footer: footer,
      onClose: onClose,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      showHandleBar: showHandleBar,
      showCloseButton: showCloseButton,
    ),
  );
}
