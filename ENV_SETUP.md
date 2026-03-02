# Environment Variables Setup

All API keys, passwords, and sensitive configuration are stored securely using environment variables to prevent them from being exposed in version control.

## Required Environment Variables

### Setup Instructions

1. **Create a `.env` file** in the root directory of the project (same level as `pubspec.yaml`)

2. **Add all required variables** to the `.env` file:
   ```env
   # Remove.bg API Key (for background removal)
   REMOVE_BG_API_KEY=q4LbKMkLkwCCgTmTh6LuHGCt

   # Banner API Base URL (optional - defaults to https://www.wardrobe.chat/api)
   BANNER_API_BASE_URL=https://www.wardrobe.chat/api

   # Google Cloud API Key (for content filtering - optional)
   # Get from: https://console.cloud.google.com/apis/credentials
   GOOGLE_CLOUD_API_KEY=YOUR_GOOGLE_CLOUD_API_KEY_HERE
   ```

3. **Verify `.env` is in `.gitignore`** (it should already be there)

## Environment Variables Reference

### Required Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `REMOVE_BG_API_KEY` | Remove.bg API key for background removal | ✅ Yes | None (feature disabled) |
| `BANNER_API_BASE_URL` | Base URL for banner API | ⚠️ Optional | `https://www.wardrobe.chat/api` |
| `GOOGLE_CLOUD_API_KEY` | Google Cloud API key for content filtering | ⚠️ Optional | None (filtering disabled) |

### Security Notes

✅ **The `.env` file is already in `.gitignore`** - your keys will NOT be committed to version control

✅ **All keys are loaded at runtime** from the `.env` file, not hardcoded in source code

✅ **Graceful fallbacks** - Features will work with fallbacks if optional keys are missing

✅ **Production safe** - Works in both debug and release modes

### Troubleshooting

#### Background Removal Not Working
1. Check that the `.env` file exists in the project root
2. Verify the file contains: `REMOVE_BG_API_KEY=q4LbKMkLkwCCgTmTh6LuHGCt`
3. Make sure there are no extra spaces or quotes around the key
4. Restart the app after creating/modifying the `.env` file

#### Banner API Not Working
1. Verify `BANNER_API_BASE_URL` is set correctly in `.env`
2. If not set, it will use the default URL: `https://www.wardrobe.chat/api`
3. Check your network connection

#### Content Filtering Not Working
1. Content filtering is optional - if `GOOGLE_CLOUD_API_KEY` is not set, filtering is disabled
2. To enable: Get API key from Google Cloud Console and add to `.env`
3. The app will fail open (allow content) if the key is missing

### For Team Members

When setting up the project:
1. Copy `.env.example` to `.env`
2. Add all required API keys to `.env`
3. Never commit the `.env` file to version control
4. Use `.env.example` as a template for required variables

### Production Deployment

For production builds:
- The `.env` file is included in the app bundle
- Make sure to set all required variables before building
- Test the release build to ensure all features work correctly
- Consider using CI/CD environment variables for automated builds