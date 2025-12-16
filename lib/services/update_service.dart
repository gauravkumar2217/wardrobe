import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to check for app updates from App Store and Play Store
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Get current app version info
  static Future<Map<String, String>> getVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'packageName': packageInfo.packageName,
        'appName': packageInfo.appName,
      };
    } catch (e) {
      debugPrint('❌ Error getting version info: $e');
      return {};
    }
  }

  /// Wrap widget with UpgradeAlert to automatically check for updates
  /// Upgrader automatically checks App Store (iOS) and Play Store (Android)
  /// The widget will automatically show a dialog when an update is available
  static Widget buildUpgrader({required Widget child}) {
    return UpgradeAlert(
      // Upgrader will automatically:
      // 1. Check current app version from package_info_plus
      // 2. Query App Store (iOS) or Play Store (Android) for latest version
      // 3. Show update dialog if newer version is available
      // 4. Allow users to update directly from the dialog
      child: child,
    );
  }
}

