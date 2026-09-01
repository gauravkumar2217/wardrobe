import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';

/// Navigator key for pages shown inside the main shell (below header, above footer).
final GlobalKey<NavigatorState> shellOverlayNavigatorKey =
    GlobalKey<NavigatorState>();

/// Named routes for the in-shell overlay navigator.
abstract final class ShellRoutes {
  static const profile = '/shell/profile';
  static const notifications = '/shell/notifications';
  static const settings = '/shell/settings';
  static const search = '/shell/search';
  static const editProfile = '/shell/edit-profile';
  static const verifyContact = '/shell/verify-contact';
  static const schedulerList = '/shell/scheduler';
  static const privacyPolicy = '/shell/privacy';
  static const termsConditions = '/shell/terms';
  static const wardrobeList = '/shell/wardrobes';
  static const friendsList = '/shell/friends';
  static const friendRequests = '/shell/friend-requests';
  static const statistics = '/shell/statistics';
  static const createAvatar = '/shell/create-avatar';
  static const changingRoom = '/shell/changing-room';
  static const batchConvert = '/shell/batch-convert';
}

bool isShellEmbedded(BuildContext context) {
  final name = ModalRoute.of(context)?.settings.name;
  return name != null && name.startsWith('/shell/');
}

void openShellOverlay(BuildContext context, String route) {
  Provider.of<NavigationProvider>(context, listen: false).openShellOverlay(route);
}

void closeShellOverlay(BuildContext context) {
  shellOverlayNavigatorKey.currentState
      ?.popUntil((route) => route.isFirst);
  Provider.of<NavigationProvider>(context, listen: false).clearShellOverlay();
}

/// Back within shell overlay stack, or dismiss the overlay.
bool handleShellBack(BuildContext context) {
  final shellNav = shellOverlayNavigatorKey.currentState;
  if (shellNav != null && shellNav.canPop()) {
    shellNav.pop();
    return true;
  }

  final navProvider = Provider.of<NavigationProvider>(context, listen: false);
  if (navProvider.hasShellOverlay) {
    navProvider.clearShellOverlay();
    return true;
  }

  return false;
}

Future<T?> pushShellPage<T>(BuildContext context, String route) {
  return Navigator.of(context).pushNamed<T>(route);
}
