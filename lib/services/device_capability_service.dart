import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Device capability service for checking device compatibility
class DeviceCapabilityService {
  static DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static bool? _isCapable;
  static String? _deviceModel;

  /// Check if device is capable of running body scan features
  /// Returns true for A12+ chips on iOS and mid-range+ Android devices
  static Future<bool> isDeviceCapable() async {
    if (_isCapable != null) return _isCapable!;

    try {
      if (Platform.isIOS) {
        _isCapable = await _checkIOSCapability();
      } else if (Platform.isAndroid) {
        _isCapable = await _checkAndroidCapability();
      } else {
        _isCapable = false;
      }
    } catch (e) {
      debugPrint('Error checking device capability: $e');
      _isCapable = false;
    }

    return _isCapable ?? false;
  }

  /// Check iOS device capability (A12 Bionic or newer)
  static Future<bool> _checkIOSCapability() async {
    try {
      final iosInfo = await _deviceInfo.iosInfo;
      _deviceModel = iosInfo.model;

      // Check for A12 Bionic or newer (iPhone XR and newer)
      // A12 devices: iPhone XR, XS, XS Max (2018)
      // A13: iPhone 11 series (2019)
      // A14: iPhone 12 series (2020)
      // A15: iPhone 13 series (2021)
      // A16: iPhone 14 series (2022)
      // A17: iPhone 15 series (2023)

      final model = iosInfo.model.toLowerCase();
      final identifier = iosInfo.utsname.machine.toLowerCase();

      // iPhone XR (A12) and newer models
      final capableModels = [
        'iphone xr',
        'iphone xs',
        'iphone 11',
        'iphone 12',
        'iphone 13',
        'iphone 14',
        'iphone 15',
        'iphone 16',
      ];

      // Check if model contains any capable model name
      final isCapableModel = capableModels.any((capable) => model.contains(capable));

      // Also check identifier for A12+ chips
      // iPhone11,8 = XR (A12)
      // iPhone12,1 = 11 (A13)
      // iPhone13,1 = 12 (A14)
      // etc.
      final isCapableIdentifier = identifier.contains('iphone1') &&
          (int.tryParse(identifier.replaceAll(RegExp(r'[^0-9]'), '').substring(6, 7)) ?? 0) >= 1;

      return isCapableModel || isCapableIdentifier;
    } catch (e) {
      debugPrint('Error checking iOS capability: $e');
      return false;
    }
  }

  /// Check Android device capability (mid-range or better)
  static Future<bool> _checkAndroidCapability() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      _deviceModel = androidInfo.model;

      // Check RAM (need at least 3GB for smooth ML processing)
      // This is a rough estimate - actual RAM info requires system-level access
      // For now, we'll assume devices with Android 8+ are capable
      final sdkInt = androidInfo.version.sdkInt;
      
      // Android 8.0 (API 26) and above generally have better hardware
      return sdkInt >= 26;
    } catch (e) {
      debugPrint('Error checking Android capability: $e');
      return false;
    }
  }

  /// Get device model name
  static Future<String?> getDeviceModel() async {
    if (_deviceModel != null) return _deviceModel;

    try {
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceModel = iosInfo.model;
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceModel = androidInfo.model;
      }
    } catch (e) {
      debugPrint('Error getting device model: $e');
    }

    return _deviceModel;
  }

  /// Check if device should use Lite Mode
  static Future<bool> shouldUseLiteMode() async {
    final isCapable = await isDeviceCapable();
    return !isCapable;
  }

  /// Get capability status message
  static Future<String> getCapabilityMessage() async {
    final isCapable = await isDeviceCapable();
    final model = await getDeviceModel();

    if (isCapable) {
      return 'Your device ($model) is capable of running body scan features.';
    } else {
      return 'Your device ($model) may experience slower performance. Lite Mode will be enabled.';
    }
  }
}
