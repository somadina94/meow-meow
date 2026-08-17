/**
 * Content Moderation Utility
 * 
 * Blocks:
 * 1. Sexual/explicit content (all languages)
 * 2. Contact information sharing (phone, email, social media)
 * 3. Harmful/threatening content
 * 4. Numbers in word/symbol form
 * 5. File attachments containing contact info
 */

import { isMediaChatMessage } from "@/lib/chat-attachments";

// ========================================
// SEXUAL CONTENT DETECTION (ALL LANGUAGES)
// ========================================

const SEXUAL_CONTENT_PATTERNS = [
  // English (expanded)
  /\b(sex|sexy|sexting|nude[s]?|naked|porn|porno|pornography|xxx|nsfw|erotic|erotica|orgasm|masturbat\w*|blowjob|handjob|rimjob|footjob|titjob|anal\s*sex|oral\s*sex|threesome|gangbang|orgy|fetish|bondage|bdsm|kinky|strip\s*tease|lap\s*dance|one\s*night\s*stand|hookup|hook\s*up|booty\s*call|friends?\s*with\s*benefits|fwb|nsa|f[*\s]?u[*\s]?c[*\s]?k|d[*\s]?i[*\s]?c[*\s]?k|p[*\s]?u[*\s]?s[*\s]?s[*\s]?y|c[*\s]?o[*\s]?c[*\s]?k|a[*\s]?s[*\s]?s\s*h[*\s]?o[*\s]?l[*\s]?e|cum\s*shot|cumshot|creampie|milf|dilf|gilf|dildo|vibrator|sex\s*toy|fleshlight|slutt?y?|whor[e]?|bitch|hoe|thot|camgirl|escort|prostitut\w*|hooker|callgirl|cuckold|incest|pedo|loli|shota|bestiality|voyeur|exhibition|upskirt|downblouse|cleavage|nipple|breast|boob[s]?|tit[s]?|titt(?:y|ies)|areola|labia|clit|clitoris|vagina|penis|erection|ejaculat\w*|sperm|semen|cum|jizz|squirt|wet\s*pussy|hard\s*on|boner|stiffy|deepthroat|gagging|choking|spank|bukkake|gloryhole|swing(?:er|ing)|polyamor\w*)\b/gi,
  /\b(send\s*(me\s*)?(nudes?|pics?|photos?|body\s*pics?))\b/gi,
  /\b(show\s*(me\s*)?(your\s*)?(body|boobs?|tits?|ass|butt|privates?))\b/gi,
  /\b(let'?s?\s*(have\s*)?sex|wanna\s*(f[*]?ck|bang|smash|screw))\b/gi,
  /\b(horny|turned\s*on|get\s*laid|make\s*love|sleep\s*with\s*me)\b/gi,
  // ========== HINDI / URDU (Romanized — Hinglish) ==========
  /\b(chod\w*|chud\w*|chudai|chudwa\w*|chudak\w*|chudasi|chinaal|lund|loda|lauda|laude|launde|lawde|gaand|gandu|gaandu|bhosd[ai]\w*|bhosdike|bhosdiwale|bhonsdi|randi|randwa|raand|chut|chutiya|chutiyap|chutmarani|chutiye|maderchod|madarchod|maaderchod|madhrchod|behenchod|bhenchod|bhencho|bsdk|mkb|jhaant|jhant|jhand|muth|muthal|hilana|hilake|hilao|hilane|gandfat|gandmara|gandmar|gandmasti|tatti|tatte|fudi|fuddi|chuchi|chuchiyan|momme|mamme|kuttiya|haraamzad\w*|haramzad\w*|kamine|kamini|raand\w*|rakhel|aiyaash|aiyash|sutta|nashe|gilf)\b/gi,
  // Hindi (Devanagari)
  /(चोद|चूद|चुदाई|चुदक्कड़|चुदासी|लंड|लौड़ा|लौड़े|लौंड़े|गांड|गाण्ड|गांडू|भोसड़ी|भोसड़ीके|भोंसड़ी|रंडी|रांड|चूत|चुतिया|चूतिये|चूतमारानी|मादरचोद|बहनचोद|भेनचोद|झांट|झांटू|मूठ|हिलाना|हिलाओ|गंदफट|गांडमारा|टट्टी|फुद्दी|चूची|चूचियाँ|कुत्तिया|हरामज़ादा|हरामी|कमीना|कमीनी|आयाश)/g,
  // Urdu (Nastaliq script)
  /(چود|چودائی|لنڈ|لوڑا|گانڈ|بھوسڑی|رنڈی|چوت|چتیا|مادرچود|بہنچود|ہراامزادہ|کمینہ|کتیا)/g,
  // ========== TAMIL ==========
  /\b(otha|othha|oththa|thevdiya|thevidiya|thevudiya|pundai|poondai|sunni|soonni|oombu|oomba|koothi|kooth|myiru|maire|naaye|naai|punda|kena|loosu|kayadi|paei|kazhuthai|panni|kena\s*panni)\b/gi,
  /(ஓத்தா|ஓத்த|தேவடியா|தேவிடியா|புண்டை|பூண்டை|சுன்னி|ஊம்பு|கூதி|மைரு|மைரே|நாயே|பண்டா|கேனா|பன்னி|கழுதை)/g,
  // ========== TELUGU ==========
  /\b(dengey|denga|dengu|dengaalaa|modda|moddha|gudda|guddha|lanja|lanjakodaka|pooku|pukulo|sulli|gajji|saami|nikamma|naayi|donga|gaddida|battayi)\b/gi,
  /(దెంగేయ్|దెంగు|దెంగా|మొడ్డ|గుద్ద|లంజ|లంజకొడక|పూకు|సుల్లి|నాయీ|దొంగ)/g,
  // ========== BENGALI ==========
  /\b(choda|chodachudi|baal|maagi|magir?|gud|dhon|magi|chudi|chudai|khanki|khankir|chodam|chudam|chudte|baalpanti|hagamuto|gandu|laar|laund|kutta|kuttar|shala|shali|harami|magiir)\b/gi,
  /(চোদা|চোদাচুদি|বাল|মাগি|গুদ|ধোন|চুদি|চুদাই|খানকি|খানকির|গাণ্ডু|হারামি|কুত্তা|কুত্তার|শালা|শালী)/g,
  // ========== KANNADA ==========
  /\b(tunne|tunni|tull|tulli|sule|sulemaga|bolimaga|bevarsi|munde|kotari|naayi|kelsa|gubbi|hode|aithu|hennu\s*kelsa)\b/gi,
  /(ತುನ್ನೆ|ತುಳ್ಳ|ತುಳ್ಳಿ|ಸೂಳೆ|ಸೂಳೇಮಗ|ಬೋಳಿಮಗ|ಬೇವರ್ಸಿ|ಮುಂಡೆ|ನಾಯಿ)/g,
  // ========== MALAYALAM ==========
  /\b(kunna|kunne|pooru|poori|thendi|thendiyole|myiru|myire|poorr|patti|naaye|kazhuvere|kandam|chettan\s*pooru|thayoli|thayolimol|achanammede|kazhuvera|nayinte\s*mone|porimol)\b/gi,
  /(കുണ്ണ|പൂറ്|പൂറി|തെണ്ടി|തെണ്ടിയോളെ|മൈര്|പട്ടി|നായേ|കഴുവേറെ|തായോളി|പൂറിമോള്)/g,
  // ========== MARATHI ==========
  /\b(zavadya|zavadi|jhavla|jhavnar|madharchod|zhavne|randya|randichi|aaichya|aaichi\s*gand|bahnchod|gandya|kutra|sali|gadhav|chyaayla|tujhya\s*aaichi)\b/gi,
  /(झवाड्या|झवाडी|झवला|झवणार|मादरचोद|झवणे|रांडया|रांडीची|आईच्या|गांड|गांड्या|भेनचोद|च्यायला|कुत्रा|गाढव)/g,
  // ========== GUJARATI ==========
  /\b(chodu|chodvu|chodva|gand|gandu|lodo|laudo|bhosad|bhosadi|chutiya|randi|saala|saali|kutra|gadhedo|haramkhor|chinaal|harami)\b/gi,
  /(ચોદુ|ચોદવુ|ગાંડ|ગાંડુ|લોડો|લૌડો|ભોસડ|ભોસડી|ચૂતિયા|રંડી|હરામી|હરામખોર|કૂતરા|ગધેડો)/g,
  // ========== PUNJABI ==========
  /\b(lann|laun|laund|phuddi|phudi|kanjri|kanjar|chod|chodu|bhosad|bhosadi|kutti|kuttiye|gashti|paindu|chinaal|haraami|teri\s*maa|teri\s*pen|behnchod|maderchod|saala|saali|gadha)\b/gi,
  /(ਲੰਨ|ਲੌਣ|ਫੁੱਦੀ|ਫੁਡੀ|ਕੰਜਰੀ|ਕੰਜਰ|ਚੋਦ|ਭੋਸੜ|ਭੋਸੜੀ|ਕੁੱਤੀ|ਕੁੱਤੀਏ|ਗਸ਼ਤੀ|ਪੈਂਡੂ|ਹਰਾਮੀ|ਮਾਦਰਚੋਦ|ਬਹਿਣਚੋਦ)/g,
  // ========== ODIA / ORIYA ==========
  /\b(maguni|nakata|maaichoda|bhainchoda|gandi|kukura|haraami|chutiya|randi)\b/gi,
  /(ମାଗୁଣି|ନକଟା|ମାଇଚୋଦା|ଭଇଁଚୋଦା|ଗଣ୍ଡି|କୁକୁର|ହରାମୀ|ଚୁତିଆ|ରଣ୍ଡୀ)/g,
  // ========== ASSAMESE ==========
  /\b(maguni|chuda|chudai|chudri|gud|dhon|magi|harami|kutta|sala|sali)\b/gi,
  /(মাগুনি|চুদা|চুদাই|গুদ|ধোন|মাগি|হারামি|কুকুৰ)/g,
  // ========== KASHMIRI / SINDHI / NEPALI / KONKANI ==========
  /\b(thoo|saale|kaminey|gandu|chutiya|randi|harami|kuttiya|nepali\s*chodne|saala\s*chor)\b/gi,
  // Arabic
  /\b(kos|ayre|sharmouta|nikni|zobb|teezi|manyak|sharmoot)\b/gi,
  /\b(كس|زب|شرموطة|طيزي|منيك)\b/g,
  // Spanish
  /\b(puta|verga|coger|chingar|pendejo|culo|polla|follar|coño|mierda)\b/gi,
  // French
  /\b(putain|baise[r]?|salope|niquer|enculer|merde|couilles|bite)\b/gi,
  // Portuguese
  /\b(foder|puta|buceta|caralho|porra|merda|safado)\b/gi,
  // Chinese
  /[操肏屌屄婊鸡巴逼骚淫荡]/g,
  // Japanese
  /[ちんこまんこセックスエッチオナニー]/g,
  // Korean
  /\b(씨발|존나|보지|자지|씹|좆)\b/g,
  // Indonesian/Malay
  /\b(kontol|memek|ngentot|pepek|jembut|bangsat)\b/gi,
  // Turkish
  /\b(sik|amcık|orospu|götveren|sikis|yarrak)\b/gi,
  // Russian
  /\b(blyad|suka|huy|pizda|yebat|nahui|mudak)\b/gi,
  /\b(блядь|сука|хуй|пизда|ебать|нахуй|мудак)\b/g,
  // Thai
  /\b(เย็ด|หี|ควย|อีสัตว์|อีเหี้ย)\b/g,
  // Vietnamese
  /\b(địt|lồn|cặc|đụ|đĩ)\b/gi,
  // German
  /\b(ficken|hurensohn|schlampe|schwanz|fotze|wichser)\b/gi,
  // Obfuscation/leetspeak
  /\b(s[3e]x|n[u0]d[3e]|p[o0]rn|fck|f[*#@]ck|sh[!1]t|d[!1]ck|p[*#@]ssy|c[*#@]ck)\b/gi,
  /\b[s$][e3][xX]|[nN][uU][dD][eE3][sS$]?\b/gi,
];

// ========================================
// HARMFUL CONTENT DETECTION
// ========================================

const HARMFUL_CONTENT_PATTERNS = [
  // Threats and violence
  /\b(i('?ll| will)\s*(kill|murder|hurt|harm|stab|shoot|beat|destroy|rape)\s*(you|him|her|them|myself|yourself))\b/gi,
  /\b(kill\s*(yourself|urself|u|your\s*self)|go\s*die|hope\s*you\s*die)\b/gi,
  /\b(i('?m| am)\s*going\s*to\s*(kill|murder|hurt|harm|attack|rape))\b/gi,
  /\b(death\s*threat|bomb\s*threat|i('?ll| will)\s*bomb)\b/gi,
  /\b(suicide|cut\s*yourself|harm\s*yourself|end\s*your\s*life)\b/gi,
  // Harassment
  /\b(i('?ll| will)\s*(find|track|stalk|hunt)\s*(you|your\s*(house|home|family|address)))\b/gi,
  /\b(you('?re| are)\s*(worthless|garbage|trash|nothing|dead))\b/gi,
  /\b(kys|k\.y\.s|kill\s*your\s*self)\b/gi,
  // Blackmail/extortion
  /\b(i('?ll| will)\s*(expose|leak|share)\s*(your|ur)\s*(photos?|pics?|videos?|nudes?))\b/gi,
  /\b(pay\s*me\s*or|send\s*money\s*or\s*i('?ll| will))\b/gi,
];

// ========================================
// HATE SPEECH DETECTION (multilingual)
// ========================================

const HATE_SPEECH_PATTERNS = [
  // English — racial / religious / casteist / homophobic / xenophobic slurs
  /\b(n[i1]gg(?:er|a|az)|ch[i1]nk|sp[i1]c|k[i1]ke|w[e3]tback|towel\s*head|sand\s*n\w+|cracker|gook|paki|raghead|jihad[i]?|terror[i1]st\s*(scum|pig)?|kafir\s*scum|infidel\s*scum|fag|f[a@]gg[o0]t|dyke|tranny|shemale|retard|spaz|mongoloid|gypsy\s*scum|jewboy|zionist\s*pig|nazi|hitler\s*was\s*right|gas\s*the\s*\w+|white\s*power|kkk|black\s*lives\s*don'?t\s*matter|all\s*\w+\s*should\s*die)\b/gi,
  // Caste-based slurs (India)
  /\b(chamar|bhangi|chura|dalit\s*scum|achoot|untouchable|neech\s*jaat|low\s*caste|harijan\s*scum|kanjar|mahar|mochi|musahar|valmiki\s*scum)\b/gi,
  // Religious hatred (India / South Asia)
  /\b(katua|katwa|mulla\s*scum|hindu\s*scum|sikh\s*scum|christian\s*scum|jain\s*scum|buddhist\s*scum|pakistani\s*scum|bangla\s*scum|rohingya\s*scum|love\s*jihad|land\s*jihad|gow?\s*mata\s*killer|cow\s*killer|beef\s*eater\s*scum|pork\s*eater\s*scum|circumcised\s*scum|kafir\s*kill)\b/gi,
  // Hindi / Hinglish hate
  /\b(saala\s*musla|saala\s*mulla|saala\s*hindu|saala\s*sardar|saala\s*madrasi|saala\s*bihari|kala\s*kaluta|kalu|habshi|chinki|momos|kaali\s*kaluti|bhangi|chamar|achoot|katuwa|katua|mulle|hindue|sikhde|jaat\s*sala|marwadi\s*chor|gujju\s*chor|south\s*indian\s*idli|madarasi\s*idli|bihari\s*bhaiya\s*chor)\b/gi,
  // Devanagari hate
  /(साला\s*मुसला|साला\s*मुल्ला|कटुवा|कटुआ|भंगी|चमार|अछूत|नीच\s*जात|काली\s*कलूटी|कलूटा|हब्शी|चिंकी|हिंदू\s*स्कम|मुल्ले|गाय\s*मारने|बीफ\s*खाने)/g,
  // Tamil hate
  /(வடநாட்டான்\s*போ|பயல்\s*தமிழன்\s*அல்ல|துலுக்கன்|தீ\s*வைப்பேன்)/g,
  // Telugu hate
  /(ఆంధ్రోడు\s*పో|నీచ\s*జాతి|మ్లేచ్ఛుడు)/g,
  // Bengali hate
  /(মালু|মালুর\s*বাচ্চা|বিহারি\s*চোর|হিন্দু\s*স্কাম)/g,
  // Calls for violence against groups
  /\b(kill\s*all\s*(muslims|hindus|sikhs|christians|jews|gays|lesbians|trans|blacks|whites|indians|pakistanis|bangladeshis|chinese|tamils|brahmins|dalits))\b/gi,
  /\b((muslims|hindus|sikhs|christians|jews|gays|lesbians|trans|blacks|whites|indians|pakistanis|bangladeshis|chinese|dalits|brahmins)\s*should\s*(die|be\s*killed|burn|hang|be\s*hanged|be\s*shot|leave))\b/gi,
  /\b(go\s*back\s*to\s*(your\s*country|pakistan|bangladesh|africa|china))\b/gi,
  // Dehumanizing language
  /\b((muslims|hindus|jews|blacks|gays|trans|dalits)\s*are\s*(animals|dogs|pigs|vermin|cockroaches|rats|cancer))\b/gi,
];

// ========================================
// CONTACT SHARING DETECTION
// ========================================

// Number words in multiple languages
const NUMBER_WORDS_EN = [
  'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
  'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
  'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety', 'hundred',
];

const NUMBER_WORDS_HINDI = [
  'ek', 'do', 'teen', 'char', 'paanch', 'panch', 'chhe', 'saat', 'aath', 'nau', 'das',
  'gyarah', 'barah', 'terah', 'chaudah', 'pandrah', 'solah', 'satrah', 'athaarah', 'unnis', 'bees',
  'nol', 'nil', 'shunya',
];

const NUMBER_WORDS_ARABIC = [
  'wahid', 'ithnayn', 'thalatha', 'arba', 'khamsa', 'sitta', 'saba', 'thamaniya', 'tisa', 'ashara',
  'sifr',
];

const ALL_NUMBER_WORDS = [...NUMBER_WORDS_EN, ...NUMBER_WORDS_HINDI, ...NUMBER_WORDS_ARABIC];

// 4+ number words in sequence = likely phone number
const numberWordsPattern = new RegExp(
  `\\b(${ALL_NUMBER_WORDS.join('|')})(\\s*[-,./\\s]?\\s*(${ALL_NUMBER_WORDS.join('|')})){3,}\\b`,
  'gi'
);

// Symbol-encoded numbers: z3r0, 0ne, tw0, thr33, f0ur, f1ve, s1x, etc.
const SYMBOL_NUMBER_PATTERNS = [
  /\b(z[3e]r[o0]|[o0]n[e3]|tw[o0]|thr[3e]{2}|f[o0]ur|f[1i]v[e3]|s[1i]x|s[3e]v[3e]n|[3e][1i]ght|n[1i]n[e3])\b/gi,
];

const PHONE_PATTERNS = [
  // Standard phone formats
  /\+?\d{1,4}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9}/g,
  // 7+ consecutive digits
  /\b\d{7,15}\b/g,
  // Digits separated by spaces/dots/dashes (e.g., "9 8 7 6 5 4 3 2 1 0")
  /\b\d[\s.-]*\d[\s.-]*\d[\s.-]*\d[\s.-]*\d[\s.-]*\d[\s.-]*\d+/g,
  // Number words in sequence
  numberWordsPattern,
  // Symbol/leet-speak numbers in sequence (4+)
  ...SYMBOL_NUMBER_PATTERNS,
  // Digits mixed with letters to obfuscate: "my num is nine8seven6five4three2one0"
  /\b(my|mera|call|ring|dial|phone|number|no|num|mob|mobile)\b.{0,20}\d/gi,
  // Hindi number words in Devanagari
  /\b(एक|दो|तीन|चार|पांच|छः|सात|आठ|नौ|दस|शून्य)(\s*(एक|दो|तीन|चार|पांच|छः|सात|आठ|नौ|दस|शून्य)){3,}\b/g,
];

const EMAIL_PATTERNS = [
  /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/gi,
  // Obfuscated: user [at] domain [dot] com
  /[a-zA-Z0-9._%+-]+\s*[@\[\(]\s*[a-zA-Z0-9.-]+\s*[.\[\(]\s*[a-zA-Z]{2,}/gi,
  /[a-zA-Z0-9._%+-]+\s*(at|@|AT|अट|ऐट)\s*[a-zA-Z0-9.-]+\s*(dot|\.|\s*डॉट)\s*[a-zA-Z]{2,}/gi,
  // Gmail/yahoo/hotmail mentions with username
  /\b(gmail|yahoo|hotmail|outlook|proton\s*mail|mail)\s*[-:]\s*[a-zA-Z0-9._]+/gi,
  /\b[a-zA-Z0-9._]+\s*(gmail|yahoo|hotmail|outlook)\b/gi,
];

// ========================================
// SOCIAL MEDIA - BLOCK APP NAMES + IDs
// ========================================

const SOCIAL_MEDIA_APPS = [
  'whatsapp', 'whats\\s*app', 'watsapp', 'wapp', 'wa',
  'instagram', 'insta', 'ig',
  'facebook', 'fb', 'messenger',
  'telegram', 'tg', 'telgram',
  'snapchat', 'snap', 'sc',
  'tiktok', 'tik\\s*tok',
  'wechat', 'we\\s*chat',
  'discord', 'dc',
  'skype',
  'twitter', 'x\\.com',
  'signal',
  'viber',
  'line',
  'imo',
  'kik',
  'hike',
  'kakaotalk', 'kakao',
  'zalo',
  'threads',
  'linkedin',
  'pinterest',
  'reddit',
  'tumblr',
  'youtube', 'yt',
  'twitch',
];

const socialAppsJoined = SOCIAL_MEDIA_APPS.join('|');

const SOCIAL_MEDIA_PATTERNS = [
  // App name followed by handle/id/number
  new RegExp(`\\b(${socialAppsJoined})\\s*[:\\-#@]?\\s*[\\w.+-]+`, 'gi'),
  // "add/contact/reach me on [app]"
  new RegExp(`\\b(add|contact|reach|text|message|dm|msg|ping|hit\\s*me|find\\s*me|follow)\\s+(me\\s+)?(on|at|via|in)\\s+(${socialAppsJoined})\\b`, 'gi'),
  // "[app] id/username/handle/number is..."
  new RegExp(`\\b(${socialAppsJoined})\\s+(id|username|handle|number|no|num|account|profile)\\s*(is|:|-|=)\\s*[\\w.@+-]+`, 'gi'),
  // "my [app] is..."
  new RegExp(`\\b(my|mera|meri)\\s+(${socialAppsJoined})\\s*(is|hai|:|-|=)\\s*[\\w.@+-]+`, 'gi'),
  // Direct links
  /\b(wa\.me|t\.me|m\.me|bit\.ly|tinyurl\.com|goo\.gl)\/\S+/gi,
  // Standalone social media app names (block even mentioning them)
  new RegExp(`\\b(${socialAppsJoined})\\b`, 'gi'),
];

const CONTACT_INTENT_PATTERNS = [
  /\b(contact|reach|text|message|call|ring)\s*(me|us)\s*(outside|privately|directly|on|at|via|off\s*this|off\s*app)/gi,
  /\b(give|send|share|tell)\s*(me|you|your|my|ur)\s*(number|phone|mobile|cell|email|id|contact|address)/gi,
  /\b(here'?s?|this is)\s*(my|the)\s*(number|phone|mobile|email|id|contact)/gi,
  /\b(dm|private message|pm|inbox)\s*(me|you)/gi,
  /\b(let'?s?\s*(talk|chat|meet)\s*(outside|off|privately|on\s*(another|other)\s*app))/gi,
  /\b(meet\s*me|come\s*to|visit\s*me)\s*(at|in|on)/gi,
  /\b(outside\s*(this\s*)?app|off\s*platform|another\s*app|other\s*app)/gi,
];

// ========================================
// FILE / ATTACHMENT BLOCKING
// ========================================

/**
 * List of file extensions that could contain contact info
 * Images with text, documents, etc.
 */
const BLOCKED_ATTACHMENT_EXTENSIONS = [
  // Documents that can contain text with contact info
  '.pdf', '.doc', '.docx', '.txt', '.rtf', '.odt',
  '.xls', '.xlsx', '.csv',
  '.ppt', '.pptx',
  // vCards / contacts
  '.vcf', '.vcard',
  // Web files
  '.html', '.htm',
];

/**
 * Check if a filename suggests contact sharing
 */
const CONTACT_FILENAME_PATTERNS = [
  /contact/i,
  /phone/i,
  /number/i,
  /my\s*id/i,
  /whatsapp/i,
  /instagram/i,
  /email/i,
  /snap/i,
  /telegram/i,
  /facebook/i,
  /vcf/i,
  /vcard/i,
];

// ========================================
// TYPES
// ========================================

export type ViolationType = 'phone' | 'email' | 'social_media' | 'contact_intent' | 'sexual_content' | 'harmful_content' | 'hate_speech' | 'blocked_attachment' | 'number_words';

export interface ModerationResult {
  isBlocked: boolean;
  reason?: string;
  detectedType?: ViolationType;
  sanitizedMessage?: string;
  /** Words/phrases that triggered the block — useful for audio beep timing */
  matches?: string[];
}

/**
 * Combined export for downstream consumers (audio/video moderation hooks).
 * The audio hook uses these to decide which words to beep over a transcript.
 */
export const SPEECH_BLOCKLIST_PATTERNS = [
  ...SEXUAL_CONTENT_PATTERNS,
  ...HATE_SPEECH_PATTERNS,
];

/**
 * Check if message contains prohibited content (for 1-to-1 chats, skips sexual content restriction)
 */
export function moderateMessage1to1(message: string): ModerationResult {
  if (!message || typeof message !== 'string') {
    return { isBlocked: false };
  }

  if (isMediaChatMessage(message)) {
    return { isBlocked: false };
  }

  const normalizedMessage = message.toLowerCase().replace(/\s+/g, ' ').trim();

  // Define patterns for prohibited content (excluding sexual)
  // Re-use existing patterns defined elsewhere in the file
  
  // 1. Harmful content
  for (const pattern of HARMFUL_CONTENT_PATTERNS) {
    if (pattern.test(message)) {
      return {
        isBlocked: true,
        reason: 'Harmful or abusive content is strictly prohibited.',
        detectedType: 'harmful_content',
      };
    }
  }

  // 2. Hate speech
  for (const pattern of HATE_SPEECH_PATTERNS) {
    if (pattern.test(message)) {
      return {
        isBlocked: true,
        reason: 'Hate speech is strictly prohibited.',
        detectedType: 'hate_speech',
      };
    }
  }

  // 4. Phone numbers (digits, words, symbols)
  for (const pattern of PHONE_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(message) || pattern.test(normalizedMessage)) {
      return {
        isBlocked: true,
        reason: 'Sharing phone numbers is not allowed for your safety.',
        detectedType: 'phone',
      };
    }
  }

  // 4. Emails
  for (const pattern of EMAIL_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(message) || pattern.test(normalizedMessage)) {
      return {
        isBlocked: true,
        reason: 'Sharing email addresses is not allowed for your safety.',
        detectedType: 'email',
      };
    }
  }

  // 5. Social media app names and handles
  for (const pattern of SOCIAL_MEDIA_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(message) || pattern.test(normalizedMessage)) {
      return {
        isBlocked: true,
        reason: 'Mentioning social media apps or sharing accounts is not allowed.',
        detectedType: 'social_media',
      };
    }
  }

  // 6. Contact sharing intent
  for (const pattern of CONTACT_INTENT_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(message) || pattern.test(normalizedMessage)) {
      return {
        isBlocked: true,
        reason: 'Sharing contact information outside the app is not allowed.',
        detectedType: 'contact_intent',
      };
    }
  }

  return { isBlocked: false };
}

// ========================================
// MAIN MODERATION FUNCTION
// ========================================

/**
 * Check if message contains prohibited content
 */
export function moderateMessage(message: string): ModerationResult {
  if (!message || typeof message !== 'string') {
    return { isBlocked: false };
  }

  if (isMediaChatMessage(message)) {
    return { isBlocked: false };
  }

  const normalizedMessage = message.toLowerCase().replace(/\s+/g, ' ').trim();
  const collectMatches = (pattern: RegExp): string[] => {
    pattern.lastIndex = 0;
    const found = message.match(pattern) || normalizedMessage.match(pattern) || [];
    return Array.from(new Set(found));
  };

  // 1. Sexual content (highest priority)
  for (const pattern of SEXUAL_CONTENT_PATTERNS) {
    const matches = collectMatches(pattern);
    if (matches.length) {
      return {
        isBlocked: true,
        reason: 'Sexual or explicit content is strictly prohibited.',
        detectedType: 'sexual_content',
        matches,
      };
    }
  }

  // 2. Hate speech (slurs, religious/caste/racial hatred, calls for violence)
  for (const pattern of HATE_SPEECH_PATTERNS) {
    const matches = collectMatches(pattern);
    if (matches.length) {
      return {
        isBlocked: true,
        reason: 'Hate speech, slurs, and discriminatory language are not allowed.',
        detectedType: 'hate_speech',
        matches,
      };
    }
  }

  // 3. Harmful/threatening content
  for (const pattern of HARMFUL_CONTENT_PATTERNS) {
    const matches = collectMatches(pattern);
    if (matches.length) {
      return {
        isBlocked: true,
        reason: 'Threatening or harmful content is not allowed.',
        detectedType: 'harmful_content',
        matches,
      };
    }
  }

  // 4. Phone numbers (digits, words, symbols)
  for (const pattern of PHONE_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(message) || pattern.test(normalizedMessage)) {
      return {
        isBlocked: true,
        reason: 'Sharing phone numbers is not allowed for your safety.',
        detectedType: 'phone',
      };
    }
  }

  // 4. Emails
  for (const pattern of EMAIL_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(message) || pattern.test(normalizedMessage)) {
      return {
        isBlocked: true,
        reason: 'Sharing email addresses is not allowed for your safety.',
        detectedType: 'email',
      };
    }
  }

  // 5. Social media app names and handles
  for (const pattern of SOCIAL_MEDIA_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(message) || pattern.test(normalizedMessage)) {
      return {
        isBlocked: true,
        reason: 'Mentioning social media apps or sharing accounts is not allowed.',
        detectedType: 'social_media',
      };
    }
  }

  // 6. Contact sharing intent
  for (const pattern of CONTACT_INTENT_PATTERNS) {
    pattern.lastIndex = 0;
    if (pattern.test(message) || pattern.test(normalizedMessage)) {
      return {
        isBlocked: true,
        reason: 'Sharing contact information outside the app is not allowed.',
        detectedType: 'contact_intent',
      };
    }
  }

  return { isBlocked: false };
}

// ========================================
// ATTACHMENT MODERATION
// ========================================

/**
 * Check if a file attachment should be blocked
 * Only blocks vCard/contact files outright.
 * Documents are allowed but their TEXT CONTENT must be checked separately
 * via moderateMessage() after extraction.
 */
export function moderateAttachment(fileName: string, fileType?: string): ModerationResult {
  if (!fileName) return { isBlocked: false };

  const lowerName = fileName.toLowerCase();

  // Block vCard files (direct contact sharing)
  if (lowerName.endsWith('.vcf') || lowerName.endsWith('.vcard')) {
    return {
      isBlocked: true,
      reason: 'Sharing contact files is not allowed.',
      detectedType: 'blocked_attachment',
    };
  }

  // Block suspicious MIME types for contacts
  if (fileType && (fileType === 'text/vcard' || fileType === 'text/x-vcard')) {
    return {
      isBlocked: true,
      reason: 'Sharing contact files is not allowed.',
      detectedType: 'blocked_attachment',
    };
  }

  // Phone-number / contact-filename checks intentionally disabled for attachments.

  return { isBlocked: false };
}

/**
 * Check if an image might contain text with contact info
 * This checks the OCR-extracted text or image filename
 */
export function moderateImageText(extractedText: string): ModerationResult {
  if (!extractedText) return { isBlocked: false };
  const result = moderateMessage(extractedText);
  // Phone/contact-info detection is disabled for attachments — only block
  // sexual/harmful/hate content found in extracted image text.
  if (result.isBlocked && (result.detectedType === 'phone' || result.detectedType === 'number_words' || result.detectedType === 'contact_intent' || result.detectedType === 'email' || result.detectedType === 'social_media')) {
    return { isBlocked: false };
  }
  return result;
}

// ========================================
// CONVENIENCE FUNCTIONS
// ========================================

/**
 * Quick check - returns true if blocked
 */
export function isMessageBlocked(message: string): boolean {
  return moderateMessage(message).isBlocked;
}

/**
 * Quick check for attachments
 */
export function isAttachmentBlocked(fileName: string, fileType?: string): boolean {
  return moderateAttachment(fileName, fileType).isBlocked;
}

/**
 * Get user-friendly error message
 */
export function getBlockedMessageError(result: ModerationResult): string {
  return result.reason || 'This message contains prohibited content.';
}
