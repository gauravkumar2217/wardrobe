import * as admin from "firebase-admin";

function storageBucketFromFirebaseConfig(): string | undefined {
  const raw = process.env.FIREBASE_CONFIG;
  if (!raw) return undefined;
  try {
    const parsed = JSON.parse(raw) as {storageBucket?: string};
    return parsed.storageBucket;
  } catch {
    return undefined;
  }
}

/**
 * Resolves the default GCS bucket without calling bucket() at module load
 * (Firebase CLI code analysis initializes Admin without storageBucket).
 */
export function getStorageBucket() {
  const app = admin.app();
  const opts = app.options as {storageBucket?: string; projectId?: string};
  const fromEnv = process.env.STORAGE_BUCKET || process.env.GCLOUD_STORAGE_BUCKET;
  const bucketName =
    fromEnv ||
    opts.storageBucket ||
    storageBucketFromFirebaseConfig() ||
    (opts.projectId ? `${opts.projectId}.appspot.com` : undefined);
  if (!bucketName) {
    throw new Error(
      "Storage bucket not configured: set STORAGE_BUCKET or use a credential that includes project_id"
    );
  }
  return admin.storage().bucket(bucketName);
}
