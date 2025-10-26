# Firebase & MSG91 Configuration Guide

## Required Setup Steps

### 1. Firebase Configuration

#### Create Firebase Project:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing project
3. Enable Authentication with Phone provider
4. Download configuration files

#### Update Firebase Configuration Files:

**Android (`android/app/google-services.json`):**
```json
{
  "project_info": {
    "project_number": "YOUR_FIREBASE_PROJECT_NUMBER",
    "project_id": "your-firebase-project-id",
    "storage_bucket": "your-firebase-project-id.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "YOUR_ANDROID_APP_ID",
        "android_client_info": {
          "package_name": "com.wardrobe.app"
        }
      },
      "oauth_client": [
        {
          "client_id": "YOUR_FIREBASE_CLIENT_ID",
          "client_type": 3
        }
      ],
      "api_key": [
        {
          "current_key": "YOUR_FIREBASE_API_KEY"
        }
      ]
    }
  ]
}
```

**iOS (`ios/Runner/GoogleService-Info.plist`):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>API_KEY</key>
    <string>YOUR_IOS_FIREBASE_API_KEY</string>
    <key>GOOGLE_APP_ID</key>
    <string>YOUR_IOS_FIREBASE_APP_ID</string>
    <key>GCM_SENDER_ID</key>
    <string>YOUR_FIREBASE_PROJECT_NUMBER</string>
    <key>PROJECT_ID</key>
    <string>your-firebase-project-id</string>
    <key>STORAGE_BUCKET</key>
    <string>your-firebase-project-id.appspot.com</string>
    <key>IS_ADS_ENABLED</key>
    <false/>
    <key>IS_ANALYTICS_ENABLED</key>
    <false/>
    <key>IS_APPINVITE_ENABLED</key>
    <true/>
    <key>IS_GCM_ENABLED</key>
    <true/>
    <key>IS_SIGNIN_ENABLED</key>
    <true/>
    <key>BUNDLE_ID</key>
    <string>com.wardrobe.app</string>
</dict>
</plist>
```

### 2. MSG91 Configuration

#### Create MSG91 Account:
1. Go to [MSG91 Dashboard](https://control.msg91.com/)
2. Create account and verify your mobile number
3. Add funds to your account
4. Create SMS template

#### Update MSG91 Settings:

**File: `lib/services/sms_service.dart`**
```dart
// Line 7-11: Update these values
static const String _authKey = 'YOUR_MSG91_AUTH_KEY'; // Get from MSG91 Dashboard
static const String _templateId = 'YOUR_TEMPLATE_ID'; // Create template in MSG91
static const String _senderId = 'WPOBE'; // Your 4-6 character sender ID
static const String _route = '4'; // 4 for transactional SMS
```

#### MSG91 Setup Steps:
1. **Get Auth Key**: Login to MSG91 → Settings → Auth Key
2. **Create Template**: 
   - Go to Templates → Create Template
   - Use template: "Your OTP for Wardrobe is {#var#}. Do not share this OTP."
   - Set template type: "Transactional"
   - Get template ID after approval
3. **Set Sender ID**: 
   - Use "WPOBE" or create custom 4-6 character ID
   - Should be alphabetic only

### 3. Android Configuration

#### Update Package Name:
**File: `android/app/build.gradle.kts`**
```gradle
defaultConfig {
    applicationId = "com.wardrobe.app" // Updated package name
    // ... other config
}
```

#### Permissions (Already Added):
**File: `android/app/src/main/AndroidManifest.xml`**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />
```

### 4. iOS Configuration

#### Update Bundle Identifier:
**File: `ios/Runner.xcodeproj/project.pbxproj`**
```bash
# Search and replace: PRODUCT_BUNDLE_IDENTIFIER = com.example.wardrobe
# Replace with: PRODUCT_BUNDLE_IDENTIFIER = com.wardrobe.app
```

### 5. Testing Setup

#### For Development/Testing:
Use these test credentials in development:

**Test Phone Numbers:**
- `test@example.com` + password: `password` (Email login)
- `9999999999` with any 6-digit OTP (Phone login)

**Firebase Test Phone:**
- Add test phone numbers in Firebase Console → Authentication → Sign-in method → Phone

### 6. Environment Variables (Optional)

Create `lib/config/config.dart`:
```dart
class Config {
  static const String firebaseProjectId = 'your-firebase-project-id';
  static const String msg91AuthKey = 'YOUR_MSG91_AUTH_KEY';
  static const String msg91TemplateId = 'YOUR_TEMPLATE_ID';
  static const String senderId = 'WPOBE';
  
  // Environment specific configs
  static const bool isDevelopment = true;
  static const String baseUrl = isDevelopment 
    ? 'https://dev-api.wardrobe.com'
    : 'https://api.wardrobe.com';
}
```

## Security Notes:

1. **Never commit real API keys** to version control
2. **Use environment variables** for production
3. **Enable API key restrictions** in Firebase
4. **Set up OAuth consent screen** for Android
5. **Review SMS template content** before production

## Troubleshooting:

### Common Issues:
1. **"Firebase not initialized"**: Check google-services.json has correct package name
2. **"SMS not sent"**: Verify MSG91 auth key and template ID
3. **"App not installed"**: Update applicationId in build.gradle.kts

### Debug Commands:
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check Firebase setup
flutter packages get
firebase --version
```

## Support:
- Firebase: [Firebase Documentation](https://firebase.google.com/docs)
- MSG91: [MSG91 API Documentation](https://docs.msg91.com/)
- Flutter: [Flutter Firebase](https://firebase.flutter.dev/)


