# High level goal (one sentence)

After login, show the user a Welcome screen that lists their wardrobes (max **2** for now). If they have none, show a **Create Wardrobe** flow (title, location/room, seasonal). After creating a wardrobe, take the user to **Add Cloth** flow (image + metadata). Later we’ll unlock more wardrobes via payments.

---

# Phase breakdown (start to finish)

Each phase contains: objective → screens & flows → Firestore schema → service/provider actions → validations → acceptance criteria.

---

## Phase 1 — Auth & Welcome + Wardrobe List (CORE)

**Objective:** After sign-in, land on Welcome screen that displays up to 2 wardrobes. Enforce limit.

### Screens / UI

1. `WelcomeScreen` (default after auth)

   * Header: greeting + profile
   * If user has wardrobes: show list (grid or list)
   * If none: show CTA “Create Wardrobe”
   * Button: “Create Wardrobe” (disabled if user has 2)
2. `WardrobeCard` (summary)

   * title, location/room, seasonal tag, cloth count, last modified
3. `CreateWardrobeButton` (floating / top-right)

### Firestore structure

```
/users/{userId}/wardrobes/{wardrobeId}
```

Wardrobe document:

```json
{
  "title": "Office Clothes",
  "location": "Master Bedroom",
  "season": "Summer",     // enum: Summer, Winter, All-season, etc.
  "createdAt": Timestamp,
  "updatedAt": Timestamp
}
```

### Services / Provider actions

* `WardrobeService.getUserWardrobes(userId)` → returns list (limit 2)
* `WardrobeService.createWardrobe(userId, data)` → checks count then creates
* `WardrobeProvider` exposes `List<Wardrobe>` and `loading` state

### Validation + Rules

* Client-side: title non-empty (min 2 chars), location optional but recommended, season selected.
* Server-side / Firestore rules: allow create only if `count < 2` (see rules snippet below).
* Display friendly message: “Upgrade to create more wardrobes” (future flow).

### Firestore security rule (concept)

```js
// pseudo-rule: enforce max 2 wardrobes per user
allow create: if request.auth.uid == userId
  && get(/databases/$(default)/documents/users/$(userId))
       .data != null
  && ( // check number of existing docs
       exists(...) ? true : true
     );
```

(Implement counting logic server-side/cloud-function or check in backend before write — Firestore rules can't easily count documents; enforce limit in Cloud Function or client + re-check with a transaction.)

### Acceptance criteria

* After login, users see 0–2 wardrobe cards.
* If user has 2 wardrobes, the create button is disabled and shows tooltip: “Max 2 wardrobes. Upgrade to add more.”
* Creating a wardrobe with valid input creates the doc and returns to Welcome with new card visible.

---

## Phase 2 — Create Wardrobe Flow (UI + Create API)

**Objective:** Build the create wardrobe screen and persist the wardrobe.

### Screens

1. `CreateWardrobeScreen`

   * Fields:

     * `Wardrobe Title` (text)
     * `Location / Room` (text)
     * `Seasonal` (dropdown: Summer/Winter/All-season/Custom)
   * Buttons: `Create` and `Cancel`

### Step-by-step flow (cursor-friendly)

1. On `CreateWardrobeScreen`, user fills fields.
2. Press `Create` → UI disables button and shows spinner.
3. Client calls `WardrobeService.createWardrobe(userId, payload)`.
4. Service checks current wardrobe count (transaction read).

   * If count >= 2 → return error: “Limit reached”.
5. If allowed → create wardrobe doc with timestamps.
6. On success → navigate to `AddClothFirstScreen` with `wardrobeId`.

### Firestore transaction example (pseudo)

```dart
final userWardrobesRef = firestore.collection('users').doc(uid).collection('wardrobes');
firestore.runTransaction((tx) async {
  final snapshot = await tx.get(userWardrobesRef.limit(3));
  if (snapshot.docs.length >= 2) throw Exception('Limit reached');
  final newRef = userWardrobesRef.doc();
  tx.set(newRef, {...});
});
```

### Validation + UX

* Title required; if empty show inline error.
* If transaction fails due to race, show modal and refresh local list.

### Acceptance criteria

* Create button performs server-side safe creation (transactional).
* On success, user proceeds to Add Cloth screen for that wardrobe.

---

## Phase 3 — Add Cloth (Image upload + metadata)

**Objective:** Allow adding cloth images + metadata for a selected wardrobe.

### Screens

1. `AddClothScreen` (for a single wardrobe)

   * Image picker (camera / gallery)
   * Type (dropdown: Shirt, Pants, Dress, Jacket, etc.)
   * Color (text or color picker)
   * Occasion (dropdown: Casual, Formal, Party, Work)
   * Season (auto from wardrobe or pick)
   * `Save` button

2. Optional `CropImageScreen` (image crop + resize)

### Firestore & Storage

Cloth path:

```
/users/{userId}/wardrobes/{wardrobeId}/clothes/{clothId}
```

Cloth document:

```json
{
  "imageUrl": "https://firebasestorage/...",
  "type": "Shirt",
  "color": "Blue",
  "occasion": "Casual",
  "season": "Summer",
  "createdAt": Timestamp,
  "lastWorn": null
}
```

Image stored in Firebase Storage:

```
/user_uploads/{userId}/wardrobe_{wardrobeId}/{clothId}.jpg
```

### Step-by-step flow (cursor-friendly)

1. On `AddClothScreen` choose Camera/Gallery.
2. Compress & crop image on device (recommended).
3. Upload image to Firebase Storage: `uploadTask = storageRef.putFile(file)`.
4. Get `imageUrl = await uploadTask.snapshot.ref.getDownloadURL()`.
5. Create cloth doc with `imageUrl` and other metadata.
6. Update `wardrobe.updatedAt` and optionally `wardrobe.clothCount` (denormalized).

### Client side validation

* Image required.
* Type required.
* Optional size limits and allowed formats.

### Acceptance criteria

* After saving, the cloth appears under that wardrobe list and cloth count increments.
* Images load properly and are compressed (to save storage).

---

## Phase 4 — Wardrobe Detail & Cloth Management

**Objective:** View a wardrobe, list clothes, edit/delete clothes.

### Screens

* `WardrobeDetailScreen` — shows all clothes grid, add cloth button, edit wardrobe button.
* `ClothDetailScreen` — full image view, metadata, edit, delete, mark as worn.

### Actions

* `EditCloth` → update metadata or replace image (delete old image in storage).
* `DeleteCloth` → remove doc and delete storage object; decrement cloth count.
* `MarkAsWorn` → set `lastWorn = Timestamp.now()`.

### Firestore considerations

* Use batched writes for multi-step changes (e.g., delete storage then doc or vice versa with retries).
* Consider `cloud function` to clean up orphaned storage objects if doc deletion fails.

### Acceptance criteria

* Edit and delete work reliably and update UI instantly (optimistic update + rollback on failure).

---

## Phase 5 — Suggestion (basic) + Daily Notification hook (MVP)

**Objective:** Generate a “What to Wear Today” suggestion after the user has at least one wardrobe and some clothes.

### Suggestion algorithm (MVP)

1. Input: wardrobeId, clothes list.
2. Filter clothes by season (match wardrobe season) and occasion (optional).
3. Sort by `lastWorn` ascending (oldest first) to avoid repetition.
4. Pick top N (1–3) and save into:

```
/users/{userId}/suggestions/{YYYY-MM-DD}
{
  "wardrobeId": "...",
  "clothIds": ["..."],
  "createdAt": Timestamp
}
```

### Notification scheduling

* Use Cloud Scheduler + Cloud Functions OR server cron to:

  * For each active user, compute suggestion for that day and send FCM push at 7:00 AM user local time.
  * Alternatively, keep notification local: schedule local notification on device at 7:00; fetch suggestion from Firestore when tapped.

### Acceptance criteria

* Suggestion saved in Firestore.
* Push or local notification shows suggestion title and small image.

---

## Phase 6 — Billing / Upgrade Flow (future)

**Objective:** Allow users to buy more wardrobe capacity.

### Basic plan

* Free Plan: 2 wardrobes
* Pro Plan: X wardrobes (configurable)
* Implement Stripe / Google Play Billing for subscription (later)
* After payment success update `users/{userId}/plan` and allow create more wardrobes

### Implementation hints

* Use Firestore to store plan info:

```json
users/{userId}.plan = {
  "name": "free",
  "maxWardrobes": 2,
  "expiresAt": null
}
```

* When creating wardrobe check `user.plan.maxWardrobes`.

---

## Phase 7 — Polishing, testing, and production checklist

* Image compression + size limit (max 5 MB)
* Pagination of clothes list
* Offline support (local cache + sync)
* Accessibility labels for images and controls
* Unit tests for providers/services (mock Firestore)
* Analytics events: wardrobe_created, cloth_added, suggestion_sent
* E2E testing on real devices
* Backup/restore user data option

---

# Useful code & schema snippets (copy-ready)

### Dart model (wardrobe)

```dart
class Wardrobe {
  final String id;
  final String title;
  final String location;
  final String season;
  final DateTime createdAt;
  final DateTime updatedAt;

  Wardrobe({...});
  Map<String, dynamic> toJson() => {...};
}
```

### Firestore path constants

```dart
String userDoc(String uid) => 'users/$uid';
String wardrobesCol(String uid) => '${userDoc(uid)}/wardrobes';
String clothesCol(String uid, String wardrobeId) => '${wardrobesCol(uid)}/$wardrobeId/clothes';
```

### Create wardrobe (pseudo-Dart)

```dart
Future<void> createWardrobe(String uid, Map<String,dynamic> data) async {
  final col = firestore.collection(wardrobesCol(uid));
  await firestore.runTransaction((tx) async {
    final q = await col.get();
    if (q.docs.length >= userPlanMax) throw Exception('Limit reached');
    final doc = col.doc();
    tx.set(doc, {...data, 'createdAt': FieldValue.serverTimestamp()});
  });
}
```

---

# Cursor-friendly Step-by-step document (exact order to follow)

1. Login flow finished (you have Firebase OTP in place).
2. After login, call `WardrobeService.getUserWardrobes(uid)`.
3. If returned list length == 0 → navigate user to `CreateWardrobeScreen`.
4. If list length > 0 → show `WelcomeScreen` with wardrobes.
5. On `CreateWardrobeScreen`:

   * Validate title & season
   * Call `createWardrobe` transaction
   * On success navigate to `AddClothScreen(wardrobeId)`
6. On `AddClothScreen`:

   * Get image (camera/gallery)
   * Compress & crop
   * Upload to Storage, get URL
   * Create cloth doc under wardrobe
   * Update wardrobe.updatedAt
7. On `WardrobeDetailScreen`:

   * List clothes with lazy loading
   * Provide edit/delete/mark-worn
8. Suggestion service can run once user has ≥1 cloth:

   * Run simple selection & save suggestion doc
   * Send FCM push or local notification at 7:00 AM

---

# Extra notes / edge cases

* Firestore document count checks must be done in transaction to avoid race conditions.
* Because Firestore rules cannot count docs easily, enforce limit in the transaction and also validate in Cloud Function (if you plan server SDK).
* When deleting cloth always try to delete the storage file — consider a Cloud Function to clean up leftover files.
