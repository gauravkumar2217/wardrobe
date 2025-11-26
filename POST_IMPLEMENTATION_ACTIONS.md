# Post-Implementation Actions

This document outlines the actions required after implementing the Wardrobe app rebuild.

## 1. Firebase Console Setup

### 1.1 Deploy Firestore Rules
- Copy `firestore.rules` content to Firebase Console > Firestore Database > Rules
- Or use: `firebase deploy --only firestore:rules`

### 1.2 Deploy Storage Rules
- Copy `storage.rules` content to Firebase Console > Storage > Rules
- Or use: `firebase deploy --only storage`

### 1.3 Create Tag Lists Document
- Create `config/tagLists` document in Firestore
- Add initial tag arrays (see SETUP_GUIDE.md)

### 1.4 Configure Authentication
- Enable Phone, Google, and Email/Password providers
- Add SHA-1 fingerprints for Android
- Download updated `google-services.json`

### 1.5 Configure App Check
- Register app in App Check
- Add debug tokens for testing
- Configure Play Integrity (Android) / App Attest (iOS) for production

## 2. Cloud Functions Setup

### 2.1 Required Cloud Functions

The following Cloud Functions are required for full functionality:

#### 2.1.1 Update Aggregate Counts
**Function**: `onClothLikeCreate`, `onClothLikeDelete`
- Updates `likesCount` when likes are added/removed
- Sends push notification to cloth owner

**Function**: `onCommentCreate`, `onCommentDelete`
- Updates `commentsCount` when comments are added/removed
- Sends push notification to cloth owner

**Function**: `onClothCreate`, `onClothDelete`
- Updates wardrobe `totalItems` count

#### 2.1.2 Friend Request Notifications
**Function**: `onFriendRequestCreate`
- Sends push notification to request recipient

**Function**: `onFriendRequestAccept`
- Sends push notification to request sender
- Creates friend documents in both users' friends subcollections

#### 2.1.3 Chat Notifications
**Function**: `onMessageCreate`
- Sends push notification to chat participants (except sender)
- Updates chat `lastMessage` and `lastMessageAt`

#### 2.1.4 Notification Creation
**Function**: `onClothLikeCreate`, `onCommentCreate`, `onFriendRequestCreate`, etc.
- Creates notification documents in users' notifications subcollection

### 2.2 Cloud Functions Deployment

1. Create `functions` directory in project root
2. Initialize Firebase Functions:
   ```bash
   firebase init functions
   ```
3. Implement functions (see examples below)
4. Deploy:
   ```bash
   firebase deploy --only functions
   ```

### 2.3 Example Cloud Function Structure

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Update likesCount when like is created/deleted
exports.onClothLikeCreate = functions.firestore
  .document('users/{userId}/wardrobes/{wardrobeId}/clothes/{clothId}/likes/{likeId}')
  .onCreate(async (snap, context) => {
    const { userId, wardrobeId, clothId } = context.params;
    const like = snap.data();
    
    // Update likesCount
    await admin.firestore()
      .collection('users').doc(userId)
      .collection('wardrobes').doc(wardrobeId)
      .collection('clothes').doc(clothId)
      .update({
        likesCount: admin.firestore.FieldValue.increment(1)
      });
    
    // Get cloth document
    const clothDoc = await admin.firestore()
      .collection('users').doc(userId)
      .collection('wardrobes').doc(wardrobeId)
      .collection('clothes').doc(clothId)
      .get();
    
    const cloth = clothDoc.data();
    
    // Send notification to cloth owner (if not the liker)
    if (cloth.ownerId !== like.userId) {
      await sendNotification(cloth.ownerId, {
        type: 'cloth_like',
        title: 'New Like',
        body: 'Someone liked your cloth',
        data: { clothId, likeId: like.userId }
      });
    }
  });

// Helper function to send notifications
async function sendNotification(userId, notification) {
  // Get user's active FCM tokens
  const devicesSnapshot = await admin.firestore()
    .collection('users').doc(userId)
    .collection('devices')
    .where('isActive', '==', true)
    .get();
  
  const tokens = devicesSnapshot.docs.map(doc => doc.data().fcmToken);
  
  if (tokens.length === 0) return;
  
  // Create notification document
  await admin.firestore()
    .collection('users').doc(userId)
    .collection('notifications')
    .add({
      ...notification,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    });
  
  // Send FCM messages
  await admin.messaging().sendEach(
    tokens.map(token => ({
      token,
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: notification.data
    }))
  );
}
```

## 3. Testing Checklist

### 3.1 Authentication
- [ ] Phone OTP authentication works
- [ ] Google Sign-In works
- [ ] Email/Password authentication works
- [ ] Profile setup screen appears for new users
- [ ] Existing users go directly to home screen

### 3.2 Core Features
- [ ] Home screen displays clothes
- [ ] Swipeable cloth cards work
- [ ] Like/Comment/Share buttons work
- [ ] Mark as Worn functionality works
- [ ] Wardrobe creation works
- [ ] Cloth addition works
- [ ] Cloth editing works
- [ ] Cloth deletion works

### 3.3 Social Features
- [ ] Friend requests can be sent
- [ ] Friend requests can be accepted/rejected
- [ ] Friends list displays correctly
- [ ] User search works
- [ ] Chat creation works
- [ ] Messages can be sent
- [ ] Cloth sharing in chat works

### 3.4 Notifications
- [ ] Push notifications are received
- [ ] Notification screen displays notifications
- [ ] Notifications can be marked as read
- [ ] Deep linking from notifications works

### 3.5 Data Validation
- [ ] Firestore rules prevent unauthorized access
- [ ] Storage rules prevent unauthorized uploads
- [ ] Tag lists are fetched correctly
- [ ] Aggregate counts update correctly (requires Cloud Functions)

## 4. Production Deployment Checklist

### 4.1 Pre-Deployment
- [ ] All Firebase rules are deployed
- [ ] Cloud Functions are deployed
- [ ] App Check is configured for production
- [ ] SHA-1 fingerprints are added for release builds
- [ ] `google-services.json` is updated with release SHA-1

### 4.2 App Configuration
- [ ] App version is updated
- [ ] App icons are set
- [ ] App name is correct
- [ ] Permissions are configured in AndroidManifest.xml / Info.plist

### 4.3 Testing
- [ ] Test on physical devices (Android and iOS)
- [ ] Test all authentication methods
- [ ] Test core features
- [ ] Test social features
- [ ] Test push notifications
- [ ] Test offline functionality (if implemented)

### 4.4 Monitoring
- [ ] Set up Firebase Analytics
- [ ] Set up Crashlytics (if using)
- [ ] Monitor Cloud Functions logs
- [ ] Monitor Firestore usage
- [ ] Monitor Storage usage

## 5. Known Limitations

1. **Cloud Functions Required**: Aggregate counts (likesCount, commentsCount, totalItems) require Cloud Functions to update automatically.

2. **User Search**: Basic prefix search is implemented. For production, consider using Algolia or similar for better search.

3. **Image Compression**: Image compression is handled client-side. Consider server-side compression for better performance.

4. **Offline Support**: Basic offline support via Firestore cache. Full offline support requires additional implementation.

5. **Admin Access**: Admin user IDs need to be configured in Firestore rules for tag lists updates.

## 6. Future Enhancements

- [ ] Implement Cloud Functions for aggregate counts
- [ ] Implement Cloud Functions for notifications
- [ ] Add AI color detection
- [ ] Add AI cloth type detection
- [ ] Implement advanced search with Algolia
- [ ] Add image compression on server
- [ ] Implement full offline support
- [ ] Add analytics events
- [ ] Implement subscription management
- [ ] Add in-app purchases

## 7. Support

For issues or questions:
1. Check Firebase Console logs
2. Check Cloud Functions logs
3. Review Firestore rules
4. Review Storage rules
5. Check App Check configuration

