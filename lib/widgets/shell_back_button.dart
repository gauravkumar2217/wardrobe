import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../utils/shell_navigation.dart';

/// Tiny back control for pushed shell pages (not a title bar).
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final nestedNav = Navigator.of(context);
    final canGoBack = nestedNav.canPop() || navProvider.hasShellOverlay;

    if (!canGoBack) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Back',
        onPressed: () => handleShellBack(context),
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface.withValues(alpha: 0.65),
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 22),
      ),
    );
  }
}
