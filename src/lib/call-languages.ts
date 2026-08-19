import { supabase } from "@/integrations/supabase/client";
import { INDIAN_OFFICIAL_LANGUAGES } from "@/data/indianOfficialLanguages";

/** 1:1 audio/video calls are only for these profile languages. */
export const INDIAN_CALL_LANGUAGES = [
  "Hindi",
  "Bengali",
  "Marathi",
  "Telugu",
  "Tamil",
] as const;

/** Group calls: all 22 scheduled Indian languages (not English). */
export const GROUP_CALL_LANGUAGES = INDIAN_OFFICIAL_LANGUAGES
  .filter((l) => l.code !== "en")
  .map((l) => l.name);

export const MAX_ACTIVE_CALL_USERS_PER_LANGUAGE = 15;
export const MAX_GROUP_CALL_PARTICIPANTS = 15;

const EXTRA_ALIASES: Record<string, string> = {
  bangla: "bengali",
  bn: "bengali",
  "bn-in": "bengali",
  "bn_in": "bengali",
  বাংলা: "bengali",
  "bengali (india)": "bengali",
  hi: "hindi",
  "hi-in": "hindi",
  "hi_in": "hindi",
  हिन्दी: "hindi",
  हिंदी: "hindi",
  mr: "marathi",
  "mr-in": "marathi",
  "mr_in": "marathi",
  मराठी: "marathi",
  te: "telugu",
  "te-in": "telugu",
  "te_in": "telugu",
  telegu: "telugu",
  telgu: "telugu",
  "telugu (india)": "telugu",
  తెలుగు: "telugu",
  ta: "tamil",
  "ta-in": "tamil",
  "ta_in": "tamil",
  தமிழ்: "tamil",
  oriya: "odia",
  or: "odia",
  panjabi: "punjabi",
  pa: "punjabi",
  meitei: "manipuri",
  meetei: "manipuri",
};

const CALL_LANGUAGE_ALIASES: Record<string, string> = { ...EXTRA_ALIASES };

for (const lang of INDIAN_OFFICIAL_LANGUAGES) {
  if (lang.code === "en") continue;
  const canonical = lang.name.toLowerCase();
  CALL_LANGUAGE_ALIASES[canonical] = canonical;
  CALL_LANGUAGE_ALIASES[lang.code.toLowerCase()] = canonical;
  CALL_LANGUAGE_ALIASES[lang.nativeName.toLowerCase()] = canonical;
}

const GROUP_CALL_LANG_SET = new Set(GROUP_CALL_LANGUAGES.map((n) => n.toLowerCase()));

export function normalizeCallLanguage(lang?: string | null): string {
  const raw = (lang || "").trim().toLowerCase();
  if (!raw) return "";
  if (CALL_LANGUAGE_ALIASES[raw]) return CALL_LANGUAGE_ALIASES[raw];
  const base = raw.split(/[-_]/)[0];
  if (base && CALL_LANGUAGE_ALIASES[base]) return CALL_LANGUAGE_ALIASES[base];
  return raw;
}

export function isIndianCallLanguage(lang?: string | null): boolean {
  const n = normalizeCallLanguage(lang);
  return n === "hindi" || n === "bengali" || n === "marathi" || n === "telugu" || n === "tamil";
}

export function isGroupCallLanguage(lang?: string | null): boolean {
  return GROUP_CALL_LANG_SET.has(normalizeCallLanguage(lang));
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

/** Same Indian 1:1 call language on both profiles. */
export function canCallEachOther(a?: string | null, b?: string | null): boolean {
  if (!isIndianCallLanguage(a) || !isIndianCallLanguage(b)) return false;
  return normalizeCallLanguage(a) === normalizeCallLanguage(b);
}

/** Same group-call language (any scheduled Indian language). */
export function canJoinGroupCall(a?: string | null, b?: string | null): boolean {
  if (!isGroupCallLanguage(a) || !isGroupCallLanguage(b)) return false;
  return normalizeCallLanguage(a) === normalizeCallLanguage(b);
}

export const CALL_LANGUAGE_UNAVAILABLE =
  "Audio and video calls only work when both of you have the same profile language: Hindi, Bengali, Marathi, Telugu, or Tamil.";

export const GROUP_CALL_LANGUAGE_UNAVAILABLE =
  "Group calls are available when your profile language is an Indian language.";

export const GROUP_HOST_TAKEN =
  "This language already has a live group-call host. Try again when they stop.";

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

export async function assertGroupHostLanguageSlot(
  language: string,
): Promise<{ allowed: boolean; error?: string }> {
  if (!isGroupCallLanguage(language)) {
    return { allowed: false, error: GROUP_CALL_LANGUAGE_UNAVAILABLE };
  }
  const { data, error } = await supabase.rpc("assert_group_host_language_slot", {
    p_language: language,
  });
  if (error) {
    console.warn("[Group calls] host-slot RPC unavailable:", error.message);
    return { allowed: true };
  }
  const result = (data || {}) as { allowed?: boolean; error?: string };
  return {
    allowed: result.allowed === true,
    error: result.error,
  };
}
