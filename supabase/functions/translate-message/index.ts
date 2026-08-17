/**
 * translate-message Edge Function
 * 
 * Embedded lingva-scraper — scrapes Google Translate's mobile page directly.
 * No external API, no Lingva instance, no API key required.
 * Uses English as pivot language for non-direct translation pairs.
 * Caches results in translation_cache table.
 * English fallback for all unsupported languages.
 * 
 * Supports ALL 130+ Google Translate languages.
 * Based on: https://github.com/thedaviddelta/lingva-scraper (MIT License)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// ─── All Google Translate supported languages ───
const GOOGLE_LANGUAGES: Record<string, string> = {
  "auto": "Detect", "af": "Afrikaans", "sq": "Albanian", "am": "Amharic",
  "ar": "Arabic", "hy": "Armenian", "as": "Assamese", "ay": "Aymara",
  "az": "Azerbaijani", "bm": "Bambara", "eu": "Basque", "be": "Belarusian",
  "bn": "Bengali", "bho": "Bhojpuri", "bs": "Bosnian", "bg": "Bulgarian",
  "ca": "Catalan", "ceb": "Cebuano", "ny": "Chichewa", "zh": "Chinese",
  "zh_HANT": "Chinese (Traditional)", "co": "Corsican", "hr": "Croatian",
  "cs": "Czech", "da": "Danish", "dv": "Dhivehi", "doi": "Dogri",
  "nl": "Dutch", "en": "English", "eo": "Esperanto", "et": "Estonian",
  "ee": "Ewe", "tl": "Filipino", "fi": "Finnish", "fr": "French",
  "fy": "Frisian", "gl": "Galician", "ka": "Georgian", "de": "German",
  "el": "Greek", "gn": "Guarani", "gu": "Gujarati", "ht": "Haitian Creole",
  "ha": "Hausa", "haw": "Hawaiian", "iw": "Hebrew", "hi": "Hindi",
  "hmn": "Hmong", "hu": "Hungarian", "is": "Icelandic", "ig": "Igbo",
  "ilo": "Ilocano", "id": "Indonesian", "ga": "Irish", "it": "Italian",
  "ja": "Japanese", "jw": "Javanese", "kn": "Kannada", "kk": "Kazakh",
  "km": "Khmer", "rw": "Kinyarwanda", "gom": "Konkani", "ko": "Korean",
  "kri": "Krio", "ku": "Kurdish (Kurmanji)", "ckb": "Kurdish (Sorani)",
  "ky": "Kyrgyz", "lo": "Lao", "la": "Latin", "lv": "Latvian",
  "ln": "Lingala", "lt": "Lithuanian", "lg": "Luganda",
  "lb": "Luxembourgish", "mk": "Macedonian", "mai": "Maithili",
  "mg": "Malagasy", "ms": "Malay", "ml": "Malayalam", "mt": "Maltese",
  "mi": "Maori", "mr": "Marathi", "mni-Mtei": "Meiteilon (Manipuri)",
  "lus": "Mizo", "mn": "Mongolian", "my": "Myanmar (Burmese)",
  "ne": "Nepali", "no": "Norwegian", "or": "Odia (Oriya)", "om": "Oromo",
  "ps": "Pashto", "fa": "Persian", "pl": "Polish", "pt": "Portuguese",
  "pa": "Punjabi", "qu": "Quechua", "ro": "Romanian", "ru": "Russian",
  "sm": "Samoan", "sa": "Sanskrit", "gd": "Scots Gaelic", "nso": "Sepedi",
  "sr": "Serbian", "st": "Sesotho", "sn": "Shona", "sd": "Sindhi",
  "si": "Sinhala", "sk": "Slovak", "sl": "Slovenian", "so": "Somali",
  "es": "Spanish", "su": "Sundanese", "sw": "Swahili", "sv": "Swedish",
  "tg": "Tajik", "ta": "Tamil", "tt": "Tatar", "te": "Telugu",
  "th": "Thai", "ti": "Tigrinya", "ts": "Tsonga", "tr": "Turkish",
  "tk": "Turkmen", "ak": "Twi", "uk": "Ukrainian", "ur": "Urdu",
  "ug": "Uyghur", "uz": "Uzbek", "vi": "Vietnamese", "cy": "Welsh",
  "xh": "Xhosa", "yi": "Yiddish", "yo": "Yoruba", "zu": "Zulu",
};

// Code mappings (lingva ↔ google)
const REQUEST_MAPPINGS: Record<string, string> = {
  "zh": "zh-CN", "zh_HANT": "zh-TW",
};

// Language name → code (case-insensitive)
const NAME_TO_CODE: Record<string, string> = {};
for (const [code, name] of Object.entries(GOOGLE_LANGUAGES)) {
  NAME_TO_CODE[name.toLowerCase()] = code;
}
// Common aliases
NAME_TO_CODE["bangla"] = "bn";
NAME_TO_CODE["mandarin"] = "zh";
NAME_TO_CODE["cantonese"] = "zh_HANT";
NAME_TO_CODE["odia"] = "or";
NAME_TO_CODE["oriya"] = "or";
NAME_TO_CODE["manipuri"] = "mni-Mtei";
NAME_TO_CODE["meiteilon"] = "mni-Mtei";
NAME_TO_CODE["filipino"] = "tl";
NAME_TO_CODE["tagalog"] = "tl";
NAME_TO_CODE["hebrew"] = "iw";
NAME_TO_CODE["javanese"] = "jw";
NAME_TO_CODE["myanmar"] = "my";
NAME_TO_CODE["burmese"] = "my";
NAME_TO_CODE["chinese (simplified)"] = "zh";
NAME_TO_CODE["chinese (traditional)"] = "zh_HANT";
NAME_TO_CODE["kurdish"] = "ku";
NAME_TO_CODE["haitian"] = "ht";
NAME_TO_CODE["scots"] = "gd";
NAME_TO_CODE["tulu"] = "kn";
NAME_TO_CODE["rajasthani"] = "hi";
NAME_TO_CODE["marwari"] = "hi";
NAME_TO_CODE["chhattisgarhi"] = "hi";
NAME_TO_CODE["magahi"] = "hi";
NAME_TO_CODE["awadhi"] = "hi";
NAME_TO_CODE["haryanvi"] = "hi";
NAME_TO_CODE["bundelkhandi"] = "hi";
// Additional Indian regional aliases → nearest supported
NAME_TO_CODE["angika"] = "hi";
NAME_TO_CODE["braj"] = "hi";
NAME_TO_CODE["garhwali"] = "hi";
NAME_TO_CODE["kumaoni"] = "hi";
NAME_TO_CODE["pahari"] = "hi";
NAME_TO_CODE["maithili"] = "mai";
NAME_TO_CODE["santali"] = "hi";
NAME_TO_CODE["ho"] = "hi";
NAME_TO_CODE["mundari"] = "hi";
NAME_TO_CODE["khasi"] = "en";
NAME_TO_CODE["garo"] = "en";
NAME_TO_CODE["mising"] = "as";
NAME_TO_CODE["bodo"] = "hi";
NAME_TO_CODE["kokborok"] = "bn";
NAME_TO_CODE["lepcha"] = "ne";
NAME_TO_CODE["limbu"] = "ne";
NAME_TO_CODE["nagamese"] = "en";
NAME_TO_CODE["tenyidie"] = "en";
NAME_TO_CODE["ao"] = "en";
NAME_TO_CODE["lotha"] = "en";
NAME_TO_CODE["sema"] = "en";
NAME_TO_CODE["pochury"] = "en";
NAME_TO_CODE["rengma"] = "en";
NAME_TO_CODE["ladakhi"] = "hi";
NAME_TO_CODE["balti"] = "ur";
NAME_TO_CODE["gondi"] = "hi";
NAME_TO_CODE["korku"] = "hi";
NAME_TO_CODE["kurukh"] = "hi";
// Global aliases
NAME_TO_CODE["persian"] = "fa";
NAME_TO_CODE["farsi"] = "fa";
NAME_TO_CODE["scots"] = "gd";
NAME_TO_CODE["creole"] = "ht";

// Random User-Agent pool
const USER_AGENTS = [
  "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
  "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
  "Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
];

function randomUA(): string {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}

function mapToGoogleCode(code: string): string {
  return REQUEST_MAPPINGS[code] || code;
}

function resolveLanguageCode(lang: string): string {
  if (!lang) return 'en';
  const lower = lang.toLowerCase().trim();
  if (lower === 'auto') return 'auto';
  // Already a valid code
  if (GOOGLE_LANGUAGES[lower]) return lower;
  // Check name→code map
  if (NAME_TO_CODE[lower]) return NAME_TO_CODE[lower];
  // Try partial match (e.g., "odia (oriya)" → "or")
  for (const [name, code] of Object.entries(NAME_TO_CODE)) {
    if (lower.includes(name) || name.includes(lower)) return code;
  }
  // Default to English if language not found
  console.warn(`[translate] Unknown language "${lang}", falling back to English`);
  return 'en';
}

/**
 * Core: Scrape Google Translate mobile page directly (lingva-scraper approach).
 * No API key needed. Supports all 130+ languages.
 * TRN-04 FIX: Added 429/rate-limit handling with exponential back-off.
 */
async function scrapeGoogleTranslate(
  text: string,
  sourceLang: string,
  targetLang: string,
  retry = 0
): Promise<string | null> {
  const src = mapToGoogleCode(sourceLang);
  const tgt = mapToGoogleCode(targetLang);
  const encoded = encodeURIComponent(text);

  if (encoded.length > 7500) return null;

  const url = `https://translate.google.com/m?sl=${src}&tl=${tgt}&q=${encoded}`;

  try {
    const resp = await fetch(url, {
      headers: { "User-Agent": randomUA() },
      signal: AbortSignal.timeout(10000),
    });

    // TRN-04 FIX: Handle 429 rate limiting with exponential back-off
    if (resp.status === 429) {
      if (retry < 3) {
        const delay = Math.pow(2, retry) * 500 + Math.random() * 200;
        await new Promise(r => setTimeout(r, delay));
        return scrapeGoogleTranslate(text, sourceLang, targetLang, retry + 1);
      }
      console.warn('[translate] Rate limited after 3 retries');
      return null;
    }

    if (!resp.ok) {
      await resp.text();
      if (retry < 3) {
        const delay = Math.pow(2, retry) * 300;
        await new Promise(r => setTimeout(r, delay));
        return scrapeGoogleTranslate(text, sourceLang, targetLang, retry + 1);
      }
      return null;
    }

    const html = await resp.text();
    const doc = new DOMParser().parseFromString(html, "text/html");
    if (!doc) {
      if (retry < 3) return scrapeGoogleTranslate(text, sourceLang, targetLang, retry + 1);
      return null;
    }

    const resultEl = doc.querySelector(".result-container");
    const translation = resultEl?.textContent?.trim();

    // TRN-04 FIX: Detect CAPTCHA or error pages in 200 responses
    if (!translation || translation.includes("#af-error-page") || 
        (translation.length > 500 && translation.toLowerCase().includes('captcha'))) {
      if (retry < 3) {
        const delay = Math.pow(2, retry) * 500;
        await new Promise(r => setTimeout(r, delay));
        return scrapeGoogleTranslate(text, sourceLang, targetLang, retry + 1);
      }
      return null;
    }

    return translation;
  } catch {
    if (retry < 3) {
      const delay = Math.pow(2, retry) * 300;
      await new Promise(r => setTimeout(r, delay));
      return scrapeGoogleTranslate(text, sourceLang, targetLang, retry + 1);
    }
    return null;
  }
}

/**
 * Translate using English as pivot language.
 * 
 * Rules:
 * - source or target is English or auto → direct translation
 * - Latin-to-Latin scripts → direct translation (Google handles well)
 * - Otherwise: source → English → target (pivot)
 */
async function translateWithPivot(
  text: string,
  sourceLang: string,
  targetLang: string
): Promise<string> {
  // Direct translation if one side is English or source is auto
  if (sourceLang === 'en' || targetLang === 'en' || sourceLang === 'auto') {
    const result = await scrapeGoogleTranslate(text, sourceLang, targetLang);
    
    // Auto-detection failure fix: if source=auto and result equals input,
    // Google couldn't detect the language. Retry treating input as English.
    // This handles transliterated text like "bagunnava" → Telugu "బాగున్నావా"
    if (sourceLang === 'auto' && result && result.trim().toLowerCase() === text.trim().toLowerCase() && targetLang !== 'en') {
      const retryResult = await scrapeGoogleTranslate(text, 'en', targetLang);
      if (retryResult && retryResult.trim().toLowerCase() !== text.trim().toLowerCase()) {
        return retryResult;
      }
    }
    
    // Auto-detection failure fix for auto→en: if result equals input,
    // the text might be transliterated. We can't do much here directly,
    // but we should NOT cache this failure so Strategy C on client side can work.
    if (sourceLang === 'auto' && targetLang === 'en' && result && result.trim().toLowerCase() === text.trim().toLowerCase()) {
      // Check if text is Latin script — if so, auto-detect genuinely failed
      const isLatin = /^[a-zA-Z\u00C0-\u024F\s\d.,!?;:'"()\-]+$/.test(text.trim());
      if (isLatin) {
        // Mark as untranslated so it won't be cached
        return text;
      }
    }
    
    return result || text;
  }

  // Pivot through English: source → en → target
  const toEnglish = await scrapeGoogleTranslate(text, sourceLang, 'en');
  if (!toEnglish) return text;

  const toTarget = await scrapeGoogleTranslate(toEnglish, 'en', targetLang);
  return toTarget || toEnglish;
}

/**
 * Check DB cache for a translation
 */
async function checkCache(
  supabase: ReturnType<typeof createClient>,
  srcCode: string,
  tgtCode: string,
  text: string
): Promise<string | null> {
  try {
    const { data } = await supabase
      .from('translation_cache')
      .select('translated_text')
      .eq('source_lang', srcCode)
      .eq('target_lang', tgtCode)
      .eq('source_text', text)
      .maybeSingle();
    return data?.translated_text || null;
  } catch {
    return null;
  }
}

/**
 * Cache translation result (fire-and-forget)
 */
function cacheResult(
  supabase: ReturnType<typeof createClient>,
  srcCode: string,
  tgtCode: string,
  sourceText: string,
  translatedText: string
) {
  supabase
    .from('translation_cache')
    .upsert({
      source_lang: srcCode,
      target_lang: tgtCode,
      source_text: sourceText,
      translated_text: translatedText,
    }, { onConflict: 'source_lang,target_lang,source_text' })
    .then(() => {});
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    let body;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
    const {
      text,
      texts,
      sourceLang = 'auto',
      targetLang = 'en',
    } = body;

    if (!text && (!texts || !Array.isArray(texts) || texts.length === 0)) {
      return new Response(
        JSON.stringify({ error: 'Provide "text" (string) or "texts" (string[])' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const srcCode = resolveLanguageCode(sourceLang);
    const tgtCode = resolveLanguageCode(targetLang);

    // Same language → return as-is
    if (srcCode === tgtCode && srcCode !== 'auto') {
      if (text) {
        return new Response(
          JSON.stringify({ translation: text, cached: false }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      return new Response(
        JSON.stringify({ translations: texts, cached: false }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Init Supabase for cache
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // ─── Single text translation ───
    if (text) {
      // Check cache first
      const cached = await checkCache(supabaseClient, srcCode, tgtCode, text);
      if (cached) {
        return new Response(
          JSON.stringify({ translation: cached, cached: true }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Live translation via embedded Google scraper
      const translation = await translateWithPivot(text, srcCode, tgtCode);

      // Cache result (fire-and-forget)
      if (translation !== text) {
        cacheResult(supabaseClient, srcCode, tgtCode, text, translation);
      }

      return new Response(
        JSON.stringify({ translation, cached: false }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ─── Batch translation ───
    // CHT-09 FIX: Parallel batch translation with concurrency limit of 5
    const batchTexts = texts.slice(0, 20);
    const CONCURRENCY = 5;
    const results: string[] = new Array(batchTexts.length);
    
    for (let i = 0; i < batchTexts.length; i += CONCURRENCY) {
      const chunk = batchTexts.slice(i, i + CONCURRENCY);
      const chunkResults = await Promise.allSettled(
        chunk.map(async (t: string) => {
          const cached = await checkCache(supabaseClient, srcCode, tgtCode, t);
          if (cached) return cached;
          const translation = await translateWithPivot(t, srcCode, tgtCode);
          if (translation !== t) cacheResult(supabaseClient, srcCode, tgtCode, t, translation);
          return translation;
        })
      );
      chunkResults.forEach((r, idx) => {
        results[i + idx] = r.status === 'fulfilled' ? r.value : batchTexts[i + idx];
      });
    }

    return new Response(
      JSON.stringify({ translations: results, cached: false }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message, timestamp: new Date().toISOString() }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
