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
  हिन्दी: "hindi",
  हिंदी: "hindi",
  bengali: "bengali",
  bangla: "bengali",
  bn: "bengali",
  বাংলা: "bengali",
  "bengali (india)": "bengali",
  marathi: "marathi",
  mr: "marathi",
  मराठी: "marathi",
  telugu: "telugu",
  te: "telugu",
  తెలుగు: "telugu",
  tamil: "tamil",
  ta: "tamil",
  தமிழ்: "tamil",
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

/** Prefer mother tongue / call-eligible language over English UI preferred_language. */
export function pickCallLanguage(...candidates: Array<string | null | undefined>): string {
  const names = candidates.map((c) => (c || "").trim()).filter(Boolean);
  const eligible = names.find((n) => isIndianCallLanguage(n));
  return eligible || names[0] || "";
}

export function resolveProfileLanguage(profile?: {
  preferred_language?: string | null;
  primary_language?: string | null;
  language?: string | null;
} | null): string {
  return pickCallLanguage(
    profile?.primary_language,
    profile?.language,
    profile?.preferred_language,
  );
}

export async function fetchCallLanguage(userId: string): Promise<string> {
  const [{ data: profile }, { data: langs }, { data: female }, { data: male }] = await Promise.all([
    supabase
      .from("profiles")
      .select("preferred_language, primary_language, language")
      .eq("user_id", userId)
      .maybeSingle(),
    supabase.from("user_languages").select("language_name").eq("user_id", userId),
    supabase
      .from("female_profiles")
      .select("primary_language, preferred_language")
      .eq("user_id", userId)
      .maybeSingle(),
    supabase
      .from("male_profiles")
      .select("primary_language, preferred_language")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);

  return pickCallLanguage(
    profile?.primary_language,
    female?.primary_language,
    male?.primary_language,
    ...((langs || []) as { language_name?: string | null }[]).map((l) => l.language_name),
    profile?.language,
    profile?.preferred_language,
    female?.preferred_language,
    male?.preferred_language,
  );
}

/** Same Indian call language on both profiles. */
export function canCallEachOther(a?: string | null, b?: string | null): boolean {
  if (!isIndianCallLanguage(a) || !isIndianCallLanguage(b)) return false;
  return normalizeCallLanguage(a) === normalizeCallLanguage(b);
}

export const CALL_LANGUAGE_UNAVAILABLE =
  "Audio and video calls only work when both of you have the same profile language: Hindi, Bengali, Marathi, Telugu, or Tamil.";

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
    return { allowed: true, count: 0 };
  }
  const result = (data || {}) as { allowed?: boolean; count?: number; error?: string };
  return {
    allowed: result.allowed === true,
    count: Number(result.count) || 0,
    error: result.error,
  };
}
