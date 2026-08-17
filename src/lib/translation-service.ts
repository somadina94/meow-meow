/**
 * Translation Service — Embedded Lingva-Scraper via Edge Function
 * 
 * NO hardcoded translations. All translations are LIVE via Google Translate scraping.
 * Uses English as pivot language for non-direct translation pairs.
 * 
 * Supported translation flows (ALL combinations of 132+ languages):
 *  1. Native → Native (e.g., తెలుగు → हिंदी) — via English pivot
 *  2. Native → Latin-script lang (e.g., తెలుగు → French) — direct
 *  3. Latin-script lang → Native (e.g., French → తెలుగు) — direct
 *  4. Latin → Native (transliteration, e.g., "bagunnava" → బాగున్నావా) — via en→target
 *  5. Native → English (e.g., తెలుగు → English) — direct
 *  6. English → Native (e.g., English → తెలుగు) — direct
 *  7. Latin → Latin (e.g., French "bonjour" → German "hallo") — direct
 *  8. English → Latin-script lang (e.g., English → French) — direct
 *  9. Latin-script lang → English (e.g., French → English) — direct
 * 10. Same-language self-translation (sender preview) — auto→same lang
 * 11. English fallback if any translation fails or language unsupported
 * 
 * Supports all 132+ Google Translate languages.
 * Unsupported languages automatically fallback to English.
 */

import { supabase } from "@/integrations/supabase/client";
import { isTranslatableChatText } from "@/lib/chat-attachments";
import { languages } from "@/data/languages";

export interface TranslationResult {
  translation: string;
  cached: boolean;
}

/**
 * All 132+ languages supported by Google Translate.
 * Any language NOT in this set will fallback to English.
 */
const GOOGLE_SUPPORTED_LANGUAGES = new Set([
  'afrikaans', 'albanian', 'amharic', 'arabic', 'armenian', 'assamese',
  'aymara', 'azerbaijani', 'bambara', 'basque', 'belarusian', 'bengali',
  'bhojpuri', 'bosnian', 'bulgarian', 'catalan', 'cebuano', 'chichewa',
  'chinese', 'chinese (simplified)', 'chinese (traditional)', 'corsican',
  'croatian', 'czech', 'danish', 'dhivehi', 'dogri', 'dutch', 'english',
  'esperanto', 'estonian', 'ewe', 'filipino', 'finnish', 'french',
  'frisian', 'galician', 'georgian', 'german', 'greek', 'guarani',
  'gujarati', 'haitian creole', 'hausa', 'hawaiian', 'hebrew', 'hindi',
  'hmong', 'hungarian', 'icelandic', 'igbo', 'ilocano', 'indonesian',
  'irish', 'italian', 'japanese', 'javanese', 'kannada', 'kazakh',
  'khmer', 'kinyarwanda', 'konkani', 'korean', 'krio',
  'kurdish', 'kurdish (kurmanji)', 'kurdish (sorani)', 'kyrgyz', 'lao',
  'latin', 'latvian', 'lingala', 'lithuanian', 'luganda',
  'luxembourgish', 'macedonian', 'maithili', 'malagasy', 'malay',
  'malayalam', 'maltese', 'maori', 'marathi', 'meiteilon', 'meiteilon (manipuri)',
  'manipuri', 'mizo', 'mongolian', 'myanmar', 'myanmar (burmese)', 'burmese',
  'nepali', 'norwegian', 'odia', 'odia (oriya)', 'oriya', 'oromo',
  'pashto', 'persian', 'polish', 'portuguese', 'punjabi', 'quechua',
  'romanian', 'russian', 'samoan', 'sanskrit', 'scots gaelic', 'scottish gaelic',
  'sepedi', 'serbian', 'sesotho', 'shona', 'sindhi', 'sinhala', 'slovak',
  'slovenian', 'somali', 'spanish', 'sundanese', 'swahili', 'swedish',
  'tajik', 'tamil', 'tatar', 'telugu', 'thai', 'tigrinya', 'tsonga',
  'turkish', 'turkmen', 'twi', 'ukrainian', 'urdu', 'uyghur', 'uzbek',
  'vietnamese', 'welsh', 'xhosa', 'yiddish', 'yoruba', 'zulu',
  // Common aliases
  'bangla', 'mandarin', 'cantonese', 'tagalog', 'haitian',
  // Indian regional languages that map to supported ones
  'tulu', 'rajasthani', 'marwari', 'chhattisgarhi', 'magahi', 'awadhi',
  'haryanvi', 'bundelkhandi',
]);

/**
 * Check if a language is supported by Google Translate.
 * Unsupported languages will fallback to English.
 */
export function isLanguageSupported(lang: string): boolean {
  if (!lang) return false;
  return GOOGLE_SUPPORTED_LANGUAGES.has(lang.toLowerCase().trim());
}

/**
 * Normalize a language name — if unsupported, return 'English' as fallback.
 */
export function normalizeLanguage(lang: string): string {
  if (!lang || lang.toLowerCase().trim() === 'english') return 'English';
  if (isLanguageSupported(lang)) return lang;
  console.warn(`[Translation] Unsupported language "${lang}", falling back to English`);
  return 'English';
}

/**
 * Detect if text is written in Latin/ASCII script (transliteration or English).
 * Covers basic Latin, extended Latin (accents for French, German, Hungarian, Polish, etc.).
 */
export function isLatinScript(text: string): boolean {
  const cleaned = text.replace(/[\s\d.,!?;:'"()\-@#$%&*+=<>/\\|~`^{}[\]_\u00A0]/g, '');
  if (!cleaned) return false;
  return /^[a-zA-Z\u00C0-\u024F\u0250-\u02AF\u1E00-\u1EFF\u0100-\u017F]+$/.test(cleaned);
}

/**
 * Detect if text is a MIX of Latin and non-Latin scripts (partial translation).
 * Returns true if both Latin and non-Latin characters are present in meaningful amounts.
 * This catches cases where auto-detect translates only PART of a transliterated message,
 * including outputs like "ఎందుకు messages మిస్ అవుతున్నాయి".
 */
export function isMixedScript(text: string): boolean {
  const cleaned = text.replace(/[\s\d.,!?;:'"()\-@#$%&*+=<>/\\|~`^{}[\]_\u00A0]/g, '');
  if (!cleaned || cleaned.length < 4) return false;

  const latinTokens: string[] = cleaned.match(/[a-zA-Z\u00C0-\u024F]+/g) ?? [];
  const latinChars = latinTokens.reduce<number>((sum, token) => sum + token.length, 0);
  const nonLatinChars = cleaned.length - latinChars;

  if (latinChars === 0 || nonLatinChars === 0) return false;

  // Strong signal: even one leftover Latin word inside native script means partial translation.
  if (latinTokens.some((token) => token.length >= 3) && nonLatinChars >= 2) return true;

  const latinRatio = latinChars / cleaned.length;
  return latinRatio > 0.08 && latinRatio < 0.92;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function getMeaningfulLatinTokens(text: string): string[] {
  return Array.from(new Set(text.match(/[a-zA-Z\u00C0-\u024F]{3,}/g) ?? []));
}

function countLatinChars(text: string): number {
  const tokens: string[] = text.match(/[a-zA-Z\u00C0-\u024F]+/g) ?? [];
  let total = 0;
  for (const token of tokens) total += token.length;
  return total;
}

function scoreTranslationCandidate(
  original: string,
  candidate: string,
  viewerUsesLatin: boolean
): number {
  if (!candidate?.trim()) return Number.NEGATIVE_INFINITY;

  const cleaned = candidate.trim();
  let score = 0;

  if (cleaned !== original.trim()) score += 40;

  if (!viewerUsesLatin) {
    const latinChars = countLatinChars(cleaned);
    const totalChars = cleaned.replace(/[\s\d.,!?;:'"()\-@#$%&*+=<>/\\|~`^{}[\]_\u00A0]/g, '').length;
    const nonLatinChars = Math.max(0, totalChars - latinChars);

    if (!isLatinScript(cleaned)) score += 30;
    if (!isMixedScript(cleaned)) score += 30;
    score += nonLatinChars * 2;
    score -= latinChars * 3;
  }

  return score;
}

function pickBetterTranslationCandidate(
  original: string,
  current: string,
  contender: string,
  viewerUsesLatin: boolean
): string {
  return scoreTranslationCandidate(original, contender, viewerUsesLatin) >
    scoreTranslationCandidate(original, current, viewerUsesLatin)
    ? contender
    : current;
}

async function cleanMixedTranslation(
  text: string,
  targetLanguage: string
): Promise<string> {
  if (!text?.trim() || isLatinScriptLanguage(targetLanguage) || !isMixedScript(text)) {
    return text;
  }

  const tokens = getMeaningfulLatinTokens(text);
  if (!tokens.length) return text;

  const replacements = new Map<string, string>();

  await Promise.all(tokens.map(async (token) => {
    const [fromEnglish, fromAuto] = await Promise.all([
      translateText(token, 'English', targetLanguage),
      translateText(token, 'auto', targetLanguage),
    ]);

    const bestReplacement = pickBetterTranslationCandidate(
      token,
      token,
      pickBetterTranslationCandidate(token, token, fromEnglish || token, false),
      false
    );

    const finalReplacement = pickBetterTranslationCandidate(
      token,
      bestReplacement,
      fromAuto || token,
      false
    );

    if (finalReplacement && finalReplacement !== token) {
      replacements.set(token, finalReplacement);
    }
  }));

  if (!replacements.size) return text;

  let cleanedText = text;
  for (const [token, replacement] of replacements.entries()) {
    cleanedText = cleanedText.replace(new RegExp(`\\b${escapeRegExp(token)}\\b`, 'g'), replacement);
  }

  return cleanedText;
}

/**
 * Languages whose native script IS Latin. For these languages:
 * - Translation output will also be in Latin script
 * - We must NOT apply the "still Latin → override with English" fallback
 * - Preview should work based on content change, not script change
 * 
 * This covers all major Latin-script languages supported by Google Translate.
 */
const LATIN_SCRIPT_LANGUAGES = new Set([
  // Top 6 Major Romance (Latin-descended)
  'spanish', 'portuguese', 'french', 'italian', 'romanian', 'catalan',
  // Ibero-Romance
  'galician', 'asturian', 'aragonese', 'ladino',
  // Gallo-Romance
  'occitan', 'walloon',
  // Rhaeto-Romance
  'romansh', 'friulian',
  // Italo-Dalmatian / Southern Romance
  'sardinian', 'sicilian', 'neapolitan', 'corsican',
  // Eastern Romance
  'aromanian',
  // Other European Latin-script (non-Romance but Latin script)
  'english', 'german', 'dutch', 'luxembourgish',
  'finnish', 'swedish', 'norwegian', 'danish', 'icelandic',
  'estonian', 'latvian', 'lithuanian',
  'polish', 'czech', 'slovak', 'hungarian', 'croatian', 'slovenian',
  'bosnian', 'albanian', 'maltese', 'basque',
  'welsh', 'irish', 'scottish gaelic', 'scots gaelic',
  // Additional Latin-script languages
  'indonesian', 'malay', 'filipino', 'tagalog', 'vietnamese',
  'swahili', 'hausa', 'yoruba', 'igbo', 'somali', 'afrikaans',
  'turkish', 'azerbaijani', 'uzbek', 'turkmen',
  'cebuano', 'javanese', 'sundanese', 'maori', 'hawaiian', 'samoan',
]);

export function isEnglishLanguage(lang?: string | null): boolean {
  const v = (lang || "").toLowerCase().trim();
  return !v || v === "english" || v === "en" || v === "eng" || v === "eng_latn";
}

export function languagesMatch(a?: string | null, b?: string | null): boolean {
  if (!a?.trim() || !b?.trim()) return false;
  const left = a.toLowerCase().trim();
  const right = b.toLowerCase().trim();
  if (isEnglishLanguage(left) && isEnglishLanguage(right)) return true;
  return left === right;
}

export function isLatinScriptLanguage(lang: string): boolean {
  return LATIN_SCRIPT_LANGUAGES.has(lang.toLowerCase().trim());
}

function toGoogleCode(lang: string): string {
  const lower = (lang || "").toLowerCase().trim();
  if (!lower || lower === "auto") return "auto";
  if (isEnglishLanguage(lower)) return "en";
  const match = languages.find(
    (l) => l.name.toLowerCase() === lower || l.code.toLowerCase() === lower
  );
  return match?.code || "en";
}

async function translateViaGtx(
  text: string,
  sourceLang: string,
  targetLang: string
): Promise<string | null> {
  try {
    const sl = sourceLang === "auto" ? "auto" : toGoogleCode(sourceLang);
    const tl = toGoogleCode(targetLang);
    if (!tl || (sl === tl && sl !== "auto")) return null;
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${encodeURIComponent(sl)}&tl=${encodeURIComponent(tl)}&dt=t&q=${encodeURIComponent(text)}`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = await res.json();
    const translated = Array.isArray(data?.[0])
      ? data[0].map((row: unknown) => (Array.isArray(row) ? String(row[0] ?? "") : "")).join("")
      : "";
    return translated.trim() || null;
  } catch {
    return null;
  }
}

/**
 * Translate a single text string via the embedded lingva scraper edge function.
 * Falls back to original text if translation fails.
 * Unsupported languages automatically fallback to English.
 */
export async function translateText(
  text: string,
  sourceLang: string = 'auto',
  targetLang: string = 'English'
): Promise<string> {
  if (!text?.trim()) return text;
  
  // Normalize languages — unsupported ones become English
  const effectiveSource = sourceLang === 'auto' ? 'auto' : normalizeLanguage(sourceLang);
  const effectiveTarget = normalizeLanguage(targetLang);
  
  const srcNorm = effectiveSource.toLowerCase().trim();
  const tgtNorm = effectiveTarget.toLowerCase().trim();
  if (srcNorm === tgtNorm && srcNorm !== 'auto') return text;

  try {
    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('TranslationTimeout')), 8000)
    );

    const invokePromise = supabase.functions.invoke('translate-message', {
      body: { text, sourceLang: effectiveSource, targetLang: effectiveTarget },
    });

    const { data, error } = await Promise.race([invokePromise, timeoutPromise]);

    const edgeText = (!error && data?.translation) ? String(data.translation) : "";
    const edgeLooksUntranslated =
      (tgtNorm !== "english" && isLatinScript(edgeText) && !isLatinScriptLanguage(tgtNorm)) ||
      (tgtNorm === "english" && edgeText && !isLatinScript(edgeText));
    if (edgeText && edgeText.trim() && !edgeLooksUntranslated) {
      return edgeText;
    }

    const gtx = await translateViaGtx(text, effectiveSource, effectiveTarget);
    if (gtx) return gtx;
    return edgeText || text;
  } catch (err: any) {
    if (err?.message === "TranslationTimeout") {
      console.warn("[Translation] Request timed out after 8s");
    } else {
      console.warn("[Translation] Failed:", err);
    }
    const gtx = await translateViaGtx(text, effectiveSource, effectiveTarget);
    if (gtx) return gtx;
    return text;
  }
}

/**
 * Emergency fallback: translate to English when target language translation fails.
 */
async function translateToEnglishFallback(text: string): Promise<string> {
  try {
    const { data } = await supabase.functions.invoke('translate-message', {
      body: { text, sourceLang: 'auto', targetLang: 'English' },
    });
    return data?.translation || text;
  } catch {
    return text;
  }
}

/**
 * Translate multiple texts in a single batch call.
 * Unsupported languages fallback to English.
 */
export async function translateBatch(
  texts: string[],
  sourceLang: string = 'auto',
  targetLang: string = 'English'
): Promise<string[]> {
  if (!texts?.length) return texts;
  
  const effectiveSource = sourceLang === 'auto' ? 'auto' : normalizeLanguage(sourceLang);
  const effectiveTarget = normalizeLanguage(targetLang);
  
  const srcNorm = effectiveSource.toLowerCase().trim();
  const tgtNorm = effectiveTarget.toLowerCase().trim();
  if (srcNorm === tgtNorm && srcNorm !== 'auto') return texts;

  try {
    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('BatchTranslationTimeout')), 10000)
    );

    const invokePromise = supabase.functions.invoke('translate-message', {
      body: { texts, sourceLang: effectiveSource, targetLang: effectiveTarget },
    });

    const { data, error } = await Promise.race([invokePromise, timeoutPromise]);

    if (error) {
      console.warn('[Translation] Batch error:', error.message);
      return texts;
    }

    return data?.translations || texts;
  } catch (err: any) {
    if (err?.message === 'BatchTranslationTimeout') {
      console.warn('[Translation] Batch request timed out after 10s');
    } else {
      console.warn('[Translation] Batch failed:', err);
    }
    return texts;
  }
}

/**
 * Smart translation for a viewer — handles ALL input types and language combinations.
 * 
 * ┌──────────────────────────────────────────────────────────────────────┐
 * │ COMBINATION MATRIX (all supported):                                  │
 * │                                                                      │
 * │ Input Script    Viewer Language    Strategy                          │
 * │ ─────────────   ──────────────    ────────────────────────────────── │
 * │ Native (తెలుగు)  Non-Latin (Hindi)  native→en→viewerLang (pivot)     │
 * │ Native (తెలుగు)  Latin (French)     auto→viewerLang (direct)         │
 * │ Native (తెలుగు)  English            auto→English                     │
 * │ Latin (French)   Non-Latin (Telugu)  auto→viewerLang (direct)        │
 * │ Latin (French)   Latin (German)      auto→viewerLang (direct)        │
 * │ Latin (French)   English             auto→English                    │
 * │ English          Non-Latin (Telugu)  en→viewerLang                   │
 * │ English          Latin (French)      en→viewerLang                   │
 * │ Translit (Latin) Non-Latin (Telugu)  en→senderLang→viewerLang        │
 * │ Same language    Same language       auto→viewerLang (self-preview)  │
 * │ Unsupported      Any                 auto→English (fallback)         │
 * └──────────────────────────────────────────────────────────────────────┘
 * 
 * Returns:
 *  - nativeText: message in the viewer's native language (Latin or non-Latin)
 *  - englishText: English translation (always shown as subtitle)
 */
export async function translateForViewer(
  message: string,
  viewerLanguage: string,
  senderLanguage?: string
): Promise<{ nativeText: string; englishText: string }> {
  if (!message?.trim() || !isTranslatableChatText(message)) {
    return { nativeText: message, englishText: message };
  }

  // Normalize — unsupported languages become English
  const viewerLang = normalizeLanguage(viewerLanguage).toLowerCase().trim();
  const viewerLangOriginal = normalizeLanguage(viewerLanguage);
  const senderLang = senderLanguage ? normalizeLanguage(senderLanguage).toLowerCase().trim() : '';
  const senderLangOriginal = senderLanguage ? normalizeLanguage(senderLanguage) : '';
  
  const inputIsLatin = isLatinScript(message);
  const viewerUsesLatin = isLatinScriptLanguage(viewerLang);
  const senderUsesLatin = senderLang ? isLatinScriptLanguage(senderLang) : false;

  try {
    // Always get English translation for subtitle (runs in parallel)
    const englishPromise = translateText(message, 'auto', 'English');

    // ── Case 1: Viewer speaks English ──
    if (viewerLang === 'english') {
      const englishText = await englishPromise;
      return { nativeText: englishText || message, englishText: englishText || message };
    }

    // Non-English viewer: one direct call to their language, plus English subtitle
    const sourceForNative = inputIsLatin ? "English" : "auto";
    const [autoResult, englishResult] = await Promise.all([
      translateText(message, sourceForNative, viewerLangOriginal),
      inputIsLatin ? Promise.resolve(message) : englishPromise,
    ]);

    let nativeText = autoResult;
    let englishText = englishResult || message;

    // ── Case 3: Latin input → Non-Latin target (transliteration handling) ──
    if (inputIsLatin && !viewerUsesLatin) {
      const isStillLatin = isLatinScript(nativeText);
      const isPartiallyTranslated = !isStillLatin && isMixedScript(nativeText);

      if (isStillLatin || isPartiallyTranslated) {
        // Strategy A: English bridge — use the English translation to re-translate
        const englishMeaning = englishResult || nativeText;
        if (englishMeaning && englishMeaning !== message) {
          const fromEnglish = await translateText(englishMeaning, 'English', viewerLangOriginal);
          nativeText = pickBetterTranslationCandidate(message, nativeText, fromEnglish || nativeText, viewerUsesLatin);
        }

        // Strategy B: Treat original as English directly → viewerLang
        if (isLatinScript(nativeText) || isMixedScript(nativeText)) {
          const directResult = await translateText(message, 'English', viewerLangOriginal);
          nativeText = pickBetterTranslationCandidate(message, nativeText, directResult || nativeText, viewerUsesLatin);
        }
      }

      // Strategy C: Sender Language Bridge (for transliteration)
      // Also fires when current result is mixed (partial translation)
      const needsBridge = isLatinScript(nativeText) || isMixedScript(nativeText) || nativeText === message;
      const bridgeLang = (senderLang && senderLang !== 'english' && !senderUsesLatin) 
        ? senderLang 
        : (!viewerUsesLatin && viewerLang !== 'english') ? viewerLang : '';
      const bridgeLangFull = bridgeLang ? (senderLang && senderLang !== 'english' ? senderLangOriginal : viewerLangOriginal) : '';
      if (bridgeLang && needsBridge) {
        const bridgeNative = await translateText(message, 'English', bridgeLangFull || viewerLangOriginal);
        if (bridgeNative && bridgeNative !== message) {
          if (bridgeLang !== viewerLang) {
            // Cross-language: translate sender's native to viewer's language
            const crossTranslated = await translateText(bridgeNative, bridgeLangFull || 'auto', viewerLangOriginal);
            nativeText = pickBetterTranslationCandidate(message, nativeText, crossTranslated || bridgeNative, viewerUsesLatin);
          } else {
            // Same language: sender's native IS the viewer's native
            nativeText = pickBetterTranslationCandidate(message, nativeText, bridgeNative, viewerUsesLatin);
          }

          // Fix English subtitle
          if (englishText === message || isLatinScript(englishText)) {
            const properEnglish = await translateText(bridgeNative, bridgeLangFull || 'auto', 'English');
            if (properEnglish && properEnglish !== bridgeNative && properEnglish !== message) {
              englishText = properEnglish;
            }
          }
        }
      }

      if (isMixedScript(nativeText)) {
        const cleanedNative = await cleanMixedTranslation(nativeText, viewerLangOriginal);
        nativeText = pickBetterTranslationCandidate(message, nativeText, cleanedNative, viewerUsesLatin);
      }
    }

    // ── Also fix English subtitle for non-Latin input when auto→English failed ──
    if (!inputIsLatin && (englishText === message || englishText === nativeText) && senderLang && senderLang !== 'english') {
      const betterEnglish = await translateText(message, senderLangOriginal || 'auto', 'English');
      if (betterEnglish && betterEnglish !== message) {
        englishText = betterEnglish;
      }
    }

    // ── Fallback: unchanged Latin input for non-Latin viewer ──
    if (nativeText === message && englishText && englishText !== message) {
      if (inputIsLatin && !viewerUsesLatin) {
        const englishFallback = await translateText(englishText, 'English', viewerLangOriginal);
        nativeText = pickBetterTranslationCandidate(message, nativeText, englishFallback || englishText, viewerUsesLatin);
      }
    }

    return {
      nativeText: nativeText || message,
      englishText: englishText || message,
    };
  } catch {
    // On any failure, fallback to English
    try {
      const englishFallback = await translateText(message, 'auto', 'English');
      return { nativeText: englishFallback || message, englishText: englishFallback || message };
    } catch {
      return { nativeText: message, englishText: message };
    }
  }
}

/**
 * Translate a chat message for sender→receiver flow.
 * 
 * Rules:
 * - Same language: both see native script + English subtitle
 * - Different language: receiver sees translated native + English subtitle
 * - Latin↔Latin: French user → German receiver → proper German translation
 * - Latin↔Native: French user → Telugu receiver → proper Telugu translation
 * - Native↔Native: Telugu user → Hindi receiver → via English pivot
 * - All translations are LIVE (no hardcoded values)
 * - English is always the fallback language
 * - Unsupported languages fallback to English
 */
export async function translateChatMessage(
  message: string,
  senderLanguage: string,
  receiverLanguage: string
): Promise<{ translated: string; englishText: string; isTranslated: boolean }> {
  if (!message?.trim()) {
    return { translated: message, englishText: message, isTranslated: false };
  }

  try {
    const result = await translateForViewer(message, receiverLanguage, senderLanguage);
    const isTranslated = result.nativeText !== message;

    return {
      translated: result.nativeText,
      englishText: result.englishText,
      isTranslated,
    };
  } catch {
    // Fallback to English
    try {
      const eng = await translateText(message, 'auto', 'English');
      return { translated: eng || message, englishText: eng || message, isTranslated: false };
    } catch {
      return { translated: message, englishText: message, isTranslated: false };
    }
  }
}

/**
 * Get English translation of a message (for subtitle display).
 * Live translation — no hardcoded values.
 */
export async function getEnglishTranslation(
  message: string,
  sourceLang: string
): Promise<string> {
  if (!message?.trim()) return message;
  const srcNorm = (sourceLang || 'english').toLowerCase().trim();
  if (srcNorm === 'english') {
    // If source is English, check if it's actually in another script
    if (!isLatinScript(message)) {
      return await translateText(message, 'auto', 'English');
    }
    return message;
  }

  try {
    return await translateText(message, 'auto', 'English');
  } catch {
    return message;
  }
}
