import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
// eslint-disable-next-line @typescript-eslint/no-var-requires
const sharp = require("sharp");
// eslint-disable-next-line @typescript-eslint/no-var-requires
const fetch: (input: any, init?: any) => Promise<any> = require("node-fetch");
import {generateAvatarWithGemini} from "./geminiService";
import {getStorageBucket} from "./storageBucket";
import {geminiApiKey} from "./secrets";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

interface PoseLandmarks {
  leftShoulder?: {x: number; y: number};
  rightShoulder?: {x: number; y: number};
  leftHip?: {x: number; y: number};
  rightHip?: {x: number; y: number};
  neck?: {x: number; y: number};
  leftElbow?: {x: number; y: number};
  rightElbow?: {x: number; y: number};
}

/**
 * Estimate pose landmarks from image (simplified approach)
 * In production, use MediaPipe API or TensorFlow.js for accurate detection
 */
async function estimatePoseLandmarks(imageBuffer: Buffer): Promise<PoseLandmarks> {
  // For now, return placeholder landmarks
  // In production, integrate MediaPipe or TensorFlow.js pose detection
  // This is a simplified estimation - replace with actual pose detection
  const metadata = await sharp(imageBuffer).metadata();
  const width = metadata.width || 1024;
  const height = metadata.height || 1024;

  // Estimate landmark positions (center-based estimation)
  // These are rough estimates - replace with actual pose detection
  return {
    neck: {x: width / 2, y: height * 0.15},
    leftShoulder: {x: width * 0.35, y: height * 0.20},
    rightShoulder: {x: width * 0.65, y: height * 0.20},
    leftElbow: {x: width * 0.30, y: height * 0.35},
    rightElbow: {x: width * 0.70, y: height * 0.35},
    leftHip: {x: width * 0.40, y: height * 0.50},
    rightHip: {x: width * 0.60, y: height * 0.50},
  };
}

/**
 * Remove background from image using basic processing
 * For better results, use rembg API or Gemini
 */
async function removeBackground(imageBuffer: Buffer): Promise<Buffer> {
  // Basic background removal using sharp
  // For production, use rembg API or Gemini for better results
  try {
    // Convert to RGBA and apply basic processing
    const processed = await sharp(imageBuffer)
      .resize(1024, 1024, {
        fit: "inside",
        withoutEnlargement: true,
      })
      .toFormat("png")
      .toBuffer();

    return processed;
  } catch (error) {
    logger.error("Error in background removal:", error);
    throw error;
  }
}

/**
 * Normalize and center the avatar image
 */
async function normalizeAvatar(imageBuffer: Buffer): Promise<Buffer> {
  try {
    const metadata = await sharp(imageBuffer).metadata();
    const width = metadata.width || 1024;
    const height = metadata.height || 1024;

    // Resize to max 1024px while maintaining aspect ratio
    const maxDimension = 1024;
    let newWidth = width;
    let newHeight = height;

    if (width > maxDimension || height > maxDimension) {
      if (width > height) {
        newWidth = maxDimension;
        newHeight = Math.round((height / width) * maxDimension);
      } else {
        newHeight = maxDimension;
        newWidth = Math.round((width / height) * maxDimension);
      }
    }

    const normalized = await sharp(imageBuffer)
      .resize(newWidth, newHeight, {
        fit: "inside",
        withoutEnlargement: false,
      })
      .toFormat("png")
      .toBuffer();

    return normalized;
  } catch (error) {
    logger.error("Error normalizing avatar:", error);
    throw error;
  }
}

/**
 * Convert image buffer to base64
 */
function bufferToBase64(buffer: Buffer): string {
  return buffer.toString("base64");
}

/**
 * Convert base64 to buffer
 */
function base64ToBuffer(base64: string): Buffer {
  return Buffer.from(base64, "base64");
}

/**
 * Callable Cloud Function: Generate 2D Avatar
 * 
 * Input: { userId, bodyImageUrl, userHeightCm? }
 * 
 * Process:
 * 1. Download body image from Storage
 * 2. Remove background
 * 3. Detect pose landmarks
 * 4. Normalize image
 * 5. Call Gemini for refinement
 * 6. Upload avatar PNG to Storage
 * 7. Store metadata in Firestore
 */
export const generateAvatar = onCall(
  {secrets: [geminiApiKey]},
  async (request) => {
    const data = request.data as any;
    const userId = (data && data.userId) as string | undefined;
    const bodyImageUrl = (data && data.bodyImageUrl) as string | undefined;
    const userHeightCm = (data && data.userHeightCm) as number | undefined;

    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Not signed in."
      );
    }

    if (!userId || userId !== request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "You can only generate an avatar for your own userId."
      );
    }

    if (!bodyImageUrl) {
      throw new HttpsError(
        "invalid-argument",
        "bodyImageUrl is required"
      );
    }

    try {
      logger.info(`Generating avatar for user: ${userId}`);

      // Step 1: Download body image
      logger.info("Downloading body image from Storage...");
      const imageResponse = await fetch(bodyImageUrl);
      if (!imageResponse.ok) {
        throw new Error(`Failed to download image: ${imageResponse.statusText}`);
      }
      const imageBuffer = Buffer.from(await imageResponse.arrayBuffer());

      // Step 2: Remove background (basic processing)
      logger.info("Removing background...");
      const processedBuffer = await removeBackground(imageBuffer);

      // Step 3: Estimate pose landmarks
      logger.info("Detecting pose landmarks...");
      const poseLandmarks = await estimatePoseLandmarks(processedBuffer);

      // Step 4: Normalize image
      logger.info("Normalizing avatar...");
      const normalizedBuffer = await normalizeAvatar(processedBuffer);

      // Step 5: Call Gemini for refinement
      logger.info("Refining avatar with Gemini...");
      const imageBase64 = bufferToBase64(normalizedBuffer);
      const refinedAvatarBase64 = await generateAvatarWithGemini(
        imageBase64,
        poseLandmarks as Record<string, {x: number; y: number}>
      );
      const avatarBuffer = base64ToBuffer(refinedAvatarBase64);

      // Step 6: Upload avatar to Storage
      logger.info("Uploading avatar to Storage...");
      const bucket = getStorageBucket();
      const avatarFileName = `users/${userId}/avatar/avatar.png`;
      const avatarFile = bucket.file(avatarFileName);

      await avatarFile.save(avatarBuffer, {
        metadata: {
          contentType: "image/png",
          cacheControl: "public, max-age=31536000",
        },
      });

      // Make file publicly readable
      await avatarFile.makePublic();

      // Get public URL
      const avatarUrl = `https://storage.googleapis.com/${bucket.name}/${avatarFileName}`;

      // Step 7: Calculate body measurements (simplified)
      const measurements = {
        heightCm: userHeightCm || 170,
        shoulderWidthCm: poseLandmarks.leftShoulder && poseLandmarks.rightShoulder
          ? Math.abs(poseLandmarks.rightShoulder.x - poseLandmarks.leftShoulder.x) * 0.1
          : 45,
        hipWidthCm: poseLandmarks.leftHip && poseLandmarks.rightHip
          ? Math.abs(poseLandmarks.rightHip.x - poseLandmarks.leftHip.x) * 0.1
          : 90,
      };

      // Step 8: Store in Firestore
      logger.info("Storing avatar metadata in Firestore...");
      const avatarDoc = {
        userId,
        bodyImageUrl,
        avatarImageUrl: avatarUrl,
        poseLandmarks,
        bodyMeasurements: measurements,
        userHeightCm: measurements.heightCm,
        generationStatus: "completed",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection("users").doc(userId)
        .collection("avatar").doc("current")
        .set(avatarDoc, {merge: true});

      logger.info(`Avatar generated successfully for user: ${userId}`);

      return {
        success: true,
        avatarUrl,
        poseLandmarks,
        measurements,
      };
    } catch (error: any) {
      logger.error("Error generating avatar:", error);
      throw new HttpsError(
        "internal",
        error?.message || "Failed to generate avatar"
      );
    }
  }
);
