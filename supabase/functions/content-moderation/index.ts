import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

// Content moderation patterns - multi-language blocking
const VIOLATION_PATTERNS = {
  sexual_content: [
    /\b(sex|nude[s]?|naked|porn|xxx|nsfw|erotic|orgasm|masturbat|blowjob|handjob|anal\s*sex|oral\s*sex|threesome|gangbang|fetish|bondage|bdsm|strip\s*tease|hookup|hook\s*up|booty\s*call|cum\s*shot|creampie|milf|dildo|vibrator|slutt?y?|whor[e]?)\b/gi,
    /\b(send\s*(me\s*)?(nudes?|pics?|photos?|body\s*pics?))\b/gi,
    /\b(show\s*(me\s*)?(your\s*)?(body|boobs?|tits?|ass|butt|privates?))\b/gi,
    /\b(let'?s?\s*(have\s*)?sex|wanna\s*(f[*]?ck|bang|smash|screw))\b/gi,
    /\b(horny|turned\s*on|get\s*laid|make\s*love|sleep\s*with\s*me)\b/gi,
    /\b(f[*\s]?u[*\s]?c[*\s]?k|d[*\s]?i[*\s]?c[*\s]?k|p[*\s]?u[*\s]?s[*\s]?s[*\s]?y|c[*\s]?o[*\s]?c[*\s]?k)\b/gi,
    /\b(chod|chud|lund|gaand|bhosdi|randi|chut|maderchod|behenchod|chudai|jhaant|muth|hilana)\b/gi,
    /\b(चोद|चूत|लंड|गांड|भोसडी|रंडी|चुदाई|मादरचोद|बहनचोद|मूठ|हिलाना)\b/g,
    /\b(otha|thevdiya|pundai|sunni|oombu|koothi|myiru)\b/gi,
    /\b(ஓத்தா|தேவடியா|புண்டை|சுன்னி|ஊம்பு|கூதி)\b/g,
    /\b(dengey|modda|gudda|lanja|pooku|sulli)\b/gi,
    /\b(దెంగేయ్|మొడ్డ|గుద్ద|లంజ|పూకు|సుల్లి)\b/g,
    /\b(choda|baal|magir?|gud|dhon|magi|chudi)\b/gi,
    /\b(চোদা|বাল|মাগি|গুদ|ধোন|চুদি)\b/g,
    /\b(tunne|tull|sule|bolimaga|ninge)\b/gi,
    /\b(ತುನ್ನೆ|ತುಳ್ಳ|ಸೂಳೆ|ಬೋಳಿಮಗ)\b/g,
    /\b(kunna|pooru|thendi|myiru|poorr)\b/gi,
    /\b(കുണ്ണ|പൂറ്|തെണ്ടി|മൈര്)\b/g,
    /\b(zavadya|jhavla|madharchod|zhavne|randya)\b/gi,
    /\b(chodu|chodvu|gand|lodo|bhosad)\b/gi,
    /\b(lann|phuddi|kanjri|kutti)\b/gi,
    /\b(kos|ayre|sharmouta|nikni|zobb|teezi|manyak|sharmoot)\b/gi,
    /\b(كس|زب|شرموطة|طيزي|منيك)\b/g,
    /\b(puta|verga|coger|chingar|polla|follar|coño)\b/gi,
    /\b(putain|baise[r]?|salope|niquer|enculer|bite)\b/gi,
    /\b(foder|buceta|caralho|porra|safado)\b/gi,
    /[操肏屌屄婊鸡巴逼骚淫荡]/g,
    /\b(씨발|존나|보지|자지|씹|좆)\b/g,
    /\b(kontol|memek|ngentot|pepek|jembut)\b/gi,
    /\b(sik|amcık|orospu|götveren|sikis|yarrak)\b/gi,
    /\b(blyad|suka|huy|pizda|yebat|nahui)\b/gi,
    /\b(блядь|сука|хуй|пизда|ебать|нахуй)\b/g,
    /\b(เย็ด|หี|ควย)\b/g,
    /\b(địt|lồn|cặc|đụ|đĩ)\b/gi,
    /\b(ficken|hurensohn|schlampe|schwanz|fotze|wichser)\b/gi,
    /\b(s[3e]x|n[u0]d[3e]|p[o0]rn|fck|f[*#@]ck|d[!1]ck|p[*#@]ssy)\b/gi,
  ],
  harmful_content: [
    /\b(i('?ll| will)\s*(kill|murder|hurt|harm|stab|shoot|beat|destroy|rape)\s*(you|him|her|them|myself|yourself))\b/gi,
    /\b(kill\s*(yourself|urself|u|your\s*self)|go\s*die|hope\s*you\s*die)\b/gi,
    /\b(death\s*threat|bomb\s*threat)\b/gi,
    /\b(suicide|cut\s*yourself|harm\s*yourself|end\s*your\s*life)\b/gi,
    /\b(kys|k\.y\.s|kill\s*your\s*self)\b/gi,
    /\b(i('?ll| will)\s*(expose|leak|share)\s*(your|ur)\s*(photos?|pics?|videos?|nudes?))\b/gi,
  ],
  spam: [
    /\b(buy\s*now|click\s*here|free\s*money|earn\s*\$|bitcoin|crypto\s*investment)\b/gi,
    /(https?:\/\/[^\s]+){3,}/gi,
  ],
  scam: [
    /\b(send\s*money|wire\s*transfer|western\s*union|gift\s*card|pay\s*me)\b/gi,
    /\b(bank\s*account|credit\s*card\s*number|ssn|social\s*security)\b/gi,
  ],
  contact_sharing: [
    /\b(\+?\d{10,15})\b/g,
    /\b\d{7,15}\b/g,
    /\b[\w.+-]+@[\w-]+\.[\w.-]+\b/gi,
    /\b(whatsapp|instagram|insta|snapchat|snap|tiktok|facebook|fb|telegram|tg|discord|skype|twitter|wechat|viber|signal|imo|kik|hike|kakaotalk|kakao|zalo|threads|linkedin|pinterest|reddit|tumblr|youtube|yt|twitch)\b/gi,
    /\b(wa\.me|t\.me|m\.me|bit\.ly)\/\S+/gi,
    /\b(contact|reach|text|message|call)\s*(me|us)\s*(outside|privately|directly|on|at|via)/gi,
    /\b(give|send|share)\s*(me|you|your|my)\s*(number|phone|mobile|cell|email|id|contact)/gi,
  ],
};

interface ModerationResult {
  isViolation: boolean;
  violations: Array<{
    type: string;
    severity: string;
    matchedContent: string;
  }>;
}

function moderateContent(content: string): ModerationResult {
  const violations: ModerationResult["violations"] = [];
  
  for (const [violationType, patterns] of Object.entries(VIOLATION_PATTERNS)) {
    for (const pattern of patterns) {
      const matches = content.match(pattern);
      if (matches) {
        let severity = "medium";
        if (violationType === "sexual_content" || violationType === "harassment") {
          severity = "high";
        } else if (violationType === "hate_speech") {
          severity = "critical";
        } else if (violationType === "contact_sharing") {
          severity = "low";
        }
        
        violations.push({
          type: violationType,
          severity,
          matchedContent: matches.slice(0, 3).join(", "),
        });
        break; // Only one match per violation type
      }
    }
  }

  return {
    isViolation: violations.length > 0,
    violations,
  };
}

interface JwtClaims {
  sub?: unknown;
  exp?: unknown;
  nbf?: unknown;
  [key: string]: unknown;
}

function decodeBase64Url(input: string): Uint8Array {
  const normalized = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(normalized.length + ((4 - normalized.length % 4) % 4), "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function decodeJwtPart<T>(part: string): T {
  return JSON.parse(new TextDecoder().decode(decodeBase64Url(part))) as T;
}

async function verifyHs256Jwt(token: string): Promise<JwtClaims | null> {
  const jwtSecret = Deno.env.get("SUPABASE_JWT_SECRET") || Deno.env.get("JWT_SECRET");
  if (!jwtSecret) return null;

  const parts = token.split(".");
  if (parts.length !== 3) return null;

  const [encodedHeader, encodedPayload, encodedSignature] = parts;
  const header = decodeJwtPart<{ alg?: string }>(encodedHeader);
  if (header.alg !== "HS256") return null;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(jwtSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const isValid = await crypto.subtle.verify(
    "HMAC",
    key,
    decodeBase64Url(encodedSignature),
    new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`),
  );
  if (!isValid) return null;

  const claims = decodeJwtPart<JwtClaims>(encodedPayload);
  const now = Math.floor(Date.now() / 1000);
  if (typeof claims.exp === "number" && claims.exp <= now) return null;
  if (typeof claims.nbf === "number" && claims.nbf > now) return null;
  return claims;
}

// Helper to verify authenticated user
async function verifyAuth(req: Request, supabase: any, authClient: any): Promise<{ isValid: boolean; error?: string; userId?: string; isAdmin?: boolean }> {
  const authHeader = req.headers.get('authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { isValid: false, error: 'Missing or invalid Authorization header' };
  }

  const token = authHeader.replace('Bearer ', '');
  
  const { data: claimsData, error } = await authClient.auth.getClaims(token);
  const claims = !error && claimsData?.claims?.sub ? claimsData.claims : await verifyHs256Jwt(token).catch(() => null);
  if (typeof claims?.sub !== 'string') {
    return { isValid: false, error: 'Invalid or expired token' };
  }

  // Check if user has admin role
  const { data: roleData } = await supabase
    .from('user_roles')
    .select('role')
    .eq('user_id', claims.sub)
    .eq('role', 'admin')
    .maybeSingle();

  return { isValid: true, userId: claims.sub, isAdmin: !!roleData };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const authHeader = req.headers.get('authorization') || '';
    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // SECURITY: Verify caller is authenticated
    const authResult = await verifyAuth(req, supabase, authClient);
    if (!authResult.isValid) {
      console.log(`[SECURITY] Unauthorized access to content-moderation: ${authResult.error}`);
      return new Response(
        JSON.stringify({ success: false, error: authResult.error }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const body = await req.json();
    const { action, messageId, chatId, content, userId } = body;
    
    // For batch scan, require admin role
    if (action === "scan_recent_messages" && !authResult.isAdmin) {
      return new Response(
        JSON.stringify({ success: false, error: "Admin role required for batch scan" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[AUDIT] User ${authResult.userId} called content-moderation action: ${action}`);

    if (action === "moderate_message") {
      // Moderate a single message
      const result = moderateContent(content || "");

      if (result.isViolation) {
        // Create alerts for each violation
        for (const violation of result.violations) {
          await supabase.from("policy_violation_alerts").insert({
            user_id: userId,
            violation_type: violation.type,
            severity: violation.severity,
            content: content?.substring(0, 500),
            source_message_id: messageId,
            source_chat_id: chatId,
            detected_by: "auto_moderation",
          });
        }

        // Flag the message
        if (messageId) {
          await supabase
            .from("chat_messages")
            .update({
              flagged: true,
              flag_reason: result.violations.map(v => v.type).join(", "),
              flagged_at: new Date().toISOString(),
              moderation_status: "flagged",
            })
            .eq("id", messageId);
        }

        console.log(`Message flagged for violations: ${result.violations.map(v => v.type).join(", ")}`);
      }

      return new Response(
        JSON.stringify({ success: true, result }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (action === "scan_recent_messages") {
      // Scan unflagged messages in batches using cursor-based pagination
      // Default batch size 500, configurable via request body (max 2000)
      const batchSize = Math.min(body?.batch_size || 500, 2000);
      const maxBatches = body?.max_batches || 10; // safety cap: up to 10 rounds
      let flaggedCount = 0;
      let totalScanned = 0;
      let lastCreatedAt: string | null = null;

      for (let batch = 0; batch < maxBatches; batch++) {
        let query = supabase
          .from("chat_messages")
          .select("id, message, sender_id, chat_id, created_at")
          .eq("flagged", false)
          .eq("moderation_status", "pending")
          .order("created_at", { ascending: true })
          .limit(batchSize);

        if (lastCreatedAt) {
          query = query.gt("created_at", lastCreatedAt);
        }

        const { data: messages, error } = await query;
        if (error) throw error;
        if (!messages || messages.length === 0) break;

        for (const msg of messages) {
          const result = moderateContent(msg.message || "");

          if (result.isViolation) {
            for (const violation of result.violations) {
              await supabase.from("policy_violation_alerts").insert({
                user_id: msg.sender_id,
                violation_type: violation.type,
                severity: violation.severity,
                content: msg.message?.substring(0, 500),
                source_message_id: msg.id,
                source_chat_id: msg.chat_id,
                detected_by: "batch_scan",
              });
            }

            await supabase
              .from("chat_messages")
              .update({
                flagged: true,
                flag_reason: result.violations.map(v => v.type).join(", "),
                flagged_at: new Date().toISOString(),
                moderation_status: "flagged",
              })
              .eq("id", msg.id);

            flaggedCount++;
          } else {
            // Mark as reviewed so it's not re-scanned
            await supabase
              .from("chat_messages")
              .update({ moderation_status: "clean" })
              .eq("id", msg.id);
          }
        }

        totalScanned += messages.length;
        lastCreatedAt = messages[messages.length - 1].created_at;

        // If we got fewer than batchSize, we've reached the end
        if (messages.length < batchSize) break;
      }

      console.log(`Batch scan complete: ${flaggedCount} messages flagged out of ${totalScanned} scanned`);

      return new Response(
        JSON.stringify({ success: true, scanned: totalScanned, flagged: flaggedCount }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: false, error: "Invalid action" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Content moderation error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error?.message || "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
