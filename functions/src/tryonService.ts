import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
// eslint-disable-next-line @typescript-eslint/no-var-requires
const sharp = require("sharp");
// eslint-disable-next-line @typescript-eslint/no-var-requires
const fetch: (input: any, init?: any) => Promise<any> = require("node-fetch");
import {
  blendMultipleClothesWithGemini,
  type GarmentBlendLayer,
} from "./geminiService";
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
    if (["shirt", "t-shirt", "top", "blouse", "sweater", "hoodie", "dress", "gown",
      "jumpsuit", "romper", "jacket", "coat", "blazer", "cardigan", "vest", "kurta",
      "tank", "polo", "crop"].includes(type)) {
      return "shirt";
    }
    if (["pants", "trousers", "jeans", "shorts", "leggings", "skirt", "cargo"].includes(type)) {
      return "pants";
    }
    if (["shoes", "sneakers", "boots", "sandals", "heels", "footwear", "loafers", "flats"].includes(type)) {
      return "shoes";
    }
    if (["accessory", "bag", "hat", "watch", "jewelry", "belt", "scarf", "sunglasses"].includes(type)) {
      return "accessory";
    }
  }
  return "shirt"; // Default
}

const OUTFIT_LAYER_ORDER = ["shirt", "pants", "shoes", "accessory"];

interface GarmentInput {
  clothingItemId?: string;
  clothingImageUrl: string;
  clothingType?: string;
}

function layerOrderIndex(category: string): number {
  const i = OUTFIT_LAYER_ORDER.indexOf(category.toLowerCase());
  return i === -1 ? OUTFIT_LAYER_ORDER.length : i;
}

/** One garment per category; later entries replace earlier (same-type replace). */
function normalizeGarmentsList(raw: GarmentInput[]): GarmentInput[] {
  const byCategory = new Map<string, GarmentInput>();
  for (const g of raw) {
    if (!g.clothingImageUrl || !String(g.clothingImageUrl).trim()) {
      continue;
    }
    const cat = detectClothingCategory(g.clothingType);
    byCategory.set(cat, g);
  }
  const list = Array.from(byCategory.values());
  list.sort(
    (a, b) =>
      layerOrderIndex(detectClothingCategory(a.clothingType)) -
      layerOrderIndex(detectClothingCategory(b.clothingType))
  );
  return list;
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
 * Input: { userId, avatarUrl, clothingItemId?, clothingImageUrl?, clothingType? }
 *   or { userId, avatarUrl, garments: [{ clothingItemId?, clothingImageUrl, clothingType? }, ...] }
 *   Multiple categories are blended in one result; duplicate categories keep the last item.
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
    const garmentsRaw = data && data.garments;

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

    let garmentsList: GarmentInput[] = [];
    if (Array.isArray(garmentsRaw) && garmentsRaw.length > 0) {
      garmentsList = garmentsRaw
        .filter((g: any) => g && typeof g.clothingImageUrl === "string")
        .map((g: any) => ({
          clothingItemId: g.clothingItemId as string | undefined,
          clothingImageUrl: g.clothingImageUrl as string,
          clothingType: g.clothingType as string | undefined,
        }));
    } else if (clothingImageUrl) {
      garmentsList = [{
        clothingItemId,
        clothingImageUrl,
        clothingType,
      }];
    }

    garmentsList = normalizeGarmentsList(garmentsList);

    if (!avatarUrl || garmentsList.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "avatarUrl and at least one garment (clothingImageUrl or garments[]) are required"
      );
    }

    try {
      const idSummary = garmentsList
        .map((g) => g.clothingItemId || "item")
        .join(",");
      logger.info(
        `Creating try-on for user: ${userId}, garments: ${garmentsList.length} (${idSummary})`
      );

      // Step 1: Download avatar + all garment images
      logger.info("Downloading avatar and clothing images...");
      const avatarResponse = await fetch(avatarUrl);
      if (!avatarResponse.ok) {
        throw new Error("Failed to download avatar");
      }
      const avatarBuffer = Buffer.from(await avatarResponse.arrayBuffer());

      const clothingBuffers = await Promise.all(
        garmentsList.map(async (g) => {
          const r = await fetch(g.clothingImageUrl);
          if (!r.ok) {
            throw new Error(`Failed to download clothing: ${g.clothingImageUrl}`);
          }
          return Buffer.from(await r.arrayBuffer());
        })
      );

      // Step 2: Load pose landmarks from Firestore
      logger.info("Loading pose landmarks from Firestore...");
      const avatarDoc = await db.collection("users").doc(userId)
        .collection("avatar").doc("current").get();

      if (!avatarDoc.exists) {
        throw new Error("Avatar not found. Please generate avatar first.");
      }

      const avatarData = avatarDoc.data();
      const poseLandmarks = (avatarData?.poseLandmarks || {}) as PoseLandmarks;

      // Step 3–6: Per-garment category, position, resize
      const avatarMetadata = await sharp(avatarBuffer).metadata();
      const avatarWidth = avatarMetadata.width || 1024;
      const avatarHeight = avatarMetadata.height || 1024;

      const avatarBase64 = bufferToBase64(avatarBuffer);

      const layers: GarmentBlendLayer[] = [];
      const categories: string[] = [];

      for (let i = 0; i < garmentsList.length; i++) {
        const g = garmentsList[i];
        const clothingBuffer = clothingBuffers[i];
        const category = detectClothingCategory(g.clothingType);
        categories.push(category);

        const positionData = calculateClothingPosition(
          category,
          poseLandmarks,
          avatarWidth,
          avatarHeight
        );

        logger.info(`Resizing clothing (${category})...`);
        const resizedClothing = await resizeClothing(
          clothingBuffer,
          avatarWidth,
          avatarHeight,
          positionData.scale
        );

        layers.push({
          clothingBase64: bufferToBase64(resizedClothing),
          category,
          positionData: {
            x: positionData.x,
            y: positionData.y,
            scale: positionData.scale,
            rotation: positionData.rotation,
          },
        });
      }

      const primaryCategory = categories[0] || "shirt";

      // Step 7: Call Gemini (multi-garment when needed)
      logger.info(
        `Blending ${layers.length} garment(s) with Gemini...`
      );
      const blendedResultBase64 = await blendMultipleClothesWithGemini(
        avatarBase64,
        layers
      );

      const resultBuffer = base64ToBuffer(blendedResultBase64);

      // Step 9: Upload result to Storage
      logger.info("Uploading try-on result to Storage...");
      const bucket = getStorageBucket();
      const resultId = `tryon_${Date.now()}_${Math.random().toString(36).slice(2, 11)}`;
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
        clothingItemId: garmentsList[0]?.clothingItemId || clothingItemId || "unknown",
        clothingImageUrl: garmentsList[0]?.clothingImageUrl || clothingImageUrl,
        clothingItemIds: garmentsList.map((g) => g.clothingItemId || ""),
        garmentCategories: categories,
        resultUrl,
        category: primaryCategory,
        garmentCount: garmentsList.length,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection("tryon_results").doc(resultId).set(tryOnDoc);

      logger.info(`Try-on created successfully: ${resultId}`);

      return {
        success: true,
        resultId,
        resultUrl,
        category: primaryCategory,
        garmentCount: garmentsList.length,
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
