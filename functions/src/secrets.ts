import {defineSecret} from "firebase-functions/params";

/** Set with: firebase functions:secrets:set GEMINI_API_KEY */
export const geminiApiKey = defineSecret("GEMINI_API_KEY");
