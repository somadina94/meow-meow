import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
};

interface VerificationRequest {
  imageBase64: string;
  expectedGender?: string;
  userId?: string;
  verificationType?: 'registration' | 'profile';
}

interface VerificationResult {
  verified: boolean;
  hasFace: boolean;
  detectedGender: 'male' | 'female' | 'unknown';
  confidence: number;
  reason: string;
  genderMatches: boolean;
}

const FACE_DETECTION_MODEL = 'microsoft/Florence-2-base';
const GENDER_CLASSIFICATION_MODEL = 'rizvandwiki/gender-classification-2';
const FACE_DETECTION_FALLBACK_MODEL = 'facebook/detr-resnet-50';

const MIN_CONFIDENCE_THRESHOLD = 0.55;
const HF_TIMEOUT_MS = 30000;

async function callHuggingFaceAPI(
  model: string,
  imageBytes: Uint8Array,
  hfToken: string,
  retries = 2
): Promise<any> {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), HF_TIMEOUT_MS);

      const response = await fetch(
        `https://api-inference.huggingface.co/models/${model}`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${hfToken}`,
            'Content-Type': 'application/octet-stream',
          },
          body: imageBytes,
          signal: controller.signal,
        }
      );

      clearTimeout(timeoutId);

      if (response.status === 503) {
        // Model is loading
        const body = await response.json();
        const waitTime = body.estimated_time ? Math.min(body.estimated_time * 1000, 20000) : 10000;
        console.log(`Model ${model} is loading, waiting ${waitTime}ms (attempt ${attempt + 1})`);
        if (attempt < retries) {
          await new Promise(r => setTimeout(r, waitTime));
          continue;
        }
        throw new Error(`Model ${model} is still loading after retries`);
      }

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`HF API error ${response.status}: ${errorText}`);
      }

      return await response.json();
    } catch (error) {
      if (attempt === retries) throw error;
      console.warn(`Attempt ${attempt + 1} failed for ${model}:`, error);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
}

async function detectFace(imageBytes: Uint8Array, hfToken: string): Promise<boolean> {
  try {
    // Use object detection model to find faces/people
    const results = await callHuggingFaceAPI(FACE_DETECTION_FALLBACK_MODEL, imageBytes, hfToken);

    if (Array.isArray(results)) {
      // DETR returns objects with labels
      const faceLabels = ['person', 'face', 'human face', 'head'];
      const hasPerson = results.some(
        (r: any) => faceLabels.some(label => r.label?.toLowerCase().includes(label)) && r.score > 0.5
      );
      console.log('Face detection results:', results.slice(0, 5).map((r: any) => ({ label: r.label, score: r.score })));
      return hasPerson;
    }
    return false;
  } catch (error) {
    console.error('Face detection error:', error);
    // If face detection fails, we'll still try gender classification
    // and use its confidence as an implicit face check
    return true; // Give benefit of doubt, gender classifier will catch non-faces
  }
}

async function classifyGender(imageBytes: Uint8Array, hfToken: string): Promise<{
  detectedGender: 'male' | 'female' | 'unknown';
  confidence: number;
  allScores: Array<{ label: string; score: number }>;
}> {
  try {
    const results = await callHuggingFaceAPI(GENDER_CLASSIFICATION_MODEL, imageBytes, hfToken);

    if (Array.isArray(results) && results.length > 0) {
      console.log('Gender classification raw results:', results);

      // Sort by score descending
      const sorted = [...results].sort((a: any, b: any) => b.score - a.score);
      const top = sorted[0];
      const label = top.label?.toLowerCase() || '';
      const score = top.score || 0;

      let detectedGender: 'male' | 'female' | 'unknown' = 'unknown';
      if (label.includes('male') && !label.includes('female')) {
        detectedGender = 'male';
      } else if (label.includes('female') || label.includes('woman') || label.includes('girl')) {
        detectedGender = 'female';
      } else if (label.includes('man') || label.includes('boy')) {
        detectedGender = 'male';
      }

      return {
        detectedGender,
        confidence: score,
        allScores: sorted.map((r: any) => ({ label: r.label, score: r.score })),
      };
    }

    return { detectedGender: 'unknown', confidence: 0, allScores: [] };
  } catch (error) {
    console.error('Gender classification error:', error);
    return { detectedGender: 'unknown', confidence: 0, allScores: [] };
  }
}

function validateImageFormat(imageBase64: string): { valid: boolean; bytes: Uint8Array | null } {
  try {
    const base64Data = imageBase64.startsWith('data:')
      ? imageBase64.split(',')[1]
      : imageBase64;

    if (base64Data.length < 1000) {
      return { valid: false, bytes: null };
    }

    // Check for valid image signatures
    const header = imageBase64.substring(0, 50).toLowerCase();
    const isValidFormat =
      header.includes('image/jpeg') ||
      header.includes('image/png') ||
      header.includes('image/webp') ||
      header.includes('image/jpg') ||
      base64Data.startsWith('/9j/') || // JPEG
      base64Data.startsWith('iVBOR') || // PNG
      base64Data.startsWith('UklGR'); // WEBP

    if (!isValidFormat) {
      return { valid: false, bytes: null };
    }

    // Decode base64 to bytes
    const binaryStr = atob(base64Data);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    // Check file size (reject if > 10MB or < 5KB)
    if (bytes.length < 5000) {
      return { valid: false, bytes: null };
    }
    if (bytes.length > 10 * 1024 * 1024) {
      return { valid: false, bytes: null };
    }

    return { valid: true, bytes };
  } catch (e) {
    console.error('Image validation error:', e);
    return { valid: false, bytes: null };
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Auth guard
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") || Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const token = authHeader.replace("Bearer ", "");
    const { data: { user: caller }, error: authError } = await authClient.auth.getUser(token);
    if (authError || !caller) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { imageBase64, expectedGender, userId } = await req.json() as VerificationRequest;

    if (!imageBase64) {
      return new Response(
        JSON.stringify({ error: 'No image provided' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const hfToken = Deno.env.get('HF_API_TOKEN');
    if (!hfToken) {
      console.error('HF_API_TOKEN not configured');
      return new Response(
        JSON.stringify({ error: 'Photo verification service not configured' }),
        { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log('Photo verification request:', {
      expectedGender,
      userId: userId ? 'provided' : 'not provided',
      imageSize: imageBase64.length,
    });

    // Step 1: Validate image format and decode
    const { valid, bytes } = validateImageFormat(imageBase64);
    if (!valid || !bytes) {
      const result: VerificationResult = {
        verified: false,
        hasFace: false,
        detectedGender: 'unknown',
        confidence: 0,
        reason: 'Invalid image format. Please upload a clear JPEG, PNG, or WebP photo.',
        genderMatches: false,
      };
      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Step 2: Detect face/person in the image
    const hasFace = await detectFace(bytes, hfToken);

    if (!hasFace) {
      const result: VerificationResult = {
        verified: false,
        hasFace: false,
        detectedGender: 'unknown',
        confidence: 0,
        reason: 'No person detected in the photo. Please upload a clear photo of yourself.',
        genderMatches: false,
      };

      if (userId && expectedGender) {
        await saveVerificationResult(userId, expectedGender, result);
      }

      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Step 3: Classify gender
    const genderResult = await classifyGender(bytes, hfToken);

    console.log('Gender classification:', genderResult);

    // Step 4: Build verification result
    let result: VerificationResult;

    if (genderResult.detectedGender === 'unknown' || genderResult.confidence < MIN_CONFIDENCE_THRESHOLD) {
      result = {
        verified: false,
        hasFace: true,
        detectedGender: genderResult.detectedGender,
        confidence: genderResult.confidence,
        reason: `Could not clearly determine gender from the photo (confidence: ${(genderResult.confidence * 100).toFixed(0)}%). Please upload a clearer, well-lit photo showing your face.`,
        genderMatches: false,
      };
    } else if (expectedGender && genderResult.detectedGender !== expectedGender) {
      result = {
        verified: false,
        hasFace: true,
        detectedGender: genderResult.detectedGender,
        confidence: genderResult.confidence,
        reason: `Photo verification failed. The detected gender does not match your profile. Please upload a genuine photo of yourself.`,
        genderMatches: false,
      };
    } else {
      result = {
        verified: true,
        hasFace: true,
        detectedGender: genderResult.detectedGender,
        confidence: genderResult.confidence,
        reason: 'Photo verified successfully.',
        genderMatches: true,
      };
    }

    console.log('Final verification result:', {
      verified: result.verified,
      detectedGender: result.detectedGender,
      confidence: result.confidence,
      genderMatches: result.genderMatches,
    });

    // Save result to database
    if (userId && expectedGender) {
      await saveVerificationResult(userId, expectedGender, result);
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: unknown) {
    console.error('Verification error:', error);
    const message = error instanceof Error ? error.message : 'Verification failed';
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

async function saveVerificationResult(
  userId: string,
  expectedGender: string,
  result: VerificationResult
): Promise<void> {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!supabaseUrl || !supabaseKey) {
      console.log('Supabase credentials not available, skipping DB update');
      return;
    }

    const supabase = createClient(supabaseUrl, supabaseKey);
    const tableName = expectedGender === 'female' ? 'female_profiles' : 'male_profiles';

    // Only update verification-specific fields to avoid conflicting with
    // ai-women-approval which manages approval_status, ai_approved, is_earning_eligible.
    // Each function owns its own column set to prevent last-write-wins conflicts.
    const { error } = await supabase
      .from(tableName)
      .update({
        is_verified: result.verified,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    if (error) {
      console.error(`Failed to update ${tableName}:`, error);
    } else {
      console.log(`[verify-photo] Updated ${tableName}.is_verified for user ${userId}: ${result.verified}`);
    }

    // Only update verification columns in profiles — do NOT touch approval_status or ai_approved
    const { error: profileError } = await supabase
      .from('profiles')
      .update({
        verification_status: result.verified,
        is_verified: result.verified,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    if (profileError) {
      console.error('Failed to update profiles:', profileError);
    } else {
      console.log(`[verify-photo] Updated profiles.is_verified for user ${userId}: ${result.verified}`);
    }
  } catch (err) {
    console.error('Error saving verification result:', err);
  }
}
