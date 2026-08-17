/**
 * The 22 official languages of India (8th Schedule) + English.
 * Group Chat is restricted to these languages only.
 */
export interface IndianOfficialLang {
  code: string;
  name: string;          // english name (used as translation target name)
  nativeName: string;    // native script display
}

export const INDIAN_OFFICIAL_LANGUAGES: IndianOfficialLang[] = [
  { code: "en",  name: "English",   nativeName: "English" },
  { code: "hi",  name: "Hindi",     nativeName: "हिन्दी" },
  { code: "bn",  name: "Bengali",   nativeName: "বাংলা" },
  { code: "te",  name: "Telugu",    nativeName: "తెలుగు" },
  { code: "mr",  name: "Marathi",   nativeName: "मराठी" },
  { code: "ta",  name: "Tamil",     nativeName: "தமிழ்" },
  { code: "ur",  name: "Urdu",      nativeName: "اردو" },
  { code: "gu",  name: "Gujarati",  nativeName: "ગુજરાતી" },
  { code: "kn",  name: "Kannada",   nativeName: "ಕನ್ನಡ" },
  { code: "ml",  name: "Malayalam", nativeName: "മലയാളം" },
  { code: "or",  name: "Odia",      nativeName: "ଓଡ଼ିଆ" },
  { code: "pa",  name: "Punjabi",   nativeName: "ਪੰਜਾਬੀ" },
  { code: "as",  name: "Assamese",  nativeName: "অসমীয়া" },
  { code: "mai", name: "Maithili",  nativeName: "मैथिली" },
  { code: "sat", name: "Santali",   nativeName: "ᱥᱟᱱᱛᱟᱲᱤ" },
  { code: "ks",  name: "Kashmiri",  nativeName: "कॉशुर" },
  { code: "kok", name: "Konkani",   nativeName: "कोंकणी" },
  { code: "doi", name: "Dogri",     nativeName: "डोगरी" },
  { code: "mni", name: "Manipuri",  nativeName: "মৈতৈলোন্" },
  { code: "brx", name: "Bodo",      nativeName: "बड़ो" },
  { code: "sa",  name: "Sanskrit",  nativeName: "संस्कृतम्" },
  { code: "ne",  name: "Nepali",    nativeName: "नेपाली" },
  { code: "sd",  name: "Sindhi",    nativeName: "سنڌي" },
];

export const INDIAN_OFFICIAL_NAMES_LC = new Set(
  INDIAN_OFFICIAL_LANGUAGES.map(l => l.name.toLowerCase())
);
export const INDIAN_OFFICIAL_CODES = new Set(INDIAN_OFFICIAL_LANGUAGES.map(l => l.code));

/** Resolve any user input (code or name) → canonical english name, or null if not in the 22+English set. */
export function resolveIndianLanguage(input: string | null | undefined): IndianOfficialLang | null {
  if (!input) return null;
  const v = input.trim().toLowerCase();
  return (
    INDIAN_OFFICIAL_LANGUAGES.find(l => l.code === v || l.name.toLowerCase() === v || l.nativeName.toLowerCase() === v) ?? null
  );
}

export function isAllowedGroupChatLanguage(input: string | null | undefined): boolean {
  return resolveIndianLanguage(input) !== null;
}
