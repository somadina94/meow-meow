/**
 * Centralized Input Validation Library
 * 
 * Provides consistent validation rules across all forms in the app.
 * Uses zod schemas where applicable and plain validators for lightweight checks.
 */

import { z } from "zod";

// ==================== Constants ====================

export const LIMITS = {
  NAME_MIN: 2,
  NAME_MAX: 100,
  BIO_MIN: 10,
  BIO_MAX: 500,
  OCCUPATION_MAX: 50,
  MESSAGE_MAX: 2000,
  GIFT_MESSAGE_MAX: 200,
  HEIGHT_MIN: 100,
  HEIGHT_MAX: 250,
  AGE_MIN: 18,
  AGE_MAX: 100,
  PASSWORD_MIN: 8,
  PASSWORD_MAX: 128,
  EMAIL_MAX: 255,
  PHONE_MIN: 7,
  PHONE_MAX: 15,
} as const;

// ==================== Zod Schemas ====================

export const emailSchema = z
  .string()
  .trim()
  .min(1, "Email is required")
  .max(LIMITS.EMAIL_MAX, `Email must be less than ${LIMITS.EMAIL_MAX} characters`)
  .email("Please enter a valid email address")
  .transform(v => v.toLowerCase());

export const passwordSchema = z
  .string()
  .min(LIMITS.PASSWORD_MIN, `Password must be at least ${LIMITS.PASSWORD_MIN} characters`)
  .max(LIMITS.PASSWORD_MAX, `Password must be less than ${LIMITS.PASSWORD_MAX} characters`)
  .regex(/[A-Z]/, "Must contain at least one uppercase letter")
  .regex(/[a-z]/, "Must contain at least one lowercase letter")
  .regex(/[0-9]/, "Must contain at least one number")
  .regex(/[!@#$%^&*(),.?":{}|<>]/, "Must contain at least one special character");

export const phoneSchema = z
  .string()
  .trim()
  .min(1, "Phone number is required")
  .transform(v => v.replace(/[\s\-()]/g, ""))
  .refine(v => /^\+?[1-9]\d{6,14}$/.test(v), "Please enter a valid phone number");

export const nameSchema = z
  .string()
  .trim()
  .min(LIMITS.NAME_MIN, `Name must be at least ${LIMITS.NAME_MIN} characters`)
  .max(LIMITS.NAME_MAX, `Name must be less than ${LIMITS.NAME_MAX} characters`)
  .regex(/^[a-zA-Z\s'.À-ÿ\u0900-\u097F\u0980-\u09FF\u0A00-\u0A7F\u0B00-\u0B7F\u0C00-\u0C7F\u0D00-\u0D7F\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uAC00-\uD7AF\u0600-\u06FF-]+$/, "Name contains invalid characters");

export const bioSchema = z
  .string()
  .trim()
  .min(LIMITS.BIO_MIN, `Bio must be at least ${LIMITS.BIO_MIN} characters`)
  .max(LIMITS.BIO_MAX, `Bio must be less than ${LIMITS.BIO_MAX} characters`);

export const heightSchema = z
  .number()
  .int("Height must be a whole number")
  .min(LIMITS.HEIGHT_MIN, `Height must be at least ${LIMITS.HEIGHT_MIN} cm`)
  .max(LIMITS.HEIGHT_MAX, `Height must be at most ${LIMITS.HEIGHT_MAX} cm`);

export const occupationSchema = z
  .string()
  .trim()
  .min(1, "Occupation is required")
  .max(LIMITS.OCCUPATION_MAX, `Occupation must be less than ${LIMITS.OCCUPATION_MAX} characters`);

export const messageSchema = z
  .string()
  .trim()
  .min(1, "Message cannot be empty")
  .max(LIMITS.MESSAGE_MAX, `Message must be less than ${LIMITS.MESSAGE_MAX} characters`);

export const giftMessageSchema = z
  .string()
  .trim()
  .max(LIMITS.GIFT_MESSAGE_MAX, `Message must be less than ${LIMITS.GIFT_MESSAGE_MAX} characters`)
  .optional();

// ==================== Profile Edit Schema ====================

export const profileEditSchema = z.object({
  full_name: nameSchema.nullable().optional(),
  bio: z.string().trim().max(LIMITS.BIO_MAX).nullable().optional(),
  occupation: z.string().trim().max(LIMITS.OCCUPATION_MAX).nullable().optional(),
  height_cm: z.number().int().min(LIMITS.HEIGHT_MIN).max(LIMITS.HEIGHT_MAX).nullable().optional(),
  education_level: z.string().nullable().optional(),
  body_type: z.string().nullable().optional(),
  marital_status: z.string().nullable().optional(),
  religion: z.string().nullable().optional(),
  country: z.string().nullable().optional(),
  state: z.string().nullable().optional(),
});

// ==================== Utility Functions ====================

/**
 * Sanitize text input to prevent XSS
 * Strips HTML tags and trims whitespace
 */
export function sanitizeText(input: string): string {
  return input
    .replace(/<[^>]*>/g, "") // Strip HTML tags
    .replace(/&[^;]+;/g, "") // Strip HTML entities
    .trim();
}

/**
 * Validate and sanitize a URL to prevent open redirects
 */
export function isValidRedirectUrl(url: string): boolean {
  try {
    const parsed = new URL(url, window.location.origin);
    return parsed.origin === window.location.origin;
  } catch {
    return false;
  }
}

/**
 * Validate file upload
 */
export function validateFileUpload(
  file: File,
  options: {
    maxSizeMB?: number;
    allowedTypes?: string[];
    allowedExtensions?: string[];
  } = {}
): { valid: boolean; error?: string } {
  const { maxSizeMB = 10, allowedTypes, allowedExtensions } = options;

  // Check file size
  if (file.size > maxSizeMB * 1024 * 1024) {
    return { valid: false, error: `File must be smaller than ${maxSizeMB}MB` };
  }

  // Check MIME type
  if (allowedTypes && !allowedTypes.some(t => file.type.startsWith(t))) {
    return { valid: false, error: `File type "${file.type}" is not allowed` };
  }

  // Check extension
  if (allowedExtensions) {
    const ext = file.name.split(".").pop()?.toLowerCase();
    if (!ext || !allowedExtensions.includes(ext)) {
      return { valid: false, error: `File extension ".${ext}" is not allowed` };
    }
  }

  // Block dangerous file types
  const dangerousExtensions = ["exe", "bat", "cmd", "sh", "ps1", "vbs", "js", "msi", "vcf", "vcard"];
  const ext = file.name.split(".").pop()?.toLowerCase();
  if (ext && dangerousExtensions.includes(ext)) {
    return { valid: false, error: "This file type is not allowed for security reasons" };
  }

  return { valid: true };
}

/**
 * Image upload validation
 */
export function validateImageUpload(file: File, maxSizeMB = 10) {
  return validateFileUpload(file, {
    maxSizeMB,
    allowedTypes: ["image/"],
    allowedExtensions: ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"],
  });
}

/**
 * Rate limiter for client-side operations
 */
export class ClientRateLimiter {
  private attempts: number[] = [];
  
  constructor(
    private maxAttempts: number,
    private windowMs: number
  ) {}

  canProceed(): boolean {
    const now = Date.now();
    this.attempts = this.attempts.filter(t => now - t < this.windowMs);
    if (this.attempts.length >= this.maxAttempts) return false;
    this.attempts.push(now);
    return true;
  }

  getRemainingWaitMs(): number {
    if (this.attempts.length < this.maxAttempts) return 0;
    const oldest = this.attempts[0];
    return Math.max(0, this.windowMs - (Date.now() - oldest));
  }
}

// Shared rate limiters
export const authRateLimiter = new ClientRateLimiter(5, 60_000); // 5 per minute
export const chatRateLimiter = new ClientRateLimiter(30, 60_000); // 30 per minute
export const giftRateLimiter = new ClientRateLimiter(10, 60_000); // 10 per minute
