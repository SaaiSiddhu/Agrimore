// Bounded real JPEG decoding/re-encoding, not MIME-only validation.
import * as jpeg from "jpeg-js";
import { HttpsError } from "firebase-functions/v2/https";
export const MAX_PHOTO_BYTES = 2 * 1024 * 1024;
function invalid(): never { throw new HttpsError("invalid-argument", "Select a valid JPEG photo within the upload limits."); }
export function photoInput(value: unknown): Buffer {
 if (typeof value !== "string" || !value.length || value.length > Math.ceil(MAX_PHOTO_BYTES / 3) * 4 || value.length % 4 !== 0 || !/^[A-Za-z0-9+/]*={0,2}$/.test(value)) invalid();
 const input = Buffer.from(value, "base64");
 if (!input.length || input.length > MAX_PHOTO_BYTES || input.toString("base64") !== value) invalid();
 return input;
}
export function normalizePhoto(input: Buffer): Buffer {
 try {
   if (input.length < 4 || input[0] !== 255 || input[1] !== 216 || input.length > MAX_PHOTO_BYTES) invalid();
   const image = jpeg.decode(input, { useTArray: true, formatAsRGBA: true, tolerantDecoding: false, maxResolutionInMP: 1.1, maxMemoryUsageInMB: 32 });
   if (!Number.isInteger(image.width) || !Number.isInteger(image.height) || image.width < 1 || image.height < 1 || image.width > 1024 || image.height > 1024 || image.width * image.height > 1024 * 1024) invalid();
   // Rebuild from pixels only: do not carry EXIF/comments/appended input metadata.
   const output = Buffer.from(jpeg.encode({ width: image.width, height: image.height, data: image.data }, 80).data);
   if (!output.length || output.length > MAX_PHOTO_BYTES) invalid();
   return output;
 } catch { return invalid(); }
}
