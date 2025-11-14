# Google Sign-In Setup Guide

This guide will help you configure Google Sign-In authentication for your Wardrobe app.

## ✅ What's Already Done

1. ✅ Google Sign-In package added (`google_sign_in: ^6.2.1`)
2. ✅ Google Sign-In UI implemented in `otp_auth_screen.dart`
3. ✅ Error handling improved for type casting issues
4. ✅ Firebase Storage rules created to support Google-authenticated users
5. ✅ App Check debug mode support added

## 🔧 Required Firebase Console Setup

### Step 1: Enable Google Sign-In in Firebase

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **wordrobe-chat**
3. Navigate to **Authentication** > **Sign-in method**
4. Click on **Google** provider
5. Enable it and save
6. **Important**: Copy the **Web client ID** (you'll need this later)

### Step 2: Add SHA-1 Fingerprint (Android)

The SHA-1 fingerprint is required for Google Sign-In to work on Android.

#### Option A: Get SHA-1 from Debug Keystore (for testing)

```bash
# Windows
cd android
gradlew signingReport

# Or using keytool directly
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

#### Option B: Get SHA-1 from Release Keystore (for production)

```bash
keytool -list -v -keystore <path-to-your-release-keystore> -alias <your-key-alias>
```

#### Add SHA-1 to Firebase:

1. Go to Firebase Console > **Project Settings** > **Your apps**
2. Select your Android app (`com.wardrobe_chat.app`)
3. Scroll down to **SHA certificate fingerprints**
4. Click **Add fingerprint**
5. Paste your SHA-1 fingerprint
6. Click **Save**

### Step 3: Configure OAuth Consent Screen (if not done)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project: **wordrobe-chat**
3. Navigate to **APIs & Services** > **OAuth consent screen**
4. Complete the OAuth consent screen setup:
   - User Type: External (or Internal if using Google Workspace)
   - App name: Wardrobe Chat
   - User support email: Your email
   - Developer contact: Your email
5. Add scopes: `email`, `profile` (usually already added)
6. Save and continue

### Step 4: Configure App Check Debug Tokens (for development)

1. Run your app in debug mode
2. Check the console logs for: `🔑 App Check Debug Token: <token>`
3. Copy the debug token
4. Go to Firebase Console > **App Check**
5. Select your Android app
6. Click **Manage debug tokens**
7. Click **Add debug token**
8. Paste the token and save

**Note**: App Check will work in release mode without debug tokens, but you need debug tokens for testing in debug mode.

### Step 5: Deploy Firebase Storage Rules

1. Install Firebase CLI (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase (if not already done):
   ```bash
   firebase init storage
   ```
   - Select your project: **wordrobe-chat**
   - Use the existing `storage.rules` file

4. Deploy Storage Rules:
   ```bash
   firebase deploy --only storage
   ```

## 🧪 Testing Google Sign-In

1. **Test in Debug Mode**:
   - Run the app: `flutter run`
   - Tap "Continue with Google"
   - Select a Google account
   - Should successfully sign in

2. **Test in Release Mode**:
   - Build release APK: `flutter build apk --release`
   - Install and test Google Sign-In

## 🐛 Troubleshooting

### Error: "Google Sign-In configuration error"

**Solution**:
1. Verify SHA-1 fingerprint is added to Firebase Console
2. Verify Google Sign-In is enabled in Firebase Authentication
3. Wait 5-10 minutes after adding SHA-1 for changes to propagate
4. Clear app data and try again

### Error: "Type casting error" or "List<Object?> is not a subtype"

**Solution**:
- This error is now handled in the code with retry logic
- If it persists, try:
  1. Update `google_sign_in` package: `flutter pub upgrade google_sign_in`
  2. Clean and rebuild: `flutter clean && flutter pub get && flutter run`
  3. Check Firebase Console for any configuration issues

### Error: "No AppCheckProvider installed" (Debug Mode)

**Solution**:
- This is expected in debug mode if debug tokens aren't configured
- Add the debug token from console logs to Firebase Console (see Step 4 above)
- Or ignore this warning - it won't affect release builds

### Google Sign-In button not showing

**Solution**:
- Verify `google_sign_in` package is in `pubspec.yaml`
- Run `flutter pub get`
- Restart the app

## 📱 Platform-Specific Notes

### Android
- Requires SHA-1 fingerprint in Firebase Console
- Uses `google-services.json` for configuration
- Works with both debug and release builds

### iOS
- Requires proper bundle ID configuration
- May need additional setup in Xcode
- Requires `GoogleService-Info.plist` file

## 🔒 Security Notes

1. **Storage Rules**: The `storage.rules` file ensures users can only access their own files
2. **Authentication**: Both phone and Google authentication are supported
3. **App Check**: Enabled in release mode to protect against abuse

## 📚 Additional Resources

- [Firebase Google Sign-In Documentation](https://firebase.google.com/docs/auth/android/google-signin)
- [Flutter google_sign_in Package](https://pub.dev/packages/google_sign_in)
- [Firebase Storage Rules Documentation](https://firebase.google.com/docs/storage/security)

## ✅ Checklist

- [ ] Google Sign-In enabled in Firebase Console
- [ ] SHA-1 fingerprint added to Firebase Console
- [ ] OAuth consent screen configured
- [ ] App Check debug token added (for development)
- [ ] Firebase Storage rules deployed
- [ ] Tested Google Sign-In in debug mode
- [ ] Tested Google Sign-In in release mode

## 🎉 Success!

Once all steps are completed, users will be able to sign in using either:
- **Phone Number** (OTP verification)
- **Google Account** (OAuth)

Both authentication methods will work seamlessly with your Firebase backend!

