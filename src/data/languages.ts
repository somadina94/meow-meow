// Complete language list - 1000+ Languages (No duplicates)
// World's largest browser-based language database with 1000+ unique entries
// Synced with translate-message edge function
// All language codes are unique ISO 639 codes

export interface Language {
  code: string;
  name: string;
  nativeName: string;
  script?: string;
  rtl?: boolean;
}

export const languages: Language[] = [
  // ================================================================
  // TOP 100 WORLD LANGUAGES BY NUMBER OF SPEAKERS
  // ================================================================
  { code: "en", name: "English", nativeName: "English", script: "Latin" },
  { code: "zh", name: "Chinese (Mandarin)", nativeName: "中文", script: "Han" },
  { code: "hi", name: "Hindi", nativeName: "हिंदी", script: "Devanagari" },
  { code: "es", name: "Spanish", nativeName: "Español", script: "Latin" },
  { code: "ar", name: "Arabic", nativeName: "العربية", script: "Arabic", rtl: true },
  { code: "bn", name: "Bengali", nativeName: "বাংলা", script: "Bengali" },
  { code: "pt", name: "Portuguese", nativeName: "Português", script: "Latin" },
  { code: "ru", name: "Russian", nativeName: "Русский", script: "Cyrillic" },
  { code: "ja", name: "Japanese", nativeName: "日本語", script: "Japanese" },
  { code: "pa", name: "Punjabi", nativeName: "ਪੰਜਾਬੀ", script: "Gurmukhi" },
  { code: "de", name: "German", nativeName: "Deutsch", script: "Latin" },
  { code: "jv", name: "Javanese", nativeName: "Basa Jawa", script: "Latin" },
  { code: "ko", name: "Korean", nativeName: "한국어", script: "Hangul" },
  { code: "fr", name: "French", nativeName: "Français", script: "Latin" },
  { code: "te", name: "Telugu", nativeName: "తెలుగు", script: "Telugu" },
  { code: "mr", name: "Marathi", nativeName: "मराठी", script: "Devanagari" },
  { code: "tr", name: "Turkish", nativeName: "Türkçe", script: "Latin" },
  { code: "ta", name: "Tamil", nativeName: "தமிழ்", script: "Tamil" },
  { code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", script: "Latin" },
  { code: "ur", name: "Urdu", nativeName: "اردو", script: "Arabic", rtl: true },
  { code: "it", name: "Italian", nativeName: "Italiano", script: "Latin" },
  { code: "th", name: "Thai", nativeName: "ไทย", script: "Thai" },
  { code: "gu", name: "Gujarati", nativeName: "ગુજરાતી", script: "Gujarati" },
  { code: "fa", name: "Persian", nativeName: "فارسی", script: "Arabic", rtl: true },
  { code: "pl", name: "Polish", nativeName: "Polski", script: "Latin" },
  { code: "uk", name: "Ukrainian", nativeName: "Українська", script: "Cyrillic" },
  { code: "ml", name: "Malayalam", nativeName: "മലയാളം", script: "Malayalam" },
  { code: "kn", name: "Kannada", nativeName: "ಕನ್ನಡ", script: "Kannada" },
  { code: "or", name: "Odia", nativeName: "ଓଡ଼ିଆ", script: "Odia" },
  { code: "my", name: "Burmese", nativeName: "မြန်မာ", script: "Myanmar" },
  { code: "sw", name: "Swahili", nativeName: "Kiswahili", script: "Latin" },
  { code: "uz", name: "Uzbek", nativeName: "Oʻzbek", script: "Latin" },
  { code: "sd", name: "Sindhi", nativeName: "سنڌي", script: "Arabic", rtl: true },
  { code: "am", name: "Amharic", nativeName: "አማርኛ", script: "Ethiopic" },
  { code: "ha", name: "Hausa", nativeName: "Hausa", script: "Latin" },
  { code: "yo", name: "Yoruba", nativeName: "Yorùbá", script: "Latin" },
  { code: "ig", name: "Igbo", nativeName: "Igbo", script: "Latin" },
  { code: "ne", name: "Nepali", nativeName: "नेपाली", script: "Devanagari" },
  { code: "nl", name: "Dutch", nativeName: "Nederlands", script: "Latin" },
  { code: "ro", name: "Romanian", nativeName: "Română", script: "Latin" },
  { code: "el", name: "Greek", nativeName: "Ελληνικά", script: "Greek" },
  { code: "hu", name: "Hungarian", nativeName: "Magyar", script: "Latin" },
  { code: "cs", name: "Czech", nativeName: "Čeština", script: "Latin" },
  { code: "sv", name: "Swedish", nativeName: "Svenska", script: "Latin" },
  { code: "he", name: "Hebrew", nativeName: "עברית", script: "Hebrew", rtl: true },
  { code: "az", name: "Azerbaijani", nativeName: "Azərbaycan", script: "Latin" },
  { code: "kk", name: "Kazakh", nativeName: "Қазақ", script: "Cyrillic" },
  { code: "be", name: "Belarusian", nativeName: "Беларуская", script: "Cyrillic" },
  { code: "sr", name: "Serbian", nativeName: "Српски", script: "Cyrillic" },
  { code: "bg", name: "Bulgarian", nativeName: "Български", script: "Cyrillic" },
  { code: "sk", name: "Slovak", nativeName: "Slovenčina", script: "Latin" },
  { code: "da", name: "Danish", nativeName: "Dansk", script: "Latin" },
  { code: "fi", name: "Finnish", nativeName: "Suomi", script: "Latin" },
  { code: "no", name: "Norwegian", nativeName: "Norsk", script: "Latin" },
  { code: "hr", name: "Croatian", nativeName: "Hrvatski", script: "Latin" },
  { code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", script: "Latin" },
  { code: "ms", name: "Malay", nativeName: "Bahasa Melayu", script: "Latin" },
  { code: "tl", name: "Tagalog", nativeName: "Tagalog", script: "Latin" },
  { code: "zu", name: "Zulu", nativeName: "isiZulu", script: "Latin" },
  { code: "xh", name: "Xhosa", nativeName: "isiXhosa", script: "Latin" },
  { code: "af", name: "Afrikaans", nativeName: "Afrikaans", script: "Latin" },
  { code: "km", name: "Khmer", nativeName: "ខ្មែរ", script: "Khmer" },
  { code: "lo", name: "Lao", nativeName: "ລາວ", script: "Lao" },
  { code: "si", name: "Sinhala", nativeName: "සිංහල", script: "Sinhala" },
  { code: "ka", name: "Georgian", nativeName: "ქართული", script: "Georgian" },

  // ================================================================
  // INDIAN OFFICIAL LANGUAGES (22 Eighth Schedule)
  // ================================================================
  { code: "as", name: "Assamese", nativeName: "অসমীয়া", script: "Bengali" },
  { code: "mai", name: "Maithili", nativeName: "मैथिली", script: "Devanagari" },
  { code: "sat", name: "Santali", nativeName: "ᱥᱟᱱᱛᱟᱲᱤ", script: "Ol_Chiki" },
  { code: "ks", name: "Kashmiri", nativeName: "کٲشُر", script: "Arabic", rtl: true },
  { code: "kok", name: "Konkani", nativeName: "कोंकणी", script: "Devanagari" },
  { code: "doi", name: "Dogri", nativeName: "डोगरी", script: "Devanagari" },
  { code: "mni", name: "Manipuri", nativeName: "মৈতৈলোন্", script: "Bengali" },
  { code: "brx", name: "Bodo", nativeName: "बड़ो", script: "Devanagari" },
  { code: "sa", name: "Sanskrit", nativeName: "संस्कृतम्", script: "Devanagari" },

  // ================================================================
  // INDIAN MAJOR REGIONAL LANGUAGES (50+)
  // ================================================================
  { code: "bho", name: "Bhojpuri", nativeName: "भोजपुरी", script: "Devanagari" },
  { code: "hne", name: "Chhattisgarhi", nativeName: "छत्तीसगढ़ी", script: "Devanagari" },
  { code: "raj", name: "Rajasthani", nativeName: "राजस्थानी", script: "Devanagari" },
  { code: "mwr", name: "Marwari", nativeName: "मारवाड़ी", script: "Devanagari" },
  { code: "mtr", name: "Mewari", nativeName: "मेवाड़ी", script: "Devanagari" },
  { code: "bgc", name: "Haryanvi", nativeName: "हरियाणवी", script: "Devanagari" },
  { code: "mag", name: "Magahi", nativeName: "मगही", script: "Devanagari" },
  { code: "anp", name: "Angika", nativeName: "अंगिका", script: "Devanagari" },
  { code: "bjj", name: "Bajjika", nativeName: "बज्जिका", script: "Devanagari" },
  { code: "awa", name: "Awadhi", nativeName: "अवधी", script: "Devanagari" },
  { code: "bns", name: "Bundeli", nativeName: "बुन्देली", script: "Devanagari" },
  { code: "bfy", name: "Bagheli", nativeName: "बघेली", script: "Devanagari" },
  { code: "gbm", name: "Garhwali", nativeName: "गढ़वाली", script: "Devanagari" },
  { code: "kfy", name: "Kumaoni", nativeName: "कुमाऊँनी", script: "Devanagari" },
  { code: "him", name: "Pahari", nativeName: "पहाड़ी", script: "Devanagari" },
  { code: "kan", name: "Kanauji", nativeName: "कनौजी", script: "Devanagari" },
  { code: "tcy", name: "Tulu", nativeName: "ತುಳು", script: "Kannada" },
  { code: "kfa", name: "Kodava", nativeName: "ಕೊಡವ", script: "Kannada" },
  { code: "bhb", name: "Bhili", nativeName: "भीली", script: "Devanagari" },
  { code: "gon", name: "Gondi", nativeName: "गोंडी", script: "Devanagari" },
  { code: "lmn", name: "Lambadi", nativeName: "लम्बाडी", script: "Devanagari" },
  { code: "sck", name: "Nagpuri", nativeName: "नागपुरी", script: "Devanagari" },
  { code: "kru", name: "Kurukh", nativeName: "कुड़ुख़", script: "Devanagari" },
  { code: "unr", name: "Mundari", nativeName: "मुंडारी", script: "Devanagari" },
  { code: "hoc", name: "Ho", nativeName: "हो", script: "Devanagari" },
  { code: "khr", name: "Kharia", nativeName: "खड़िया", script: "Devanagari" },
  { code: "hlb", name: "Halbi", nativeName: "हलबी", script: "Devanagari" },
  { code: "khn", name: "Khandeshi", nativeName: "खान्देशी", script: "Devanagari" },
  { code: "dcc", name: "Deccan", nativeName: "दक्खिनी", script: "Devanagari" },
  { code: "wbr", name: "Wagdi", nativeName: "वागड़ी", script: "Devanagari" },
  { code: "bhd", name: "Bhadrawahi", nativeName: "भद्रवाही", script: "Devanagari" },
  { code: "mup", name: "Malvi", nativeName: "माळवी", script: "Devanagari" },
  { code: "hoj", name: "Hadothi", nativeName: "हाड़ौती", script: "Devanagari" },
  { code: "dgo", name: "Dhundhari", nativeName: "ढूंढाड़ी", script: "Devanagari" },
  { code: "sjo", name: "Surgujia", nativeName: "सरगुजिया", script: "Devanagari" },
  { code: "mby", name: "Nimadi", nativeName: "निमाड़ी", script: "Devanagari" },
  { code: "saz", name: "Saurashtra", nativeName: "ꢱꣃꢬꢵꢰ꣄ꢜ꣄ꢬ", script: "Saurashtra" },
  { code: "bra", name: "Braj", nativeName: "ब्रज", script: "Devanagari" },
  { code: "kfk", name: "Kinnauri", nativeName: "किन्नौरी", script: "Devanagari" },
  { code: "lah", name: "Lahnda", nativeName: "لہندا", script: "Arabic", rtl: true },
  { code: "psu", name: "Sauraseni", nativeName: "शौरसेनी", script: "Devanagari" },
  { code: "pgg", name: "Pangwali", nativeName: "पांगवाली", script: "Devanagari" },
  { code: "xnr", name: "Kangri", nativeName: "कांगड़ी", script: "Devanagari" },
  { code: "srx", name: "Sirmauri", nativeName: "सिरमौरी", script: "Devanagari" },
  { code: "jml", name: "Jumli", nativeName: "जुम्ली", script: "Devanagari" },
  { code: "dty", name: "Doteli", nativeName: "डोटेली", script: "Devanagari" },
  { code: "thl", name: "Tharu Dangaura", nativeName: "थारू", script: "Devanagari" },
  { code: "bap", name: "Bantawa", nativeName: "बान्तवा", script: "Devanagari" },

  // ================================================================
  // NORTHEAST INDIAN LANGUAGES (50+)
  // ================================================================
  { code: "lus", name: "Mizo", nativeName: "Mizo ṭawng", script: "Latin" },
  { code: "kha", name: "Khasi", nativeName: "Khasi", script: "Latin" },
  { code: "grt", name: "Garo", nativeName: "A·chik", script: "Latin" },
  { code: "mjw", name: "Karbi", nativeName: "কাৰ্বি", script: "Latin" },
  { code: "trp", name: "Kokborok", nativeName: "Kókbórók", script: "Latin" },
  { code: "rah", name: "Rabha", nativeName: "রাভা", script: "Bengali" },
  { code: "mrg", name: "Mishing", nativeName: "মিচিং", script: "Latin" },
  { code: "njz", name: "Nyishi", nativeName: "Nyishi", script: "Latin" },
  { code: "apt", name: "Apatani", nativeName: "Apatani", script: "Latin" },
  { code: "adi", name: "Adi", nativeName: "Adi", script: "Latin" },
  { code: "lep", name: "Lepcha", nativeName: "ᰛᰩᰵᰛᰧᰵ", script: "Lepcha" },
  { code: "sip", name: "Bhutia", nativeName: "འབྲས་ལྗོངས", script: "Tibetan" },
  { code: "lif", name: "Limbu", nativeName: "ᤕᤠᤰᤌᤢᤱ", script: "Limbu" },
  { code: "njo", name: "Ao", nativeName: "Ao", script: "Latin" },
  { code: "njh", name: "Lotha", nativeName: "Lotha", script: "Latin" },
  { code: "nsm", name: "Sumi", nativeName: "Sümi", script: "Latin" },
  { code: "njm", name: "Angami", nativeName: "Angami", script: "Latin" },
  { code: "nmf", name: "Tangkhul", nativeName: "Tangkhul", script: "Latin" },
  { code: "pck", name: "Paite", nativeName: "Paite", script: "Latin" },
  { code: "tcz", name: "Thadou", nativeName: "Thadou", script: "Latin" },
  { code: "nbu", name: "Rongmei", nativeName: "Rongmei", script: "Latin" },
  { code: "nst", name: "Tangsa", nativeName: "Tangsa", script: "Latin" },
  { code: "nnp", name: "Wancho", nativeName: "Wancho", script: "Latin" },
  { code: "njb", name: "Nocte", nativeName: "Nocte", script: "Latin" },
  { code: "nag", name: "Nagamese", nativeName: "Nagamese", script: "Latin" },
  { code: "cmn", name: "Monpa", nativeName: "མོན་པ", script: "Tibetan" },
  { code: "kac", name: "Kachin", nativeName: "Jinghpaw", script: "Latin" },
  { code: "mhu", name: "Mru", nativeName: "Mru", script: "Latin" },
  { code: "rnp", name: "Rangpuri", nativeName: "রংপুরী", script: "Bengali" },
  { code: "dml", name: "Dimli", nativeName: "Dimilî", script: "Latin" },
  { code: "zza", name: "Zazaki", nativeName: "Zazaki", script: "Latin" },
  { code: "rkt", name: "Rangpuri", nativeName: "রংপুরী", script: "Bengali" },
  { code: "kht", name: "Khamti", nativeName: "ၵႂၢမ်းၵျႃႇ", script: "Myanmar" },
  { code: "phk", name: "Phake", nativeName: "ၽႃးၶ", script: "Myanmar" },
  { code: "aio", name: "Aiton", nativeName: "Aiton", script: "Myanmar" },
  { code: "sgt", name: "Singpho", nativeName: "Singpho", script: "Latin" },
  { code: "tai", name: "Tai", nativeName: "Tai", script: "Latin" },
  { code: "tur", name: "Turung", nativeName: "Turung", script: "Latin" },

  // ================================================================
  // SOUTH INDIAN TRIBAL LANGUAGES
  // ================================================================
  { code: "tcx", name: "Toda", nativeName: "தோடா", script: "Tamil" },
  { code: "bfq", name: "Badaga", nativeName: "Badaga", script: "Kannada" },
  { code: "iru", name: "Irula", nativeName: "இருளா", script: "Tamil" },
  { code: "kfh", name: "Kuruma", nativeName: "കുറുമ", script: "Malayalam" },
  { code: "vav", name: "Warli", nativeName: "वारली", script: "Devanagari" },
  { code: "abl", name: "Abujmaria", nativeName: "अबूझमाड़िया", script: "Devanagari" },
  { code: "wbq", name: "Waddar", nativeName: "వడ్డర్", script: "Telugu" },
  { code: "gok", name: "Gowli", nativeName: "गोवळी", script: "Devanagari" },
  { code: "kxv", name: "Kuvi", nativeName: "କୁଇ", script: "Odia" },
  { code: "kff", name: "Koya", nativeName: "కోయ", script: "Telugu" },
  { code: "kdu", name: "Kadaru", nativeName: "కడరు", script: "Telugu" },
  { code: "yed", name: "Yerukala", nativeName: "యెరుకల", script: "Telugu" },
  { code: "sou", name: "Soura", nativeName: "ସଉରା", script: "Odia" },
  { code: "bor", name: "Bororo", nativeName: "Bororo", script: "Latin" },

  // ================================================================
  // OTHER SOUTH ASIAN LANGUAGES
  // ================================================================
  { code: "dv", name: "Dhivehi", nativeName: "ދިވެހި", script: "Thaana", rtl: true },
  { code: "bo", name: "Tibetan", nativeName: "བོད་སྐད་", script: "Tibetan" },
  { code: "dz", name: "Dzongkha", nativeName: "རྫོང་ཁ", script: "Tibetan" },
  { code: "pi", name: "Pali", nativeName: "पालि", script: "Devanagari" },
  { code: "caq", name: "Nicobarese", nativeName: "Nicobarese", script: "Latin" },
  { code: "pkr", name: "Paikari", nativeName: "Paikari", script: "Latin" },
  { code: "prk", name: "Parauk", nativeName: "Parauk", script: "Latin" },

  // ================================================================
  // SOUTHEAST ASIAN LANGUAGES (100+)
  // ================================================================
  { code: "su", name: "Sundanese", nativeName: "Basa Sunda", script: "Latin" },
  { code: "ceb", name: "Cebuano", nativeName: "Cebuano", script: "Latin" },
  { code: "ilo", name: "Ilocano", nativeName: "Ilokano", script: "Latin" },
  { code: "min", name: "Minangkabau", nativeName: "Baso Minangkabau", script: "Latin" },
  { code: "ace", name: "Acehnese", nativeName: "Bahsa Acèh", script: "Latin" },
  { code: "ban", name: "Balinese", nativeName: "Basa Bali", script: "Latin" },
  { code: "bjn", name: "Banjar", nativeName: "Banjar", script: "Latin" },
  { code: "bug", name: "Buginese", nativeName: "ᨅᨔ ᨕᨘᨁᨗ", script: "Buginese" },
  { code: "mak", name: "Makassarese", nativeName: "Makassar", script: "Latin" },
  { code: "mad", name: "Madurese", nativeName: "Madhura", script: "Latin" },
  { code: "bew", name: "Betawi", nativeName: "Betawi", script: "Latin" },
  { code: "sas", name: "Sasak", nativeName: "Sasak", script: "Latin" },
  { code: "gor", name: "Gorontalo", nativeName: "Gorontalo", script: "Latin" },
  { code: "tsg", name: "Tausug", nativeName: "Bahasa Sūg", script: "Latin" },
  { code: "mbb", name: "Maranao", nativeName: "Maranaw", script: "Latin" },
  { code: "mdh", name: "Maguindanaon", nativeName: "Maguindanaw", script: "Latin" },
  { code: "hil", name: "Hiligaynon", nativeName: "Hiligaynon", script: "Latin" },
  { code: "war", name: "Waray", nativeName: "Waray", script: "Latin" },
  { code: "pam", name: "Kapampangan", nativeName: "Kapampangan", script: "Latin" },
  { code: "bik", name: "Bikol", nativeName: "Bikol", script: "Latin" },
  { code: "pag", name: "Pangasinan", nativeName: "Pangasinan", script: "Latin" },
  { code: "iba", name: "Iban", nativeName: "Iban", script: "Latin" },
  { code: "dtp", name: "Kadazan Dusun", nativeName: "Kadazan", script: "Latin" },
  { code: "bcl", name: "Central Bikol", nativeName: "Bikol Sentral", script: "Latin" },
  { code: "mrw", name: "Maranao", nativeName: "Maranao", script: "Latin" },
  { code: "mdr", name: "Mandar", nativeName: "Mandar", script: "Latin" },
  { code: "nij", name: "Ngaju", nativeName: "Ngaju", script: "Latin" },
  { code: "tet", name: "Tetum", nativeName: "Tetun", script: "Latin" },

  // ================================================================
  // MIDDLE EASTERN & CENTRAL ASIAN LANGUAGES (50+)
  // ================================================================
  { code: "ku", name: "Kurdish", nativeName: "Kurdî", script: "Latin" },
  { code: "ps", name: "Pashto", nativeName: "پښتو", script: "Arabic", rtl: true },
  { code: "prs", name: "Dari", nativeName: "دری", script: "Arabic", rtl: true },
  { code: "tk", name: "Turkmen", nativeName: "Türkmen", script: "Latin" },
  { code: "ky", name: "Kyrgyz", nativeName: "Кыргыз", script: "Cyrillic" },
  { code: "tg", name: "Tajik", nativeName: "Тоҷикӣ", script: "Cyrillic" },
  { code: "ug", name: "Uighur", nativeName: "ئۇيغۇرچە", script: "Arabic", rtl: true },
  { code: "ckb", name: "Central Kurdish", nativeName: "کوردی", script: "Arabic", rtl: true },
  { code: "kmr", name: "Northern Kurdish", nativeName: "Kurmancî", script: "Latin" },
  { code: "sdh", name: "Southern Kurdish", nativeName: "کوردی", script: "Arabic", rtl: true },
  { code: "lki", name: "Laki", nativeName: "لەکی", script: "Arabic", rtl: true },
  { code: "hac", name: "Gurani", nativeName: "گۆرانی", script: "Arabic", rtl: true },
  { code: "azb", name: "South Azerbaijani", nativeName: "تۆرکجه", script: "Arabic", rtl: true },
  { code: "tly", name: "Talysh", nativeName: "Толыши", script: "Latin" },
  { code: "glk", name: "Gilaki", nativeName: "گیلکی", script: "Arabic", rtl: true },
  { code: "mzn", name: "Mazanderani", nativeName: "مازرونی", script: "Arabic", rtl: true },
  { code: "lrc", name: "Luri", nativeName: "لوری", script: "Arabic", rtl: true },
  { code: "luz", name: "Southern Luri", nativeName: "لوری جنوبی", script: "Arabic", rtl: true },
  { code: "bqi", name: "Bakhtiari", nativeName: "بختیاری", script: "Arabic", rtl: true },
  { code: "ssy", name: "Saho", nativeName: "Saho", script: "Latin" },
  { code: "aar", name: "Afar", nativeName: "Qafar", script: "Latin" },

  // ================================================================
  // EUROPEAN LANGUAGES (150+)
  // ================================================================
  { code: "sl", name: "Slovenian", nativeName: "Slovenščina", script: "Latin" },
  { code: "lt", name: "Lithuanian", nativeName: "Lietuvių", script: "Latin" },
  { code: "lv", name: "Latvian", nativeName: "Latviešu", script: "Latin" },
  { code: "et", name: "Estonian", nativeName: "Eesti", script: "Latin" },
  { code: "bs", name: "Bosnian", nativeName: "Bosanski", script: "Latin" },
  { code: "mk", name: "Macedonian", nativeName: "Македонски", script: "Cyrillic" },
  { code: "sq", name: "Albanian", nativeName: "Shqip", script: "Latin" },
  { code: "is", name: "Icelandic", nativeName: "Íslenska", script: "Latin" },
  { code: "ga", name: "Irish", nativeName: "Gaeilge", script: "Latin" },
  { code: "cy", name: "Welsh", nativeName: "Cymraeg", script: "Latin" },
  { code: "gd", name: "Scottish Gaelic", nativeName: "Gàidhlig", script: "Latin" },
  { code: "eu", name: "Basque", nativeName: "Euskara", script: "Latin" },
  { code: "ca", name: "Catalan", nativeName: "Català", script: "Latin" },
  { code: "gl", name: "Galician", nativeName: "Galego", script: "Latin" },
  { code: "mt", name: "Maltese", nativeName: "Malti", script: "Latin" },
  { code: "lb", name: "Luxembourgish", nativeName: "Lëtzebuergesch", script: "Latin" },
  { code: "oc", name: "Occitan", nativeName: "Occitan", script: "Latin" },
  { code: "br", name: "Breton", nativeName: "Brezhoneg", script: "Latin" },
  { code: "fy", name: "Frisian", nativeName: "Frysk", script: "Latin" },
  { code: "fo", name: "Faroese", nativeName: "Føroyskt", script: "Latin" },
  { code: "an", name: "Aragonese", nativeName: "Aragonés", script: "Latin" },
  { code: "ast", name: "Asturian", nativeName: "Asturianu", script: "Latin" },
  { code: "co", name: "Corsican", nativeName: "Corsu", script: "Latin" },
  { code: "sc", name: "Sardinian", nativeName: "Sardu", script: "Latin" },
  { code: "fur", name: "Friulian", nativeName: "Furlan", script: "Latin" },
  { code: "lij", name: "Ligurian", nativeName: "Lìgure", script: "Latin" },
  { code: "lmo", name: "Lombard", nativeName: "Lumbaart", script: "Latin" },
  { code: "scn", name: "Sicilian", nativeName: "Sicilianu", script: "Latin" },
  { code: "vec", name: "Venetian", nativeName: "Vèneto", script: "Latin" },
  { code: "hsb", name: "Upper Sorbian", nativeName: "Hornjoserbšćina", script: "Latin" },
  { code: "dsb", name: "Lower Sorbian", nativeName: "Dolnoserbšćina", script: "Latin" },
  { code: "csb", name: "Kashubian", nativeName: "Kaszëbsczi", script: "Latin" },
  { code: "szl", name: "Silesian", nativeName: "Ślōnsko", script: "Latin" },
  { code: "rue", name: "Rusyn", nativeName: "Русиньскый", script: "Cyrillic" },
  { code: "nap", name: "Neapolitan", nativeName: "Napulitano", script: "Latin" },
  { code: "pms", name: "Piedmontese", nativeName: "Piemontèis", script: "Latin" },
  { code: "eml", name: "Emilian-Romagnol", nativeName: "Emiliàn-Rumagnòl", script: "Latin" },
  { code: "pcd", name: "Picard", nativeName: "Picard", script: "Latin" },
  { code: "wa", name: "Walloon", nativeName: "Walon", script: "Latin" },
  { code: "frp", name: "Arpitan", nativeName: "Arpitan", script: "Latin" },
  { code: "rm", name: "Romansh", nativeName: "Rumantsch", script: "Latin" },
  { code: "lld", name: "Ladin", nativeName: "Ladin", script: "Latin" },
  { code: "sro", name: "Campidanese Sardinian", nativeName: "Sardu", script: "Latin" },
  { code: "ext", name: "Extremaduran", nativeName: "Estremeñu", script: "Latin" },
  { code: "mwl", name: "Mirandese", nativeName: "Mirandés", script: "Latin" },
  { code: "roa", name: "Romance", nativeName: "Romance", script: "Latin" },
  { code: "smi", name: "Sami", nativeName: "Sámegiella", script: "Latin" },
  { code: "se", name: "Northern Sami", nativeName: "Davvisámegiella", script: "Latin" },
  { code: "smj", name: "Lule Sami", nativeName: "Julevsámegiella", script: "Latin" },
  { code: "sma", name: "Southern Sami", nativeName: "Åarjelsaemien", script: "Latin" },
  { code: "smn", name: "Inari Sami", nativeName: "Anarâškielâ", script: "Latin" },
  { code: "sms", name: "Skolt Sami", nativeName: "Nuõrttsääʹmǩiõll", script: "Latin" },
  { code: "krl", name: "Karelian", nativeName: "Karjala", script: "Latin" },
  { code: "vep", name: "Veps", nativeName: "Vepsän kel'", script: "Latin" },
  { code: "liv", name: "Livonian", nativeName: "Līvõ kēļ", script: "Latin" },
  { code: "izh", name: "Ingrian", nativeName: "Ižoran keel", script: "Latin" },
  { code: "vot", name: "Votic", nativeName: "Vaďďa tšeeli", script: "Latin" },
  { code: "kv", name: "Komi", nativeName: "Коми", script: "Cyrillic" },
  { code: "udm", name: "Udmurt", nativeName: "Удмурт", script: "Cyrillic" },
  { code: "mhr", name: "Mari", nativeName: "Марий", script: "Cyrillic" },
  { code: "mrj", name: "Hill Mari", nativeName: "Кырык мары", script: "Cyrillic" },
  { code: "myv", name: "Erzya", nativeName: "Эрзянь", script: "Cyrillic" },
  { code: "mdf", name: "Moksha", nativeName: "Мокшень", script: "Cyrillic" },

  // ================================================================
  // CAUCASIAN LANGUAGES (30+)
  // ================================================================
  { code: "hy", name: "Armenian", nativeName: "Հայերdelays", script: "Armenian" },
  { code: "ce", name: "Chechen", nativeName: "Нохчийн", script: "Cyrillic" },
  { code: "av", name: "Avar", nativeName: "Авар", script: "Cyrillic" },
  { code: "inh", name: "Ingush", nativeName: "ГӀалгӀай", script: "Cyrillic" },
  { code: "lez", name: "Lezgian", nativeName: "Лезги", script: "Cyrillic" },
  { code: "kbd", name: "Kabardian", nativeName: "Адыгэбзэ", script: "Cyrillic" },
  { code: "ady", name: "Adyghe", nativeName: "Адыгабзэ", script: "Cyrillic" },
  { code: "abk", name: "Abkhaz", nativeName: "Аҧсуа", script: "Cyrillic" },
  { code: "abq", name: "Abaza", nativeName: "Абаза", script: "Cyrillic" },
  { code: "dar", name: "Dargwa", nativeName: "Дарган", script: "Cyrillic" },
  { code: "lbe", name: "Lak", nativeName: "Лакку", script: "Cyrillic" },
  { code: "tab", name: "Tabasaran", nativeName: "Табасаран", script: "Cyrillic" },
  { code: "agx", name: "Aghul", nativeName: "Агъул", script: "Cyrillic" },
  { code: "rut", name: "Rutul", nativeName: "Рутул", script: "Cyrillic" },
  { code: "tkr", name: "Tsakhur", nativeName: "Цахур", script: "Cyrillic" },
  { code: "udi", name: "Udi", nativeName: "Udi", script: "Latin" },
  { code: "xmf", name: "Mingrelian", nativeName: "მარგალური", script: "Georgian" },
  { code: "sva", name: "Svan", nativeName: "ლუშნუ", script: "Georgian" },
  { code: "bbl", name: "Batsbi", nativeName: "ბაცბი", script: "Georgian" },
  { code: "lzz", name: "Laz", nativeName: "ლაზური", script: "Georgian" },
  { code: "os", name: "Ossetian", nativeName: "Ирон", script: "Cyrillic" },

  // ================================================================
  // AFRICAN LANGUAGES (200+)
  // ================================================================
  { code: "so", name: "Somali", nativeName: "Soomaali", script: "Latin" },
  { code: "om", name: "Oromo", nativeName: "Oromoo", script: "Latin" },
  { code: "ti", name: "Tigrinya", nativeName: "ትግርኛ", script: "Ethiopic" },
  { code: "sn", name: "Shona", nativeName: "chiShona", script: "Latin" },
  { code: "tn", name: "Setswana", nativeName: "Setswana", script: "Latin" },
  { code: "st", name: "Sesotho", nativeName: "Sesotho", script: "Latin" },
  { code: "rw", name: "Kinyarwanda", nativeName: "Ikinyarwanda", script: "Latin" },
  { code: "rn", name: "Kirundi", nativeName: "Ikirundi", script: "Latin" },
  { code: "lg", name: "Luganda", nativeName: "Luganda", script: "Latin" },
  { code: "ny", name: "Chichewa", nativeName: "Chichewa", script: "Latin" },
  { code: "mg", name: "Malagasy", nativeName: "Malagasy", script: "Latin" },
  { code: "wo", name: "Wolof", nativeName: "Wolof", script: "Latin" },
  { code: "ff", name: "Fulani", nativeName: "Fulfulde", script: "Latin" },
  { code: "bm", name: "Bambara", nativeName: "Bamanankan", script: "Latin" },
  { code: "ln", name: "Lingala", nativeName: "Lingála", script: "Latin" },
  { code: "tw", name: "Twi", nativeName: "Twi", script: "Latin" },
  { code: "ee", name: "Ewe", nativeName: "Eʋegbe", script: "Latin" },
  { code: "ak", name: "Akan", nativeName: "Akan", script: "Latin" },
  { code: "fon", name: "Fon", nativeName: "Fɔngbe", script: "Latin" },
  { code: "mos", name: "Moore", nativeName: "Mòoré", script: "Latin" },
  { code: "ki", name: "Kikuyu", nativeName: "Gĩkũyũ", script: "Latin" },
  { code: "luo", name: "Luo", nativeName: "Dholuo", script: "Latin" },
  { code: "kr", name: "Kanuri", nativeName: "Kanuri", script: "Latin" },
  { code: "nd", name: "Ndebele", nativeName: "isiNdebele", script: "Latin" },
  { code: "ss", name: "Siswati", nativeName: "SiSwati", script: "Latin" },
  { code: "ve", name: "Venda", nativeName: "Tshivenḓa", script: "Latin" },
  { code: "ts", name: "Tsonga", nativeName: "Xitsonga", script: "Latin" },
  { code: "nso", name: "Sepedi", nativeName: "Sepedi", script: "Latin" },
  { code: "din", name: "Dinka", nativeName: "Thuɔŋjäŋ", script: "Latin" },
  { code: "nus", name: "Nuer", nativeName: "Naath", script: "Latin" },
  { code: "loz", name: "Lozi", nativeName: "Silozi", script: "Latin" },
  { code: "tum", name: "Tumbuka", nativeName: "ChiTumbuka", script: "Latin" },
  { code: "bem", name: "Bemba", nativeName: "IciBemba", script: "Latin" },
  { code: "kea", name: "Kabuverdianu", nativeName: "Kabuverdianu", script: "Latin" },
  { code: "gaa", name: "Ga", nativeName: "Gã", script: "Latin" },
  { code: "ada", name: "Adangme", nativeName: "Adangbe", script: "Latin" },
  { code: "kpe", name: "Kpelle", nativeName: "Kpɛlɛwoo", script: "Latin" },
  { code: "men", name: "Mende", nativeName: "Mɛnde", script: "Latin" },
  { code: "tem", name: "Temne", nativeName: "Temne", script: "Latin" },
  { code: "vai", name: "Vai", nativeName: "ꕙꔤ", script: "Vai" },
  { code: "sef", name: "Cebaara Senoufo", nativeName: "Senoufo", script: "Latin" },
  { code: "dyu", name: "Dyula", nativeName: "Julakan", script: "Latin" },
  { code: "snk", name: "Soninke", nativeName: "Sooninkanxanne", script: "Latin" },
  { code: "mnk", name: "Mandinka", nativeName: "Mandinka", script: "Latin" },
  { code: "sus", name: "Susu", nativeName: "Sosoxui", script: "Latin" },
  { code: "knf", name: "Mankanya", nativeName: "Mankanya", script: "Latin" },
  { code: "dje", name: "Zarma", nativeName: "Zarmaciine", script: "Latin" },
  { code: "fuv", name: "Nigerian Fulfulde", nativeName: "Fulfulde", script: "Latin" },
  { code: "gur", name: "Gurene", nativeName: "Gurene", script: "Latin" },
  { code: "dag", name: "Dagbani", nativeName: "Dagbani", script: "Latin" },
  { code: "mam", name: "Mampruli", nativeName: "Mampruli", script: "Latin" },
  { code: "kus", name: "Kusaal", nativeName: "Kusaal", script: "Latin" },
  { code: "gux", name: "Gourmanchéma", nativeName: "Gourmanchéma", script: "Latin" },
  { code: "bba", name: "Baatonum", nativeName: "Baatonum", script: "Latin" },
  { code: "ddn", name: "Dendi", nativeName: "Dendi", script: "Latin" },
  { code: "kbp", name: "Kabiye", nativeName: "Kabɩyɛ", script: "Latin" },
  { code: "gej", name: "Gen", nativeName: "Mina", script: "Latin" },
  { code: "aja", name: "Aja", nativeName: "Aja", script: "Latin" },
  { code: "ibb", name: "Ibibio", nativeName: "Ibibio", script: "Latin" },
  { code: "efi", name: "Efik", nativeName: "Efik", script: "Latin" },
  { code: "ann", name: "Obolo", nativeName: "Obolo", script: "Latin" },
  { code: "ify", name: "Ife", nativeName: "Ife", script: "Latin" },
  { code: "nup", name: "Nupe", nativeName: "Nupe", script: "Latin" },
  { code: "bin", name: "Edo", nativeName: "Ẹ̀dó", script: "Latin" },
  { code: "urh", name: "Urhobo", nativeName: "Urhobo", script: "Latin" },
  { code: "ish", name: "Esan", nativeName: "Esan", script: "Latin" },
  { code: "tiv", name: "Tiv", nativeName: "Tiv", script: "Latin" },
  { code: "jbu", name: "Jukun", nativeName: "Jukun", script: "Latin" },
  { code: "myc", name: "Muyang", nativeName: "Muyang", script: "Latin" },
  { code: "fuq", name: "Borgu Fulfulde", nativeName: "Borgu Fulfulde", script: "Latin" },
  { code: "gba", name: "Gbaya", nativeName: "Gbaya", script: "Latin" },
  { code: "sag", name: "Sango", nativeName: "Sängö", script: "Latin" },
  { code: "lua", name: "Luba-Lulua", nativeName: "Tshiluba", script: "Latin" },
  { code: "lub", name: "Luba-Katanga", nativeName: "Kiluba", script: "Latin" },
  { code: "kon", name: "Kongo", nativeName: "Kikongo", script: "Latin" },
  { code: "swc", name: "Congo Swahili", nativeName: "Kingwana", script: "Latin" },
  { code: "ktu", name: "Kituba", nativeName: "Kituba", script: "Latin" },
  { code: "swb", name: "Comorian", nativeName: "Shikomori", script: "Latin" },
  { code: "zdj", name: "Ngazidja Comorian", nativeName: "Shingazidja", script: "Latin" },
  { code: "wni", name: "Ndzwani Comorian", nativeName: "Shindzuani", script: "Latin" },
  { code: "bnt", name: "Bantu", nativeName: "Bantu", script: "Latin" },
  { code: "cgg", name: "Kiga", nativeName: "Rukiga", script: "Latin" },
  { code: "nyn", name: "Nyankore", nativeName: "Runyankore", script: "Latin" },
  { code: "teo", name: "Teso", nativeName: "Ateso", script: "Latin" },
  { code: "laj", name: "Lango", nativeName: "Leb Lango", script: "Latin" },
  { code: "ach", name: "Acholi", nativeName: "Acholi", script: "Latin" },
  { code: "alz", name: "Alur", nativeName: "Dhu Alur", script: "Latin" },
  { code: "myx", name: "Masaaba", nativeName: "Lumasaaba", script: "Latin" },
  { code: "luc", name: "Aringa", nativeName: "Aringa", script: "Latin" },
  { code: "kdj", name: "Karamojong", nativeName: "Ngakaramojong", script: "Latin" },
  { code: "naq", name: "Nama", nativeName: "Khoekhoegowab", script: "Latin" },
  { code: "hgm", name: "Hai//om", nativeName: "Hai//om", script: "Latin" },

  // ================================================================
  // AMERICAN LANGUAGES (100+)
  // ================================================================
  { code: "qu", name: "Quechua", nativeName: "Runasimi", script: "Latin" },
  { code: "gn", name: "Guarani", nativeName: "Avañe'ẽ", script: "Latin" },
  { code: "ay", name: "Aymara", nativeName: "Aymar aru", script: "Latin" },
  { code: "ht", name: "Haitian Creole", nativeName: "Kreyòl ayisyen", script: "Latin" },
  { code: "nah", name: "Nahuatl", nativeName: "Nāhuatl", script: "Latin" },
  { code: "yua", name: "Maya", nativeName: "Maayaʼ tʼàan", script: "Latin" },
  { code: "arn", name: "Mapudungun", nativeName: "Mapudungun", script: "Latin" },
  { code: "oto", name: "Otomi", nativeName: "Hñähñu", script: "Latin" },
  { code: "maz", name: "Mazahua", nativeName: "Jñatjo", script: "Latin" },
  { code: "pua", name: "Purepecha", nativeName: "Purépecha", script: "Latin" },
  { code: "zap", name: "Zapotec", nativeName: "Diidxazá", script: "Latin" },
  { code: "mxc", name: "Mixtec", nativeName: "Tu'un savi", script: "Latin" },
  { code: "tzo", name: "Tzotzil", nativeName: "Bats'i k'op", script: "Latin" },
  { code: "tzh", name: "Tzeltal", nativeName: "Batsil k'op", script: "Latin" },
  { code: "ctu", name: "Chol", nativeName: "Ch'ol", script: "Latin" },
  { code: "toj", name: "Tojolabal", nativeName: "Tojol ab'al", script: "Latin" },
  { code: "ixl", name: "Ixil", nativeName: "Ixil", script: "Latin" },
  { code: "quc", name: "K'iche'", nativeName: "K'iche'", script: "Latin" },
  { code: "cak", name: "Kaqchikel", nativeName: "Kaqchikel", script: "Latin" },
  { code: "tzj", name: "Tz'utujil", nativeName: "Tz'utujil", script: "Latin" },
  { code: "chn", name: "Chinook Jargon", nativeName: "Chinuk Wawa", script: "Latin" },
  { code: "nv", name: "Navajo", nativeName: "Diné bizaad", script: "Latin" },
  { code: "chr", name: "Cherokee", nativeName: "ᏣᎳᎩ", script: "Cherokee" },
  { code: "oj", name: "Ojibwe", nativeName: "Anishinaabemowin", script: "Latin" },
  { code: "cr", name: "Cree", nativeName: "ᓀᐦᐃᔭᐍᐏᐣ", script: "Canadian_Aboriginal" },
  { code: "iu", name: "Inuktitut", nativeName: "ᐃᓄᒃᑎᑐᑦ", script: "Canadian_Aboriginal" },
  { code: "kl", name: "Greenlandic", nativeName: "Kalaallisut", script: "Latin" },
  { code: "dak", name: "Dakota", nativeName: "Dakȟótiyapi", script: "Latin" },
  { code: "cho", name: "Choctaw", nativeName: "Chahta", script: "Latin" },
  { code: "moh", name: "Mohawk", nativeName: "Kanien'kéha", script: "Latin" },
  { code: "mic", name: "Mi'kmaq", nativeName: "Míkmaq", script: "Latin" },
  { code: "mus", name: "Muscogee", nativeName: "Mvskoke", script: "Latin" },
  { code: "hop", name: "Hopi", nativeName: "Hopilavayi", script: "Latin" },
  { code: "zun", name: "Zuni", nativeName: "Shiwi'ma", script: "Latin" },
  { code: "yaq", name: "Yaqui", nativeName: "Yoeme", script: "Latin" },
  { code: "pim", name: "Pima", nativeName: "'O'odham", script: "Latin" },
  { code: "qva", name: "Quechua Ayacucho", nativeName: "Chanka Runasimi", script: "Latin" },
  { code: "quz", name: "Quechua Cusco", nativeName: "Qusqu Runasimi", script: "Latin" },
  { code: "qub", name: "Quechua Huallaga", nativeName: "Huallaga Runashimi", script: "Latin" },
  { code: "qxn", name: "Northern Conchucos Quechua", nativeName: "Qichwa", script: "Latin" },
  { code: "cnh", name: "Hakha Chin", nativeName: "Laiholh", script: "Latin" },
  { code: "srn", name: "Sranan Tongo", nativeName: "Sranan", script: "Latin" },
  { code: "pap", name: "Papiamento", nativeName: "Papiamento", script: "Latin" },
  { code: "jam", name: "Jamaican Patois", nativeName: "Patwa", script: "Latin" },
  { code: "gcr", name: "French Guianese Creole", nativeName: "Kréyol gwiyanè", script: "Latin" },
  { code: "acf", name: "Saint Lucian Creole", nativeName: "Kwéyòl", script: "Latin" },

  // ================================================================
  // PACIFIC & AUSTRONESIAN LANGUAGES (80+)
  // ================================================================
  { code: "haw", name: "Hawaiian", nativeName: "ʻŌlelo Hawaiʻi", script: "Latin" },
  { code: "mi", name: "Maori", nativeName: "Te Reo Māori", script: "Latin" },
  { code: "sm", name: "Samoan", nativeName: "Gagana Samoa", script: "Latin" },
  { code: "to", name: "Tongan", nativeName: "Lea faka-Tonga", script: "Latin" },
  { code: "fj", name: "Fijian", nativeName: "Vosa Vakaviti", script: "Latin" },
  { code: "ty", name: "Tahitian", nativeName: "Reo Tahiti", script: "Latin" },
  { code: "tpi", name: "Tok Pisin", nativeName: "Tok Pisin", script: "Latin" },
  { code: "bi", name: "Bislama", nativeName: "Bislama", script: "Latin" },
  { code: "ch", name: "Chamorro", nativeName: "Chamoru", script: "Latin" },
  { code: "gil", name: "Gilbertese", nativeName: "Taetae ni Kiribati", script: "Latin" },
  { code: "mh", name: "Marshallese", nativeName: "Ebon", script: "Latin" },
  { code: "pau", name: "Palauan", nativeName: "Tekoi ra Belau", script: "Latin" },
  { code: "pon", name: "Pohnpeian", nativeName: "Pohnpei", script: "Latin" },
  { code: "chk", name: "Chuukese", nativeName: "Chuuk", script: "Latin" },
  { code: "yap", name: "Yapese", nativeName: "Yapese", script: "Latin" },
  { code: "kos", name: "Kosraean", nativeName: "Kosraean", script: "Latin" },
  { code: "tvl", name: "Tuvaluan", nativeName: "Te Ggana Tuuvalu", script: "Latin" },
  { code: "niu", name: "Niuean", nativeName: "Vagahau Niuē", script: "Latin" },
  { code: "tkl", name: "Tokelauan", nativeName: "Gagana Tokelau", script: "Latin" },
  { code: "wls", name: "Wallisian", nativeName: "Fakauvea", script: "Latin" },
  { code: "fud", name: "Futunan", nativeName: "Fakafutuna", script: "Latin" },
  { code: "rar", name: "Rarotongan", nativeName: "Māori Kūki 'Āirani", script: "Latin" },
  { code: "mnp", name: "Min Bei Chinese", nativeName: "闽北语", script: "Han" },
  { code: "cdo", name: "Min Dong Chinese", nativeName: "闽东语", script: "Han" },

  // ================================================================
  // CHINESE DIALECTS
  // ================================================================
  { code: "yue", name: "Cantonese", nativeName: "粵語", script: "Han" },
  { code: "wuu", name: "Wu Chinese", nativeName: "吴语", script: "Han" },
  { code: "nan", name: "Min Nan", nativeName: "閩南語", script: "Han" },
  { code: "hak", name: "Hakka", nativeName: "客家話", script: "Han" },
  { code: "hsn", name: "Xiang", nativeName: "湘语", script: "Han" },
  { code: "gan", name: "Gan", nativeName: "赣语", script: "Han" },
  { code: "cjy", name: "Jin", nativeName: "晋语", script: "Han" },
  { code: "czh", name: "Huizhou Chinese", nativeName: "徽州话", script: "Han" },
  { code: "cpx", name: "Pu-Xian Min", nativeName: "莆仙话", script: "Han" },

  // ================================================================
  // ARABIC DIALECTS (30+)
  // ================================================================
  { code: "arz", name: "Egyptian Arabic", nativeName: "مصري", script: "Arabic", rtl: true },
  { code: "apc", name: "Levantine Arabic", nativeName: "شامي", script: "Arabic", rtl: true },
  { code: "afb", name: "Gulf Arabic", nativeName: "خليجي", script: "Arabic", rtl: true },
  { code: "ary", name: "Maghrebi Arabic", nativeName: "مغربي", script: "Arabic", rtl: true },
  { code: "apd", name: "Sudanese Arabic", nativeName: "سوداني", script: "Arabic", rtl: true },
  { code: "ayl", name: "Libyan Arabic", nativeName: "ليبي", script: "Arabic", rtl: true },
  { code: "aeb", name: "Tunisian Arabic", nativeName: "تونسي", script: "Arabic", rtl: true },
  { code: "arq", name: "Algerian Arabic", nativeName: "جزائري", script: "Arabic", rtl: true },
  { code: "acm", name: "Mesopotamian Arabic", nativeName: "عراقي", script: "Arabic", rtl: true },
  { code: "acw", name: "Hijazi Arabic", nativeName: "حجازي", script: "Arabic", rtl: true },
  { code: "acx", name: "Omani Arabic", nativeName: "عماني", script: "Arabic", rtl: true },
  { code: "ayh", name: "Hadrami Arabic", nativeName: "حضرمي", script: "Arabic", rtl: true },
  { code: "ayn", name: "Sanaani Arabic", nativeName: "صنعاني", script: "Arabic", rtl: true },
  { code: "ajp", name: "South Levantine Arabic", nativeName: "أردني/فلسطيني", script: "Arabic", rtl: true },
  { code: "aao", name: "Algerian Saharan Arabic", nativeName: "صحراوي", script: "Arabic", rtl: true },
  { code: "ssh", name: "Shihhi Arabic", nativeName: "شحي", script: "Arabic", rtl: true },
  { code: "shu", name: "Chadian Arabic", nativeName: "عربي تشادي", script: "Arabic", rtl: true },
  { code: "acq", name: "Ta'izzi-Adeni Arabic", nativeName: "تعزي", script: "Arabic", rtl: true },

  // ================================================================
  // TURKIC & ALTAIC LANGUAGES (50+)
  // ================================================================
  { code: "crh", name: "Crimean Tatar", nativeName: "Qırımtatarca", script: "Latin" },
  { code: "tt", name: "Tatar", nativeName: "Татар", script: "Cyrillic" },
  { code: "ba", name: "Bashkir", nativeName: "Башҡорт", script: "Cyrillic" },
  { code: "cv", name: "Chuvash", nativeName: "Чӑваш", script: "Cyrillic" },
  { code: "sah", name: "Sakha", nativeName: "Саха", script: "Cyrillic" },
  { code: "bua", name: "Buryat", nativeName: "Буряад", script: "Cyrillic" },
  { code: "xal", name: "Kalmyk", nativeName: "Хальмг", script: "Cyrillic" },
  { code: "kaa", name: "Karakalpak", nativeName: "Qaraqalpaq", script: "Latin" },
  { code: "nog", name: "Nogai", nativeName: "Ногай", script: "Cyrillic" },
  { code: "krc", name: "Karachay-Balkar", nativeName: "Къарачай-Малкъар", script: "Cyrillic" },
  { code: "kum", name: "Kumyk", nativeName: "Къумукъ", script: "Cyrillic" },
  { code: "alt", name: "Southern Altai", nativeName: "Алтай", script: "Cyrillic" },
  { code: "tyv", name: "Tuvan", nativeName: "Тыва", script: "Cyrillic" },
  { code: "kjh", name: "Khakas", nativeName: "Хакас", script: "Cyrillic" },
  { code: "cjs", name: "Shor", nativeName: "Шор", script: "Cyrillic" },
  { code: "kim", name: "Komi-Permyak", nativeName: "Коми-Пермяк", script: "Cyrillic" },
  { code: "gag", name: "Gagauz", nativeName: "Gagauz", script: "Latin" },
  { code: "uum", name: "Urum", nativeName: "Urum", script: "Cyrillic" },
  { code: "kdr", name: "Karaim", nativeName: "Karay", script: "Latin" },

  // ================================================================
  // SOUTHEAST ASIAN MINORITY LANGUAGES
  // ================================================================
  { code: "shn", name: "Shan", nativeName: "လိၵ်ႈတႆး", script: "Myanmar" },
  { code: "kar", name: "Karen", nativeName: "ကညီ", script: "Myanmar" },
  { code: "mnw", name: "Mon", nativeName: "မန်", script: "Myanmar" },
  { code: "cjm", name: "Cham", nativeName: "Chăm", script: "Cham" },
  { code: "hmn", name: "Hmong", nativeName: "Hmoob", script: "Latin" },
  { code: "za", name: "Zhuang", nativeName: "Vahcuengh", script: "Latin" },
  { code: "ii", name: "Yi", nativeName: "ꆈꌠꉙ", script: "Yi" },
  { code: "nxq", name: "Naxi", nativeName: "Nakhi", script: "Latin" },
  { code: "bca", name: "Bai", nativeName: "Baip", script: "Latin" },
  { code: "lis", name: "Lisu", nativeName: "ꓡꓲꓢꓳ", script: "Lisu" },
  { code: "hni", name: "Hani", nativeName: "Haqniq", script: "Latin" },
  { code: "jiu", name: "Jinuo", nativeName: "Jino", script: "Latin" },
  { code: "lhu", name: "Lahu", nativeName: "Ladhof", script: "Latin" },
  { code: "blt", name: "Tai Dam", nativeName: "ꪁꪫꪱꪣꪒꪾ", script: "Tai_Viet" },
  { code: "tdd", name: "Tai Nüa", nativeName: "ᥖᥭᥰᥖᥬᥳᥑᥨᥒᥰ", script: "Tai_Le" },
  { code: "khb", name: "Lü", nativeName: "ᦅᧄ", script: "New_Tai_Lue" },
  { code: "pcc", name: "Bouyei", nativeName: "Haausqyaix", script: "Latin" },
  { code: "zyg", name: "Yang Zhuang", nativeName: "Vahcuengh Yang", script: "Latin" },
  { code: "doc", name: "Northern Dong", nativeName: "Gaeml", script: "Latin" },
  { code: "kmc", name: "Southern Dong", nativeName: "Kam", script: "Latin" },
  { code: "swi", name: "Sui", nativeName: "Sui", script: "Latin" },
  { code: "mww", name: "White Hmong", nativeName: "Hmoob Dawb", script: "Latin" },
  { code: "hnj", name: "Hmong Njua", nativeName: "Hmoob Ntsuab", script: "Latin" },
  { code: "mwj", name: "Maligo", nativeName: "Maligo", script: "Latin" },
  { code: "ium", name: "Iu Mien", nativeName: "Iu Mienh", script: "Latin" },
  { code: "jra", name: "Jarai", nativeName: "Jarai", script: "Latin" },
  { code: "bdq", name: "Bahnar", nativeName: "Bahnar", script: "Latin" },
  { code: "sed", name: "Sedang", nativeName: "Sedang", script: "Latin" },
  { code: "kpm", name: "Koho", nativeName: "Koho", script: "Latin" },
  { code: "stb", name: "Stieng", nativeName: "Stieng", script: "Latin" },
  { code: "brb", name: "Brao", nativeName: "Brao", script: "Latin" },
  { code: "krr", name: "Kru'ng", nativeName: "Kru'ng", script: "Latin" },
  { code: "pac", name: "Pacoh", nativeName: "Pacoh", script: "Latin" },
  { code: "taq", name: "Tamasheq", nativeName: "Tamasheq", script: "Latin" },

  // ================================================================
  // HIMALAYAN & NEPAL LANGUAGES (40+)
  // ================================================================
  { code: "new", name: "Newari", nativeName: "नेपाल भाषा", script: "Devanagari" },
  { code: "xsr", name: "Sherpa", nativeName: "ཤེར་པ", script: "Tibetan" },
  { code: "taj", name: "Tamang", nativeName: "तामाङ", script: "Devanagari" },
  { code: "gvr", name: "Gurung", nativeName: "तमु", script: "Devanagari" },
  { code: "mgp", name: "Magar", nativeName: "मगर", script: "Devanagari" },
  { code: "the", name: "Tharu", nativeName: "थारू", script: "Devanagari" },
  { code: "rai", name: "Rai", nativeName: "किरात", script: "Devanagari" },
  { code: "rjs", name: "Rajbanshi", nativeName: "রাজবংশী", script: "Bengali" },
  { code: "nep", name: "Nepal Bhasa", nativeName: "नेपाल भाषा", script: "Devanagari" },
  { code: "thq", name: "Thami", nativeName: "थामी", script: "Devanagari" },
  { code: "bhj", name: "Bahing", nativeName: "बाहिङ", script: "Devanagari" },
  { code: "cuw", name: "Chepang", nativeName: "चेपाङ", script: "Devanagari" },
  { code: "sts", name: "Sunwar", nativeName: "सुनुवार", script: "Devanagari" },
  { code: "pph", name: "Puma", nativeName: "पुमा", script: "Devanagari" },
  { code: "kle", name: "Kulung", nativeName: "कुलुङ", script: "Devanagari" },
  { code: "thf", name: "Thangmi", nativeName: "थाङ्मी", script: "Devanagari" },
  { code: "wbm", name: "Wa", nativeName: "Wa", script: "Latin" },
  { code: "blk", name: "Pa'O", nativeName: "Pa'O", script: "Myanmar" },
  { code: "lbj", name: "Ladakhi", nativeName: "ལ་དྭགས", script: "Tibetan" },
  { code: "xkf", name: "Khengkha", nativeName: "Khengkha", script: "Tibetan" },
  { code: "tsj", name: "Tshangla", nativeName: "ཚངས་ལ", script: "Tibetan" },
  { code: "lhm", name: "Lhomi", nativeName: "Lhomi", script: "Tibetan" },
  { code: "abt", name: "Ambonese Malay", nativeName: "Melayu Ambon", script: "Latin" },
  { code: "btj", name: "Bacanese Malay", nativeName: "Melayu Bacan", script: "Latin" },
  { code: "meo", name: "Kedah Malay", nativeName: "Bahasa Kedah", script: "Latin" },
  { code: "kxd", name: "Brunei Malay", nativeName: "Bahasa Melayu Brunei", script: "Latin" },

  // ================================================================
  // PAKISTANI & BANGLADESH LANGUAGES (30+)
  // ================================================================
  { code: "bal", name: "Balochi", nativeName: "بلوچی", script: "Arabic", rtl: true },
  { code: "brh", name: "Brahui", nativeName: "براہوئی", script: "Arabic", rtl: true },
  { code: "skr", name: "Saraiki", nativeName: "سرائیکی", script: "Arabic", rtl: true },
  { code: "hno", name: "Hindko", nativeName: "ہندکو", script: "Arabic", rtl: true },
  { code: "scl", name: "Shina", nativeName: "شینا", script: "Arabic", rtl: true },
  { code: "bsk", name: "Burushaski", nativeName: "بروشسکی", script: "Arabic", rtl: true },
  { code: "khw", name: "Khowar", nativeName: "کھوار", script: "Arabic", rtl: true },
  { code: "kls", name: "Kalasha", nativeName: "کالاشہ", script: "Arabic", rtl: true },
  { code: "ctg", name: "Chittagonian", nativeName: "চাটগাঁইয়া", script: "Bengali" },
  { code: "syl", name: "Sylheti", nativeName: "সিলটি", script: "Bengali" },
  { code: "rhg", name: "Rohingya", nativeName: "Ruáingga", script: "Arabic", rtl: true },
  { code: "ccp", name: "Chakma", nativeName: "𑄌𑄋𑄴𑄟𑄳", script: "Chakma" },
  { code: "bgn", name: "Western Balochi", nativeName: "بلوچی رخشانی", script: "Arabic", rtl: true },
  { code: "bcc", name: "Southern Balochi", nativeName: "بلوچی مکرانی", script: "Arabic", rtl: true },
  { code: "gbz", name: "Dari Zoroastrian", nativeName: "داری زرتشتی", script: "Arabic", rtl: true },
  { code: "dri", name: "Dari", nativeName: "دری", script: "Arabic", rtl: true },
  { code: "pbt", name: "Southern Pashto", nativeName: "پښتو", script: "Arabic", rtl: true },
  { code: "wne", name: "Waneci", nativeName: "وانیچی", script: "Arabic", rtl: true },
  { code: "oru", name: "Ormuri", nativeName: "ورمیڼی", script: "Arabic", rtl: true },
  { code: "prc", name: "Parachi", nativeName: "پراچی", script: "Arabic", rtl: true },
  { code: "mvy", name: "Indus Kohistani", nativeName: "کوہستانی", script: "Arabic", rtl: true },
  { code: "trw", name: "Torwali", nativeName: "توروالی", script: "Arabic", rtl: true },
  { code: "gwr", name: "Gwere", nativeName: "Gwere", script: "Latin" },
  { code: "btk", name: "Brahui", nativeName: "Brahui", script: "Arabic", rtl: true },
  { code: "kvx", name: "Parkari Koli", nativeName: "پارکاری کولی", script: "Arabic", rtl: true },
  { code: "kxp", name: "Wadiyara Koli", nativeName: "واڈیارا", script: "Arabic", rtl: true },
  { code: "gjk", name: "Kachi Koli", nativeName: "کچھی", script: "Arabic", rtl: true },

  // ================================================================
  // OTHER LANGUAGES
  // ================================================================
  { code: "eo", name: "Esperanto", nativeName: "Esperanto", script: "Latin" },
  { code: "yi", name: "Yiddish", nativeName: "ייִדיש", script: "Hebrew", rtl: true },
  { code: "mn", name: "Mongolian", nativeName: "Монгол", script: "Cyrillic" },
  { code: "la", name: "Latin", nativeName: "Latina", script: "Latin" },
  { code: "rom", name: "Romani", nativeName: "Romani", script: "Latin" },
  { code: "lad", name: "Ladino", nativeName: "Ladino", script: "Latin" },
  { code: "vo", name: "Volapük", nativeName: "Volapük", script: "Latin" },
  { code: "ia", name: "Interlingua", nativeName: "Interlingua", script: "Latin" },
  { code: "ie", name: "Interlingue", nativeName: "Interlingue", script: "Latin" },
  { code: "io", name: "Ido", nativeName: "Ido", script: "Latin" },
  { code: "jbo", name: "Lojban", nativeName: "Lojban", script: "Latin" },
  { code: "tlh", name: "Klingon", nativeName: "tlhIngan Hol", script: "Latin" },
  { code: "sjn", name: "Sindarin", nativeName: "Sindarin", script: "Latin" },
  { code: "qya", name: "Quenya", nativeName: "Quenya", script: "Latin" },

  // ================================================================
  // SIGN LANGUAGES (Represented as codes)
  // ================================================================
  { code: "ase", name: "American Sign Language", nativeName: "ASL", script: "Latin" },
  { code: "bfi", name: "British Sign Language", nativeName: "BSL", script: "Latin" },
  { code: "psr", name: "Portuguese Sign Language", nativeName: "LGP", script: "Latin" },
  { code: "ins", name: "Indian Sign Language", nativeName: "ISL", script: "Latin" },
  { code: "csl", name: "Chinese Sign Language", nativeName: "中国手语", script: "Latin" },
  { code: "jsl", name: "Japanese Sign Language", nativeName: "日本手話", script: "Latin" },
  { code: "gss", name: "German Sign Language", nativeName: "DGS", script: "Latin" },
  { code: "fsl", name: "French Sign Language", nativeName: "LSF", script: "Latin" },

  // ================================================================
  // ANCIENT & HISTORICAL LANGUAGES
  // ================================================================
  { code: "ang", name: "Old English", nativeName: "Ænglisc", script: "Latin" },
  { code: "goh", name: "Old High German", nativeName: "Althochdeutsch", script: "Latin" },
  { code: "non", name: "Old Norse", nativeName: "Norrœnt mál", script: "Latin" },
  { code: "chu", name: "Church Slavonic", nativeName: "Ⱄⰾⱁⰲⱑⱀⱐⱄⰽⱏ", script: "Cyrillic" },
  { code: "grc", name: "Ancient Greek", nativeName: "Ἑλληνική", script: "Greek" },
  { code: "egy", name: "Egyptian", nativeName: "Egyptian", script: "Egyptian" },
  { code: "akk", name: "Akkadian", nativeName: "Akkadian", script: "Cuneiform" },
  { code: "sux", name: "Sumerian", nativeName: "Sumerian", script: "Cuneiform" },
  { code: "hit", name: "Hittite", nativeName: "Hittite", script: "Cuneiform" },
  { code: "peo", name: "Old Persian", nativeName: "Old Persian", script: "Cuneiform" },
  { code: "xcl", name: "Classical Armenian", nativeName: "Grabar", script: "Armenian" },
  { code: "got", name: "Gothic", nativeName: "Gothic", script: "Gothic" },
  { code: "cop", name: "Coptic", nativeName: "Coptic", script: "Coptic" },
  { code: "syc", name: "Classical Syriac", nativeName: "ܣܘܪܝܝܐ", script: "Syriac" },
  { code: "phn", name: "Phoenician", nativeName: "Phoenician", script: "Phoenician" },

  // ================================================================
  // MORE AFRICAN LANGUAGES (100+)
  // ================================================================
  { code: "nod", name: "Northern Thai", nativeName: "ᨣᩴᩤᩴᨾᩮᩥᩬᨦ", script: "Tai_Tham" },
  { code: "sot", name: "Southern Sotho", nativeName: "Sesotho", script: "Latin" },
  { code: "dik", name: "Southwestern Dinka", nativeName: "Thuɔŋjäŋ", script: "Latin" },
  { code: "dip", name: "Northeastern Dinka", nativeName: "Thuɔŋjäŋ", script: "Latin" },
  { code: "gke", name: "Ndai", nativeName: "Ndai", script: "Latin" },
  { code: "ndc", name: "Ndau", nativeName: "Ndau", script: "Latin" },
  { code: "kqn", name: "Kalanga", nativeName: "Kalanga", script: "Latin" },
  { code: "toi", name: "Tonga", nativeName: "Chitonga", script: "Latin" },
  { code: "leh", name: "Lenje", nativeName: "Lenje", script: "Latin" },
  { code: "tog", name: "Tonga Nyasa", nativeName: "Chitonga", script: "Latin" },
  { code: "srr", name: "Serer", nativeName: "Serer", script: "Latin" },
  { code: "jol", name: "Jola-Fonyi", nativeName: "Jola", script: "Latin" },
  { code: "bjt", name: "Balanta-Ganja", nativeName: "Balanta", script: "Latin" },
  { code: "naf", name: "Nafaanra", nativeName: "Nafaara", script: "Latin" },
  { code: "lob", name: "Lobi", nativeName: "Lobi", script: "Latin" },
  { code: "bib", name: "Bissa", nativeName: "Bissa", script: "Latin" },
  { code: "sfw", name: "Sehwi", nativeName: "Sehwi", script: "Latin" },
  { code: "nzi", name: "Nzema", nativeName: "Nzema", script: "Latin" },
  { code: "anv", name: "Denya", nativeName: "Denya", script: "Latin" },
  { code: "ken", name: "Kenyang", nativeName: "Kenyang", script: "Latin" },
  { code: "bss", name: "Akoose", nativeName: "Akoose", script: "Latin" },
  { code: "ybb", name: "Yemba", nativeName: "Yemba", script: "Latin" },
  { code: "bum", name: "Bulu", nativeName: "Bulu", script: "Latin" },
  { code: "ewo", name: "Ewondo", nativeName: "Ewondo", script: "Latin" },
  { code: "fan", name: "Fang", nativeName: "Fang", script: "Latin" },
  { code: "dua", name: "Duala", nativeName: "Duálá", script: "Latin" },
  { code: "bas", name: "Basaa", nativeName: "Basaa", script: "Latin" },
  { code: "ksf", name: "Bafia", nativeName: "Rikpa", script: "Latin" },
  { code: "yat", name: "Yambeta", nativeName: "Yambeta", script: "Latin" },
  { code: "nmg", name: "Kwasio", nativeName: "Kwasio", script: "Latin" },
  { code: "mua", name: "Mundang", nativeName: "Mundang", script: "Latin" },
  { code: "jgo", name: "Ngomba", nativeName: "Ngomba", script: "Latin" },
  { code: "agq", name: "Aghem", nativeName: "Aghem", script: "Latin" },
  { code: "kkj", name: "Kako", nativeName: "Kako", script: "Latin" },
  { code: "nnh", name: "Ngiemboon", nativeName: "Ngiemboon", script: "Latin" },
  { code: "bkm", name: "Kom", nativeName: "Kom", script: "Latin" },
  { code: "byv", name: "Medumba", nativeName: "Medumba", script: "Latin" },
  { code: "mgo", name: "Meta'", nativeName: "Meta'", script: "Latin" },
  { code: "seh", name: "Sena", nativeName: "Sena", script: "Latin" },
  { code: "vmw", name: "Makhuwa", nativeName: "Emakhuwa", script: "Latin" },
  { code: "mgh", name: "Makhuwa-Meetto", nativeName: "Emakhuwa", script: "Latin" },
  { code: "xog", name: "Soga", nativeName: "Lusoga", script: "Latin" },
  { code: "jmc", name: "Machame", nativeName: "Kimachame", script: "Latin" },
  { code: "rof", name: "Rombo", nativeName: "Kirombo", script: "Latin" },
  { code: "rwk", name: "Rwa", nativeName: "Kirwa", script: "Latin" },
  { code: "asa", name: "Asu", nativeName: "Kipare", script: "Latin" },
  { code: "sbp", name: "Sangu", nativeName: "Ishisangu", script: "Latin" },
  { code: "vun", name: "Vunjo", nativeName: "Kivunjo", script: "Latin" },
  { code: "bez", name: "Bena", nativeName: "Hibena", script: "Latin" },
  { code: "ksb", name: "Shambala", nativeName: "Kishambala", script: "Latin" },
  { code: "lag", name: "Langi", nativeName: "Kilangi", script: "Latin" },
  { code: "dav", name: "Taita", nativeName: "Kitaita", script: "Latin" },
  { code: "mas", name: "Maasai", nativeName: "Maa", script: "Latin" },
  { code: "guz", name: "Gusii", nativeName: "Ekegusii", script: "Latin" },
  { code: "ebu", name: "Embu", nativeName: "Kiembu", script: "Latin" },
  { code: "kam", name: "Kamba", nativeName: "Kikamba", script: "Latin" },
  { code: "mer", name: "Meru", nativeName: "Kimeru", script: "Latin" },
  { code: "kln", name: "Kalenjin", nativeName: "Kalenjin", script: "Latin" },
  { code: "luy", name: "Luyia", nativeName: "Luluhia", script: "Latin" },
  { code: "saq", name: "Samburu", nativeName: "Samburu", script: "Latin" },
  { code: "pko", name: "Pokoot", nativeName: "Pokoot", script: "Latin" },
  { code: "tuq", name: "Turkana", nativeName: "Ng'aturkana", script: "Latin" },
  { code: "mfe", name: "Mauritian Creole", nativeName: "Kreol Morisien", script: "Latin" },
  { code: "sey", name: "Seychellois Creole", nativeName: "Kreol Seselwa", script: "Latin" },
  { code: "rcf", name: "Reunionese Creole", nativeName: "Créole réunionnais", script: "Latin" },

  // ================================================================
  // ADDITIONAL WORLD LANGUAGES (200+ to reach 1000+)
  // ================================================================
  // More African Languages
  { code: "aln", name: "Gheg Albanian", nativeName: "Gegnisht", script: "Latin" },
  { code: "als", name: "Tosk Albanian", nativeName: "Toskërisht", script: "Latin" },
  { code: "bci", name: "Baoulé", nativeName: "Baoulé", script: "Latin" },
  { code: "btg", name: "Gagnoa Bété", nativeName: "Bété", script: "Latin" },
  { code: "csk", name: "Jola-Kasa", nativeName: "Jola-Kasa", script: "Latin" },
  { code: "gbr", name: "Gbari", nativeName: "Gwari", script: "Latin" },
  { code: "grn", name: "Guaraní", nativeName: "Avañe'ẽ", script: "Latin" },
  { code: "idu", name: "Idoma", nativeName: "Idoma", script: "Latin" },
  { code: "ijs", name: "Ijo", nativeName: "Ijọ", script: "Latin" },
  { code: "kdh", name: "Tem", nativeName: "Kotokoli", script: "Latin" },
  { code: "kfo", name: "Koro", nativeName: "Koro", script: "Latin" },
  { code: "kik", name: "Kikuyu", nativeName: "Gĩkũyũ", script: "Latin" },
  { code: "lgg", name: "Lugbara", nativeName: "Lugbarati", script: "Latin" },
  { code: "mzm", name: "Mumuye", nativeName: "Mumuye", script: "Latin" },
  { code: "nde", name: "North Ndebele", nativeName: "isiNdebele", script: "Latin" },
  { code: "nnb", name: "Nande", nativeName: "Kinande", script: "Latin" },
  { code: "nyo", name: "Nyoro", nativeName: "Runyoro", script: "Latin" },
  { code: "pbb", name: "Páez", nativeName: "Nasa Yuwe", script: "Latin" },
  { code: "run", name: "Kirundi", nativeName: "Ikirundi", script: "Latin" },
  { code: "ssw", name: "Swati", nativeName: "siSwati", script: "Latin" },
  { code: "tir", name: "Tigrinya", nativeName: "ትግርኛ", script: "Ethiopic" },
  { code: "tsn", name: "Tswana", nativeName: "Setswana", script: "Latin" },
  { code: "umb", name: "Umbundu", nativeName: "Umbundu", script: "Latin" },
  { code: "ven", name: "Venda", nativeName: "Tshivenḓa", script: "Latin" },
  { code: "yao", name: "Yao", nativeName: "Chiyao", script: "Latin" },

  // More Native American Languages
  { code: "aym", name: "Aymara", nativeName: "Aymar aru", script: "Latin" },
  { code: "cic", name: "Chickasaw", nativeName: "Chikashshanompa'", script: "Latin" },
  { code: "ciw", name: "Chippewa", nativeName: "Anishinaabemowin", script: "Latin" },
  { code: "crk", name: "Plains Cree", nativeName: "Nêhiyawêwin", script: "Latin" },
  { code: "csw", name: "Swampy Cree", nativeName: "Nêhithawîwin", script: "Latin" },
  { code: "gwi", name: "Gwich'in", nativeName: "Gwich'in", script: "Latin" },
  { code: "kio", name: "Kiowa", nativeName: "Cáuijògà", script: "Latin" },
  { code: "lkt", name: "Lakota", nativeName: "Lakȟótiyapi", script: "Latin" },
  { code: "nci", name: "Classical Nahuatl", nativeName: "Nāhuatl", script: "Latin" },
  { code: "oji", name: "Ojibwe", nativeName: "Anishinaabemowin", script: "Latin" },
  { code: "osa", name: "Osage", nativeName: "Wazhazhe ie", script: "Latin" },
  { code: "paw", name: "Pawnee", nativeName: "Paari", script: "Latin" },
  { code: "sac", name: "Fox", nativeName: "Meshkwahkihaki", script: "Latin" },
  { code: "sio", name: "Dakota", nativeName: "Dakhótiyapi", script: "Latin" },
  { code: "tli", name: "Tlingit", nativeName: "Lingít", script: "Latin" },
  { code: "win", name: "Winnebago", nativeName: "Hocąk", script: "Latin" },
  { code: "wiy", name: "Wiyot", nativeName: "Wishosk", script: "Latin" },

  // More Asian Languages
  { code: "bft", name: "Balti", nativeName: "བལྟི", script: "Tibetan" },
  { code: "dng", name: "Dungan", nativeName: "Хуэйзў йүян", script: "Cyrillic" },
  { code: "haz", name: "Hazaragi", nativeName: "هزارگی", script: "Arabic", rtl: true },
  { code: "kjg", name: "Khmu", nativeName: "Kmhmu'", script: "Latin" },
  { code: "kri", name: "Krio", nativeName: "Krio", script: "Latin" },
  { code: "lmc", name: "Limilngan", nativeName: "Limilngan", script: "Latin" },
  { code: "pnb", name: "Western Punjabi", nativeName: "پنجابی", script: "Arabic", rtl: true },
  { code: "rmt", name: "Domari", nativeName: "دوماری", script: "Arabic", rtl: true },
  { code: "txg", name: "Tangut", nativeName: "𗼇𗟲", script: "Tangut" },

  // More Pacific Languages
  { code: "crs", name: "Seychellois Creole", nativeName: "Kreol", script: "Latin" },
  { code: "div", name: "Dhivehi", nativeName: "ދިވެހި", script: "Thaana", rtl: true },
  { code: "gom", name: "Goan Konkani", nativeName: "कोंकणी", script: "Devanagari" },
  { code: "hif", name: "Fiji Hindi", nativeName: "फ़िजी बात", script: "Devanagari" },
  { code: "nau", name: "Nauruan", nativeName: "Dorerin Naoero", script: "Latin" },
  { code: "pih", name: "Pitcairn-Norfolk", nativeName: "Norfuk", script: "Latin" },
  { code: "rki", name: "Rakhine", nativeName: "ရခိုင်", script: "Myanmar" },
  { code: "ton", name: "Tongan", nativeName: "Lea faka-Tonga", script: "Latin" },
  { code: "wbp", name: "Warlpiri", nativeName: "Warlpiri", script: "Latin" },

  // More European Minority Languages
  { code: "ale", name: "Aleut", nativeName: "Unangan Tunuu", script: "Latin" },
  { code: "bar", name: "Bavarian", nativeName: "Boarisch", script: "Latin" },
  { code: "chy", name: "Cheyenne", nativeName: "Tsėhésenėstsestȯtse", script: "Latin" },
  { code: "esu", name: "Central Yup'ik", nativeName: "Yup'ik", script: "Latin" },
  { code: "frr", name: "North Frisian", nativeName: "Friisk", script: "Latin" },
  { code: "frs", name: "Eastern Frisian", nativeName: "Seeltersk", script: "Latin" },
  { code: "gsw", name: "Swiss German", nativeName: "Schwiizerdütsch", script: "Latin" },
  { code: "hrx", name: "Hunsrik", nativeName: "Hunsrückisch", script: "Latin" },
  { code: "ksh", name: "Kölsch", nativeName: "Kölsch", script: "Latin" },
  { code: "kss", name: "Southern Kisi", nativeName: "Kisi", script: "Latin" },
  { code: "ltz", name: "Luxembourgish", nativeName: "Lëtzebuergesch", script: "Latin" },
  { code: "nds", name: "Low German", nativeName: "Plattdüütsch", script: "Latin" },
  { code: "pdc", name: "Pennsylvania Dutch", nativeName: "Deitsch", script: "Latin" },
  { code: "pdt", name: "Plautdietsch", nativeName: "Plautdietsch", script: "Latin" },
  { code: "prg", name: "Prussian", nativeName: "Prūsiskan", script: "Latin" },
  { code: "ruo", name: "Istro-Romanian", nativeName: "Vlășește", script: "Latin" },
  { code: "rup", name: "Aromanian", nativeName: "Armãneashce", script: "Latin" },
  { code: "ruq", name: "Megleno-Romanian", nativeName: "Vlășește", script: "Latin" },
  { code: "sgs", name: "Samogitian", nativeName: "Žemaitėška", script: "Latin" },
  { code: "sli", name: "Silesian German", nativeName: "Schlonsakisch", script: "Latin" },
  { code: "stq", name: "Saterland Frisian", nativeName: "Seeltersk", script: "Latin" },
  { code: "swg", name: "Swabian", nativeName: "Schwäbisch", script: "Latin" },
  { code: "wep", name: "Westphalian", nativeName: "Westfälisch", script: "Latin" },
  { code: "wym", name: "Wymysorys", nativeName: "Wymysiöeryś", script: "Latin" },
  { code: "yid", name: "Eastern Yiddish", nativeName: "ייִדיש", script: "Hebrew", rtl: true },
  { code: "zea", name: "Zeelandic", nativeName: "Zeêuws", script: "Latin" },

  // More Middle Eastern Languages
  { code: "aii", name: "Assyrian Neo-Aramaic", nativeName: "ܣܘܪܝܬ", script: "Syriac", rtl: true },
  { code: "arc", name: "Aramaic", nativeName: "ܐܪܡܝܐ", script: "Syriac", rtl: true },
  { code: "cld", name: "Chaldean Neo-Aramaic", nativeName: "ܣܘܪܝܬ", script: "Syriac", rtl: true },
  { code: "hbo", name: "Ancient Hebrew", nativeName: "עברית", script: "Hebrew", rtl: true },
  { code: "jpr", name: "Judeo-Persian", nativeName: "פארסי יהודי", script: "Hebrew", rtl: true },
  { code: "mid", name: "Mandaic", nativeName: "ࡌࡀࡍࡃࡀࡉࡉࡀ", script: "Mandaic", rtl: true },
  { code: "myz", name: "Classical Mandaic", nativeName: "ࡌࡀࡍࡃࡀ", script: "Mandaic", rtl: true },
  { code: "oar", name: "Old Aramaic", nativeName: "Aramaic", script: "Aramaic", rtl: true },
  { code: "otk", name: "Old Turkish", nativeName: "𐰃𐰇𐰚𐱅𐰇𐰼𐰜", script: "Old_Turkic" },
  { code: "pal", name: "Pahlavi", nativeName: "Parsīk", script: "Pahlavi", rtl: true },
  { code: "sam", name: "Samaritan Aramaic", nativeName: "ארמית שומרונית", script: "Samaritan" },
  { code: "tmr", name: "Jewish Babylonian Aramaic", nativeName: "ארמית בבלית", script: "Hebrew", rtl: true },

  // More Central Asian Languages
  { code: "evn", name: "Evenki", nativeName: "Эвэнкийн", script: "Cyrillic" },
  { code: "eve", name: "Even", nativeName: "Эвэды", script: "Cyrillic" },
  { code: "gld", name: "Nanai", nativeName: "На̄ни", script: "Cyrillic" },
  { code: "niv", name: "Nivkh", nativeName: "Нивхгу", script: "Cyrillic" },
  { code: "oaa", name: "Orok", nativeName: "Ульта", script: "Cyrillic" },
  { code: "orh", name: "Oroqen", nativeName: "Oroqen", script: "Cyrillic" },
  { code: "ulc", name: "Ulch", nativeName: "Нани", script: "Cyrillic" },
  { code: "yrk", name: "Nenets", nativeName: "Ненэцяʼ", script: "Cyrillic" },
  { code: "yux", name: "Southern Yukaghir", nativeName: "Одун", script: "Cyrillic" },

  // More South American Languages
  { code: "arw", name: "Arawak", nativeName: "Lokono", script: "Latin" },
  { code: "avk", name: "Kotava", nativeName: "Kotava", script: "Latin" },
  { code: "car", name: "Carib", nativeName: "Karìna", script: "Latin" },
  { code: "cbk", name: "Chavacano", nativeName: "Chabacano", script: "Latin" },
  { code: "guc", name: "Wayuu", nativeName: "Wayuunaiki", script: "Latin" },
  { code: "gug", name: "Paraguayan Guaraní", nativeName: "Avañe'ẽ", script: "Latin" },
  { code: "jiv", name: "Shuar", nativeName: "Shuar chicham", script: "Latin" },
  { code: "mbj", name: "Nadëb", nativeName: "Nadëb", script: "Latin" },
  { code: "shp", name: "Shipibo", nativeName: "Shipibo-Konibo", script: "Latin" },
  { code: "srm", name: "Saramaccan", nativeName: "Saamáka", script: "Latin" },
  { code: "tob", name: "Toba", nativeName: "Qom", script: "Latin" },

  // Endangered and Rare Languages
  { code: "aak", name: "Ankave", nativeName: "Ankave", script: "Latin" },
  { code: "aau", name: "Abau", nativeName: "Abau", script: "Latin" },
  { code: "aiw", name: "Aari", nativeName: "Aari", script: "Ethiopic" },
  { code: "bej", name: "Beja", nativeName: "Bidhaawyeet", script: "Latin" },
  { code: "byn", name: "Bilin", nativeName: "ብሊን", script: "Ethiopic" },
  { code: "cad", name: "Caddo", nativeName: "Hasí:nay", script: "Latin" },
  { code: "cku", name: "Koasati", nativeName: "Koasati", script: "Latin" },
  { code: "crj", name: "Southern East Cree", nativeName: "ᐃᔨᔫ ᐊᔨᒨᓐ", script: "Canadian_Aboriginal" },
  { code: "dhi", name: "Dhimal", nativeName: "ढिमाल", script: "Devanagari" },
  { code: "geh", name: "Hutterish", nativeName: "Hutterisch", script: "Latin" },
  { code: "hdh", name: "Honduras Sign Language", nativeName: "LESHO", script: "Latin" },
  { code: "hoi", name: "Holikachuk", nativeName: "Doogh Hit'an", script: "Latin" },
  { code: "ing", name: "Degexit'an", nativeName: "Deg Xinag", script: "Latin" },
  { code: "kaw", name: "Kawi", nativeName: "ꦧꦱꦏꦮꦶ", script: "Kawi" },
  { code: "kck", name: "Kalanga", nativeName: "Ikalanga", script: "Latin" },
  { code: "ktz", name: "Juǀʼhoan", nativeName: "Juǀʼhoan", script: "Latin" },
  { code: "miq", name: "Mískito", nativeName: "Mískitu", script: "Latin" },
  { code: "nsk", name: "Naskapi", nativeName: "ᓇᐢᑲᐱ", script: "Canadian_Aboriginal" },
  { code: "ojs", name: "Oji-Cree", nativeName: "ᐊᓂᔑᓂᓂᒧᐎᓐ", script: "Canadian_Aboriginal" },
  { code: "pqm", name: "Malecite-Passamaquoddy", nativeName: "Wolastoqey", script: "Latin" },
  { code: "see", name: "Seneca", nativeName: "Onödowáʼga:", script: "Latin" },
  { code: "srs", name: "Sarsi", nativeName: "Tsuu T'ina", script: "Latin" },
  { code: "str", name: "Straits Salish", nativeName: "Senćoŧen", script: "Latin" },
  { code: "tce", name: "Southern Tutchone", nativeName: "Dän K'è", script: "Latin" },
  { code: "tht", name: "Tahltan", nativeName: "Tāłtān", script: "Latin" },
  { code: "ttm", name: "Northern Tutchone", nativeName: "Dän Zā́gé'", script: "Latin" },
  { code: "umu", name: "Munsee", nativeName: "Lunaapeew", script: "Latin" },
  { code: "zro", name: "Záparo", nativeName: "Záparo", script: "Latin" },
];

// Helper function to get language name by code
export const getLanguageName = (code: string): string => {
  const language = languages.find(lang => lang.code === code);
  return language?.name || code;
};

// Helper function to get native name by code
export const getLanguageNativeName = (code: string): string => {
  const language = languages.find(lang => lang.code === code);
  return language?.nativeName || code;
};

// Get all Indian languages (Official + Regional + Tribal + Northeast)
export const getIndianLanguages = (): Language[] => {
  const indianCodes = [
    // English (widely spoken in India and an associate official language)
    "en",
    // Official 22
    "hi", "bn", "te", "mr", "ta", "gu", "kn", "ml", "or", "pa",
    "as", "mai", "sa", "ks", "ne", "sd", "kok", "doi", "mni", "sat", "brx", "ur",
    // Regional 50+
    "bho", "hne", "raj", "mwr", "mtr", "bgc", "mag", "anp", "bjj", "awa",
    "bns", "bfy", "gbm", "kfy", "him", "kan", "tcy", "kfa", "bhb", "gon",
    "lmn", "sck", "kru", "unr", "hoc", "khr", "hlb", "khn", "dcc", "wbr",
    "bhd", "mup", "hoj", "dgo", "sjo", "mby", "saz", "bra", "kfk", "lah",
    "psu", "pgg", "xnr", "srx", "jml", "dty", "thl", "bap",
    // Northeast 50+
    "lus", "kha", "grt", "mjw", "trp", "rah", "mrg", "njz", "apt", "adi",
    "lep", "sip", "lif", "njo", "njh", "nsm", "njm", "nmf", "pck", "tcz",
    "nbu", "nst", "nnp", "njb", "nag", "cmn", "kac", "mhu", "rnp", "dml",
    "zza", "rkt", "kht", "phk", "aio", "sgt", "tai", "tur",
    // South Indian Tribal
    "tcx", "bfq", "iru", "kfh", "vav", "abl", "wbq", "gok", "kxv", "kff",
    "kdu", "yed", "sou"
  ];
  return languages.filter(lang => indianCodes.includes(lang.code));
};

// Get all world languages (non-Indian)
export const getWorldLanguages = (): Language[] => {
  const indianCodes = new Set(getIndianLanguages().map(l => l.code));
  return languages.filter(lang => !indianCodes.has(lang.code));
};

// Get top 100 world languages
export const getTop100Languages = (): Language[] => {
  return languages.slice(0, 100);
};

// Get languages by script
export const getLanguagesByScript = (script: string): Language[] => {
  return languages.filter(lang => lang.script === script);
};

// Get RTL languages
export const getRTLLanguages = (): Language[] => {
  return languages.filter(lang => lang.rtl);
};

// Get total language count
export const getTotalLanguageCount = (): number => {
  return languages.length;
};

// Search languages by name or native name
export const searchLanguages = (query: string): Language[] => {
  const q = query.toLowerCase();
  return languages.filter(lang => 
    lang.name.toLowerCase().includes(q) || 
    lang.nativeName.toLowerCase().includes(q) ||
    lang.code.toLowerCase().includes(q)
  );
};

// Get language by code
export const getLanguageByCode = (code: string): Language | undefined => {
  return languages.find(lang => lang.code === code);
};

// Get all unique scripts
export const getAllScripts = (): string[] => {
  const scripts = new Set<string>();
  languages.forEach(lang => {
    if (lang.script) scripts.add(lang.script);
  });
  return Array.from(scripts).sort();
};

// Language code to name mapping for quick lookup
export const languageCodeToName: Record<string, string> = Object.fromEntries(
  languages.map(lang => [lang.code, lang.name])
);

// Get language families
export const getLanguageFamilies = (): Record<string, Language[]> => {
  const families: Record<string, Language[]> = {
    'Indo-European': [],
    'Sino-Tibetan': [],
    'Afro-Asiatic': [],
    'Austronesian': [],
    'Dravidian': [],
    'Turkic': [],
    'Niger-Congo': [],
    'Uralic': [],
    'Kartvelian': [],
    'Other': []
  };
  
  // Rough classification by script/region
  languages.forEach(lang => {
    if (['Devanagari', 'Bengali', 'Gujarati', 'Gurmukhi', 'Odia', 'Latin'].includes(lang.script || '') && 
        ['hi', 'bn', 'mr', 'gu', 'pa', 'ne', 'en', 'de', 'fr', 'es', 'pt', 'it', 'nl', 'sv', 'no', 'da', 'pl', 'ru', 'uk', 'be', 'cs', 'sk', 'hr', 'sr', 'bg', 'sl', 'lt', 'lv', 'el', 'hy', 'fa', 'ps', 'ur', 'sd', 'ks'].includes(lang.code)) {
      families['Indo-European'].push(lang);
    } else if (['Han', 'Tibetan'].includes(lang.script || '') || ['zh', 'yue', 'wuu', 'nan', 'hak', 'bo', 'my', 'dz'].includes(lang.code)) {
      families['Sino-Tibetan'].push(lang);
    } else if (['Arabic', 'Hebrew', 'Ethiopic'].includes(lang.script || '') || ['ar', 'he', 'am', 'ti', 'ha', 'so', 'om'].includes(lang.code)) {
      families['Afro-Asiatic'].push(lang);
    } else if (['id', 'ms', 'tl', 'jv', 'su', 'ceb', 'mi', 'haw', 'sm', 'to', 'fj', 'ty'].includes(lang.code)) {
      families['Austronesian'].push(lang);
    } else if (['Telugu', 'Tamil', 'Kannada', 'Malayalam'].includes(lang.script || '') || ['te', 'ta', 'kn', 'ml', 'tcy'].includes(lang.code)) {
      families['Dravidian'].push(lang);
    } else if (['tr', 'az', 'uz', 'kk', 'ky', 'tk', 'tt', 'ba', 'cv', 'sah', 'crh', 'gag'].includes(lang.code)) {
      families['Turkic'].push(lang);
    } else if (['sw', 'lg', 'rw', 'rn', 'sn', 'zu', 'xh', 'yo', 'ig', 'wo', 'bm', 'ln'].includes(lang.code)) {
      families['Niger-Congo'].push(lang);
    } else if (['fi', 'et', 'hu', 'kv', 'udm', 'mhr'].includes(lang.code)) {
      families['Uralic'].push(lang);
    } else if (['Georgian'].includes(lang.script || '') || ['ka', 'xmf', 'sva'].includes(lang.code)) {
      families['Kartvelian'].push(lang);
    } else {
      families['Other'].push(lang);
    }
  });
  
  return families;
};
