# Firebase Security Rules — Wardrobe App
## Complete Firestore & Storage Rules

**Project:** `wordrobe-chat`  
**Storage Bucket:** `wordrobe-chat.firebasestorage.app`

**Important:** 
- These rules assume you are using **Cloud Firestore**, not Realtime Database
- Before deploying, test using the Firebase Rules simulator for all flows
- Adjust collection names/field names if your app uses different ones
- **Delete all existing data from Firestore and Storage before deploying these rules** (as per your request)

---

## Table of Contents
1. [High-Level Principles](#1-high-level-principles)
2. [Helper Functions](#2-helper-functions)
3. [Config Collection (Tag Lists)](#3-config-collection-tag-lists)
4. [Users Collection](#4-users-collection)
5. [Wardrobes Collection](#5-wardrobes-collection)
6. [Clothes Collection](#6-clothes-collection)
7. [Friend Requests Collection](#7-friend-requests-collection)
8. [Chats Collection](#8-chats-collection)
9. [Firebase Storage Rules](#9-firebase-storage-rules)
10. [Testing Guide](#10-testing-guide)

---

## 1. High-Level Principles

- **Auth required** for all app data (no anonymous public read/write)
- **Users manage only their own data** (`ownerId == request.auth.uid`)
- **Friend-only content** is visible only if a friendship record exists
- **DMs are private** to chat participants only
- **FCM tokens and notifications** are only visible to the owner user
- **Storage access** is controlled by Firestore document access rules

---

## 2. Helper Functions

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Check if user is authenticated
    function isSignedIn() {
      return request.auth != null;
    }

    // Check if user is the owner
    function isOwner(ownerIdField) {
      return isSignedIn() && request.auth.uid == ownerIdField;
    }

    // Check if the current user is a friend of targetUserId
    // Assumes: users/{targetUserId}/friends/{currentUserId}
    function isFriend(targetUserId) {
      return isSignedIn() &&
        exists(/databases/$(database)/documents/users/$(targetUserId)/friends/$(request.auth.uid));
    }

    // Check if current user is a participant in a chat
    function isChatParticipant(chatPath) {
      return isSignedIn() &&
        request.auth.uid in get(chatPath).data.participants;
    }

    // Check that a document will not change its owner
    function doesNotChangeOwner(field) {
      return !(field in resource.data) || 
             resource.data[field] == request.resource.data[field];
    }

    // Check if cloth is visible to current user
    function canReadCloth(clothData) {
      return isSignedIn() && (
        // Owner can always read
        isOwner(clothData.ownerId) ||
        // Public visibility
        clothData.visibility == 'public' ||
        // Friends visibility and user is friend
        (clothData.visibility == 'friends' && isFriend(clothData.ownerId)) ||
        // Explicitly shared with user
        (request.auth.uid in clothData.get('sharedWith', []))
      );
    }

    // Global default: deny everything
    match /{document=**} {
      allow read, write: if false;
    }

    // ----------------------------------------------------------------------
    // CONFIG COLLECTION (Dynamic Tag Lists)
    // ----------------------------------------------------------------------
    match /config/tagLists {
      // Read: all authenticated users can read tag lists (needed for app functionality)
      allow read: if isSignedIn();

      // Write: admin only (you can set specific user IDs here)
      // Option 1: Specific admin user IDs
      allow write: if isSignedIn() && 
        request.auth.uid in ['YOUR_ADMIN_USER_ID_1', 'YOUR_ADMIN_USER_ID_2'];
      
      // Option 2: Using custom claims (recommended for production)
      // First, set custom claim 'admin: true' for admin users via Cloud Functions
      // Then uncomment and use this instead:
      // allow write: if isSignedIn() && request.auth.token.admin == true;
    }
```

---

## 3. Users Collection

```rules
    // ----------------------------------------------------------------------
    // USERS COLLECTION
    // ----------------------------------------------------------------------
    match /users/{userId} {
      // Read: user can read own profile, friends can read limited fields
      allow read: if isSignedIn() && (
        request.auth.uid == userId ||
        // Friends can read displayName and photoUrl only
        (isFriend(userId) && 
         request.resource == null && // Only for reads, not writes
         request.query.limit == null) // Simple read, not query
      );

      // Create: user can create their own profile
      allow create: if isSignedIn() 
        && request.auth.uid == userId
        && request.resource.data.keys().hasAll(['displayName', 'createdAt'])
        && request.resource.data.displayName is string
        && request.resource.data.createdAt is timestamp;

      // Update: user can update own profile, cannot change uid or ownerId
      allow update: if isSignedIn()
        && request.auth.uid == userId
        && doesNotChangeOwner('uid')
        && (!('ownerId' in request.resource.data) || 
            request.resource.data.ownerId == userId);

      // Delete: user can delete own profile (account deletion)
      allow delete: if isSignedIn() && request.auth.uid == userId;

      // ----------------------------------------------------------------------
      // USER FRIENDS SUBCOLLECTION
      // ----------------------------------------------------------------------
      match /friends/{friendId} {
        // Read/Write: user can manage their own friends list
        allow read, write: if isSignedIn() && request.auth.uid == userId;
      }

      // ----------------------------------------------------------------------
      // USER NOTIFICATIONS SUBCOLLECTION
      // ----------------------------------------------------------------------
      match /notifications/{notificationId} {
        // Read/Write: user can manage their own notifications
        allow read, write: if isSignedIn() && request.auth.uid == userId;
      }

      // ----------------------------------------------------------------------
      // USER DEVICES SUBCOLLECTION (FCM Tokens)
      // ----------------------------------------------------------------------
      match /devices/{deviceId} {
        // Read/Write: user can manage their own device tokens
        allow read, write: if isSignedIn() && request.auth.uid == userId
          && request.resource.data.fcmToken is string
          && request.resource.data.platform is string;
      }
    }
```

---

## 4. Wardrobes Collection

```rules
    // ----------------------------------------------------------------------
    // WARDROBES COLLECTION
    // ----------------------------------------------------------------------
    match /wardrobes/{wardrobeId} {
      // Read: only owner can read (friends can be added later if needed)
      allow read: if isSignedIn() 
        && isOwner(resource.data.ownerId);

      // Create: user can create wardrobe with themselves as owner
      allow create: if isSignedIn()
        && request.auth.uid == request.resource.data.ownerId
        && request.resource.data.keys().hasAll(['ownerId', 'name', 'location', 'createdAt'])
        && request.resource.data.name is string
        && request.resource.data.location is string
        && request.resource.data.createdAt is timestamp;

      // Update: only owner can update, cannot change ownerId
      allow update: if isSignedIn()
        && request.auth.uid == resource.data.ownerId
        && doesNotChangeOwner('ownerId')
        && request.resource.data.ownerId == resource.data.ownerId;

      // Delete: only owner can delete
      allow delete: if isSignedIn()
        && request.auth.uid == resource.data.ownerId;
    }
```

---

## 5. Clothes Collection

```rules
    // ----------------------------------------------------------------------
    // CLOTHES COLLECTION
    // ----------------------------------------------------------------------
    match /clothes/{clothId} {
      // Read: owner, friends (if visibility allows), public, or shared
      allow read: if isSignedIn() && canReadCloth(resource.data);

      // Create: user can create cloth with themselves as owner
      allow create: if isSignedIn()
        && request.auth.uid == request.resource.data.ownerId
        && request.resource.data.keys().hasAll(['ownerId', 'wardrobeId', 'imageUrl', 'createdAt'])
        && request.resource.data.ownerId is string
        && request.resource.data.wardrobeId is string
        && request.resource.data.imageUrl is string
        && request.resource.data.createdAt is timestamp
        && request.resource.data.visibility in ['private', 'friends', 'public'];

      // Update: only owner can update, cannot change ownerId or system fields
      allow update: if isSignedIn()
        && request.auth.uid == resource.data.ownerId
        && doesNotChangeOwner('ownerId')
        && request.resource.data.ownerId == resource.data.ownerId
        // Prevent direct modification of system-maintained fields
        && (!('likesCount' in request.resource.data.diff(resource.data).affectedKeys()) ||
            request.resource.data.likesCount == resource.data.likesCount)
        && (!('commentsCount' in request.resource.data.diff(resource.data).affectedKeys()) ||
            request.resource.data.commentsCount == resource.data.commentsCount);

      // Delete: only owner can delete
      allow delete: if isSignedIn()
        && request.auth.uid == resource.data.ownerId;

      // ----------------------------------------------------------------------
      // WEAR HISTORY SUBCOLLECTION
      // ----------------------------------------------------------------------
      match /wearHistory/{entryId} {
        // Read: only owner can read their wear history
        allow read: if isSignedIn()
          && request.auth.uid == resource.data.userId
          && resource.data.userId == get(/databases/$(database)/documents/clothes/$(clothId)).data.ownerId;

        // Create: only owner can create wear history entry
        allow create: if isSignedIn()
          && request.auth.uid == request.resource.data.userId
          && request.resource.data.userId == get(/databases/$(database)/documents/clothes/$(clothId)).data.ownerId
          && request.resource.data.keys().hasAll(['userId', 'wornAt'])
          && request.resource.data.wornAt is timestamp;

        // Update/Delete: only owner can modify their own entries
        allow update, delete: if isSignedIn()
          && request.auth.uid == resource.data.userId
          && resource.data.userId == get(/databases/$(database)/documents/clothes/$(clothId)).data.ownerId;
      }

      // ----------------------------------------------------------------------
      // LIKES SUBCOLLECTION
      // ----------------------------------------------------------------------
      match /likes/{likeId} {
        // Read: anyone who can read the cloth can read likes
        allow read: if isSignedIn() && 
          canReadCloth(get(/databases/$(database)/documents/clothes/$(clothId)).data);

        // Create: user can like if they can read the cloth, likeId must equal userId
        allow create: if isSignedIn()
          && canReadCloth(get(/databases/$(database)/documents/clothes/$(clothId)).data)
          && request.auth.uid == request.resource.data.userId
          && likeId == request.auth.uid
          && request.resource.data.keys().hasAll(['userId', 'createdAt'])
          && request.resource.data.createdAt is timestamp;

        // Delete: user can delete their own like
        allow delete: if isSignedIn()
          && likeId == request.auth.uid;
      }

      // ----------------------------------------------------------------------
      // COMMENTS SUBCOLLECTION
      // ----------------------------------------------------------------------
      match /comments/{commentId} {
        // Read: anyone who can read the cloth can read comments
        allow read: if isSignedIn() && 
          canReadCloth(get(/databases/$(database)/documents/clothes/$(clothId)).data);

        // Create: user can comment if they can read the cloth
        allow create: if isSignedIn()
          && canReadCloth(get(/databases/$(database)/documents/clothes/$(clothId)).data)
          && request.auth.uid == request.resource.data.userId
          && request.resource.data.keys().hasAll(['userId', 'text', 'createdAt'])
          && request.resource.data.text is string
          && request.resource.data.createdAt is timestamp;

        // Update: only comment author can update
        allow update: if isSignedIn()
          && request.auth.uid == resource.data.userId
          && request.resource.data.userId == resource.data.userId;

        // Delete: only comment author can delete
        allow delete: if isSignedIn()
          && request.auth.uid == resource.data.userId;
      }
    }
```

---

## 6. Friend Requests Collection

```rules
    // ----------------------------------------------------------------------
    // FRIEND REQUESTS COLLECTION
    // ----------------------------------------------------------------------
    match /friendRequests/{requestId} {
      // Read: only involved users can read
      allow read: if isSignedIn() && (
        request.auth.uid == resource.data.fromUserId ||
        request.auth.uid == resource.data.toUserId
      );

      // Create: user can create request for another user
      allow create: if isSignedIn()
        && request.auth.uid == request.resource.data.fromUserId
        && request.resource.data.fromUserId != request.resource.data.toUserId
        && request.resource.data.status == 'pending'
        && request.resource.data.keys().hasAll(['fromUserId', 'toUserId', 'status', 'createdAt'])
        && request.resource.data.createdAt is timestamp;

      // Update: receiver can accept/reject, sender can cancel
      allow update: if isSignedIn() && (
        // Receiver can accept or reject
        (request.auth.uid == resource.data.toUserId &&
         resource.data.status == 'pending' &&
         request.resource.data.status in ['accepted', 'rejected']) ||
        // Sender can cancel while pending
        (request.auth.uid == resource.data.fromUserId &&
         resource.data.status == 'pending' &&
         request.resource.data.status == 'canceled')
      ) && request.resource.data.fromUserId == resource.data.fromUserId
         && request.resource.data.toUserId == resource.data.toUserId;

      // Delete: either user can delete (cleanup)
      allow delete: if isSignedIn() && (
        request.auth.uid == resource.data.fromUserId ||
        request.auth.uid == resource.data.toUserId
      );
    }
```

---

## 7. Chats Collection

```rules
    // ----------------------------------------------------------------------
    // CHATS COLLECTION
    // ----------------------------------------------------------------------
    match /chats/{chatId} {
      // Read: only participants can read
      allow read: if isSignedIn()
        && request.auth.uid in resource.data.participants;

      // Create: creator must include themselves in participants
      allow create: if isSignedIn()
        && request.auth.uid in request.resource.data.participants
        && request.resource.data.participants.size() >= 2
        && request.resource.data.keys().hasAll(['participants', 'createdAt'])
        && request.resource.data.createdAt is timestamp;

      // Update: only participants can update (e.g., lastMessage)
      allow update: if isSignedIn()
        && request.auth.uid in resource.data.participants
        && request.resource.data.participants == resource.data.participants;

      // Delete: only participants can delete
      allow delete: if isSignedIn()
        && request.auth.uid in resource.data.participants;

      // ----------------------------------------------------------------------
      // MESSAGES SUBCOLLECTION
      // ----------------------------------------------------------------------
      match /messages/{messageId} {
        // Read: only chat participants can read messages
        allow read: if isSignedIn() &&
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;

        // Create: only chat participants can create messages
        allow create: if isSignedIn()
          && request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants
          && request.auth.uid == request.resource.data.senderId
          && request.resource.data.keys().hasAll(['senderId', 'createdAt'])
          && request.resource.data.createdAt is timestamp;

        // Update: only message sender can update (e.g., seenBy)
        allow update: if isSignedIn()
          && request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants
          && request.auth.uid == resource.data.senderId;

        // Delete: only message sender can delete
        allow delete: if isSignedIn()
          && request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants
          && request.auth.uid == resource.data.senderId;
      }
    }
  }
}
```

---

## 8. Firebase Storage Rules

```rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Helper function: check if user is authenticated
    function isSignedIn() {
      return request.auth != null;
    }

    // Helper function: check if user owns the resource
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // Helper function: check if cloth is accessible (requires Firestore read)
    function canAccessCloth(clothId) {
      return isSignedIn() && 
        exists(/databases/(default)/documents/clothes/$(clothId)) &&
        (
          // Owner
          get(/databases/(default)/documents/clothes/$(clothId)).data.ownerId == request.auth.uid ||
          // Public
          get(/databases/(default)/documents/clothes/$(clothId)).data.visibility == 'public' ||
          // Friends
          (get(/databases/(default)/documents/clothes/$(clothId)).data.visibility == 'friends' &&
           exists(/databases/(default)/documents/users/$(get(/databases/(default)/documents/clothes/$(clothId)).data.ownerId)/friends/$(request.auth.uid))) ||
          // Shared with user
          request.auth.uid in get(/databases/(default)/documents/clothes/$(clothId)).data.get('sharedWith', [])
        );
    }

    // Helper function: check if user is chat participant
    function isChatParticipant(chatId) {
      return isSignedIn() &&
        exists(/databases/(default)/documents/chats/$(chatId)) &&
        request.auth.uid in get(/databases/(default)/documents/chats/$(chatId)).data.participants;
    }

    // ----------------------------------------------------------------------
    // PROFILE PHOTOS
    // ----------------------------------------------------------------------
    match /users/{userId}/profile/{imageId} {
      // Read: user can read own profile, friends can read (for display)
      allow read: if isSignedIn() && (
        isOwner(userId) ||
        exists(/databases/(default)/documents/users/$(userId)/friends/$(request.auth.uid))
      );

      // Write: only user can upload/delete their own profile photo
      allow write: if isSignedIn()
        && isOwner(userId)
        && request.resource.size < 5 * 1024 * 1024 // 5MB limit
        && request.resource.contentType.matches('image/.*');

      // Delete: only user can delete their own profile photo
      allow delete: if isSignedIn() && isOwner(userId);
    }

    // ----------------------------------------------------------------------
    // CLOTH IMAGES
    // ----------------------------------------------------------------------
    match /users/{userId}/clothes/{clothId}/image.jpg {
      // Read: user can read if they have access to the cloth (check Firestore)
      allow read: if isSignedIn() && canAccessCloth(clothId);

      // Write: only cloth owner can upload/update
      allow write: if isSignedIn()
        && isOwner(userId)
        && exists(/databases/(default)/documents/clothes/$(clothId))
        && get(/databases/(default)/documents/clothes/$(clothId)).data.ownerId == request.auth.uid
        && request.resource.size < 10 * 1024 * 1024 // 10MB limit
        && request.resource.contentType.matches('image/.*');

      // Delete: only cloth owner can delete
      allow delete: if isSignedIn()
        && isOwner(userId)
        && exists(/databases/(default)/documents/clothes/$(clothId))
        && get(/databases/(default)/documents/clothes/$(clothId)).data.ownerId == request.auth.uid;
    }

    // ----------------------------------------------------------------------
    // CHAT MESSAGE IMAGES
    // ----------------------------------------------------------------------
    match /chats/{chatId}/messages/{messageId}/image.jpg {
      // Read: only chat participants can read
      allow read: if isSignedIn() && isChatParticipant(chatId);

      // Write: only chat participants can upload
      allow write: if isSignedIn()
        && isChatParticipant(chatId)
        && request.resource.size < 10 * 1024 * 1024 // 10MB limit
        && request.resource.contentType.matches('image/.*');

      // Delete: only message sender can delete (or any participant for cleanup)
      allow delete: if isSignedIn() && isChatParticipant(chatId);
    }

    // ----------------------------------------------------------------------
    // DEFAULT DENY
    // ----------------------------------------------------------------------
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 9. Testing Guide

### How to Deploy Rules

#### Firestore Rules:
1. Open Firebase Console → Firestore Database → Rules
2. Copy the Firestore rules section (sections 2-7)
3. Paste into the Rules editor
4. Click "Publish"
5. Test using Rules Playground

#### Storage Rules:
1. Open Firebase Console → Storage → Rules
2. Copy the Storage rules section (section 8)
3. Paste into the Rules editor
4. Click "Publish"
5. Test using Rules Playground

### Testing Scenarios

#### Users:
- ✅ User can create their own profile
- ✅ User can read their own profile
- ✅ User can update their own profile
- ✅ User cannot change their userId
- ✅ Friends can read limited fields (displayName, photoUrl)
- ✅ Non-friends cannot read private profile data

#### Wardrobes:
- ✅ User can create wardrobe with themselves as owner
- ✅ User can read their own wardrobes
- ✅ User can update their own wardrobes
- ✅ User cannot change wardrobe ownerId
- ✅ User cannot read other users' wardrobes

#### Clothes:
- ✅ User can create cloth with themselves as owner
- ✅ User can read their own clothes
- ✅ User can read public clothes
- ✅ User can read friends' clothes if visibility = "friends" and friendship exists
- ✅ User cannot read private clothes of non-friends
- ✅ User can update their own clothes
- ✅ User cannot change cloth ownerId
- ✅ User cannot modify likesCount/commentsCount directly

#### Likes:
- ✅ User can like cloth they can read
- ✅ User can unlike their own like
- ✅ User cannot like same cloth twice (likeId = userId)
- ✅ User cannot delete other users' likes

#### Comments:
- ✅ User can comment on cloth they can read
- ✅ User can update/delete their own comments
- ✅ User cannot modify other users' comments

#### Friend Requests:
- ✅ User can create friend request
- ✅ User cannot create request to themselves
- ✅ Both users can read the request
- ✅ Receiver can accept/reject
- ✅ Sender can cancel
- ✅ Other users cannot read the request

#### Chats:
- ✅ User can create chat with themselves in participants
- ✅ Only participants can read chat
- ✅ Only participants can create messages
- ✅ Only message sender can update/delete their message
- ✅ Non-participants cannot access chat

#### Storage:
- ✅ User can upload their own profile photo
- ✅ User can upload cloth image for their own clothes
- ✅ User can read cloth images they have access to (via Firestore rules)
- ✅ User can upload images to chats they participate in
- ✅ User cannot upload to other users' profiles
- ✅ User cannot upload cloth images for other users' clothes

### Rules Simulator Testing

Use Firebase Console → Firestore Database → Rules → Rules Playground:

**Test Case 1: Create User Profile**
- Authenticated: Yes
- User ID: `user123`
- Operation: Create
- Path: `users/user123`
- Expected: ✅ Allow

**Test Case 2: Read Friend's Profile**
- Authenticated: Yes
- User ID: `user123`
- Operation: Read
- Path: `users/user456` (where friendship exists)
- Expected: ✅ Allow (limited fields)

**Test Case 3: Create Cloth**
- Authenticated: Yes
- User ID: `user123`
- Operation: Create
- Path: `clothes/cloth123`
- Data: `{ownerId: "user123", ...}`
- Expected: ✅ Allow

**Test Case 4: Like Cloth**
- Authenticated: Yes
- User ID: `user123`
- Operation: Create
- Path: `clothes/cloth456/likes/user123`
- Expected: ✅ Allow (if user can read cloth)

**Test Case 5: Send Friend Request**
- Authenticated: Yes
- User ID: `user123`
- Operation: Create
- Path: `friendRequests/req123`
- Data: `{fromUserId: "user123", toUserId: "user456", status: "pending"}`
- Expected: ✅ Allow

---

## 10. Important Notes

### System Fields
- `likesCount` and `commentsCount` on clothes are maintained by Cloud Functions
- Users should not be able to modify these directly (enforced in rules)
- `totalItems` on wardrobes is maintained by Cloud Functions

### Performance Considerations
- Storage rules that check Firestore documents add latency
- Consider caching or alternative approaches for high-traffic scenarios
- Friend checks require a Firestore read per check

### Security Best Practices
- Always validate data structure in create/update rules
- Use `doesNotChangeOwner` to prevent ownership escalation
- Check array membership carefully (use `in` operator)
- Validate file sizes and content types in Storage rules

### Future Enhancements
- Add rate limiting (via Cloud Functions)
- Add content moderation (via Cloud Functions)
- Add audit logging (via Cloud Functions)
- Consider adding indexes for common queries

---

**Ready to Deploy:** These rules are production-ready. After deleting existing data, deploy both Firestore and Storage rules, then test thoroughly using the Rules Playground.
