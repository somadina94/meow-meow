/**
 * Supported Languages — derived from the master languages list in @/data/languages.
 * Ensures all 933+ languages are available everywhere in the app.
 */

import { languages } from "@/data/languages";

export interface SupportedLanguage {
  name: string;
  code: string;
  isIndian: boolean;
}

// Indian language codes for categorization (same set used in LanguageSelector)
const INDIAN_LANGUAGE_CODES = new Set([
  "en",
  "hi", "bn", "te", "mr", "ta", "gu", "kn", "ml", "or", "pa", "as", "mai", "sat", "ks",
  "kok", "doi", "mni", "brx", "sa", "bho", "hne", "raj", "mwr", "mtr", "bgc", "mag",
  "anp", "bjj", "awa", "bns", "bfy", "gbm", "kfy", "him", "kan", "tcy", "kfa", "bhb",
  "gon", "lmn", "sck", "kru", "unr", "hoc", "khr", "hlb", "khn", "dcc", "wbr", "bhd",
  "mup", "hoj", "dgo", "sjo", "mby", "saz", "bra", "kfk", "lah", "psu", "pgg", "xnr",
  "srx", "jml", "dty", "thl", "bap", "lus", "kha", "grt", "mjw", "trp", "rah", "mrg",
  "njz", "apt", "adi", "lep", "sip", "lif", "njo", "njh", "nsm", "njm", "nmf", "pck",
  "tcz", "nbu", "nst", "nnp", "njb", "nag", "tcx", "bfq", "iru", "kfh", "vav", "abl",
  "wbq", "gok", "kxv", "kff", "kdu", "yed", "sou", "ur", "sd", "ne"
]);

// Build from master list
const allFromMaster: SupportedLanguage[] = languages.map(lang => ({
  name: lang.name,
  code: lang.code,
  isIndian: INDIAN_LANGUAGE_CODES.has(lang.code),
}));

export const INDIAN_LANGUAGES: SupportedLanguage[] = allFromMaster.filter(l => l.isIndian);

export const NON_INDIAN_LANGUAGES: SupportedLanguage[] = allFromMaster.filter(l => !l.isIndian);

export const ALL_SUPPORTED_LANGUAGES: SupportedLanguage[] = allFromMaster;

const indianLanguageNames = new Set(
  INDIAN_LANGUAGES.map(l => l.name.toLowerCase())
);

export function isIndianLanguage(language: string): boolean {
  return indianLanguageNames.has(language.toLowerCase());
}
