# Build Instructions for Release

This document explains how to build a release version of the app with R8/ProGuard enabled.

## Prerequisites

1. **Keystore File**: You need a signing keystore file for release builds
2. **key.properties**: Create this file in `android/` directory with:
   ```
   storePassword=your_store_password
   keyPassword=your_key_password
   keyAlias=your_key_alias
   storeFile=path/to/your/keystore.jks
   ```

## Building Release App Bundle (AAB)

```bash
flutter build appbundle --release
```

The output will be at: `build/app/outputs/bundle/release/app-release.aab`

## Building Release APK

```bash
flutter build apk --release
```

The output will be at: `build/app/outputs/flutter-apk/app-release.apk`

## Mapping File Location

After building, the mapping file (for deobfuscation) will be located at:
- **App Bundle**: `build/app/outputs/mapping/release/mapping.txt`
- **APK**: `build/app/outputs/mapping/release/mapping.txt`

## Uploading to Google Play Console

### 1. Upload the App Bundle (AAB)
- Go to Google Play Console → Your App → Release → Production
- Upload the `app-release.aab` file

### 2. Upload the Mapping File (Important!)
- After uploading the AAB, go to **App Bundle Explorer**
- Click on your version
- Scroll down to **"Deobfuscation file"** section
- Click **"Upload"** and select `mapping.txt` from:
  ```
  build/app/outputs/mapping/release/mapping.txt
  ```

### Alternative: Upload via Play Console
1. Go to **Release** → **Production** → **App bundles**
2. Click on your version
3. In the **"Deobfuscation file"** section, click **"Upload"**
4. Select the `mapping.txt` file

## Benefits of R8/ProGuard

✅ **Reduced App Size**: Code shrinking can reduce app size by 20-50%
✅ **Better Performance**: Code optimization improves runtime performance
✅ **Code Obfuscation**: Makes reverse engineering harder
✅ **Crash Reporting**: Mapping file allows readable stack traces in Firebase Crashlytics

## Troubleshooting

### If Build Fails

1. **Check ProGuard Rules**: Ensure all required classes are kept
2. **Check Dependencies**: Some libraries may need additional ProGuard rules
3. **Test Release Build**: Always test release builds before uploading:
   ```bash
   flutter build apk --release
   flutter install --release
   ```

### If App Crashes After Obfuscation

1. Check Firebase Crashlytics for obfuscated stack traces
2. Upload the mapping file to Firebase Crashlytics:
   - Go to Firebase Console → Crashlytics → Settings
   - Upload the mapping file
3. Add more ProGuard rules if needed (check crash logs)

## Notes

- **Debug builds** don't use ProGuard (faster builds, easier debugging)
- **Release builds** use R8/ProGuard (smaller size, better performance)
- Always keep a backup of your mapping files for each release version
- Mapping files are version-specific - don't mix them between versions

