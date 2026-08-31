import * as functions from "firebase-functions";
// eslint-disable-next-line @typescript-eslint/no-var-requires
const fetch: (input: any, init?: any) => Promise<any> = require("node-fetch");

function getGeminiApiKey(): string {
  const key = process.env.GEMINI_API_KEY || "";
  if (!key) {
    throw new Error("GEMINI_API_KEY not configured");
  }
  return key;
}

/** Image output (avatar/try-on legacy Cloud Functions). Use GEMINI_IMAGE_MODEL on server. */
function getGeminiImageModel(): string {
  return (
    process.env.GEMINI_IMAGE_MODEL ||
    process.env.GEMINI_MODEL ||
    "gemini-2.5-flash-image"
  );
}

function buildGenerateContentUrl(): string {
  const model = getGeminiImageModel();
  return `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${getGeminiApiKey()}`;
}

const imageGenerationConfig = {
  responseModalities: ["TEXT", "IMAGE"],
};

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        text?: string;
        inline_data?: {mime_type: string; data: string};
        /** REST JSON often uses camelCase */
        inlineData?: {mimeType: string; data: string};
      }>;
    };
  }>;
}

function partImageBase64(part: {
  text?: string;
  inline_data?: {mime_type: string; data: string};
  inlineData?: {mimeType: string; data: string};
}): string | undefined {
  return part.inline_data?.data ?? part.inlineData?.data;
}

/**
 * Generate a clean avatar with transparent background using Gemini Vision API
 * @param imageBase64 - Base64 encoded image of the user's body photo
 * @param poseLandmarks - MediaPipe pose landmarks for reference
 * @returns Base64 encoded PNG image with transparent background
 */
export async function generateAvatarWithGemini(
  imageBase64: string,
  _poseLandmarks?: Record<string, {x: number; y: number}>
): Promise<string> {
  const url = buildGenerateContentUrl();

  const prompt = `You are an AI image processing expert. Your task is to create a clean, realistic avatar from this full-body photo.

Requirements:
1. Remove the background completely (make it transparent)
2. Keep the person in a neutral standing pose (straighten if needed)
3. Center the person in the frame
4. Maintain realistic proportions and natural appearance
5. Preserve skin tone, hair color, and facial features accurately
6. Output should be a high-quality transparent PNG

The person should be:
- Standing straight with arms slightly away from body
- Head upright, looking forward
- Legs straight and together
- Clean edges with no background artifacts

Return ONLY the processed image as base64-encoded PNG data.`;

  const body = {
    contents: [
      {
        parts: [
          {text: prompt},
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: imageBase64,
            },
          },
        ],
      },
    ],
    generationConfig: imageGenerationConfig,
  };

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
    }

    const json = (await response.json()) as GeminiResponse;
    const candidates = json.candidates;

    if (!candidates || !candidates.length) {
      throw new Error("No candidates returned from Gemini API");
    }

    // Extract base64 image from response
    const parts = candidates[0]?.content?.parts;
    if (!parts || !parts.length) {
      throw new Error("No content parts in Gemini response");
    }

    const imagePart = parts.find((p) => partImageBase64(p));
    const img = imagePart && partImageBase64(imagePart);
    if (img) {
      return img;
    }

    // If text response, try to extract base64 from text
    const textPart = parts.find((p) => p.text);
    if (textPart?.text) {
      // Try to extract base64 from markdown or JSON in text
      const base64Match = textPart.text.match(/data:image\/png;base64,([A-Za-z0-9+/=]+)/);
      if (base64Match && base64Match[1]) {
        return base64Match[1];
      }
    }

    throw new Error("Could not extract image data from Gemini response");
  } catch (error) {
    functions.logger.error("Error calling Gemini API for avatar generation:", error);
    throw error;
  }
}

/**
 * Blend clothing item onto avatar using Gemini Vision API
 * @param avatarBase64 - Base64 encoded transparent PNG avatar
 * @param clothingBase64 - Base64 encoded clothing item image
 * @param positionData - Position and scale data for clothing placement
 * @returns Base64 encoded PNG image with clothing blended onto avatar
 */
export async function blendClothingWithGemini(
  avatarBase64: string,
  clothingBase64: string,
  positionData: {
    category: string;
    x: number;
    y: number;
    scale: number;
    rotation?: number;
  }
): Promise<string> {
  const url = buildGenerateContentUrl();

  const categoryInstructions: Record<string, string> = {
    shirt: "Place the shirt/top on the upper body, between the shoulders, below the neck. Ensure it fits naturally and follows the body contours.",
    pants: "Place the pants/trousers on the lower body, starting from the waist and extending down. Ensure proper fit and natural draping.",
    shoes: "Place the shoes at the feet, aligned with the bottom of the avatar. Ensure proper perspective and size.",
    accessory: "Place the accessory in an appropriate location (neck for jewelry, head for hats, etc.). Ensure it looks natural and well-positioned.",
  };

  const categoryInstruction = categoryInstructions[positionData.category.toLowerCase()] ||
    "Place the clothing item naturally on the avatar.";

  const scaleHint = typeof positionData.scale === "number" ?
    `Approximate scale factor relative to body: ${positionData.scale.toFixed(2)} (use as a loose guide only).` :
    "";

  const prompt = `You are an AI fashion visualization expert. Your task is to blend a clothing item onto an avatar image.

Instructions:
1. Take the transparent avatar (first image) as the body; use the clothing item (second image) as the garment to wear.
2. ${categoryInstruction}
3. ${scaleHint}
4. Warp and perspective-match the garment to the avatar's pose — do not paste it as a flat rectangle; it must wrap the torso, legs, or feet naturally.
5. Match the lighting and shadows of the avatar; add subtle contact shadows where fabric meets skin.
6. Ensure the clothing follows the body's natural curves and contours.
7. Blend edges seamlessly for a realistic appearance.
8. Keep the background fully transparent outside the person, like the input avatar.
9. If the second image still shows a mannequin or hanger, ignore it and only transfer the garment's fabric, color, and design onto the avatar.

The result should look like the person is actually wearing the clothing item, with:
- Natural fit and proportions
- Realistic shadows and highlights
- Seamless blending
- Professional quality

Return ONLY the final composite image as base64-encoded PNG data with transparent background.`;

  const body = {
    contents: [
      {
        parts: [
          {text: prompt},
          {
            inline_data: {
              mime_type: "image/png",
              data: avatarBase64,
            },
          },
          {
            inline_data: {
              mime_type: "image/jpeg",
              data: clothingBase64,
            },
          },
        ],
      },
    ],
    generationConfig: imageGenerationConfig,
  };

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
    }

    const json = (await response.json()) as GeminiResponse;
    const candidates = json.candidates;

    if (!candidates || !candidates.length) {
      throw new Error("No candidates returned from Gemini API");
    }

    // Extract base64 image from response
    const parts = candidates[0]?.content?.parts;
    if (!parts || !parts.length) {
      throw new Error("No content parts in Gemini response");
    }

    const imagePart = parts.find((p) => partImageBase64(p));
    const img = imagePart && partImageBase64(imagePart);
    if (img) {
      return img;
    }

    // If text response, try to extract base64 from text
    const textPart = parts.find((p) => p.text);
    if (textPart?.text) {
      const base64Match = textPart.text.match(/data:image\/png;base64,([A-Za-z0-9+/=]+)/);
      if (base64Match && base64Match[1]) {
        return base64Match[1];
      }
    }

    throw new Error("Could not extract image data from Gemini response");
  } catch (error) {
    functions.logger.error("Error calling Gemini API for clothing blend:", error);
    throw error;
  }
}

export interface GarmentBlendLayer {
  clothingBase64: string;
  category: string;
  positionData: {
    x: number;
    y: number;
    scale: number;
    rotation?: number;
  };
}

/**
 * Blend multiple clothing items onto one avatar in a single pass (full outfit).
 */
export async function blendMultipleClothesWithGemini(
  avatarBase64: string,
  layers: GarmentBlendLayer[]
): Promise<string> {
  if (!layers.length) {
    throw new Error("No garments to blend");
  }
  if (layers.length === 1) {
    const g = layers[0];
    return blendClothingWithGemini(avatarBase64, g.clothingBase64, {
      category: g.category,
      x: g.positionData.x,
      y: g.positionData.y,
      scale: g.positionData.scale,
      rotation: g.positionData.rotation,
    });
  }

  const url = buildGenerateContentUrl();

  const categoryInstructions: Record<string, string> = {
    shirt: "upper body / top / dress / outerwear — fit to shoulders and torso",
    pants: "lower body — waist through legs (skip if image 1 already shows a full-length dress covering legs)",
    shoes: "feet only — correct perspective and ground contact",
    accessory: "appropriate zone (head, neck, wrist, or carried) without duplicating body parts",
  };

  const lines = layers.map((g, i) => {
    const hint =
      categoryInstructions[g.category.toLowerCase()] ||
      "place naturally on the body";
    const scaleHint =
      typeof g.positionData.scale === "number" ?
        ` (scale guide ~${g.positionData.scale.toFixed(2)})` :
        "";
    return `- Image ${i + 2}: **${g.category}** — ${hint}${scaleHint}`;
  });

  const prompt = `You are an AI fashion visualization expert.

Image 1 is one full-body person on a **transparent PNG** background.

The following ${layers.length} images are **separate product photos** of clothing or accessories. Apply **all of them at once** to the **same person** in image 1 so they appear to be wearing the **complete outfit** together:

${lines.join("\n")}

Rules:
1. Preserve the person's identity, pose, and proportions from image 1.
2. Warp and perspective-match each garment to the body; do not paste flat rectangles.
3. **Shirt/top/dress/jacket** and **pants/skirt** must both appear if both are provided; if a **dress** covers the lower body, do not add conflicting separate bottoms.
4. Match lighting and add subtle contact shadows; edges must blend naturally.
5. Keep the background **fully transparent** outside the person, like image 1.
6. Ignore mannequins, hangers, or hands in product images — only the garment design matters.

Return ONLY the final composite as base64-encoded PNG with transparent background.`;

  const parts: Array<
    | {text: string}
    | {inline_data: {mime_type: string; data: string}}
  > = [{text: prompt}, {
    inline_data: {mime_type: "image/png", data: avatarBase64},
  }];

  for (const g of layers) {
    parts.push({
      inline_data: {mime_type: "image/png", data: g.clothingBase64},
    });
  }

  const body = {
    contents: [{parts}],
    generationConfig: imageGenerationConfig,
  };

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
    }

    const json = (await response.json()) as GeminiResponse;
    const candidates = json.candidates;

    if (!candidates || !candidates.length) {
      throw new Error("No candidates returned from Gemini API");
    }

    const respParts = candidates[0]?.content?.parts;
    if (!respParts || !respParts.length) {
      throw new Error("No content parts in Gemini response");
    }

    const imagePart = respParts.find((p) => partImageBase64(p));
    const img = imagePart && partImageBase64(imagePart);
    if (img) {
      return img;
    }

    const textPart = respParts.find((p) => p.text);
    if (textPart?.text) {
      const base64Match = textPart.text.match(
        /data:image\/png;base64,([A-Za-z0-9+/=]+)/
      );
      if (base64Match && base64Match[1]) {
        return base64Match[1];
      }
    }

    throw new Error("Could not extract image data from Gemini response");
  } catch (error) {
    functions.logger.error(
      "Error calling Gemini API for multi-garment blend:",
      error
    );
    throw error;
  }
}
