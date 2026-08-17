# Backend Layer (Edge Functions)

This folder contains Supabase Edge Functions that run on Deno runtime.

## Structure

```
functions/
├── ai-women-approval/     # AI-powered profile approval
├── ai-women-manager/      # AI profile management
├── chat-manager/          # Chat session lifecycle
├── content-moderation/    # Message filtering
├── data-cleanup/          # Scheduled cleanup
├── group-cleanup/         # Group message cleanup
├── reset-password/        # Password reset flow
├── seed-legal-documents/  # Seed legal docs
├── seed-super-users/      # Seed test users

├── translate-message/     # Real-time translation
├── trigger-backup/        # Database backup
├── verify-photo/          # Photo verification
├── video-call-server/     # Video call management
└── video-cleanup/         # Video session cleanup
```

## Guidelines

### 1. Function Structure
Each function has its own folder with `index.ts`:
```
my-function/
└── index.ts
```

### 2. Pattern
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // Function logic here

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
```

### 3. Secrets
Access secrets via `Deno.env.get('SECRET_NAME')`.
Available secrets are listed in project settings.

### 4. Deployment
Edge functions are deployed automatically when code is pushed.
