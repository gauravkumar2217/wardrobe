# Step-by-Step: Google Play Console Submission Process

## Overview
You need to **upload the AAB file first**, then address the exact alarm permission declaration when Play Console prompts you.

---

## Step-by-Step Process

### Step 1: Build Your Updated AAB File ✅

First, build your app with all the recent changes:

1. **Open terminal/command prompt** in your project directory:
   ```bash
   cd C:\Users\hp\wordrope
   ```

2. **Clean the project** (optional but recommended):
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Build the release AAB file**:
   ```bash
   flutter build appbundle --release
   ```

4. **Locate your AAB file**:
   - Path: `build\app\outputs\bundle\release\app-release.aab`
   - This is the file you'll upload to Play Console

---

### Step 2: Upload AAB to Play Console 📤

1. **Go to Google Play Console**: https://play.google.com/console
2. **Select your app**
3. **Navigate to**: **Release** → **Production** (or **Testing** → **Internal testing**)
4. **Click**: **Create new release** (or **Create release**)
5. **Upload your AAB file**:
   - Click **Upload** or drag and drop `app-release.aab`
   - Wait for upload to complete
   - Play Console will analyze your app

---

### Step 3: Address Exact Alarm Permission Declaration ⚠️

After uploading, Play Console will show warnings/errors. Here's how to fix them:

1. **Look for the error/warning**:
   - You'll see: *"You must let us know whether your app uses any exact alarm permissions"*
   - This appears in the **Policy** section or as a **blocking issue**

2. **Go to Policy section**:
   - Navigate to: **Policy** → **App content**
   - Or click directly on the error message

3. **Find "Alarms & reminders" section**:
   - Scroll down to find this section
   - If you don't see it, click **"Start"** or **"Edit"** next to "Alarms & reminders"

4. **Answer the questions**:

   **Question 1**: "Does your app use exact alarm permissions?"
   - ✅ **Answer: Yes**
   
   **Question 2**: "Is this permission used for core functionality?"
   - ✅ **Answer: No**
   
   **Question 3**: "Please provide justification"
   - ✅ **Copy and paste this**:
     ```
     Our app uses SCHEDULE_EXACT_ALARM permission to send daily outfit 
     suggestion notifications at 7 AM. This is a convenience feature 
     that enhances user experience but is not required for the app's 
     core functionality. Users can still access outfit suggestions 
     manually at any time.
     ```

5. **Save your answers**

---

### Step 4: Complete Release Checklist ✅

After fixing the exact alarm declaration, complete the rest of your release:

1. **Review release notes** (if required)
2. **Check other policy requirements**:
   - Privacy policy (if you have one)
   - Data safety (if applicable)
   - Content ratings
3. **Review and publish**:
   - Click **"Review release"**
   - If everything is green, click **"Start rollout to Production"** (or **"Save"** for testing)

---

## Alternative: Pre-fill Declaration (Optional)

You can also fill out the exact alarm declaration **before** uploading:

1. **Go to**: Policy → App content → Alarms & reminders
2. **Fill out the form** (same answers as above)
3. **Save**
4. **Then upload your AAB file**

This way, the error won't appear, but you'll still need to upload the AAB.

---

## Important Notes

### ⚠️ Common Mistakes to Avoid:

1. **Don't upload without building first** - Always build the AAB with `flutter build appbundle --release`
2. **Don't skip the exact alarm declaration** - Play Console will block your release until this is filled
3. **Don't say "Yes" to core functionality** - Daily notifications are NOT core functionality
4. **Don't forget to test** - Upload to Internal testing first before Production

### ✅ Recommended Workflow:

1. **Build AAB** → `flutter build appbundle --release`
2. **Upload to Internal Testing** → Test with a small group first
3. **Fix any issues** → Including exact alarm declaration
4. **Test thoroughly** → Make sure notifications work
5. **Promote to Production** → After testing is successful

---

## Verification Checklist

Before submitting, verify:

- [ ] AAB file built successfully (`app-release.aab` exists)
- [ ] AAB file uploaded to Play Console
- [ ] Exact alarm permission declaration completed
- [ ] All other policy requirements met
- [ ] App tested on at least one device
- [ ] Notifications working correctly
- [ ] No other blocking errors in Play Console

---

## Troubleshooting

### Error: "AAB file not found"
- **Solution**: Make sure you ran `flutter build appbundle --release` first
- Check: `build\app\outputs\bundle\release\app-release.aab`

### Error: "Exact alarm permission still showing"
- **Solution**: Make sure you saved your answers in Policy → App content
- Refresh the page and check again

### Error: "Upload failed"
- **Solution**: Check your internet connection
- Try uploading again
- Make sure the AAB file is not corrupted

---

## Quick Command Reference

```bash
# Navigate to project
cd C:\Users\hp\wordrope

# Clean and get dependencies
flutter clean
flutter pub get

# Build release AAB
flutter build appbundle --release

# AAB location
# build\app\outputs\bundle\release\app-release.aab
```

---

## Next Steps After Submission

1. **Monitor Play Console** for any additional issues
2. **Test notifications** on a real device after release
3. **Monitor user feedback** for notification-related issues
4. **Use Firebase Console** to send push notifications to users

For detailed notification management, see `NOTIFICATIONS_GUIDE.md`

