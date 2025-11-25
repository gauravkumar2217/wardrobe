✅ WARDROBE APP — FEATURE BLUEPRINT (v4)
Firebase & Google Cloud Only Architecture

(Updated with comprehensive push notifications + Firebase Storage rules)

---

## 1. CLOTH CARD — FINAL DESIGN

Each cloth card (full screen, swipe up/down like Reels) includes:

### Top Section
- Fullscreen cloth image
- Transparent top icons:
  - Back
  - Edit (only on your clothes)

### Right Side Interaction Panel (vertical icon strip)
- ❤️ Like → **Push notification to owner**
- 💬 Comment → **Push notification to owner**
- 🔄 Share (only for your own clothes)
- 👕 Mark Worn Today

### Bottom Section (Information Panel)
- Season
- Placement
- Color tags
- Cloth type
- Category
- Occasions
- Wardrobe name
- Added date, worn history summary

All fields editable via Edit Icon (For your own cloth only)

---

## 2. SPECIAL RULES FOR SHARED CLOTH (FRIEND'S CLOTH)

When you receive a cloth from a friend:

### Allowed:
- ❤️ Like → **Push notification to cloth owner**
- 💬 Comment → **Push notification to cloth owner**
- 👀 View fullscreen (same as original view)

### NOT Allowed:
- 🚫 No Share
- 🚫 No Save to Wardrobe
- 🚫 No Edit
- 🚫 No Mark Worn
- 🚫 No re-share from DM
- 🚫 No copy/save image option

**Why?** This protects user privacy and keeps ownership of clothing items clear.

---

## 3. FRIEND'S DM — CLOTH BEHAVIOR

When clicking a cloth inside DM:

### Shows:
- FULLSCREEN cloth card
- Like → **Push notification to cloth owner**
- Comment → **Push notification to cloth owner**
- Swipe to close

### Hidden / Disabled:
- No share
- No save to wardrobe
- No options menu
- No mark worn
- No edit icon

This exactly replicates Instagram's "shared reel" behavior.

---

## 4. MARK WORN OPTION — FINAL LOGIC

When user presses Mark Worn Today:
- Store date in `clothes/{clothId}/wearHistory/{entryId}` collection
- Update `lastWornAt` field on cloth document
- Feed AI suggestion engine
- Help improve scheduled notifications
- Track usage patterns
- Enable "not worn recently" suggestions

**Button design:** A small T-Shirt icon (👕 or hanger icon) that changes to "Worn Today ✔" after tap.

**Push Notification:** None (this is a personal action, no need to notify others)

---

## 5. EDIT CLOTH INFO (FULL CONTROL)

Users can edit only their own clothes.

### Editable fields:
- Season
- Placement
- Color
- Cloth Type
- Category
- Occasions
- Wardrobe
- Image (replace/update in Firebase Storage)

### Not editable:
- Likes
- Comments
- Wear history timestamps
- Owner ID

**Push Notification:** None (personal action)

---

## 6. WARDROBE MANAGEMENT (IMPROVED)

### 6.1 Create Wardrobe
**Required:**
- Name
- Location

**Auto:**
- Total item count (dynamic, updated via Cloud Function or client)
- `createdAt` timestamp
- `ownerId` (from auth)

**Push Notification:** None (personal action)

### 6.2 Wardrobe List View
Each wardrobe card shows:
- Wardrobe Name
- Location
- Total Cloth Count
- Last updated time
- Tiny wardrobe icon

### 6.3 Clicking Wardrobe
Instead of opening a grid view:
- ➡ Redirect to Home Screen
- ➡ Apply Filter: Wardrobe = Selected Wardrobe
- ➡ Feed shows only that wardrobe's clothes
- ➡ Same swipe-up fullscreen experience

This gives a consistent browsing experience.

---

## 7. MORE POLISH & OPTIONAL PROFESSIONAL ADDITIONS

### 7.1 Wardrobe Stats (optional upgrade)
- Most worn clothes
- Least worn
- Seasonal distribution
- Category breakdown

### 7.2 Smart Wardrobe Suggestions
AI can suggest:
- "You haven't worn these 5 clothes in 60 days" → **Push notification (if enabled in settings)**
- "Trending colors in your wardrobe"
- "Recommended outfit combinations" (future upgrade) → **Push notification (if enabled)**

### 7.3 Privacy Controls
- Who can see your wardrobe
- Who can comment
- Block users → **Push notification to blocked user (optional)**
- Hide wardrobe from friends
- Turn off DM sharing from non-friends

---

## 8. USER SETTINGS (FINAL)

Under Profile → Settings:

- Edit profile
- Change password
- Verify phone & email
- **Notification settings** (granular controls):
  - Friend request notifications (on/off)
  - Friend accept notifications (on/off)
  - DM message notifications (on/off)
  - Cloth like notifications (on/off)
  - Cloth comment notifications (on/off)
  - Suggestion notifications (on/off)
  - Quiet hours (time range)
- Scheduled notifications
- Privacy Policy
- Terms & Conditions
- About
- Logout
- Delete Account
  - OTP confirmation
  - 30-day recovery option

---

## 9. SUMMARY — FULL FLOW

1. **User installs app → Authentication**
   - If new → Profile Setup
   - If existing → Open Home
   - **FCM token registered** → Stored in `users/{userId}/devices/{deviceId}`

2. **HOME = Swipe full-screen cloth cards**
   - Each card: Like, Comment, Share, Mark Worn
   - **Like/Comment actions trigger push notifications to cloth owner**

3. **DM Shared Clothes:**
   - Like, Comment only → **Push notifications to cloth owner**
   - No share, no save, no edit

4. **Wardrobe = List → Selecting wardrobe applies filter on Home**

5. **Chat = DM + shared cloth fullscreen**
   - **New messages trigger push notifications to other participants**

6. **Friends = Search, requests, list**
   - **Friend requests trigger push notifications**
   - **Friend accept triggers push notification to requester**

7. **Profile = Info + settings**

---

## 10. FIREBASE & GOOGLE CLOUD ARCHITECTURE (NO CUSTOM SERVER)

### 10.1 Core Services Used

#### **Firebase Services:**
- **Firebase Auth**: Email/password, phone, Google Sign-In
- **Cloud Firestore**: Main app database (all collections)
- **Firebase Storage**: Cloth images, profile photos, media files
- **Firebase Cloud Messaging (FCM)**: Push notifications to devices
- **Firebase Cloud Functions**: **REQUIRED** - Serverless logic for:
  - Sending push notifications (all cross-user events)
  - Maintaining aggregate counts (likesCount, commentsCount, totalItems)
  - Scheduled tasks (daily suggestions)
  - Data validation and business rules
- **Firebase App Check**: Security against abuse
- **Firebase Analytics**: User behavior tracking

#### **Google Cloud Services (via Firebase):**
- **Cloud Storage Bucket**: `wordrobe-chat.firebasestorage.app` (managed by Firebase Storage)
- **Cloud Scheduler**: For scheduled Cloud Functions (daily suggestions)

**No traditional web server needed** - Everything runs on Firebase/Google Cloud serverless infrastructure.

---

### 10.2 Firestore Collections & Documents Structure

#### **`config/tagLists`** (Dynamic Tag Lists - No App Update Required)
**Purpose:** Centralized tag lists that can be updated without app releases.

**Fields:**
- `seasons` (array of strings): ["Summer", "Winter", "Rainy", "All Season", "Spring", "Fall", etc.]
- `placements` (array of strings): ["InWardrobe", "DryCleaning", "Repairing", "Laundry", "Storage", etc.]
- `clothTypes` (array of strings): ["Saree", "Kurta", "Blazer", "Jeans", "Suit", "Shirt", "Lehenga", etc.] - Western and Indian combination
- `occasions` (array of strings): ["Diwali", "Eid", "Baisakhi", "Holi", "Onam", "Christmas", "Wedding", etc.] - Western and Indian occasions
- `categories` (array of strings): ["Ethnic", "Western", "Office", "Casual", "Festive", "Wedding", "Sports", "Party", "Travel", etc.]
- `commonColors` (array of strings): ["Red", "Blue", "Green", "Black", "White", etc.] - Reference for AI color detection
- `lastUpdated` (timestamp)
- `version` (number) - Increment when tags are updated

**Access:** 
- **Read:** All authenticated users (public read for app functionality)
- **Write:** Admin only (configure specific user IDs in rules or use custom claims)

**Usage:**
- App fetches this document on startup or when needed
- All tag dropdowns/pickers use values from this document
- No app update required to add/remove/modify tags
- AI color detection can use `commonColors` as reference
- User can manually override AI-detected values

**Initial Setup:**
Create this document in Firestore Console with your initial tag lists. See sample data structure below.

**Sample Initial Data Structure:**
```json
{
  "seasons": [
    "Summer",
    "Winter",
    "Rainy",
    "All Season",
    "Spring",
    "Fall",
    "Monsoon"
  ],
  "placements": [
    "InWardrobe",
    "DryCleaning",
    "Repairing",
    "Laundry",
    "Storage",
    "Donated",
    "Sold",
    "Lent"
  ],
  "clothTypes": [
    "Saree",
    "Kurta",
    "Lehenga",
    "Anarkali",
    "Sherwani",
    "Dhoti",
    "Kurta Pajama",
    "Blazer",
    "Jeans",
    "Suit",
    "Shirt",
    "T-Shirt",
    "Dress",
    "Pants",
    "Skirt",
    "Shorts",
    "Jacket",
    "Coat",
    "Sweater",
    "Blouse",
    "Top",
    "Trouser",
    "Jumpsuit",
    "Palazzo",
    "Churidar",
    "Salwar",
    "Dupatta",
    "Waistcoat"
  ],
  "occasions": [
    "Diwali",
    "Eid",
    "Baisakhi",
    "Holi",
    "Onam",
    "Pongal",
    "Durga Puja",
    "Navratri",
    "Raksha Bandhan",
    "Karva Chauth",
    "Christmas",
    "New Year",
    "Easter",
    "Thanksgiving",
    "Valentine's Day",
    "Wedding",
    "Birthday",
    "Anniversary",
    "Engagement",
    "Reception",
    "Casual",
    "Formal",
    "Party",
    "Office",
    "Travel",
    "Sports",
    "Gym",
    "Beach",
    "Dinner",
    "Lunch",
    "Brunch",
    "Cocktail",
    "Festival",
    "Religious",
    "Cultural"
  ],
  "categories": [
    "Ethnic",
    "Western",
    "Office",
    "Casual",
    "Festive",
    "Wedding",
    "Sports",
    "Nighty",
    "Party",
    "Travel",
    "Formal",
    "Traditional",
    "Contemporary",
    "Fusion",
    "Vintage",
    "Designer",
    "Streetwear",
    "Athletic",
    "Beachwear",
    "Loungewear"
  ],
  "commonColors": [
    "Red",
    "Blue",
    "Green",
    "Black",
    "White",
    "Yellow",
    "Pink",
    "Orange",
    "Purple",
    "Brown",
    "Grey",
    "Navy",
    "Maroon",
    "Beige",
    "Cream",
    "Gold",
    "Silver",
    "Turquoise",
    "Coral",
    "Lavender",
    "Teal",
    "Burgundy",
    "Magenta",
    "Cyan",
    "Olive",
    "Khaki",
    "Indigo",
    "Violet",
    "Peach",
    "Mint"
  ],
  "lastUpdated": "2024-01-01T00:00:00Z",
  "version": 1
}
```

**How to Update Tag Lists:**
1. Open Firebase Console → Firestore Database
2. Navigate to `config/tagLists` document
3. Edit the arrays (add/remove items)
4. Update `lastUpdated` timestamp
5. Increment `version` number
6. Save changes
7. App will fetch updated lists on next startup or when cache expires

**App Implementation:**
- Fetch `config/tagLists` on app startup
- Cache locally for offline access
- Listen for changes (optional) or refresh periodically
- Use arrays for all tag pickers/dropdowns
- Validate user selections against fetched lists (client-side)

---

#### **`users/{userId}`**
**Fields:**
- `displayName` (string)
- `photoUrl` (string, Firebase Storage URL)
- `email` (string)
- `phone` (string, optional)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)
- `settings` (map):
  - `notifications` (map):
    - `friendRequests` (boolean)
    - `friendAccepts` (boolean)
    - `dmMessages` (boolean)
    - `clothLikes` (boolean)
    - `clothComments` (boolean)
    - `suggestions` (boolean)
    - `quietHoursStart` (string, e.g., "22:00")
    - `quietHoursEnd` (string, e.g., "08:00")
  - `privacy` (map):
    - `profileVisibility` (string: "public", "friends", "private")
    - `wardrobeVisibility` (string: "public", "friends", "private")
    - `allowDmFromNonFriends` (boolean)

**Access:** User can read/write own profile. Limited fields (`displayName`, `photoUrl`) readable by friends.

**Subcollections:**
- `users/{userId}/friends/{friendId}` - Friend relationships
- `users/{userId}/notifications/{notificationId}` - In-app notifications
- `users/{userId}/devices/{deviceId}` - FCM tokens per device

---

#### **`wardrobes/{wardrobeId}`**
**Fields:**
- `ownerId` (string, required)
- `name` (string, required)
- `location` (string, required)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)
- `totalItems` (number, maintained by Cloud Function)

**Access:** Only `ownerId` can create/update/delete. Readable by owner (and friends only if visibility allows).

**Cloud Function:** Updates `totalItems` when clothes are added/removed.

---

#### **`config/tagLists`** (Dynamic Tag Lists - No App Update Required)
**Fields:**
- `seasons` (array of strings): ["Summer", "Winter", "Rainy", "All Season", "Spring", "Fall", etc.]
- `placements` (array of strings): ["InWardrobe", "DryCleaning", "Repairing", "Laundry", "Storage", etc.]
- `clothTypes` (array of strings): ["Saree", "Kurta", "Blazer", "Jeans", "Suit", "Shirt", "Lehenga", "Dress", "T-Shirt", "Pants", "Skirt", "Jacket", etc.] - Western and Indian combination
- `occasions` (array of strings): ["Diwali", "Eid", "Baisakhi", "Holi", "Onam", "Christmas", "New Year", "Wedding", "Birthday", "Casual", "Formal", "Party", etc.] - Western and Indian occasions
- `categories` (array of strings): ["Ethnic", "Western", "Office", "Casual", "Festive", "Wedding", "Sports", "Nighty", "Party", "Travel", "Formal", "Traditional", etc.]
- `commonColors` (array of strings): ["Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Orange", "Purple", "Brown", "Grey", "Navy", "Maroon", etc.] - Reference list for AI color detection
- `lastUpdated` (timestamp)
- `version` (number) - Increment when tags are updated

**Access:** 
- **Read:** All authenticated users can read (public read for app functionality)
- **Write:** Admin only (you can set specific user IDs or use a custom claim)

**Usage:**
- App fetches this document on startup or when needed
- All tag dropdowns/pickers use values from this document
- No app update required to add/remove/modify tags
- AI color detection can use `commonColors` as reference
- User can manually override AI-detected values

**Initial Data Structure:**
```json
{
  "seasons": ["Summer", "Winter", "Rainy", "All Season", "Spring", "Fall"],
  "placements": ["InWardrobe", "DryCleaning", "Repairing", "Laundry", "Storage", "Donated", "Sold"],
  "clothTypes": [
    "Saree", "Kurta", "Lehenga", "Anarkali", "Sherwani", "Dhoti", "Kurta Pajama",
    "Blazer", "Jeans", "Suit", "Shirt", "T-Shirt", "Dress", "Pants", "Skirt", 
    "Shorts", "Jacket", "Coat", "Sweater", "Blouse", "Top", "Trouser", "Jumpsuit"
  ],
  "occasions": [
    "Diwali", "Eid", "Baisakhi", "Holi", "Onam", "Pongal", "Durga Puja", "Navratri",
    "Christmas", "New Year", "Easter", "Thanksgiving", "Valentine's Day",
    "Wedding", "Birthday", "Anniversary", "Engagement", "Reception",
    "Casual", "Formal", "Party", "Office", "Travel", "Sports", "Gym", "Beach"
  ],
  "categories": [
    "Ethnic", "Western", "Office", "Casual", "Festive", "Wedding", "Sports", 
    "Nighty", "Party", "Travel", "Formal", "Traditional", "Contemporary", 
    "Fusion", "Vintage", "Designer"
  ],
  "commonColors": [
    "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Orange", 
    "Purple", "Brown", "Grey", "Navy", "Maroon", "Beige", "Cream", "Gold", 
    "Silver", "Turquoise", "Coral", "Lavender", "Teal", "Burgundy"
  ],
  "lastUpdated": "2024-01-01T00:00:00Z",
  "version": 1
}
```

---

#### **`clothes/{clothId}`**
**Fields:**
- `ownerId` (string, required)
- `wardrobeId` (string, required)
- `imageUrl` (string, Firebase Storage URL)
- `season` (string) - **Must be from `config/tagLists.seasons`**
- `placement` (string) - **Must be from `config/tagLists.placements`**
- `colorTags` (map):
  - `primary` (string) - Primary color detected by AI or set by user
  - `secondary` (string, optional) - Secondary color if multi-color
  - `colors` (array of strings) - All colors detected (for multi-color items)
  - `isMultiColor` (boolean) - True if item has multiple colors
- `clothType` (string) - **Must be from `config/tagLists.clothTypes`**
- `category` (string) - **Must be from `config/tagLists.categories`**
- `occasions` (array of strings) - **Each must be from `config/tagLists.occasions`** (multiple allowed)
- `aiDetected` (map, optional):
  - `clothType` (string) - AI-detected cloth type
  - `colors` (array of strings) - AI-detected colors
  - `confidence` (number) - AI confidence score (0-1)
  - `detectedAt` (timestamp)
- `createdAt` (timestamp)
- `updatedAt` (timestamp)
- `lastWornAt` (timestamp, optional)
- `visibility` (string: "private", "friends", "public")
- `sharedWith` (array of user IDs, optional)
- `likesCount` (number, maintained by Cloud Function)
- `commentsCount` (number, maintained by Cloud Function)

**Access:**
- Owner: full read/write (except system fields like `likesCount`, `commentsCount`)
- Friends: can read if `visibility == "friends"` AND friendship exists
- Public: can read if `visibility == "public"`
- Shared: can read if `uid` in `sharedWith` array
- No one except owner can edit or mark worn

**Subcollections:**
- `clothes/{clothId}/wearHistory/{entryId}` - Wear tracking
- `clothes/{clothId}/likes/{likeId}` - Likes (likeId = userId)
- `clothes/{clothId}/comments/{commentId}` - Comments

**Cloud Functions:**
- On like create/delete → Update `likesCount` → **Send push notification to owner**
- On comment create → Update `commentsCount` → **Send push notification to owner**

---

#### **`clothes/{clothId}/wearHistory/{entryId}`**
**Fields:**
- `userId` (string, must match cloth `ownerId`)
- `wornAt` (timestamp)
- `source` (string: "manual", "scheduledSuggestion")

**Access:** Only owner can create (Mark Worn) and read their own history.

**Cloud Function:** Updates `lastWornAt` on parent cloth document.

---

#### **`clothes/{clothId}/likes/{likeId}`**
**Fields:**
- `userId` (string, required)
- `createdAt` (timestamp)

**Pattern:** `likeId = userId` (prevents duplicates)

**Access:** Any authenticated user who can see the cloth can like/unlike.

**Cloud Function Trigger:**
- On create → **Send push notification to cloth owner** (if enabled in settings)
- On create/delete → Update `likesCount` on parent cloth

---

#### **`clothes/{clothId}/comments/{commentId}`**
**Fields:**
- `userId` (string, required)
- `text` (string, required)
- `createdAt` (timestamp)
- `updatedAt` (timestamp, optional)

**Access:** Any authenticated user who can see the cloth can comment. Only author can edit/delete their own comments.

**Cloud Function Trigger:**
- On create → **Send push notification to cloth owner** (if enabled in settings)
- On create → Update `commentsCount` on parent cloth

---

#### **`friendRequests/{requestId}`**
**Fields:**
- `fromUserId` (string, required)
- `toUserId` (string, required)
- `status` (string: "pending", "accepted", "rejected", "canceled")
- `createdAt` (timestamp)
- `updatedAt` (timestamp)

**Access:**
- Only `fromUserId` and `toUserId` can read the request
- Only `fromUserId` can create or cancel
- Only `toUserId` can accept/reject

**Cloud Function Triggers:**
- On create (status = "pending") → **Send push notification to `toUserId`** (if enabled)
- On update (status: "pending" → "accepted") → **Send push notification to `fromUserId`** (if enabled)
- On update (status: "pending" → "accepted") → Create friend documents in both users' friends subcollections

---

#### **`users/{userId}/friends/{friendId}`**
**Fields:**
- `friendId` (string, required)
- `createdAt` (timestamp)

**Access:** Each user can read/write only their own friends list.

**Cloud Function:** Created automatically when friend request is accepted.

---

#### **`chats/{chatId}`**
**Fields:**
- `participants` (array of user IDs, required, min 2)
- `lastMessage` (string, optional)
- `lastMessageAt` (timestamp, optional)
- `isGroup` (boolean, default false)
- `createdAt` (timestamp)

**Access:** Only users in `participants` can read/update this chat.

**Subcollections:**
- `chats/{chatId}/messages/{messageId}` - Chat messages

**Cloud Function:** Updates `lastMessage` and `lastMessageAt` when new message is created.

---

#### **`chats/{chatId}/messages/{messageId}`**
**Fields:**
- `senderId` (string, required)
- `text` (string, optional)
- `imageUrl` (string, optional, Firebase Storage URL)
- `clothId` (string, optional, when sharing a cloth)
- `createdAt` (timestamp)
- `seenBy` (array of user IDs)

**Access:** Only users in `participants` (from parent chat) can read/write messages.

**Cloud Function Trigger:**
- On create → **Send push notification to all participants except `senderId`** (if enabled in settings)
- On create → Update `lastMessage` and `lastMessageAt` on parent chat

---

#### **`users/{userId}/notifications/{notificationId}`**
**Fields:**
- `type` (string: "friend_request", "friend_accept", "dm_message", "cloth_like", "cloth_comment", "suggestion")
- `title` (string)
- `body` (string)
- `data` (map, contains relevant IDs like `clothId`, `chatId`, `userId`)
- `createdAt` (timestamp)
- `read` (boolean, default false)

**Access:** Only owner user can read/write their notification docs.

**Cloud Function:** Creates notification document when sending push notification.

---

#### **`users/{userId}/devices/{deviceId}`**
**Fields:**
- `fcmToken` (string, required)
- `platform` (string: "android", "ios", "web")
- `deviceName` (string, optional)
- `isActive` (boolean, default true)
- `lastActiveAt` (timestamp)
- `createdAt` (timestamp)

**Access:** Only owner user can read/write their device tokens.

**Client:** Updates `lastActiveAt` on app foreground. Sets `isActive = false` on logout.

---

### 10.3 Firebase Storage Structure

**Bucket:** `wordrobe-chat.firebasestorage.app`

**Paths:**
- `users/{userId}/profile/{imageId}.jpg` - Profile photos
- `users/{userId}/clothes/{clothId}/image.jpg` - Cloth images
- `chats/{chatId}/messages/{messageId}/image.jpg` - Chat images

**Storage Rules:** See `firebase-database-rule.md` for complete Storage security rules.

**Access:**
- Users can upload/delete their own profile photos
- Users can upload/delete their own cloth images
- Users can upload images to chats they participate in
- Users can read images for clothes they have access to (based on Firestore visibility rules)

---

### 10.4 Cloud Functions Required

#### **Function 1: `onFriendRequestCreate`**
**Trigger:** Firestore `friendRequests/{requestId}` onCreate
**Actions:**
1. Validate request (no duplicate, not self-request)
2. Get `toUserId` settings
3. Check if notifications enabled for friend requests
4. Get FCM tokens from `users/{toUserId}/devices` (where `isActive = true`)
5. Get `fromUserId` displayName
6. **Send push notification** to all active devices
7. Create notification document in `users/{toUserId}/notifications`

---

#### **Function 2: `onFriendRequestUpdate`**
**Trigger:** Firestore `friendRequests/{requestId}` onUpdate
**Actions:**
1. Check if status changed from "pending" → "accepted"
2. If accepted:
   - Create `users/{fromUserId}/friends/{toUserId}`
   - Create `users/{toUserId}/friends/{fromUserId}`
   - Get `fromUserId` settings
   - Check if notifications enabled for friend accepts
   - Get FCM tokens from `users/{fromUserId}/devices`
   - Get `toUserId` displayName
   - **Send push notification** to requester
   - Create notification document in `users/{fromUserId}/notifications`

---

#### **Function 3: `onClothLikeCreate`**
**Trigger:** Firestore `clothes/{clothId}/likes/{likeId}` onCreate
**Actions:**
1. Get cloth document to find `ownerId`
2. If `ownerId != userId` (don't notify self-likes):
   - Get `ownerId` settings
   - Check if notifications enabled for cloth likes
   - Get FCM tokens from `users/{ownerId}/devices`
   - Get liker's displayName
   - **Send push notification** to cloth owner
   - Create notification document
3. Update `clothes/{clothId}.likesCount` (increment)

---

#### **Function 4: `onClothLikeDelete`**
**Trigger:** Firestore `clothes/{clothId}/likes/{likeId}` onDelete
**Actions:**
1. Update `clothes/{clothId}.likesCount` (decrement)

---

#### **Function 5: `onClothCommentCreate`**
**Trigger:** Firestore `clothes/{clothId}/comments/{commentId}` onCreate
**Actions:**
1. Get cloth document to find `ownerId`
2. If `ownerId != userId` (don't notify self-comments):
   - Get `ownerId` settings
   - Check if notifications enabled for cloth comments
   - Get FCM tokens from `users/{ownerId}/devices`
   - Get commenter's displayName
   - **Send push notification** to cloth owner
   - Create notification document
3. Update `clothes/{clothId}.commentsCount` (increment)

---

#### **Function 6: `onMessageCreate`**
**Trigger:** Firestore `chats/{chatId}/messages/{messageId}` onCreate
**Actions:**
1. Get chat document to find `participants`
2. For each participant except `senderId`:
   - Get user settings
   - Check if notifications enabled for DM messages
   - Check quiet hours (if enabled, skip if current time in quiet hours)
   - Get FCM tokens from `users/{participantId}/devices`
   - Get sender's displayName
   - **Send push notification** to participant
   - Create notification document
3. Update `chats/{chatId}.lastMessage` and `lastMessageAt`

---

#### **Function 7: `onWearHistoryCreate`**
**Trigger:** Firestore `clothes/{clothId}/wearHistory/{entryId}` onCreate
**Actions:**
1. Update `clothes/{clothId}.lastWornAt` = entry `wornAt` timestamp

---

#### **Function 8: `onClothCreate`**
**Trigger:** Firestore `clothes/{clothId}` onCreate
**Actions:**
1. Increment `wardrobes/{wardrobeId}.totalItems`

---

#### **Function 9: `onClothDelete`**
**Trigger:** Firestore `clothes/{clothId}` onDelete
**Actions:**
1. Decrement `wardrobes/{wardrobeId}.totalItems`
2. Delete cloth image from Storage (if exists)

---

#### **Function 10: `dailySuggestionScheduler`**
**Trigger:** Cloud Scheduler (daily, configurable time)
**Actions:**
1. For each user:
   - Query clothes not worn in last 60 days (or configurable)
   - If found, create suggestion notification
   - If user has suggestions enabled, **send push notification**
   - Create notification document in `users/{userId}/notifications`

---

#### **Function 11: `validateClothTags`** (Optional - Client-side validation recommended)
**Trigger:** Firestore `clothes/{clothId}` onCreate/onUpdate
**Actions:**
1. Get `config/tagLists` document
2. Validate:
   - `season` exists in `tagLists.seasons`
   - `placement` exists in `tagLists.placements`
   - `clothType` exists in `tagLists.clothTypes`
   - `category` exists in `tagLists.categories`
   - All `occasions` exist in `tagLists.occasions`
3. If validation fails, reject the write or set to default values
4. Log validation errors for monitoring

**Note:** This function is optional. Client-side validation is recommended for better UX, but this provides server-side enforcement.

---

### 10.5 Auth & Identity Rules

- **All write operations require authentication**
- **User ID = Auth UID**: Documents owned by a user must store `ownerId == request.auth.uid`
- **Friendship-based access**: Friend-only content checks:
  - `visibility == "friends"` AND
  - Existence of `users/{ownerId}/friends/{request.auth.uid}`

**Full, concrete Firestore and Storage rules are in `firebase-database-rule.md`**

---

## 11. PUSH NOTIFICATION FLOW (COMPREHENSIVE)

### 11.1 Device Token Management

**On App Start / Login:**
1. App requests FCM token from Firebase Messaging SDK
2. Get device info (platform, device name)
3. Store/update in `users/{userId}/devices/{deviceId}`:
   - `fcmToken` = token
   - `platform` = "android" | "ios" | "web"
   - `deviceName` = device identifier
   - `isActive` = true
   - `lastActiveAt` = now
   - `createdAt` = now (if new device)

**On App Foreground:**
- Update `lastActiveAt` = now
- Ensure `isActive` = true

**On Logout:**
- Set `isActive` = false for current device
- Optionally delete device document (or keep for re-login)

**Token Refresh:**
- FCM tokens can refresh automatically
- Listen to `onTokenRefresh` and update device document

---

### 11.2 Push Notification Events (Complete List)

#### **1. Friend Request Sent** 🔔
- **Trigger:** `friendRequests/{requestId}` created with `status = "pending"`
- **Recipient:** `toUserId`
- **Notification:**
  - Title: "New Friend Request"
  - Body: "{fromUserName} wants to be your friend"
  - Data: `{type: "friend_request", fromUserId: "...", requestId: "..."}`
- **Settings Check:** `users/{toUserId}.settings.notifications.friendRequests`
- **Cloud Function:** `onFriendRequestCreate`

---

#### **2. Friend Request Accepted** 🔔
- **Trigger:** `friendRequests/{requestId}` updated: `status: "pending" → "accepted"`
- **Recipient:** `fromUserId` (the person who sent the request)
- **Notification:**
  - Title: "Friend Request Accepted"
  - Body: "{toUserName} accepted your friend request"
  - Data: `{type: "friend_accept", toUserId: "...", requestId: "..."}`
- **Settings Check:** `users/{fromUserId}.settings.notifications.friendAccepts`
- **Cloud Function:** `onFriendRequestUpdate`
- **Additional Action:** Creates friend documents in both users' friends subcollections

---

#### **3. New DM Message** 🔔
- **Trigger:** `chats/{chatId}/messages/{messageId}` created
- **Recipients:** All `participants` except `senderId`
- **Notification:**
  - Title: "New Message"
  - Body: "{senderName}: {messagePreview}" (first 50 chars)
  - Data: `{type: "dm_message", chatId: "...", senderId: "...", messageId: "..."}`
- **Settings Check:** `users/{participantId}.settings.notifications.dmMessages`
- **Quiet Hours:** Skip if current time is within quiet hours range
- **Cloud Function:** `onMessageCreate`

---

#### **4. Like on Your Cloth** 🔔
- **Trigger:** `clothes/{clothId}/likes/{likeId}` created
- **Recipient:** Cloth `ownerId` (only if `ownerId != liker's userId`)
- **Notification:**
  - Title: "New Like"
  - Body: "{userName} liked your cloth"
  - Data: `{type: "cloth_like", clothId: "...", userId: "...", likeId: "..."}`
- **Settings Check:** `users/{ownerId}.settings.notifications.clothLikes`
- **Cloud Function:** `onClothLikeCreate`
- **Additional Action:** Updates `clothes/{clothId}.likesCount`

---

#### **5. Comment on Your Cloth** 🔔
- **Trigger:** `clothes/{clothId}/comments/{commentId}` created
- **Recipient:** Cloth `ownerId` (only if `ownerId != commenter's userId`)
- **Notification:**
  - Title: "New Comment"
  - Body: "{userName} commented on your cloth: {commentPreview}"
  - Data: `{type: "cloth_comment", clothId: "...", userId: "...", commentId: "..."}`
- **Settings Check:** `users/{ownerId}.settings.notifications.clothComments`
- **Cloud Function:** `onClothCommentCreate`
- **Additional Action:** Updates `clothes/{clothId}.commentsCount`

---

#### **6. Scheduled Suggestions** 🔔
- **Trigger:** Cloud Scheduler (daily, configurable time per user)
- **Recipient:** User who has unworn clothes
- **Notification:**
  - Title: "Wardrobe Suggestion"
  - Body: "You haven't worn {count} items in a while. Check them out!"
  - Data: `{type: "suggestion", clothIds: [...]}`
- **Settings Check:** `users/{userId}.settings.notifications.suggestions`
- **Cloud Function:** `dailySuggestionScheduler`

---

### 11.3 Notification Settings Structure

Each user has granular control in `users/{userId}.settings.notifications`:

```json
{
  "notifications": {
    "friendRequests": true,
    "friendAccepts": true,
    "dmMessages": true,
    "clothLikes": true,
    "clothComments": true,
    "suggestions": true,
    "quietHoursStart": "22:00",
    "quietHoursEnd": "08:00"
  }
}
```

**Cloud Functions check these settings before sending push notifications.**

---

### 11.4 Push Notification Implementation Details

#### **Client-Side (Flutter):**
- Use `firebase_messaging` package
- Handle foreground messages (show in-app banner)
- Handle background messages (system notification)
- Handle notification taps (deep link to relevant screen)
- Update notification badge count

#### **Server-Side (Cloud Functions):**
- Use `firebase-admin` SDK
- Get FCM tokens from `users/{userId}/devices` where `isActive = true`
- Check user notification settings
- Check quiet hours
- Send notification via FCM Admin API
- Create notification document in Firestore
- Handle errors (invalid tokens, etc.)

#### **No Direct Client-to-Client Push:**
- Flutter app **never** sends notifications directly to other users
- All cross-user notifications go through **Cloud Functions**
- This keeps FCM tokens private and logic secure

---

### 11.5 In-App Notification Badge

- Show unread count badge on:
  - Friends tab (pending friend requests)
  - Chat tab (unread messages)
  - Profile/Notifications section (all unread notifications)
- Update badge when:
  - Push notification received
  - User opens relevant screen
  - User marks notification as read

---

## 12. PRIVACY & SECURITY OVERVIEW

### 12.1 Authentication
- **All operations require authentication** (except public profile viewing if enabled)
- **User ID = Auth UID** for ownership validation
- **Firebase App Check** enabled for additional security

### 12.2 Data Access Rules
- **Users can only modify their own data** (profile, wardrobes, clothes, wear history, friend list, FCM tokens)
- **Friends-only access** enforced in:
  - Firestore rules (check friendship existence)
  - UI (hide buttons where not allowed)
- **DMs are strictly private** to `participants` only
- **Storage access** controlled by Firestore rules (read cloth document to check access)

### 12.3 Push Notification Privacy
- **FCM tokens are private** - only stored in user's own devices subcollection
- **Notification content** limited to safe info:
  - Display names only (no emails, phone numbers)
  - Message previews (first 50 chars)
  - No sensitive data in notification payload
- **User controls** - granular settings for each notification type
- **Quiet hours** - respect user's sleep schedule

### 12.4 Storage Security
- **Profile photos:** Only user can upload/delete their own
- **Cloth images:** Only owner can upload/delete, but readable based on cloth visibility rules
- **Chat images:** Only participants can upload to their chats

---

## 12.5 Tag List Management

### Admin Access Setup
To manage tag lists, you need admin access. Two options:

**Option 1: Specific User IDs (Simple)**
- Add your user ID(s) to Firebase Rules in `config/tagLists` write rule
- Replace `'YOUR_ADMIN_USER_ID_1'` with your actual Firebase Auth UID
- Find your UID in Firebase Console → Authentication → Users

**Option 2: Custom Claims (Recommended for Production)**
- Create a Cloud Function to set custom claim `admin: true` for admin users
- Update Firebase Rules to check `request.auth.token.admin == true`
- More secure and scalable

### Adding/Removing Tags
1. **Via Firebase Console:**
   - Open Firestore Database
   - Navigate to `config/tagLists`
   - Edit arrays directly
   - Update `lastUpdated` and `version`
   - Save

2. **Via Cloud Function (Future Enhancement):**
   - Create admin panel function
   - Validate tag additions
   - Maintain version history
   - Send notifications to app users (optional)

### Best Practices
- **Version Control:** Always increment `version` when updating
- **Backward Compatibility:** Don't remove tags that are in use (mark as deprecated instead)
- **Validation:** Validate new tags before adding (no duplicates, proper formatting)
- **Testing:** Test tag updates in staging before production
- **Documentation:** Document tag meanings if needed

---

## 13. IMPLEMENTATION CHECKLIST

### Phase 1: Core Setup
- [ ] Firebase project configured (`wordrobe-chat`)
- [ ] Firestore database created
- [ ] Storage bucket configured (`wordrobe-chat.firebasestorage.app`)
- [ ] Firestore rules deployed (from `firebase-database-rule.md`)
- [ ] Storage rules deployed (from `firebase-database-rule.md`)
- [ ] **Create `config/tagLists` document** with initial tag lists (see section 10.2.1)
- [ ] Cloud Functions project initialized
- [ ] FCM configured in Firebase Console

### Phase 2: Authentication & User Management
- [ ] Email/password auth implemented
- [ ] Google Sign-In implemented
- [ ] Phone auth implemented (optional)
- [ ] User profile creation/update
- [ ] FCM token registration on login
- [ ] Device management (register/unregister)

### Phase 3: Wardrobes & Clothes
- [ ] **Fetch tag lists from `config/tagLists` on app startup**
- [ ] **Implement tag pickers using dynamic lists (not hardcoded)**
- [ ] Wardrobe CRUD operations
- [ ] Cloth CRUD operations
- [ ] Image upload to Storage
- [ ] **AI color detection with manual override option**
- [ ] **AI cloth type detection with manual override option**
- [ ] Cloth visibility settings
- [ ] Wear history tracking
- [ ] Cloud Functions for aggregate counts

### Phase 4: Social Features
- [ ] Friend request system
- [ ] Friends list management
- [ ] Cloth sharing in DMs
- [ ] Like/Comment system
- [ ] Cloud Functions for friend request notifications
- [ ] Cloud Functions for like/comment notifications

### Phase 5: Messaging
- [ ] Chat creation
- [ ] Message sending (text, image, cloth)
- [ ] Real-time message updates
- [ ] Cloud Functions for message notifications
- [ ] Read receipts (seenBy)

### Phase 6: Notifications
- [ ] Notification settings UI
- [ ] All Cloud Functions for push notifications
- [ ] In-app notification center
- [ ] Notification badge counts
- [ ] Deep linking from notifications

### Phase 7: Suggestions & AI
- [ ] Daily suggestion Cloud Function
- [ ] Cloud Scheduler setup
- [ ] Suggestion notifications
- [ ] AI integration (future)

---

## 14. CLOUD FUNCTIONS DEPLOYMENT

### Setup Instructions:
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Initialize Functions: `firebase init functions`
4. Choose TypeScript or JavaScript
5. Install dependencies: `cd functions && npm install`
6. Deploy: `firebase deploy --only functions`

### Required Functions (in order of priority):
1. `onFriendRequestCreate` - Friend request notifications
2. `onFriendRequestUpdate` - Friend accept notifications + friend creation
3. `onClothLikeCreate` - Like notifications + count update
4. `onClothCommentCreate` - Comment notifications + count update
5. `onMessageCreate` - DM notifications
6. `onWearHistoryCreate` - Update lastWornAt
7. `onClothCreate` - Update wardrobe totalItems
8. `onClothDelete` - Update wardrobe totalItems + delete storage
9. `dailySuggestionScheduler` - Daily suggestions

### Environment Variables:
- None required (uses Firebase Admin SDK with default credentials)

---

## 15. TESTING CHECKLIST

### Push Notifications:
- [ ] Friend request sent → notification received
- [ ] Friend request accepted → notification received
- [ ] Like on cloth → notification received (not for self-likes)
- [ ] Comment on cloth → notification received (not for self-comments)
- [ ] DM message → notification received
- [ ] Quiet hours respected (no notifications during quiet hours)
- [ ] Notification settings respected (disabled types don't send)
- [ ] Deep linking works (tap notification → opens relevant screen)

### Security:
- [ ] Users can't access other users' private data
- [ ] Friends-only clothes visible only to friends
- [ ] DMs private to participants only
- [ ] Storage access controlled by Firestore rules
- [ ] Users can't modify aggregate counts directly

### Cloud Functions:
- [ ] All triggers fire correctly
- [ ] Aggregate counts update correctly
- [ ] Friend documents created on accept
- [ ] Storage cleanup on cloth delete
- [ ] Daily scheduler runs correctly

---

**For implementation details, see `firebase-database-rule.md` for complete Firestore and Storage security rules.**
