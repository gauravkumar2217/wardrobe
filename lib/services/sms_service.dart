import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SMSService {
  static const String _baseUrl = 'https://api.msg91.com/api/v5/otp';

  // MSG91 Configuration
  static const String _authKey =
      'YOUR_MSG91_AUTH_KEY'; // Replace with your MSG91 Auth Key
  static const String _templateId =
      'YOUR_TEMPLATE_ID'; // Replace with your MSG91 Template ID
  static const String _senderId = 'WPOBE'; // Replace with your sender ID
  // static const String _route = '4'; // 4 for transactional SMS

  /// Send OTP via SMS using MSG91
  static Future<bool> sendOTP({
    required String phoneNumber,
    required String otp,
    String? message,
  }) async {
    try {
      const url = '$_baseUrl?authkey=$_authKey';

      final headers = {
        'Content-Type': 'application/json',
      };

      final body = {
        'mobile': phoneNumber,
        'authkey': _authKey,
        'message': message ??
            'Your OTP for Wardrobe is $otp. Do not share this OTP with anyone.',
        'sender': _senderId,
        'flow_id': _templateId,
        'country': '91', // India country code
      };

      if (kDebugMode) {
        print('Sending SMS to: $phoneNumber');
        print('OTP: $otp');
        print('MSG91 Body: $body');
      }

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (kDebugMode) {
          print('SMS Response: $responseData');
        }

        return responseData['type'] == 'success';
      } else {
        if (kDebugMode) {
          print('SMS Error: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('SMS Service Error: $e');
      }
      return false;
    }
  }

  /// Generate a random 6-digit OTP
  static String generateOTP() {
    return (100000 + (100000 * DateTime.now().millisecond / 1000000).round())
        .toString();
  }

  /// Verify phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Check if it's a valid Indian mobile number (10 digits)
    if (cleanNumber.length == 10 && cleanNumber.startsWith(RegExp(r'[6-9]'))) {
      return true;
    }

    // Check if it's already prefixed with country code (12 digits)
    if (cleanNumber.length == 12 && cleanNumber.startsWith('91')) {
      return true;
    }

    return false;
  }

  /// Format phone number to international format
  static String formatPhoneNumber(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanNumber.length == 10) {
      return '+91$cleanNumber';
    } else if (cleanNumber.length == 12 && cleanNumber.startsWith('91')) {
      return '+$cleanNumber';
    }

    return '+$cleanNumber';
  }
}
