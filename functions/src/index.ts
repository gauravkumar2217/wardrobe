/**
 * Firebase Cloud Functions for Wardrobe App Notifications
 *
 * This file contains Cloud Functions that send push notifications
 * for various events: friend requests, friend accepts, DM messages,
 * cloth likes, and cloth comments.
 *
 * See: https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as path from "path";
import * as fs from "fs";

// Initialize Firebase Admin
// For local development, use service account file if it exists
// For production, Firebase automatically uses the default service account
try {
  // Try multiple possible service account file names
  const possiblePaths = [
    path.join(__dirname, "../service-account.json"),
    path.join(__dirname, "../wordrobe-chat-firebase-adminsdk-fbsvc-6a72dd5bad.json"),
  ];

  let serviceAccountPath: string | null = null;
  for (const possiblePath of possiblePaths) {
    if (fs.existsSync(possiblePath)) {
      serviceAccountPath = possiblePath;
      break;
    }
  }

  if (serviceAccountPath) {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    logger.info("✅ Firebase Admin initialized with service account file");
  } else {
    // Production: Use default credentials (automatic in Firebase Cloud Functions)
    admin.initializeApp();
    logger.info("✅ Firebase Admin initialized with default credentials");
  }
} catch (error) {
  // Fallback to default initialization
  admin.initializeApp();
  logger.warn("⚠️ Using default Firebase Admin credentials");
}

const db = admin.firestore();
const messaging = admin.messaging();

// Set global options for cost control
setGlobalOptions({
  maxInstances: 10,
  region: "us-central1", // Change to your preferred region
});

/**
 * Helper function to get user notification settings
 */
async function getUserNotificationSettings(userId: string): Promise<any> {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      logger.warn(`User document not found: ${userId}`);
      return null;
    }

    const userData = userDoc.data();
    return userData?.settings?.notifications || null;
  } catch (error) {
    logger.error(`Error getting notification settings for ${userId}:`, error);
    return null;
  }
}

/**
 * Helper function to check if quiet hours are active
 */
function isQuietHours(settings: any): boolean {
  if (!settings || !settings.quietHoursStart || !settings.quietHoursEnd) {
    return false;
  }

  try {
    const now = new Date();
    const currentHour = now.getHours();
    const currentMinute = now.getMinutes();
    const currentTime = currentHour * 60 + currentMinute;

    const [startHour, startMinute] = settings.quietHoursStart.split(":").map(Number);
    const [endHour, endMinute] = settings.quietHoursEnd.split(":").map(Number);
    const startTime = startHour * 60 + startMinute;
    const endTime = endHour * 60 + endMinute;

    // Handle quiet hours that span midnight (e.g., 22:00 to 08:00)
    if (endTime <= startTime) {
      return currentTime >= startTime || currentTime < endTime;
    } else {
      // Quiet hours within same day
      return currentTime >= startTime && currentTime < endTime;
    }
  } catch (error) {
    logger.error("Error checking quiet hours:", error);
    return false;
  }
}

/**
 * Helper function to get active FCM tokens for a user
 */
async function getActiveFCMTokens(userId: string): Promise<string[]> {
  try {
    const tokensSnapshot = await db
      .collection("fcmTokens")
      .where("userId", "==", userId)
      .where("isActive", "==", true)
      .get();

    const tokens = tokensSnapshot.docs
      .map((doc) => doc.data().fcmToken as string)
      .filter((token) => token && token.length > 0);

    logger.info(`Found ${tokens.length} active FCM tokens for user ${userId}`);
    return tokens;
  } catch (error) {
    logger.error(`Error getting FCM tokens for ${userId}:`, error);
    // Fallback to old devices collection
    try {
      const devicesSnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("devices")
        .where("isActive", "==", true)
        .get();

      return devicesSnapshot.docs
        .map((doc) => doc.data().fcmToken as string)
        .filter((token) => token && token.length > 0);
    } catch (fallbackError) {
      logger.error(`Error getting FCM tokens (fallback) for ${userId}:`, fallbackError);
      return [];
    }
  }
}

/**
 * Helper function to send FCM notification
 */
async function sendFCMNotification(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) {
    logger.warn("No active tokens found, skipping notification");
    return;
  }

  try {
    // Convert data values to strings (FCM requires string values)
    const stringData: Record<string, string> = {};
    for (const [key, value] of Object.entries(data)) {
      stringData[key] = String(value);
    }

    const message: admin.messaging.MulticastMessage = {
      notification: {
        title: title,
        body: body,
      },
      data: stringData,
      tokens: tokens,
      android: {
        priority: "high",
        notification: {
          channelId: "scheduled_notifications",
          sound: "default",
          color: "#7C3AED",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);
    logger.info(`Successfully sent ${response.successCount} notification(s)`);

    if (response.failureCount > 0) {
      logger.warn(`Failed to send ${response.failureCount} notification(s)`);
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          logger.error(`Failed token ${tokens[idx]}:`, resp.error);
          // If token is invalid, mark it as inactive
          if (resp.error?.code === "messaging/invalid-registration-token" ||
              resp.error?.code === "messaging/registration-token-not-registered") {
            // Mark token as inactive (non-blocking)
            markTokenAsInactive(tokens[idx]).catch((e) => {
              logger.error(`Failed to mark token as inactive:`, e);
            });
          }
        }
      });
    }
  } catch (error) {
    logger.error("Error sending FCM notification:", error);
    throw error;
  }
}

/**
 * Helper function to mark FCM token as inactive
 */
async function markTokenAsInactive(token: string): Promise<void> {
  try {
    // Update in fcmTokens collection
    const tokenDocs = await db
      .collection("fcmTokens")
      .where("fcmToken", "==", token)
      .get();

    const batch = db.batch();
    tokenDocs.docs.forEach((doc) => {
      batch.update(doc.ref, {
        isActive: false,
        lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    logger.info(`Marked token as inactive: ${token.substring(0, 20)}...`);
  } catch (error) {
    logger.error(`Error marking token as inactive:`, error);
  }
}

/**
 * Cloud Function: Send notification when trigger is created
 * 
 * Listens to: notificationTriggers/{triggerId}
 * 
 * This function processes notification triggers created by the Flutter app
 * and sends actual FCM push notifications to users.
 */
export const onNotificationTrigger = onDocumentCreated(
  {
    document: "notificationTriggers/{triggerId}",
    maxInstances: 10,
  },
  async (event) => {
    const triggerData = event.data?.data();
    const triggerId = event.params.triggerId;

    if (!triggerData) {
      logger.error(`Trigger data is null for ${triggerId}`);
      return;
    }

    logger.info(`Processing notification trigger: ${triggerId}`, {triggerData});

    // Skip if already sent
    if (triggerData.sent === true) {
      logger.info(`Trigger ${triggerId} already sent, skipping`);
      return;
    }

    const recipientUserId = triggerData.recipientUserId;
    const notificationType = triggerData.type;

    if (!recipientUserId) {
      logger.error(`Missing recipientUserId in trigger ${triggerId}`);
      return;
    }

    try {
      // Get user notification settings
      const settings = await getUserNotificationSettings(recipientUserId);

      // Check if notification type is enabled
      let isEnabled = true;
      switch (notificationType) {
        case "friend_request":
          isEnabled = settings?.friendRequests !== false;
          break;
        case "friend_accept":
          isEnabled = settings?.friendAccepts !== false;
          break;
        case "dm_message":
          isEnabled = settings?.dmMessages !== false;
          break;
        case "cloth_like":
          isEnabled = settings?.clothLikes !== false;
          break;
        case "cloth_comment":
          isEnabled = settings?.clothComments !== false;
          break;
        default:
          isEnabled = true;
      }

      if (!isEnabled) {
        logger.info(
          `Notification type ${notificationType} disabled for user ${recipientUserId}`
        );
        // Mark as sent to prevent retry
        await event.data?.ref.update({
          sent: true,
          skipped: true,
          skipReason: "notification_type_disabled",
        });
        return;
      }

      // Check quiet hours
      if (isQuietHours(settings)) {
        logger.info(
          `Quiet hours active for user ${recipientUserId}, skipping notification`
        );
        // Mark as sent to prevent retry
        await event.data?.ref.update({
          sent: true,
          skipped: true,
          skipReason: "quiet_hours",
        });
        return;
      }

      // Get active FCM tokens
      const tokens = await getActiveFCMTokens(recipientUserId);
      if (tokens.length === 0) {
        logger.warn(`No active tokens for user ${recipientUserId}`);
        // Mark as sent to prevent retry
        await event.data?.ref.update({
          sent: true,
          skipped: true,
          skipReason: "no_active_tokens",
        });
        return;
      }

      // Send notification
      await sendFCMNotification(
        tokens,
        triggerData.title || "Notification",
        triggerData.body || "You have a new notification",
        triggerData.data || {}
      );

      // Mark trigger as sent
      await event.data?.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        tokensCount: tokens.length,
      });

      logger.info(`Successfully processed notification trigger ${triggerId}`);
    } catch (error) {
      logger.error(`Error processing notification trigger ${triggerId}:`, error);
      // Don't mark as sent on error, so it can be retried
      // Firebase Functions will automatically retry failed functions
      throw error;
    }
  }
);

/**
 * Cloud Function: Clean up old notification triggers
 * 
 * Runs daily to delete notification triggers older than 7 days
 * This helps keep the database clean and reduces storage costs
 */
export const cleanupOldNotificationTriggers = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "UTC",
    maxInstances: 1,
  },
  async () => {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    try {
      logger.info("Starting cleanup of old notification triggers");

      const oldTriggers = await db
        .collection("notificationTriggers")
        .where("createdAt", "<", admin.firestore.Timestamp.fromDate(sevenDaysAgo))
        .limit(500) // Process in batches to avoid timeout
        .get();

      if (oldTriggers.empty) {
        logger.info("No old triggers to clean up");
        return;
      }

      const batch = db.batch();
      let count = 0;

      oldTriggers.docs.forEach((doc) => {
        batch.delete(doc.ref);
        count++;
      });

      await batch.commit();
      logger.info(`Cleaned up ${count} old notification triggers`);
    } catch (error) {
      logger.error("Error cleaning up old triggers:", error);
      // Don't throw - this is a cleanup function, failures shouldn't break the system
    }
  }
);
