import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';

/// Handles Android/iOS back and AppBar back for the main shell:
/// 1. If a route is stacked above the shell (e.g. add-cloth flow), pop it.
/// 2. Else if not on Home tab, switch to Home.
/// 3. Else exit the app (Home with nothing to pop).
void handleMainShellBackButton(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  final navigationProvider =
      Provider.of<NavigationProvider>(context, listen: false);
  if (navigationProvider.currentIndex != 0) {
    navigationProvider.goHomeTab();
    return;
  }
  SystemNavigator.pop();
}

/// Leading widget for tab root screens (Wardrobes, Friends, Chats, Profile).
Widget mainShellAppBarLeading(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.arrow_back),
    tooltip: 'Back to Home',
    onPressed: () => handleMainShellBackButton(context),
  );
}
