# Cloud Functions Setup for Daily Push Notifications

This guide explains how to set up Firebase Cloud Functions to send daily push notifications for outfit suggestions at 7 AM.

## Prerequisites

1. Firebase CLI installed: `npm install -g firebase-tools`
2. Node.js installed (v14 or higher)
3. Firebase project with Firestore and Cloud Messaging enabled

## Setup Steps

### 1. Initialize Firebase Functions

```bash
# Navigate to your project root
cd wardrobe

# Initialize Firebase (if not already done)
firebase init functions

# Select:
# - Use an existing project (select your Firebase project)
# - Language: JavaScript (or TypeScript)
# - ESLint: Yes
# - Install dependencies: Yes
```

### 2. Install Required Dependencies

```bash
cd functions
npm install firebase-admin firebase-functions
```

### 3. Create the Daily Notification Function

Create `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Scheduled function to send daily outfit suggestion notifications at 7 AM
exports.sendDailySuggestionNotifications = functions.pubsub
  .schedule('0 7 * * *') // Run daily at 7 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('Starting daily suggestion notification job...');
    
    try {
      const db = admin.firestore();
      const messaging = admin.messaging();
      
      // Get all users
      const usersSnapshot = await db.collection('users').get();
      
      if (usersSnapshot.empty) {
        console.log('No users found');
        return null;
      }
      
      let successCount = 0;
      let failureCount = 0;
      
      // Process each user
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        
        try {
          // Get active FCM tokens for this user
          const tokensSnapshot = await db
            .collection(`users/${userId}/fcmTokens`)
            .where('isActive', '==', true)
            .get();
          
          if (tokensSnapshot.empty) {
            console.log(`No active tokens for user ${userId}`);
            continue;
          }
          
          // Get user's wardrobes
          const wardrobesSnapshot = await db
            .collection(`users/${userId}/wardrobes`)
            .get();
          
          if (wardrobesSnapshot.empty) {
            console.log(`No wardrobes for user ${userId}`);
            continue;
          }
          
          // Check if today's suggestion already exists
          const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
          const suggestionDoc = await db
            .collection(`users/${userId}/suggestions`)
            .doc(today)
            .get();
          
          // If suggestion doesn't exist, we'll still send notification
          // The app will generate it when opened
          
          // Prepare notification message
          const message = {
            notification: {
              title: 'Wardrobe',
              body: 'Your daily outfit suggestion is ready! Check it out now.',
            },
            data: {
              type: 'daily_suggestion',
              userId: userId,
              date: today,
            },
            android: {
              priority: 'high',
              notification: {
                channelId: 'daily_suggestions',
                sound: 'default',
                color: '#7C3AED',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          };
          
          // Send to all active tokens for this user
          const tokens = tokensSnapshot.docs.map(doc => doc.data().token);
          
          if (tokens.length > 0) {
            const response = await messaging.sendToDevice(tokens, message);
            
            // Check for failures
            const failedTokens = [];
            response.results.forEach((result, index) => {
              if (result.error) {
                console.error(`Failed to send to token ${tokens[index]}:`, result.error);
                if (result.error.code === 'messaging/invalid-registration-token' ||
                    result.error.code === 'messaging/registration-token-not-registered') {
                  failedTokens.push(tokensSnapshot.docs[index].id);
                }
              } else {
                successCount++;
              }
            });
            
            // Remove invalid tokens
            if (failedTokens.length > 0) {
              const batch = db.batch();
              failedTokens.forEach(tokenId => {
                batch.delete(db.doc(`users/${userId}/fcmTokens/${tokenId}`));
              });
              await batch.commit();
            }
          }
        } catch (error) {
          console.error(`Error processing user ${userId}:`, error);
          failureCount++;
        }
      }
      
      console.log(`Notification job completed. Success: ${successCount}, Failures: ${failureCount}`);
      return null;
    } catch (error) {
      console.error('Error in daily notification job:', error);
      throw error;
    }
  });
```

### 4. Deploy the Function

```bash
# Deploy the function
firebase deploy --only functions

# Or deploy a specific function
firebase deploy --only functions:sendDailySuggestionNotifications
```

### 5. Test the Function

You can test the function manually:

```bash
# Test locally (requires emulator)
firebase emulators:start

# Or trigger manually from Firebase Console
# Go to Functions > sendDailySuggestionNotifications > Test
```

### 6. Adjust Time Zone (Optional)

To send notifications at 7 AM in a specific timezone, modify the schedule:

```javascript
// For 7 AM IST (UTC+5:30)
exports.sendDailySuggestionNotifications = functions.pubsub
  .schedule('0 1 * * *') // 1:30 AM UTC = 7 AM IST
  .timeZone('Asia/Kolkata')
  .onRun(async (context) => {
    // ... rest of the code
  });
```

## Alternative: Using Cloud Scheduler

If you prefer using Cloud Scheduler directly:

1. Go to Google Cloud Console
2. Navigate to Cloud Scheduler
3. Create a new job:
   - Name: `daily-suggestion-notifications`
   - Frequency: `0 7 * * *` (daily at 7 AM UTC)
   - Target: HTTP
   - URL: Your Cloud Function HTTP trigger URL
   - Method: POST

## Monitoring

Monitor your function in Firebase Console:
- Go to Functions tab
- View logs and execution history
- Check for errors and performance

## Cost Considerations

- Cloud Functions: Free tier includes 2 million invocations/month
- Cloud Scheduler: Free tier includes 3 jobs
- FCM: Free for unlimited messages

## Troubleshooting

1. **Function not triggering**: Check Cloud Scheduler logs
2. **Notifications not received**: Verify FCM tokens are active in Firestore
3. **Permission errors**: Ensure service account has proper permissions

## Notes

- The function runs daily at 7 AM UTC by default
- Adjust the schedule based on your target timezone
- The function automatically handles invalid tokens
- Notifications are sent to all active users with valid FCM tokens

