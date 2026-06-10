# Wardrobe Authentication Migration

Laravel Sanctum is the source of truth for authentication and user profiles. Firebase remains for FCM, Analytics, Firestore app data, and temporary social sign-in token verification.

## Architecture

```
Google / Apple Sign-In
        ↓
Firebase Auth (ID token only)
        ↓
POST /api/auth/social-login
        ↓
Laravel Sanctum token → flutter_secure_storage
        ↓
Firebase Auth sign-out (session is Laravel-only)
```

Email/password flows call Laravel directly without Firebase Auth.

## Flutter

| Component | Path | Role |
|-----------|------|------|
| AuthProvider | `lib/providers/auth_provider.dart` | Session state, sign-in/out, profile |
| LaravelAuthService | `lib/services/laravel_auth_service.dart` | API calls, token persistence |
| SecureTokenStorage | `lib/services/secure_token_storage.dart` | Encrypted token + user cache |
| SocialAuthBridge | `lib/services/social_auth_bridge.dart` | Google/Apple → Laravel exchange |
| ApiConfig | `lib/config/api_config.dart` | Endpoint URLs |

### Startup

1. `SplashScreen` → `AuthProvider.initialize()`
2. Read token from secure storage
3. `GET /api/auth/me` validates session
4. `GET /api/users/me` loads profile
5. Route to home or login

### Token storage

- **Use:** `flutter_secure_storage`
- **Migrate:** legacy SharedPreferences tokens moved on first read
- **Clear:** logout and account deletion

## Laravel

| Endpoint | Method | Auth |
|----------|--------|------|
| `/api/auth/social-login` | POST | Public (rate limited) |
| `/api/auth/register` | POST | Public |
| `/api/auth/login` | POST | Public |
| `/api/auth/me` | GET | Sanctum |
| `/api/auth/user` | GET | Sanctum (alias) |
| `/api/auth/logout` | POST | Sanctum |
| `/api/auth/delete-account` | DELETE | Sanctum |
| `/api/users/me` | GET/PUT | Sanctum |
| `/api/profile/update` | PUT | Sanctum (alias) |

### Social login matching

1. Match `provider` + `provider_id`
2. Match `email` → link provider to existing account
3. Create new user with Firebase UID as `id`

### Database migration

Run on the Laravel server:

```bash
php artisan migrate
```

Adds: `first_name`, `last_name`, `provider`, `provider_id`, `email_verified_at`, `last_login_at`, `is_active`, `deleted_at`.

## Deployment checklist

1. Run Laravel migration on production
2. Ensure `FIREBASE_CREDENTIALS` is set for social-login token verification
3. Set `LARAVEL_API_BASE_URL` in Flutter `.env`
4. Test Google/Apple sign-in on device
5. Verify auto-login after app restart

## Migrated to Laravel (Phase 2)

| Feature | Flutter service | Laravel endpoint |
|---------|----------------|------------------|
| FCM / devices | `fcm_service.dart` | `POST /devices`, `POST /fcm-tokens` |
| EULA | `user_service.dart` | `GET/POST /eula/*` |
| Tag lists | `tag_list_service.dart` | `GET /config/tag-lists` |
| Wardrobes | `wardrobe_service.dart` | `/wardrobes` CRUD |

Run Laravel migration: `php artisan migrate`

## Remaining Firestore usage

- Clothes, friends, chat, notifications, schedules, reports
- Body profile / avatar subdocs (partial — avatar generation uses Laravel)
- Firebase Storage for images
