/**
 * India-only enforcement helpers.
 * The platform is restricted to the Indian market — non-Indian languages,
 * countries, or states must be rejected during registration / profile setup.
 */

import { isIndianLanguage } from "@/data/supportedLanguages";
import { languages } from "@/data/languages";

export const INDIA_COUNTRY_CODES = new Set(["IN", "in"]);
export const INDIA_COUNTRY_NAMES = new Set(["india", "bharat", "भारत"]);

export const NON_INDIA_ERROR = {
  title: "Not supported",
  description: "Non-Indian language or country is not supported in this app.",
} as const;

export function isIndianCountry(country: string | null | undefined): boolean {
  if (!country) return false;
  const v = country.trim();
  if (!v) return false;
  if (INDIA_COUNTRY_CODES.has(v.toUpperCase())) return true;
  return INDIA_COUNTRY_NAMES.has(v.toLowerCase());
}

/**
 * Accepts either a language code (e.g. "hi") or a language name (e.g. "Hindi").
 */
export function isIndianLanguageInput(input: string | null | undefined): boolean {
  if (!input) return false;
  const v = input.trim();
  if (!v) return false;
  // Try as code first
  const byCode = languages.find(l => l.code.toLowerCase() === v.toLowerCase());
  const name = byCode?.name ?? v;
  return isIndianLanguage(name);
}
