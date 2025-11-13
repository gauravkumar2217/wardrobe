# Push Notifications Setup Guide

This guide explains how to set up automatic daily push notifications for outfit suggestions.

## Current Setup

The app is configured to:
1. ✅ Save FCM tokens to Firestore when users log in
2. ✅ Handle foreground FCM messages (show notifications)
3. ✅ Handle background FCM messages (automatic notifications)
4. ✅ Navigate to suggestions screen when notification is tapped
5. ✅ Use local notifications as fallback (scheduled at 7 AM)

## What You Need to Do

### Option 1: Use Cloud Functions (Recommended)

For automatic daily push notifications, you need to set up Firebase Cloud Functions.

**See:** `CLOUD_FUNCTIONS_SETUP.md` for detailed instructions.

**Quick Steps:**
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Initialize functions: `firebase init functions`
3. Create the scheduled function (see CLOUD_FUNCTIONS_SETUP.md)
4. Deploy: `firebase deploy --only functions`

### Option 2: Use Local Notifications (Current)

The app currently uses local notifications scheduled at 7 AM daily. These work even without Cloud Functions, but:
- Only work if the app is installed
- May not be as reliable as push notifications
- Don't work if the app is uninstalled

## Testing Push Notifications

### Test from Firebase Console

1. Go to Firebase Console > Cloud Messaging
2. Click "Send test message"
3. Enter your FCM token (check app logs or Firestore)
4. Send a test notification

### Test from Cloud Functions

Once Cloud Functions are set up, you can:
1. Manually trigger the function from Firebase Console
2. Or wait for the scheduled time (7 AM daily)

## How It Works

1. **User logs in** → FCM token is saved to Firestore
2. **Cloud Function runs daily at 7 AM** → Sends push notifications to all active users
3. **User receives notification** → Can tap to open suggestions screen
4. **App handles notification** → Shows notification and navigates appropriately

## Troubleshooting

### Notifications not received?

1. **Check FCM token is saved:**
   - Look in Firestore: `users/{userId}/fcmTokens/{token}`
   - Token should have `isActive: true`

2. **Check notification permissions:**
   - Android: Settings > Apps > Wardrobe > Notifications
   - iOS: Settings > Notifications > Wardrobe

3. **Check Cloud Functions:**
   - Verify function is deployed
   - Check function logs for errors
   - Ensure function has proper permissions

4. **Check FCM token validity:**
   - Invalid tokens are automatically removed
   - User needs to log in again to get a new token

### Local notifications not working?

1. **Check SCHEDULE_EXACT_ALARM permission:**
   - Android 12+: User needs to grant permission
   - Check in app settings

2. **Check notification channel:**
   - Android: Ensure "Daily Outfit Suggestions" channel is enabled

3. **Check timezone:**
   - Local notifications use device timezone
   - Ensure device time is correct

## Next Steps

1. ✅ **Done**: Removed USE_EXACT_ALARM permission (Google Play requirement)
2. ✅ **Done**: Improved FCM message handling
3. ⏳ **To Do**: Set up Cloud Functions for daily push notifications
4. ⏳ **To Do**: Test push notifications from Firebase Console
5. ⏳ **To Do**: Deploy Cloud Functions to production

## Notes

- **USE_EXACT_ALARM removed**: This permission is only for alarm clock/calendar apps. We removed it to comply with Google Play policies.
- **SCHEDULE_EXACT_ALARM kept**: This is allowed for scheduled notifications and is requested at runtime.
- **Push notifications preferred**: Cloud Functions provide more reliable daily notifications than local notifications.

