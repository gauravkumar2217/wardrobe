# Community Module — Build Tracker

Last updated: 2026-08-09

## Goal

Community hub with three tabs:

| Tab | Purpose |
|-----|---------|
| **Style** | **Style Feed** = look photos users post (how they look). **Not** wardrobe inventory. |
| **Friends** | Friends list / requests / search (Laravel) |
| **Chats** | Messaging (Laravel) |

### Style Feed vs Wardrobe (important)

| | **Style Feed** | **Wardrobe** |
|--|----------------|--------------|
| What | Real photos of the user’s styled look / outfit posts | Individual clothes & accessories as inventory |
| Source | User posts a photo to Style Feed | Scan a photo (camera, gallery, **or a Style post**) → detect → save items |
| Shown in | Community → Style (Your Style / All Styles) | Wardrobe screens / try-on |
| Scan | “Scan to wardrobe” on a post extracts items into wardrobe | Add-cloth / AddClothFlow |

Push notifications use **one** Laravel FCM layer: `FcmTokenResolver` → `FcmPushService` → `AppNotificationService`.

---

## Phase status

| Phase | Description | Status |
|-------|-------------|--------|
| **0** | FCM common service (token resolver + push gateway) | ✅ Complete |
| **0b** | Wire FCM to chat / friend request / accept / comments | ✅ Complete |
| **1** | Community hub shell: Style \| Friends \| Chats | ✅ Complete |
| **2** | Friends migration → Laravel API | ✅ Complete |
| **3** | Cloth comments migration → Laravel API | ✅ Complete |
| **4** | *(superseded)* Old Style tab used wardrobe clothes — **corrected** | ✅ Replaced |
| **4b** | Style Posts (separate from wardrobe) + feed UI + create post | ✅ Complete |
| **4c** | Scan Style post → detect → save to wardrobe | ✅ Complete |
| **5** | Style share → friends’ All Styles + dedicated `style_shared` type | 🟡 Partial (share API exists; uses notification type `suggestion` until enum extended) |
| **6** | Style post comments UI in app | ⬜ Not started (API exists) |
| **7** | Worn only on Try-On; Home mock cleanup; Discover polish | ⬜ Not started |

Legend: ✅ Complete · 🟡 Partial · ⬜ Not started

---

## What shipped

### Laravel

| Item | Notes |
|------|--------|
| `FcmTokenResolver` / `FcmPushService` / `AppNotificationService` | Single FCM place |
| Push on DM, friend request/accept, cloth comment, style like/comment | |
| `style_posts`, `style_post_likes`, `style_post_comments` migration | **Run migrate** |
| `StylePostController` | CRUD feed, like, comment, share |
| Routes `/api/style-posts...` | |
| `UserStorageService::FOLDER_STYLE` | `upload-users/{userId}/style/` |

### Flutter

| Item | Notes |
|------|--------|
| Community hub Style / Friends / Chats | |
| `StyleFeedTab` | Your Style / All Styles — **posts**, not clothes |
| `CreateStylePostScreen` | Post look photo + caption + visibility |
| `StylePost` model + `StylePostService` | |
| `AddClothFlowScreen.initialImageFile` | Scan from Style post |
| Friends + cloth comments on Laravel | |

---

## Manual work (required)

### Laravel

1. Deploy latest Laravel code.
2. Run migration:
   ```bash
   php artisan migrate
   ```
   Creates `style_posts`, `style_post_likes`, `style_post_comments`.
3. Ensure `public/upload-users` (user_uploads disk) is writable.
4. Firebase credentials for FCM (`FIREBASE_CREDENTIALS` or service-account JSON).
5. Smoke-test:
   - `POST /api/style-posts` (multipart `image`, optional `caption`, `visibility`)
   - `GET /api/style-posts?scope=mine` and `scope=all`
   - `POST /api/style-posts/{id}/like`
   - Share: `POST /api/style-posts/{id}/share` with `{ "user_ids": ["..."] }`

### Flutter

1. Point `.env` `LARAVEL_API_BASE_URL` at the server that has the new migration.
2. Rebuild app.
3. Community → Style → **Post your style** (look photo).
4. Confirm wardrobe clothes **do not** appear as Style posts.
5. On a post, tap **Scan to wardrobe** → detection flow → items saved to wardrobe.
6. Friends / Chats tabs still work.

### Optional later

- Add `style_shared` to `notifications.type` enum (currently share notifies with type `suggestion` + data `type=style_shared`).
- Deep-link FCM `style_post_id` → Style Feed.
- In-app comments UI for style posts (API ready).

---

## Next phases (product)

1. Polish share-to-friends from Style card UI.
2. Style post comments screen.
3. Home community preview → real Style posts.
4. Remove leftover “cloth feed” naming elsewhere; keep wardrobe browse separate from Community Style.

---

## Change log

| Date | Change |
|------|--------|
| 2026-08-09 | Phases 0–4: hub, FCM, friends/comments Laravel |
| 2026-08-09 | **Correction:** Style Feed ≠ wardrobe. Added Style Posts + scan-to-wardrobe |
