import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

/**
 * Video Call Circuit Breaker
 * 
 * When CPU or memory utilization exceeds 95%, this function:
 * 1. Blocks all new video calls
 * 2. Terminates all existing active video calls
 * 3. Auto-resumes after 2 hours
 * 
 * Called by the webrtc-monitor.sh script or manually by admins.
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
};

const CIRCUIT_BREAKER_KEY = 'video_call_circuit_breaker';
const COOLDOWN_HOURS = 2;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Auth guard: validate JWT via anon-key client (not service role)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const token = authHeader.replace("Bearer ", "");
    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: caller }, error: authError } = await authClient.auth.getUser(token);
    if (authError || !caller) {
      return new Response(JSON.stringify({ success: false, error: "Invalid token" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const { action, cpu_percent, memory_percent, source } = body;

    // check_status is allowed for any authenticated user (frontend needs it)
    // All other actions (report_high_utilization, reset) require admin role
    if (action !== "check_status") {
      const { data: roleData } = await supabase
        .from("user_roles").select("role")
        .eq("user_id", caller.id).eq("role", "admin").maybeSingle();
      if (!roleData) {
        return new Response(JSON.stringify({ success: false, error: "Admin access required" }), {
          status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    console.log(`[CircuitBreaker] action=${action}, cpu=${cpu_percent}%, mem=${memory_percent}%, source=${source}`);

    switch (action) {
      // Called by monitoring script when utilization is high
      case 'report_high_utilization': {
        const cpuHigh = (cpu_percent ?? 0) > 95;
        const memHigh = (memory_percent ?? 0) > 95;

        if (!cpuHigh && !memHigh) {
          return new Response(
            JSON.stringify({ success: true, breaker_tripped: false, message: 'Utilization within limits' }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        const reason = [
          cpuHigh ? `CPU: ${cpu_percent}%` : '',
          memHigh ? `Memory: ${memory_percent}%` : '',
        ].filter(Boolean).join(', ');

        const trippedAt = new Date().toISOString();
        const resumesAt = new Date(Date.now() + COOLDOWN_HOURS * 60 * 60 * 1000).toISOString();

        // Set circuit breaker flag in app_settings
        const breakerValue = JSON.stringify({
          active: true,
          tripped_at: trippedAt,
          resumes_at: resumesAt,
          reason,
          cpu_percent,
          memory_percent,
        });

        await supabase
          .from('app_settings')
          .upsert({
            setting_key: CIRCUIT_BREAKER_KEY,
            setting_value: breakerValue,
            setting_type: 'json',
            category: 'system',
            description: 'Video call circuit breaker - auto-disables calls when server resources are critical',
            is_public: true,
          }, { onConflict: 'setting_key' });

        // Terminate all active video calls
        const { data: activeCalls, error: fetchError } = await supabase
          .from('video_call_sessions')
          .select('call_id, man_user_id, woman_user_id')
          .in('status', ['active', 'connecting', 'ringing']);

        if (fetchError) {
          console.error('[CircuitBreaker] Error fetching active calls:', fetchError);
        }

        const terminatedCount = activeCalls?.length ?? 0;

        if (terminatedCount > 0) {
          // End all active calls
          const { error: updateError } = await supabase
            .from('video_call_sessions')
            .update({
              status: 'ended',
              ended_at: new Date().toISOString(),
              end_reason: 'system_circuit_breaker',
            })
            .in('status', ['active', 'connecting', 'ringing']);

          if (updateError) {
            console.error('[CircuitBreaker] Error terminating calls:', updateError);
          }

          // Reset user statuses for affected users
          const userIds = new Set<string>();
          for (const call of activeCalls!) {
            userIds.add(call.man_user_id);
            userIds.add(call.woman_user_id);
          }

          for (const uid of userIds) {
            await supabase.from('user_status').update({
              status_text: 'online',
              last_seen: new Date().toISOString(),
            }).eq('user_id', uid);
          }
        }

        console.log(`[CircuitBreaker] TRIPPED — ${reason}. Terminated ${terminatedCount} calls. Resumes at ${resumesAt}`);

        return new Response(
          JSON.stringify({
            success: true,
            breaker_tripped: true,
            terminated_calls: terminatedCount,
            reason,
            resumes_at: resumesAt,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Check circuit breaker status (called by frontend)
      case 'check_status': {
        const { data: setting } = await supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', CIRCUIT_BREAKER_KEY)
          .maybeSingle();

        if (!setting) {
          return new Response(
            JSON.stringify({ success: true, active: false }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }

        let breakerState: { active: boolean; resumes_at?: string; reason?: string };
        try {
          breakerState = typeof setting.setting_value === 'string'
            ? JSON.parse(setting.setting_value)
            : setting.setting_value as typeof breakerState;
        } catch {
          breakerState = { active: false };
        }

        // Auto-resume if cooldown has passed
        if (breakerState.active && breakerState.resumes_at) {
          const resumeTime = new Date(breakerState.resumes_at).getTime();
          if (Date.now() >= resumeTime) {
            // Reset breaker
            await supabase
              .from('app_settings')
              .update({
                setting_value: JSON.stringify({ active: false, last_tripped_reason: breakerState.reason }),
              })
              .eq('setting_key', CIRCUIT_BREAKER_KEY);

            console.log('[CircuitBreaker] Auto-resumed after cooldown');
            return new Response(
              JSON.stringify({ success: true, active: false, auto_resumed: true }),
              { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            );
          }
        }

        return new Response(
          JSON.stringify({
            success: true,
            active: breakerState.active,
            resumes_at: breakerState.resumes_at,
            reason: breakerState.reason,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Manual reset by admin
      case 'reset': {
        await supabase
          .from('app_settings')
          .update({
            setting_value: JSON.stringify({ active: false, manually_reset: true }),
          })
          .eq('setting_key', CIRCUIT_BREAKER_KEY);

        console.log('[CircuitBreaker] Manually reset by admin');
        return new Response(
          JSON.stringify({ success: true, message: 'Circuit breaker reset' }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      default:
        return new Response(
          JSON.stringify({ success: false, error: 'Invalid action' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    }
  } catch (error: unknown) {
    console.error('[CircuitBreaker] Error:', error);
    const msg = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ success: false, error: msg }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
