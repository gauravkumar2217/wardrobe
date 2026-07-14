import 'package:flutter/material.dart';

/// Intentionally empty under the main shell header — sub-pages do not show a
/// second title bar. [title] / [actions] / [leading] are accepted for
/// call-site compatibility only (not rendered).
///
/// Navigation: use the system/back gesture, bottom tabs, or in-body controls.
class CompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool? automaticallyImplyLeading;

  const CompactAppBar({
    super.key,
    this.title = '',
    this.actions,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.automaticallyImplyLeading,
  });

  static const double toolbarHeight = 0;

  @override
  Size get preferredSize => Size.zero;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
