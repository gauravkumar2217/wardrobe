import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
// eslint-disable-next-line @typescript-eslint/no-var-requires
const sharp = require("sharp");
// eslint-disable-next-line @typescript-eslint/no-var-requires
const fetch: (input: any, init?: any) => Promise<any> = require("node-fetch");
import {blendClothingWithGemini} from "./geminiService";
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
}

/**
 * Detect clothing category from image or type string
 */
function detectClothingCategory(
  clothingType?: string,
  _clothingImageUrl?: string
): string {
  if (clothingType) {
    const type = clothingType.toLowerCase();
    if (["shirt", "t-shirt", "top", "blouse", "sweater", "hoodie"].includes(type)) {
      return "shirt";
    }
    if (["pants", "trousers", "jeans", "shorts", "leggings"].includes(type)) {
      return "pants";
    }
    if (["shoes", "sneakers", "boots", "sandals", "heels", "footwear"].includes(type)) {
      return "shoes";
    }
    if (["accessory", "bag", "hat", "watch", "jewelry", "belt"].includes(type)) {
      return "accessory";
    }
  }
  return "shirt"; // Default
}

/**
 * Calculate clothing position based on pose landmarks and category
 */
function calculateClothingPosition(
  category: string,
  landmarks: PoseLandmarks,
  avatarWidth: number,
  avatarHeight: number
): {x: number; y: number; scale: number; rotation: number} {
  let x = 0;
  let y = 0;
  let scale = 1.0;
  const rotation = 0;

  switch (category.toLowerCase()) {
    case "shirt":
    case "top":
      // Position between shoulders, below neck
      if (landmarks.leftShoulder && landmarks.rightShoulder && landmarks.neck) {
        x = (landmarks.leftShoulder.x + landmarks.rightShoulder.x) / 2;
        y = landmarks.neck.y + (avatarHeight * 0.05);
        const shoulderWidth = Math.abs(
          landmarks.rightShoulder.x - landmarks.leftShoulder.x
        );
        scale = shoulderWidth / 200; // Normalize scale
      } else {
        x = avatarWidth / 2;
        y = avatarHeight * 0.20;
      }
      break;

    case "pants":
    case "trousers":
      // Position below waist, at hips
      if (landmarks.leftHip && landmarks.rightHip) {
        x = (landmarks.leftHip.x + landmarks.rightHip.x) / 2;
        y = (landmarks.leftHip.y + landmarks.rightHip.y) / 2;
        const hipWidth = Math.abs(landmarks.rightHip.x - landmarks.leftHip.x);
        scale = hipWidth / 180;
      } else {
        x = avatarWidth / 2;
        y = avatarHeight * 0.50;
      }
      break;

    case "shoes":
    case "footwear":
      // Position at bottom
      x = avatarWidth / 2;
      y = avatarHeight * 0.90;
      scale = 0.8;
      break;

    case "accessory":
      // Position varies, default to neck area
      if (landmarks.neck) {
        x = landmarks.neck.x;
        y = landmarks.neck.y;
      } else {
        x = avatarWidth / 2;
        y = avatarHeight * 0.15;
      }
      scale = 0.6;
      break;

    default:
      x = avatarWidth / 2;
      y = avatarHeight * 0.30;
      scale = 1.0;
  }

  // Clamp scale
  scale = Math.max(0.5, Math.min(2.0, scale));

  return {x, y, scale, rotation};
}

/**
 * Resize clothing image to match avatar proportions
 */
async function resizeClothing(
  clothingBuffer: Buffer,
  targetWidth: number,
  targetHeight: number,
  scale: number
): Promise<Buffer> {
  const metadata = await sharp(clothingBuffer).metadata();
  const newWidth = Math.round((metadata.width || targetWidth) * scale);
  const newHeight = Math.round((metadata.height || targetHeight) * scale);

  return await sharp(clothingBuffer)
    .resize(newWidth, newHeight, {
      fit: "inside",
      withoutEnlargement: false,
    })
    .toFormat("png")
    .toBuffer();
}

/**
 * Convert buffer to base64
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
 * Callable Cloud Function: Create Try-On
 * 
 * Input: { userId, avatarUrl, clothingItemId, clothingImageUrl, clothingType? }
 * 
 * Process:
 * 1. Download avatar and clothing images
 * 2. Load pose landmarks from Firestore
 * 3. Detect clothing category
 * 4. Calculate position
 * 5. Resize clothing
 * 6. Overlay clothing (basic)
 * 7. Call Gemini for blending
 * 8. Upload result
 * 9. Store in Firestore
 */
export const createTryOn = onCall(
  {secrets: [geminiApiKey]},
  async (request) => {
    const data = request.data as any;
    const userId = (data && data.userId) as string | undefined;
    const avatarUrl = (data && data.avatarUrl) as string | undefined;
    const clothingItemId = (data && data.clothingItemId) as string | undefined;
    const clothingImageUrl = (data && data.clothingImageUrl) as string | undefined;
    const clothingType = (data && data.clothingType) as string | undefined;

    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Not signed in."
      );
    }

    if (!userId || userId !== request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "You can only create try-on for your own userId."
      );
    }

    if (!avatarUrl || !clothingImageUrl) {
      throw new HttpsError(
        "invalid-argument",
        "avatarUrl and clothingImageUrl are required"
      );
    }

    try {
      logger.info(
        `Creating try-on for user: ${userId}, clothing: ${clothingItemId}`
      );

      // Step 1: Download images
      logger.info("Downloading avatar and clothing images...");
      const [avatarResponse, clothingResponse] = await Promise.all([
        fetch(avatarUrl),
        fetch(clothingImageUrl),
      ]);

      if (!avatarResponse.ok || !clothingResponse.ok) {
        throw new Error("Failed to download images");
      }

      const avatarBuffer = Buffer.from(await avatarResponse.arrayBuffer());
      const clothingBuffer = Buffer.from(await clothingResponse.arrayBuffer());

      // Step 2: Load pose landmarks from Firestore
      logger.info("Loading pose landmarks from Firestore...");
      const avatarDoc = await db.collection("users").doc(userId)
        .collection("avatar").doc("current").get();

      if (!avatarDoc.exists) {
        throw new Error("Avatar not found. Please generate avatar first.");
      }

      const avatarData = avatarDoc.data();
      const poseLandmarks = (avatarData?.poseLandmarks || {}) as PoseLandmarks;

      // Step 3: Detect clothing category
      const category = detectClothingCategory(clothingType);

      // Step 4: Get avatar dimensions
      const avatarMetadata = await sharp(avatarBuffer).metadata();
      const avatarWidth = avatarMetadata.width || 1024;
      const avatarHeight = avatarMetadata.height || 1024;

      // Step 5: Calculate clothing position
      const positionData = calculateClothingPosition(
        category,
        poseLandmarks,
        avatarWidth,
        avatarHeight
      );

      // Step 6: Resize clothing
      logger.info("Resizing clothing...");
      const resizedClothing = await resizeClothing(
        clothingBuffer,
        avatarWidth,
        avatarHeight,
        positionData.scale
      );

      // Step 7: Convert to base64 for Gemini
      const avatarBase64 = bufferToBase64(avatarBuffer);
      const clothingBase64 = bufferToBase64(resizedClothing);

      // Step 8: Call Gemini for blending
      logger.info("Blending clothing with Gemini...");
      const blendedResultBase64 = await blendClothingWithGemini(
        avatarBase64,
        clothingBase64,
        {
          category,
          x: positionData.x,
          y: positionData.y,
          scale: positionData.scale,
          rotation: positionData.rotation,
        }
      );

      const resultBuffer = base64ToBuffer(blendedResultBase64);

      // Step 9: Upload result to Storage
      logger.info("Uploading try-on result to Storage...");
      const bucket = getStorageBucket();
      const resultId = `${clothingItemId || "tryon"}_${Date.now()}`;
      const resultFileName = `users/${userId}/tryon/${resultId}.png`;
      const resultFile = bucket.file(resultFileName);

      await resultFile.save(resultBuffer, {
        metadata: {
          contentType: "image/png",
          cacheControl: "public, max-age=31536000",
        },
      });

      await resultFile.makePublic();
      const resultUrl = `https://storage.googleapis.com/${bucket.name}/${resultFileName}`;

      // Step 10: Store in Firestore
      logger.info("Storing try-on result in Firestore...");
      const tryOnDoc = {
        userId,
        avatarUrl,
        clothingItemId: clothingItemId || "unknown",
        clothingImageUrl,
        resultUrl,
        category,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection("tryon_results").doc(resultId).set(tryOnDoc);

      logger.info(`Try-on created successfully: ${resultId}`);

      return {
        success: true,
        resultId,
        resultUrl,
        category,
      };
    } catch (error: any) {
      logger.error("Error creating try-on:", error);
      throw new HttpsError(
        "internal",
        error?.message || "Failed to create try-on"
      );
    }
  }
);
