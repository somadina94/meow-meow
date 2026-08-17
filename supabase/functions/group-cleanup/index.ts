import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') || supabaseServiceKey;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Auth guard: require admin role
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
    const { data: roleData } = await supabase
      .from("user_roles").select("role")
      .eq("user_id", caller.id).eq("role", "admin").maybeSingle();
    if (!roleData) {
      return new Response(JSON.stringify({ success: false, error: "Admin access required" }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log('Starting group cleanup...');

    // Cleanup old group messages (older than 5 minutes)
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const { error: msgError } = await supabase
      .from('group_messages')
      .delete()
      .lt('created_at', fiveMinutesAgo);

    if (msgError) {
      console.error('Error cleaning up messages:', msgError);
    } else {
      console.log('Cleaned up old group messages');
    }

    // Reset stale live streams (older than 15 minutes) - clear ALL host fields
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000).toISOString();
    const { data: staleGroups, error: videoError } = await supabase
      .from('private_groups')
      .update({
        is_live: false,
        stream_id: null,
        current_host_id: null,
        current_host_name: null,
        participant_count: 0,
      })
      .eq('is_live', true)
      .lt('updated_at', fifteenMinutesAgo)
      .select('id');

    if (videoError) {
      console.error('Error cleaning up video sessions:', videoError);
    } else {
      const staleIds = staleGroups?.map(g => g.id) || [];
      console.log(`Reset ${staleIds.length} stale live streams`);

      // Clean up memberships for stale groups
      if (staleIds.length > 0) {
        for (const groupId of staleIds) {
          await supabase.from('group_memberships').delete().eq('group_id', groupId);
        }
        console.log('Cleaned up memberships for stale groups');
      }
    }

    // Daily midnight reset (IST 00:00 = UTC 18:30 previous day)
    const now = new Date();
    const istHour = (now.getUTCHours() + 5) % 24 + (now.getUTCMinutes() >= 30 ? 1 : 0);
    const istMinute = (now.getUTCMinutes() + 30) % 60;
    
    // Run if within the midnight window (00:00-00:05 IST)
    if (istHour === 0 && istMinute < 5) {
      console.log('Running daily midnight reset (IST)...');
      
      const { error: resetError } = await supabase
        .from('private_groups')
        .update({
          is_live: false,
          stream_id: null,
          current_host_id: null,
          current_host_name: null,
          participant_count: 0,
        })
        .eq('is_active', true);

      if (resetError) {
        console.error('Error during midnight reset:', resetError);
      } else {
        console.log('Midnight reset complete - all groups cleared');
      }

      // Clear all memberships
      const { error: memberError } = await supabase
        .from('group_memberships')
        .delete()
        .gte('created_at', '1970-01-01');

      if (memberError) {
        console.error('Error clearing memberships:', memberError);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        timestamp: new Date().toISOString()
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : 'Unknown error';
    console.error('Group cleanup error:', errorMessage);
    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
