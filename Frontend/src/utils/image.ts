import { API_URL } from "@/constants";

export const ACCEPTED_IMAGE_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;

export const MAX_IMAGE_FILE_SIZE = 2 * 1024 * 1024;

export const ACCEPTED_IMAGE_INPUT = ACCEPTED_IMAGE_TYPES.join(",");

export function resolveImageUrl(imageUrl: string | null | undefined): string | null {
  if (!imageUrl) return null;
  if (/^(https?:|data:|blob:)/i.test(imageUrl)) return imageUrl;
  let origin = "";
  try {
    origin = new URL(API_URL).origin;
  } catch {
    origin = "";
  }
  return `${origin}${imageUrl.startsWith("/") ? "" : "/"}${imageUrl}`;
}

export function validateProductImage(file: File): string | null {
  if (!ACCEPTED_IMAGE_TYPES.includes(file.type as (typeof ACCEPTED_IMAGE_TYPES)[number])) {
    return "Unsupported file type. Please choose a JPEG, PNG or WebP image.";
  }
  if (file.size > MAX_IMAGE_FILE_SIZE) {
    return "Image is too large. Maximum size is 2 MB.";
  }
  return null;
}
