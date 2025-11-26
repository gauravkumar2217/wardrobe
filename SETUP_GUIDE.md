# Firebase Console Setup Guide

This guide provides step-by-step instructions to set up your Firebase project for the Wardrobe app.

## Prerequisites

- Firebase project created
- Flutter app configured with `firebase_options.dart`
- Firebase CLI installed (optional, for deploying rules)

## 1. Enable Authentication Providers

### Phone Authentication
1. Go to Firebase Console > Authentication > Sign-in method
2. Enable **Phone** provider
3. Configure reCAPTCHA settings if needed

### Google Sign-In
1. Go to Firebase Console > Authentication > Sign-in method
2. Enable **Google** provider
3. Add SHA-1 fingerprints (see below)
4. Download updated `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)

### Email/Password Authentication
1. Go to Firebase Console > Authentication > Sign-in method
2. Enable **Email/Password** provider

## 2. Add SHA-1 Fingerprints (Android)

1. Get your SHA-1 fingerprint:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Look for SHA1 under both `debug` and `release` variants.

2. Add to Firebase Console:
   - Go to Project Settings > Your apps > Android app
   - Under "SHA certificate fingerprints", click "Add fingerprint"
   - Add both debug and release SHA-1 fingerprints

3. Download updated `google-services.json` and replace the existing file.

## 3. Deploy Firestore Rules

1. Copy the contents of `firestore.rules`
2. Go to Firebase Console > Firestore Database > Rules
3. Paste the rules and click "Publish"

Or use Firebase CLI:
```bash
firebase deploy --only firestore:rules
```

## 4. Deploy Storage Rules

1. Copy the contents of `storage.rules`
2. Go to Firebase Console > Storage > Rules
3. Paste the rules and click "Publish"

Or use Firebase CLI:
```bash
firebase deploy --only storage
```

## 5. Create Initial Tag Lists Document

1. Go to Firebase Console > Firestore Database > Data
2. Create a new collection: `config`
3. Create a document with ID: `tagLists`
4. Add the following fields:
   - `seasons` (array): ["Summer", "Winter", "Rainy", "All Season", "Spring", "Fall"]
   - `placements` (array): ["InWardrobe", "DryCleaning", "Repairing", "Laundry", "Storage"]
   - `clothTypes` (array): ["Saree", "Kurta", "Blazer", "Jeans", "Suit", "Shirt", "T-Shirt", "Dress", "Pants", "Skirt", "Shorts", "Jacket", "Coat", "Sweater"]
   - `occasions` (array): ["Diwali", "Eid", "Christmas", "Wedding", "Birthday", "Casual", "Formal", "Party", "Office"]
   - `categories` (array): ["Ethnic", "Western", "Office", "Casual", "Festive", "Wedding", "Sports", "Party"]
   - `commonColors` (array): ["Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Orange", "Purple", "Brown", "Grey"]
   - `lastUpdated` (timestamp): Current timestamp
   - `version` (number): 1

## 6. Configure App Check

1. Go to Firebase Console > App Check
2. Register your app (if not already registered)
3. For debug builds:
   - Go to "Manage debug tokens"
   - Add debug tokens (printed in console when app runs)
4. For release builds:
   - Configure Play Integrity (Android) or App Attest (iOS)

## 7. Configure Cloud Messaging (FCM)

1. Go to Firebase Console > Cloud Messaging
2. Ensure Cloud Messaging API is enabled
3. Configure notification settings as needed

## 8. Set Up Cloud Functions (Optional)

Cloud Functions are required for:
- Updating aggregate counts (likesCount, commentsCount, totalItems)
- Sending push notifications for social interactions
- Managing friend relationships

See `POST_IMPLEMENTATION_ACTIONS.md` for Cloud Functions setup.

## 9. Update Admin User IDs in Firestore Rules

In `firestore.rules`, replace `YOUR_ADMIN_USER_ID_1` and `YOUR_ADMIN_USER_ID_2` with actual admin user IDs, or set up custom claims for admin users.

## Testing Checklist

- [ ] Phone authentication works
- [ ] Google Sign-In works
- [ ] Email/Password authentication works
- [ ] Firestore rules allow authenticated users to read/write their data
- [ ] Storage rules allow authenticated users to upload images
- [ ] Tag lists document exists and is readable
- [ ] App Check is configured (debug tokens added for testing)
- [ ] FCM tokens are registered on login

## Troubleshooting

- **Google Sign-In fails**: Ensure SHA-1 fingerprints are added and `google-services.json` is updated
- **Firestore permission denied**: Check that rules are deployed and user is authenticated
- **Storage upload fails**: Verify storage rules are deployed and user is authenticated
- **Tag lists not loading**: Ensure `config/tagLists` document exists with correct structure

