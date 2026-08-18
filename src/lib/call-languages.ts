import { supabase } from "@/integrations/supabase/client";

/** Audio/video calls are only for these profile languages. */
export const INDIAN_CALL_LANGUAGES = [
  "Hindi",
  "Bengali",
  "Marathi",
  "Telugu",
  "Tamil",
] as const;

export const MAX_ACTIVE_CALL_USERS_PER_LANGUAGE = 15;

const CALL_LANGUAGE_ALIASES: Record<string, string> = {
  hindi: "hindi",
  hi: "hindi",
  bengali: "bengali",
  bangla: "bengali",
  bn: "bengali",
  marathi: "marathi",
  mr: "marathi",
  telugu: "telugu",
  te: "telugu",
  tamil: "tamil",
  ta: "tamil",
};

export function normalizeCallLanguage(lang?: string | null): string {
  const raw = (lang || "").trim().toLowerCase();
  if (!raw) return "";
  return CALL_LANGUAGE_ALIASES[raw] || raw;
}

export function isIndianCallLanguage(lang?: string | null): boolean {
  const n = normalizeCallLanguage(lang);
  return n === "hindi" || n === "bengali" || n === "marathi" || n === "telugu" || n === "tamil";
}

export function resolveProfileLanguage(profile?: {
  preferred_language?: string | null;
  primary_language?: string | null;
  language?: string | null;
} | null): string {
  return (
    profile?.preferred_language?.trim() ||
    profile?.primary_language?.trim() ||
    profile?.language?.trim() ||
    ""
  );
}

/** Same Indian call language on both profiles. */
export function canCallEachOther(a?: string | null, b?: string | null): boolean {
  if (!isIndianCallLanguage(a) || !isIndianCallLanguage(b)) return false;
  return normalizeCallLanguage(a) === normalizeCallLanguage(b);
}

export const CALL_LANGUAGE_UNAVAILABLE =
  "Audio and video calls are only available if your profile language is Hindi, Bengali, Marathi, Telugu, or Tamil.";

export const CALL_LANGUAGE_CAP_REACHED =
  "This language already has 15 people on audio/video calls. Try again later.";

export async function assertLanguageCallCapacity(
  language: string,
  slotsNeeded = 1,
): Promise<{ allowed: boolean; count: number; error?: string }> {
  const { data, error } = await supabase.rpc("assert_language_call_capacity", {
    p_language: language,
    p_slots: slotsNeeded,
  });
  if (error) {
    console.warn("[Calls] capacity RPC unavailable:", error.message);
    if (!isIndianCallLanguage(language)) {
      return { allowed: false, count: 0, error: CALL_LANGUAGE_UNAVAILABLE };
    }
    // RPC not deployed yet — still allow if the language is eligible.
    return { allowed: true, count: 0 };
  }
  const result = (data || {}) as { allowed?: boolean; count?: number; error?: string };
  return {
    allowed: result.allowed === true,
    count: Number(result.count) || 0,
    error: result.error,
  };
}
