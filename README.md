# Wardrobe - Personal Fashion Assistant

Wardrobe is your personal fashion assistant that helps you organize your clothes, get daily outfit suggestions, and chat with an AI stylist to create the perfect look.

## Features

- **Smart Wardrobe Organization**: Organize your clothes by wardrobe, season, and occasion
- **AI-Powered Outfit Suggestions**: Get personalized daily outfit recommendations
- **AI Styling Assistant**: Chat with an intelligent styling assistant for fashion advice
- **Image Management**: Take photos or select from gallery to organize your clothing collection
- **Daily Notifications**: Receive daily outfit suggestions at your preferred time
- **Multiple Wardrobes**: Manage different wardrobes for different locations

## Getting Started

### Prerequisites

- **Flutter SDK** (>=3.0.0)
- **Dart SDK** (included with Flutter)
- **Firebase Account**: For authentication, database, and storage
- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)

### Installation

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd wardrobe
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Add your `google-services.json` to `android/app/`
   - Add your `GoogleService-Info.plist` to `ios/Runner/`
   - Update Firebase configuration in `lib/firebase_options.dart`

4. Run the app:
   ```bash
   flutter run
   ```

## Building for Production

### Android

1. Create a keystore file:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties`:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=<path-to-keystore>
   ```

3. Build release APK:
   ```bash
   flutter build apk --release
   ```

4. Build release App Bundle (for Play Store):
   ```bash
   flutter build appbundle --release
   ```

### iOS

1. Open `ios/Runner.xcworkspace` in Xcode
2. Configure signing with your Apple Developer account
3. Build for release:
   ```bash
   flutter build ios --release
   ```

## Project Structure

```
lib/
├── constants/          # App constants and configuration
├── models/             # Data models
├── providers/          # State management providers
├── screens/            # App screens
│   ├── about_screen.dart
│   ├── privacy_policy_screen.dart
│   ├── terms_conditions_screen.dart
│   └── ...
├── services/           # Business logic services
│   ├── auth_service.dart
│   ├── fcm_token_service.dart
│   ├── legal_content_service.dart
│   └── ...
└── widgets/            # Reusable widgets
```

## App Store Submission

### Google Play Store

- See `STORE_SUBMISSION.md` for detailed checklist
- Privacy Policy URL required
- App signing required
- Screenshots and descriptions needed

### Apple App Store

- See `STORE_SUBMISSION.md` for detailed checklist
- Privacy Policy URL required
- App signing with Apple Developer account
- Screenshots and descriptions needed

## Legal Pages

- **Privacy Policy**: Available in-app and at `assets/store/privacy_policy.txt`
- **Terms & Conditions**: Available in-app and at `assets/store/terms_conditions.txt`
- **About Page**: Includes app credits and information

## Credits

- **App Conceptualized by**: Rakesh Maheshwari
- **App Designed by**: Dr. Sandhya Kumari Singh
- **App Developed by**: GeniusWebSolution

## Permissions

The app requires the following permissions:
- **Internet**: For Firebase services and network requests
- **Camera**: For taking photos of clothing items
- **Storage**: For accessing and saving images
- **Notifications**: For daily outfit suggestions
- **Phone**: For authentication (optional)

See `PERMISSIONS.md` for detailed information.

## Testing

Before submitting to app stores:
- Test on both Android and iOS devices
- Verify all features work correctly
- Test in release mode
- Check all legal pages are accessible
- Verify permissions are requested properly

See `TESTING_CHECKLIST.md` for complete testing checklist.

## Support

For support, please contact:
- Email: support@wardrobe.app
- Privacy: privacy@wardrobe.app

## License

Copyright © 2025 Wardrobe App. All rights reserved.

## Learn More

- [Flutter documentation](https://docs.flutter.dev/)
- [Firebase documentation](https://firebase.google.com/docs)
- [Dart language documentation](https://dart.dev/guides/language/language-tour)
