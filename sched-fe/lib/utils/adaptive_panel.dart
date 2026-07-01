import 'package:flutter/material.dart';
import 'responsive_helper.dart';

/// Which edge a side sheet slides in from on desktop.
enum AdaptiveSide { left, right }

/// Owns a [ScrollController] and hands it to [builder]. Use on the desktop
/// (dialog) path for content that was originally written against a
/// [DraggableScrollableSheet]'s controller, so it keeps scrolling inside the
/// fixed-height modal without the bottom-sheet drag behavior.
class DialogScrollBody extends StatefulWidget {
  final Widget Function(ScrollController scrollController) builder;

  const DialogScrollBody({super.key, required this.builder});

  @override
  State<DialogScrollBody> createState() => _DialogScrollBodyState();
}

class _DialogScrollBodyState extends State<DialogScrollBody> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

/// Adaptive presentation helpers.
///
/// App rule: on mobile, transient surfaces are bottom-sheets/drawers; on wider
/// screens (tablet/desktop) the same surface should be a centered MODAL dialog.
/// Navigation / account / options menus are the exception — on desktop they
/// slide in from the SIDE instead of appearing as a centered modal.
///
/// [showAdaptivePanel] is a near drop-in replacement for [showModalBottomSheet]
/// for CONTENT surfaces (detail views, forms, pickers, confirmations).
/// [showAdaptiveSideSheet] is for MENU surfaces.
///
/// "Mobile" is decided by [ResponsiveHelper.isMobile] (width < 600).

/// Shows [builder] as a bottom sheet on mobile, or a centered modal dialog on
/// tablet/desktop. Common [showModalBottomSheet] parameters are forwarded so
/// existing call sites can swap the function name with minimal changes.
///
/// On desktop the content is placed in a rounded, size-constrained dialog. If a
/// call site's builder returns a [DraggableScrollableSheet] (bottom-sheet only),
/// pass [desktopBuilder] with a flat version for the dialog path.
Future<T?> showAdaptivePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  WidgetBuilder? desktopBuilder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  Color? barrierColor,
  double desktopMaxWidth = 640,
  double desktopMaxHeightFactor = 0.9,
  bool useRootNavigator = false,
}) {
  if (ResponsiveHelper.isMobile(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor ?? Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      shape: shape,
      useRootNavigator: useRootNavigator,
      builder: builder,
    );
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    builder: (dialogContext) {
      final maxHeight =
          MediaQuery.of(dialogContext).size.height * desktopMaxHeightFactor;
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: desktopMaxWidth,
            maxHeight: maxHeight,
          ),
          child: Material(
            color: backgroundColor == null || backgroundColor == Colors.transparent
                ? (isDark ? const Color(0xFF18181B) : Colors.white)
                : backgroundColor,
            child: (desktopBuilder ?? builder)(dialogContext),
          ),
        ),
      );
    },
  );
}

/// Shows [builder] as a bottom sheet on mobile, or a side sheet that slides in
/// from [side] on tablet/desktop. Use this for navigation / account / options
/// menus (the "comes from the side" case).
Future<T?> showAdaptiveSideSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  WidgetBuilder? desktopBuilder,
  AdaptiveSide side = AdaptiveSide.right,
  double width = 400,
  bool isDismissible = true,
  Color? backgroundColor,
}) {
  if (ResponsiveHelper.isMobile(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor ?? Colors.transparent,
      isDismissible: isDismissible,
      enableDrag: true,
      builder: builder,
    );
  }

  final effectiveBuilder = desktopBuilder ?? builder;

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final panelColor =
      backgroundColor ?? (isDark ? const Color(0xFF18181B) : Colors.white);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: side == AdaptiveSide.right
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Material(
          color: panelColor,
          elevation: 16,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: SafeArea(child: effectiveBuilder(dialogContext)),
          ),
        ),
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final begin =
          side == AdaptiveSide.right ? const Offset(1, 0) : const Offset(-1, 0);
      return SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      );
    },
  );
}
