# Scheduled Notifications Flow Documentation

## Overview
This document describes the complete flow of scheduled notifications from creation to delivery, including background worker processing.

## Architecture

### Components
1. **ScheduleEditScreen** - UI for creating/editing schedules
2. **SchedulerProvider** - State management for schedules
3. **SchedulerService** - Local storage for schedules (SharedPreferences)
4. **LocalNotificationService** - OS-level notification scheduling
5. **ScheduleNotificationWorker** - Background worker for periodic checks
6. **ClothService** - Fetches and filters clothes based on schedule criteria

## Complete Flow

### 1. Schedule Creation/Update

```
User creates/edits schedule
    ↓
ScheduleEditScreen._saveSchedule()
    ↓
SchedulerProvider.addSchedule() / updateSchedule()
    ↓
SchedulerService.saveSchedules() → SharedPreferences (local storage)
    ↓
LocalNotificationService.scheduleNotification()
    ↓
OS schedules notification using flutter_local_notifications
    ↓
ScheduleNotificationWorker.registerPeriodicTask() (if enabled)
    ↓
Background worker registered to run every 15 minutes
```

**Files Involved:**
- `lib/screens/scheduler/schedule_edit_screen.dart`
- `lib/providers/scheduler_provider.dart`
- `lib/services/scheduler_service.dart`
- `lib/services/local_notification_service.dart`
- `lib/services/schedule_notification_worker.dart`

### 2. Background Worker Processing

The background worker runs every 15 minutes to check if any schedules should trigger:

```
WorkManager triggers periodic task
    ↓
callbackDispatcher() (top-level function)
    ↓
ScheduleNotificationWorker.processSchedules()
    ↓
Get userId from SharedPreferences
    ↓
SchedulerService.loadSchedules(userId)
    ↓
For each enabled schedule:
    - Check if current time matches schedule time
    - Check if current day matches schedule days
    ↓
If match found:
    ScheduleNotificationWorker._sendScheduleNotification()
        ↓
        ClothService.getClothes() / getAllUserClothes()
        ↓
        Apply filters from schedule.filterSettings:
            - wardrobeId
            - types
            - occasions
            - seasons
            - colors
        ↓
        Filter clothes based on criteria
        ↓
        Generate notification message:
            - If clothes found: "You have X items matching your criteria!"
            - If no clothes: "No clothes match your filter criteria."
        ↓
        LocalNotificationService.sendImmediateNotification()
        ↓
        User receives notification
```

**Files Involved:**
- `lib/services/schedule_notification_worker.dart`
- `lib/services/cloth_service.dart`
- `lib/services/local_notification_service.dart`

### 3. Notification Delivery

There are **two mechanisms** for notification delivery:

#### A. OS-Level Scheduling (Primary)
- Uses `flutter_local_notifications` with `zonedSchedule()`
- OS handles exact timing
- Works even when app is closed
- Uses `AndroidScheduleMode.exactAllowWhileIdle` for Android
- Automatically recurring based on `matchDateTimeComponents`

#### B. Background Worker (Secondary/Backup)
- Runs every 15 minutes
- Checks if any schedule should trigger
- Sends immediate notification if time matches
- Applies filters and shows filtered cloth count
- Acts as backup and provides dynamic content

### 4. Filter Application

When a notification triggers, clothes are filtered based on `schedule.filterSettings`:

```dart
filterSettings: {
  'types': ['Shirt', 'Pants'],           // Cloth types
  'occasions': ['Casual', 'Formal'],     // Occasions
  'seasons': ['Spring', 'Summer'],       // Seasons
  'colors': ['Blue', 'Red'],             // Colors
  'wardrobeId': 'wardrobe123'            // Specific wardrobe (optional)
}
```

**Filter Logic:**
1. Load clothes (all or from specific wardrobe)
2. Filter by types (if specified)
3. Filter by occasions (if specified)
4. Filter by seasons (if specified)
5. Filter by colors (if specified)
6. Generate notification message based on filtered count

### 5. Notification Content

**Title:** Schedule title (e.g., "Office Clothes Reminder")

**Body:** 
- If description provided: Uses schedule description
- If no description: 
  - "You have X item(s) matching your criteria!" (if clothes found)
  - "No clothes match your filter criteria." (if no clothes)

**Payload:** Schedule ID (for navigation if needed)

### 6. Settings Integration

Scheduled notifications can be toggled on/off:

```
SettingsScreen → Scheduled Notifications toggle
    ↓
SchedulerProvider.setScheduledNotificationsEnabled()
    ↓
If enabled:
    - LocalNotificationService.rescheduleAll()
    - ScheduleNotificationWorker.registerPeriodicTask()
If disabled:
    - LocalNotificationService.cancelAllNotifications()
    - ScheduleNotificationWorker.cancelPeriodicTask()
```

## Data Flow

### Schedule Storage
- **Location:** SharedPreferences
- **Key:** `user_schedules{userId}`
- **Format:** JSON array of Schedule objects

### User ID Storage
- **Location:** SharedPreferences
- **Key:** `current_user_id`
- **Purpose:** Background worker needs userId to load schedules

### Notification Settings
- **Location:** SharedPreferences
- **Key:** `scheduled_notifications_enabled_{userId}`
- **Default:** `true`

## Background Worker Configuration

### Task Registration
```dart
Workmanager().registerPeriodicTask(
  'periodicScheduleCheck',
  'periodicScheduleCheck',
  frequency: Duration(minutes: 15),
  constraints: Constraints(
    networkType: NetworkType.not_required,
    requiresBatteryNotLow: false,
    requiresCharging: false,
    requiresDeviceIdle: false,
    requiresStorageNotLow: false,
  ),
);
```

### Task Execution
- Runs every 15 minutes
- Checks current time against all enabled schedules
- Sends notification if time matches
- No network required (uses local data)

## Error Handling

1. **Schedule Loading Errors:** Logged, doesn't crash app
2. **Notification Scheduling Errors:** Logged, returns false
3. **Background Worker Errors:** Logged, returns false to WorkManager
4. **Cloth Loading Errors:** Logged, shows "No clothes match" message

## Testing the Flow

### Manual Testing Steps:

1. **Create a Schedule:**
   - Go to Settings → Manage Schedules
   - Create new schedule with time 2 minutes from now
   - Set filters (types, occasions, etc.)
   - Save schedule

2. **Wait for Notification:**
   - Wait for scheduled time
   - Should receive notification via OS scheduling
   - Background worker will also check every 15 minutes

3. **Verify Filtering:**
   - Create schedule with specific filters
   - Ensure you have clothes matching those filters
   - Notification should show correct count

4. **Test Background Worker:**
   - Create schedule for current time
   - Wait up to 15 minutes
   - Background worker should trigger notification

## Platform-Specific Notes

### Android
- Requires notification permission (Android 13+)
- Uses `AndroidScheduleMode.exactAllowWhileIdle` for precise timing
- Background worker uses WorkManager (Android's recommended solution)

### iOS
- Requires notification permissions
- Uses `UILocalNotificationDateInterpretation.absoluteTime`
- Background worker has limitations (may not run when app is terminated)

## Future Enhancements

1. **Cloud Sync:** Sync schedules across devices
2. **Smart Suggestions:** AI-based outfit suggestions in notifications
3. **Notification Actions:** Quick actions from notification (e.g., "View Clothes")
4. **Better Timing:** More precise background worker timing
5. **Analytics:** Track notification delivery and user engagement

