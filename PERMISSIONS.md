# Permissions Documentation

This document explains all permissions used by the Wardrobe app and why they are required.

## Android Permissions

### INTERNET
- **Purpose**: Required for Firebase services, network requests, and cloud storage
- **Why**: The app uses Firebase Authentication, Firestore, Storage, Analytics, and Cloud Messaging, all of which require internet connectivity
- **When Requested**: Automatically granted (normal permission)

### SCHEDULE_EXACT_ALARM
- **Purpose**: Schedule daily outfit suggestion notifications at specific times
- **Why**: Allows the app to send notifications at 7 AM daily for outfit suggestions
- **When Requested**: Requested at runtime on Android 12+ (API 31+)

### USE_EXACT_ALARM
- **Purpose**: Use exact alarms for scheduled notifications
- **Why**: Ensures notifications are delivered at the exact scheduled time
- **When Requested**: Requested at runtime on Android 12+ (API 31+)

### POST_NOTIFICATIONS
- **Purpose**: Display push notifications and local notifications
- **Why**: Required to show daily outfit suggestions and other app notifications
- **When Requested**: Requested at runtime on Android 13+ (API 33+)

### READ_EXTERNAL_STORAGE
- **Purpose**: Access images from device storage to add clothing items
- **Why**: Users need to select existing photos from their gallery to add to their wardrobe
- **When Requested**: Requested at runtime on Android 12 and below (API 32 and below)
- **Note**: Not required on Android 13+ due to granular media permissions

### WRITE_EXTERNAL_STORAGE
- **Purpose**: Save images to device storage (optional feature)
- **Why**: Allows users to save wardrobe images to their device
- **When Requested**: Requested at runtime on Android 12 and below (API 32 and below)
- **Note**: Not required on Android 13+ due to granular media permissions

### CAMERA
- **Purpose**: Take photos of clothing items using device camera
- **Why**: Users can take photos directly in the app to add clothing items to their wardrobe
- **When Requested**: Requested at runtime when user tries to take a photo

### READ_PHONE_STATE
- **Purpose**: Used by Firebase Authentication for phone number verification
- **Why**: Helps verify phone numbers during authentication process
- **When Requested**: Requested at runtime on Android 12 and below (API 32 and below)
- **Note**: Not required on Android 13+ as Firebase handles phone verification differently

## iOS Permissions

### NSPhotoLibraryUsageDescription
- **Purpose**: Access user's photo library to select clothing images
- **Why**: Users need to select existing photos from their photo library to add to their wardrobe
- **When Requested**: Requested when user tries to select an image from photo library
- **Message**: "We need access to your photo library to let you select images of your clothing items to organize your wardrobe."

### NSPhotoLibraryAddUsageDescription
- **Purpose**: Save images to user's photo library (optional feature)
- **Why**: Allows users to save wardrobe images to their photo library
- **When Requested**: Requested when user tries to save an image
- **Message**: "We need access to save images of your clothing items to your photo library."

### NSCameraUsageDescription
- **Purpose**: Take photos using device camera
- **Why**: Users can take photos directly in the app to add clothing items to their wardrobe
- **When Requested**: Requested when user tries to take a photo
- **Message**: "We need access to your camera to let you take photos of your clothing items to add them to your wardrobe."

### NSUserNotificationsUsageDescription
- **Purpose**: Send push notifications and local notifications
- **Why**: Required to show daily outfit suggestions and other app notifications
- **When Requested**: Requested when app first launches
- **Message**: "We need permission to send you daily outfit suggestions and notifications about your wardrobe."

## Permission Request Flow

### Android

1. **App Launch**: 
   - Internet permission automatically granted
   - Notification permissions requested on Android 13+

2. **First Use**:
   - Camera permission requested when user tries to take a photo
   - Storage permissions requested when user tries to select an image (Android 12 and below)

3. **Scheduled Notifications**:
   - Exact alarm permissions requested when scheduling daily notifications (Android 12+)

### iOS

1. **App Launch**:
   - Notification permission requested immediately

2. **First Use**:
   - Camera permission requested when user tries to take a photo
   - Photo library permission requested when user tries to select an image

## User Control

Users can:
- **Grant or deny permissions**: All permissions can be granted or denied by the user
- **Revoke permissions**: Users can revoke permissions at any time in device settings
- **App continues to work**: App will continue to function with limited features if permissions are denied

## Privacy Considerations

- **Minimal data collection**: We only request permissions necessary for app functionality
- **User control**: Users have full control over permissions
- **Transparent requests**: All permission requests include clear explanations
- **No tracking**: We do not use permissions for tracking or advertising purposes

## Permission Denial Handling

If permissions are denied:
- **Camera**: User can still add images from photo library
- **Photo Library**: User can still take photos with camera
- **Notifications**: User will not receive daily suggestions but can still use the app
- **Storage**: App will use alternative methods for image handling

## Compliance

All permissions comply with:
- Google Play Store policies
- Apple App Store guidelines
- GDPR requirements
- Platform-specific privacy requirements

## Updates

This document will be updated if new permissions are added or existing permissions are modified.

For questions about permissions, contact: privacy@wardrobe.app

