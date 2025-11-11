# Notifications Setup Guide

This guide explains how to resolve the Google Play Console exact alarm permission error and how to manage push notifications using Firebase Cloud Messaging (FCM) without a web server.

## Table of Contents
1. [Resolving Google Play Console Exact Alarm Error](#resolving-google-play-console-exact-alarm-error)
2. [Sending Push Notifications via Firebase Console](#sending-push-notifications-via-firebase-console)
3. [Sending Notifications to Specific Users](#sending-notifications-to-specific-users)
4. [Automated Notifications with Firebase Cloud Functions (Optional)](#automated-notifications-with-firebase-cloud-functions-optional)

---

## Resolving Google Play Console Exact Alarm Error

### Step 1: Declare Exact Alarm Usage in Play Console

When uploading your app to Google Play Console, you'll see an error about exact alarm permissions. Here's how to resolve it:

1. **Go to Google Play Console** → Your App → **Policy** → **App content**

2. **Find "Alarms & reminders" section** and answer the question:
   - **Question**: "Does your app use exact alarm permissions?"
   - **Answer**: **Yes**
   
3. **Next question**: "Is this permission used for core functionality?"
   - **Answer**: **No** (Daily outfit suggestions are a nice-to-have feature, not core functionality)

4. **Provide justification** (example):
   ```
   Our app uses SCHEDULE_EXACT_ALARM permission to send daily outfit 
   suggestion notifications at 7 AM. This is a convenience feature 
   that enhances user experience but is not required for the app's 
   core functionality. Users can still access outfit suggestions 
   manually at any time.
   ```

### Step 2: Understanding the Permission

- **SCHEDULE_EXACT_ALARM**: Used for scheduling daily notifications at a specific time (7 AM)
- **USE_EXACT_ALARM**: Removed - this is only for system apps
- The app gracefully falls back to inexact alarms if exact alarm permission is not granted

### Step 3: User Experience

- On Android 12+ (API 31+), users may need to grant exact alarm permission manually
- The app will work fine without this permission, but notifications may be less precise
- Users can grant permission via: Settings → Apps → Wardrobe → Special app access → Alarms & reminders

---

## Sending Push Notifications via Firebase Console

You can send push notifications to all users or specific users directly from Firebase Console without any server code.

### Method 1: Send to All Users (Broadcast)

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Select your project** → **Cloud Messaging** (or **Engage** → **Cloud Messaging**)
3. **Click "Send your first message"** or **"New notification"**
4. **Fill in the notification details**:
   - **Notification title**: e.g., "New Outfit Suggestions Available!"
   - **Notification text**: e.g., "Check out today's personalized outfit recommendations"
   - **Notification image** (optional): Upload an image
5. **Target**: Select **"Send to all users"** or **"Send to a segment"**
6. **Additional options**:
   - **Schedule**: Send now or schedule for later
   - **Conversion events**: Track notification performance
7. **Review and publish**

### Method 2: Send to Specific Users (Using FCM Tokens)

To send notifications to specific users, you need their FCM tokens stored in Firestore.

#### Step 1: Get User's FCM Token from Firestore

1. **Go to Firebase Console** → **Firestore Database**
2. **Navigate to**: `users/{userId}/fcmTokens/{token}`
3. **Copy the token** from the document

#### Step 2: Send Test Notification

1. **Go to Firebase Console** → **Cloud Messaging**
2. **Click "Send test message"**
3. **Enter the FCM token** you copied
4. **Enter notification title and text**
5. **Click "Test"**

#### Step 3: Send to Multiple Users via API

For sending to multiple users, you can use Firebase Cloud Functions (see below) or use the Firebase Admin SDK from a simple script.

---

## Sending Notifications to Specific Users

### Option A: Using Firebase Console (Manual)

1. **Get FCM tokens** from Firestore: `users/{userId}/fcmTokens/`
2. **Use "Send test message"** in Firebase Console for individual users
3. **For multiple users**, use Cloud Functions (see below)

### Option B: Using Firebase Cloud Functions (Automated)

Create a Cloud Function that sends notifications based on Firestore data:

#### Setup Cloud Functions

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Initialize Firebase Functions** in your project:
   ```bash
   firebase init functions
   ```
   - Select **JavaScript** or **TypeScript**
   - Install dependencies when prompted

3. **Create a function** to send notifications:

**functions/index.js**:
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Send notification to a specific user
exports.sendNotificationToUser = functions.https.onCall(async (data, context) => {
  const { userId, title, body } = data;
  
  // Get user's FCM tokens
  const tokensSnapshot = await admin.firestore()
    .collection('users')
    .doc(userId)
    .collection('fcmTokens')
    .where('isActive', '==', true)
    .get();
  
  const tokens = tokensSnapshot.docs.map(doc => doc.id);
  
  if (tokens.length === 0) {
    return { success: false, message: 'No active tokens found' };
  }
  
  // Send notification
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    tokens: tokens,
  };
  
  try {
    const response = await admin.messaging().sendMulticast(message);
    return { 
      success: true, 
      successCount: response.successCount,
      failureCount: response.failureCount 
    };
  } catch (error) {
    console.error('Error sending message:', error);
    return { success: false, error: error.message };
  }
});

// Send daily notifications to all active users
exports.sendDailyNotifications = functions.pubsub
  .schedule('0 7 * * *') // 7 AM every day
  .timeZone('America/New_York') // Adjust to your timezone
  .onRun(async (context) => {
    // Get all active users
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .get();
    
    const promises = [];
    
    usersSnapshot.forEach(async (userDoc) => {
      const tokensSnapshot = await admin.firestore()
        .collection('users')
        .doc(userDoc.id)
        .collection('fcmTokens')
        .where('isActive', '==', true)
        .get();
      
      const tokens = tokensSnapshot.docs.map(doc => doc.id);
      
      if (tokens.length > 0) {
        const message = {
          notification: {
            title: 'Wardrobe',
            body: 'Outfit Suggestion Ready! Check out today\'s outfit suggestion',
          },
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          tokens: tokens,
        };
        
        promises.push(admin.messaging().sendMulticast(message));
      }
    });
    
    await Promise.all(promises);
    console.log('Daily notifications sent');
  });
```

4. **Deploy the function**:
   ```bash
   firebase deploy --only functions
   ```

5. **Call the function** from your app or Firebase Console:
   - Go to **Firebase Console** → **Functions**
   - Click on your function → **Test** tab
   - Enter test data and run

---

## Testing Notifications

### Test Local Notifications
1. Run the app
2. The app will automatically schedule a daily notification at 7 AM
3. You can test immediately by calling `NotificationService.showNotification()` from your code

### Test FCM Push Notifications

1. **Get FCM Token**:
   - Run the app
   - Check logs for "Initial FCM Token: ..."
   - Or check Firestore: `users/{userId}/fcmTokens/`

2. **Send Test Message**:
   - Firebase Console → Cloud Messaging → Send test message
   - Paste the FCM token
   - Enter title and body
   - Click "Test"

3. **Verify**:
   - If app is in foreground: Notification should appear via `showFCMNotification()`
   - If app is in background: System notification should appear
   - If app is closed: System notification should appear

---

## Notification Channels

The app creates two notification channels:

1. **daily_suggestions**: For scheduled daily outfit suggestions
2. **wardrobe_notifications**: For FCM push notifications

Users can customize notification settings for each channel in Android Settings.

---

## Troubleshooting

### Notifications Not Appearing

1. **Check permissions**:
   - Android 13+: POST_NOTIFICATIONS permission must be granted
   - Check app settings: Settings → Apps → Wardrobe → Notifications

2. **Check FCM Token**:
   - Verify token is saved in Firestore
   - Token should be under `users/{userId}/fcmTokens/{token}`

3. **Check Firebase Configuration**:
   - Verify `google-services.json` is in `android/app/`
   - Verify Firebase project is correctly configured

4. **Check Logs**:
   - Look for FCM-related errors in logcat
   - Check Firebase Console → Cloud Messaging → Reports

### Exact Alarm Permission Issues

1. **On Android 12+**: Users need to grant permission manually
2. **Fallback**: App uses inexact alarms if exact alarms aren't available
3. **Check permission**: Use `NotificationService.canScheduleExactAlarms()`

---

## Best Practices

1. **Don't spam users**: Send meaningful, timely notifications
2. **Respect user preferences**: Allow users to disable notifications
3. **Handle token refresh**: FCM tokens can change; listen to `onTokenRefresh`
4. **Clean up inactive tokens**: Periodically remove old/inactive tokens from Firestore
5. **Test thoroughly**: Test notifications in foreground, background, and closed states

---

## Additional Resources

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications Plugin](https://pub.dev/packages/flutter_local_notifications)
- [Android Exact Alarm Permissions](https://developer.android.com/training/scheduling/alarms)
- [Google Play Console Policy](https://support.google.com/googleplay/android-developer/answer/9888170)

