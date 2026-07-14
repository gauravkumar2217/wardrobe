import 'package:flutter/material.dart';

/// Tiny back control for pushed shell pages (not a title bar).
class ShellBackButton extends StatelessWidget {
  const ShellBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Navigator.of(context).canPop()) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surface.withValues(alpha: 0.65),
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 22),
      ),
    );
  }
}
