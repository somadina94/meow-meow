/**
 * Font Loading Module
 * 
 * Provides on-demand font loading for 900+ languages.
 * Only loads fonts when text in that script is detected.
 */

export {
  loadFontsForText,
  loadFontsForLanguage,
  preloadBaseFonts,
  detectScripts,
  getLoadedFontGroups,
  isFontLoadedForScript,
} from './font-loader';
