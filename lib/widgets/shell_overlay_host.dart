import 'package:flutter/material.dart';

import '../screens/friends/friend_requests_screen.dart';
import '../screens/friends/friends_list_screen.dart';
import '../screens/friends/search_users_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/privacy_policy_screen.dart';
import '../screens/profile/create_avatar_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/verify_contact_screen.dart';
import '../screens/scheduler/scheduler_list_screen.dart';
import '../screens/statistics/statistics_screen.dart';
import '../screens/terms_conditions_screen.dart';
import '../screens/wardrobe/wardrobe_list_screen.dart';
import '../screens/changing_room/changing_room_screen.dart';
import '../screens/cloth/batch_convert_screen.dart';
import '../utils/shell_navigation.dart';

/// In-shell navigator for profile, settings, search, and their sub-pages.
class ShellOverlayHost extends StatelessWidget {
  final String initialRoute;

  const ShellOverlayHost({
    super.key,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: shellOverlayNavigatorKey,
      initialRoute: initialRoute,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic> _route(Widget page, RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => page,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case ShellRoutes.profile:
        return _route(const ProfileScreen(), settings);
      case ShellRoutes.notifications:
        return _route(const NotificationsScreen(), settings);
      case ShellRoutes.settings:
        return _route(const SettingsScreen(), settings);
      case ShellRoutes.search:
        return _route(const SearchUsersScreen(), settings);
      case ShellRoutes.editProfile:
        return _route(const EditProfileScreen(), settings);
      case ShellRoutes.verifyContact:
        return _route(const VerifyContactScreen(), settings);
      case ShellRoutes.schedulerList:
        return _route(const SchedulerListScreen(), settings);
      case ShellRoutes.privacyPolicy:
        return _route(const PrivacyPolicyScreen(), settings);
      case ShellRoutes.termsConditions:
        return _route(const TermsConditionsScreen(), settings);
      case ShellRoutes.wardrobeList:
        return _route(const WardrobeListScreen(), settings);
      case ShellRoutes.friendsList:
        return _route(const FriendsListScreen(), settings);
      case ShellRoutes.friendRequests:
        return _route(const FriendRequestsScreen(), settings);
      case ShellRoutes.statistics:
        return _route(const StatisticsScreen(), settings);
      case ShellRoutes.createAvatar:
        return _route(const CreateAvatarScreen(), settings);
      case ShellRoutes.changingRoom:
        return _route(const ChangingRoomScreen(), settings);
      case ShellRoutes.batchConvert:
        return _route(const BatchConvertScreen(), settings);
      default:
        return _route(const SizedBox.shrink(), settings);
    }
  }
}
