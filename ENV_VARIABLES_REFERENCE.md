# Environment Variables Reference

This document lists all environment variables used in the application and how to configure them.

## Quick Setup

1. Create a `.env` file in the project root (same level as `pubspec.yaml`)
2. Copy the template below and fill in your values
3. The `.env` file is already in `.gitignore` - it will NOT be committed

## Template (.env file)

```env
# ============================================
# REQUIRED - Background Removal Feature
# ============================================
REMOVE_BG_API_KEY=q4LbKMkLkwCCgTmTh6LuHGCt

# ============================================
# OPTIONAL - Banner API Configuration
# ============================================
# Default: https://www.wardrobe.chat/api
# Only change if using a different endpoint
BANNER_API_BASE_URL=https://www.wardrobe.chat/api

# ============================================
# OPTIONAL - Content Filtering
# ============================================
# Get from: https://console.cloud.google.com/apis/credentials
# If not set, content filtering is disabled (fail open)
GOOGLE_CLOUD_API_KEY=YOUR_GOOGLE_CLOUD_API_KEY_HERE
```

## Environment Variables Details

### REMOVE_BG_API_KEY (Required)
- **Purpose**: API key for remove.bg service (background removal)
- **Required**: ✅ Yes (for background removal feature)
- **Default**: None (feature disabled if not set)
- **Get from**: https://www.remove.bg/api
- **Used in**: `lib/services/background_removal_service.dart`
- **Fallback**: Returns original image if key is missing

### BANNER_API_BASE_URL (Optional)
- **Purpose**: Base URL for banner advertisement API
- **Required**: ⚠️ Optional
- **Default**: `https://www.wardrobe.chat/api`
- **Used in**: `lib/services/banner_service.dart`
- **Fallback**: Uses default URL if not set

### GOOGLE_CLOUD_API_KEY (Optional)
- **Purpose**: Google Cloud API key for content moderation/filtering
- **Required**: ⚠️ Optional
- **Default**: None (filtering disabled if not set)
- **Get from**: https://console.cloud.google.com/apis/credentials
- **Used in**: `lib/services/content_filter_service.dart`
- **Fallback**: Content filtering disabled (fail open - allows content)

## Production Build Notes

### ✅ Release Mode Compatibility

The environment variables work in **both debug and release modes**:

1. **Debug Mode**: Loads from `.env` file in project root
2. **Release Mode**: `.env` file is bundled with the app, variables are loaded at runtime

### Building for Production

1. **Ensure `.env` file exists** with all required variables
2. **Test the release build** before deploying:
   ```bash
   flutter build apk --release  # Android
   flutter build ios --release  # iOS
   ```
3. **Verify all features work** in the release build
4. **Never commit `.env`** to version control (already in `.gitignore`)

### CI/CD Integration

For automated builds, you can:
- Use CI/CD environment variables
- Generate `.env` file during build process
- Use secure secret management (GitHub Secrets, GitLab CI Variables, etc.)

## Security Best Practices

✅ **DO:**
- Keep `.env` file in `.gitignore` (already configured)
- Use different API keys for development and production
- Rotate API keys regularly
- Use environment-specific `.env` files (`.env.dev`, `.env.prod`)
- Store production keys in secure secret management systems

❌ **DON'T:**
- Commit `.env` file to version control
- Share API keys in chat/email
- Use production keys in development
- Hardcode keys in source code

## Troubleshooting

### Variables Not Loading

1. **Check file location**: `.env` must be in project root (same level as `pubspec.yaml`)
2. **Check file format**: No spaces around `=`, no quotes needed
3. **Restart app**: Restart after creating/modifying `.env`
4. **Check logs**: Look for warning messages in debug console

### Feature Not Working

1. **Check if variable is set**: Look for warning messages in logs
2. **Verify key is correct**: Test API key directly with the service
3. **Check fallback behavior**: Some features have graceful fallbacks
4. **Review documentation**: Check feature-specific docs in `ENV_SETUP.md`

## Firebase Configuration

**Note**: Firebase API keys are **NOT** moved to environment variables because:
- Firebase API keys are **public** by design
- They're meant to be included in the app bundle
- Security is handled via Firebase Security Rules
- Moving them would break Firebase initialization

Firebase configuration remains in `lib/firebase_options.dart` (auto-generated).

## Adding New Environment Variables

If you need to add a new environment variable:

1. **Add to `.env` file**:
   ```env
   NEW_VARIABLE_NAME=value
   ```

2. **Load in code**:
   ```dart
   import 'package:flutter_dotenv/flutter_dotenv.dart';
   
   final value = dotenv.env['NEW_VARIABLE_NAME'];
   ```

3. **Add to this documentation** for reference

4. **Update `.env.example`** template (if you create one)

## Support

For issues or questions:
- Check `ENV_SETUP.md` for detailed setup instructions
- Review service-specific documentation
- Check Flutter dotenv documentation: https://pub.dev/packages/flutter_dotenv
