import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
};

const legalDocuments = [
  {
    name: "Terms of Service",
    document_type: "terms_of_service",
    version: "1.0",
    description: "Main Terms of Service for Meow Meow dating app",
    file_name: "terms-of-service.txt"
  },
  {
    name: "Privacy Policy",
    document_type: "privacy_policy",
    version: "1.0",
    description: "Privacy Policy covering data collection and usage",
    file_name: "privacy-policy.txt"
  },
  {
    name: "Security Policy",
    document_type: "security_policy",
    version: "1.0",
    description: "Security measures and infrastructure details",
    file_name: "security-policy.txt"
  },
  {
    name: "GDPR Compliance",
    document_type: "gdpr_compliance",
    version: "1.0",
    description: "GDPR compliance statement for EU users",
    file_name: "gdpr-compliance.txt"
  },
  {
    name: "Data Storage Policy",
    document_type: "data_storage_policy",
    version: "1.0",
    description: "Data storage and localization policy",
    file_name: "data-storage-policy.txt"
  },
  {
    name: "User Guidelines",
    document_type: "user_guidelines",
    version: "1.0",
    description: "Community guidelines and allowed behavior",
    file_name: "user-guidelines.txt"
  },
  {
    name: "Anti-Sexual Content Policy",
    document_type: "anti_sexual_content",
    version: "1.0",
    description: "Zero tolerance policy for sexual content",
    file_name: "anti-sexual-content-policy.txt"
  },
  {
    name: "Payments & Payouts",
    document_type: "payments_policy",
    version: "1.0",
    description: "Payment and payout rules for men and women",
    file_name: "payments-and-payouts.txt"
  },
  {
    name: "Content Moderation Policy",
    document_type: "content_moderation",
    version: "1.0",
    description: "Content moderation actions and tools",
    file_name: "content-moderation-policy.txt"
  },
  {
    name: "Age Verification Policy",
    document_type: "age_verification",
    version: "1.0",
    description: "Age verification requirements and process",
    file_name: "age-verification-policy.txt"
  },
  {
    name: "AI Usage Disclosure",
    document_type: "ai_disclosure",
    version: "1.0",
    description: "Disclosure of AI usage in the platform",
    file_name: "ai-usage-disclosure.txt"
  },
  {
    name: "Data Retention Policy",
    document_type: "data_retention",
    version: "1.0",
    description: "Data retention periods for different data types",
    file_name: "data-retention-policy.txt"
  }
];

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Auth guard: require admin role
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");
    const { data: { user: caller }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !caller) {
      return new Response(JSON.stringify({ success: false, error: "Invalid token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const { data: roleData } = await supabase
      .from("user_roles").select("role")
      .eq("user_id", caller.id).eq("role", "admin").maybeSingle();
    if (!roleData) {
      return new Response(JSON.stringify({ success: false, error: "Admin access required" }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const results = [];

    for (const doc of legalDocuments) {
      // Check if document already exists
      const { data: existing } = await supabase
        .from('legal_documents')
        .select('id')
        .eq('document_type', doc.document_type)
        .eq('version', doc.version)
        .single();

      if (existing) {
        results.push({ name: doc.name, status: 'skipped', reason: 'Already exists' });
        continue;
      }

      // Create the document content
      const filePath = `legal/${doc.document_type}_v${doc.version}.txt`;

      // Fetch the document content from public folder
      const publicUrl = `${supabaseUrl.replace('/functions/v1', '')}/storage/v1/object/public/legal-documents/${doc.file_name}`;
      
      // Insert into database with a placeholder path (actual upload would be done via admin UI)
      const { error: insertError } = await supabase
        .from('legal_documents')
        .insert({
          name: doc.name,
          document_type: doc.document_type,
          version: doc.version,
          description: doc.description,
          file_path: filePath,
          is_active: true,
          effective_date: new Date().toISOString().split('T')[0],
          mime_type: 'text/plain'
        });

      if (insertError) {
        results.push({ name: doc.name, status: 'error', reason: insertError.message });
      } else {
        results.push({ name: doc.name, status: 'created' });
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Legal documents seeded',
        results 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error seeding legal documents:', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
