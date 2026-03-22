import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../providers/navigation_provider.dart';
import '../screens/home/clothes_screen.dart';
import 'navigator_key.dart';

/// Selects the Home tab and opens the **Clothes** swipe feed (same as the Home "Clothes" card).
///
/// Uses [navigatorKey] so it works after [Navigator.pop] from overlays (e.g. Statistics).
void openClothesFeed(NavigationProvider navigationProvider) {
  navigationProvider.navigateToHome();
  SchedulerBinding.instance.addPostFrameCallback((_) {
    final nav = navigatorKey.currentState;
    if (nav == null || !nav.mounted) return;
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const ClothesScreen()),
    );
  });
}
