import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // --- Mandatory authentication ---
    const authHeader = req.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized – missing token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Validate JWT via anon-key client (respects signing keys)
    const token = authHeader.replace('Bearer ', '');
    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: caller }, error: authError } = await authClient.auth.getUser(token);

    if (authError || !caller) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized – invalid token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const authenticatedUserId: string = caller.id;

    // Service-role client for privileged DB operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { action, data } = await req.json();
    console.log(`AI Women Manager - Action: ${action}`, data);

    // SECURITY: Admin-only actions
    if (action === 'auto_approve_women' || action === 'suspend_inactive_women') {
      const { data: roleData } = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', authenticatedUserId)
        .eq('role', 'admin')
        .maybeSingle();

      if (!roleData) {
        console.log(`[SECURITY] Non-admin user ${authenticatedUserId} attempted ${action} - BLOCKED`);
        return new Response(
          JSON.stringify({ error: 'Admin access required' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
      console.log(`[SECURITY] Admin ${authenticatedUserId} authorized for ${action}`);
    }

    // SECURITY: For distribution actions, verify the caller's gender
    if (action === 'distribute_for_chat' || action === 'distribute_for_call') {
      // Women can now initiate chats and calls freely
      console.log(`[SECURITY] User ${authenticatedUserId} initiating ${action}`);
    }

    switch (action) {
      case 'auto_approve_women':
        return await autoApproveWomen(supabase);
      
      case 'suspend_inactive_women':
        return await suspendInactiveWomen(supabase);
      
      case 'distribute_for_chat':
        return await distributeWomanForChat(supabase, data);
      
      case 'distribute_for_call':
        return await distributeWomanForCall(supabase, data, authenticatedUserId);
      
      case 'get_available_woman':
        return await getAvailableWoman(supabase, data);
      
      case 'create_direct_call':
        return await createDirectCall(supabase, data);
      
      default:
        return new Response(
          JSON.stringify({ error: 'Invalid action' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    }
  } catch (error) {
    console.error('AI Women Manager Error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// Auto-approve women with complete profile + verified photo
async function autoApproveWomen(supabase: any) {
  console.log('Running auto-approval check...');

  // Find pending women with complete profiles
  const { data: pendingWomen, error } = await supabase
    .from('female_profiles')
    .select('id, user_id, full_name, photo_url, age, primary_language, country, approval_status')
    .eq('approval_status', 'pending')
    .not('photo_url', 'is', null)
    .neq('photo_url', '')
    .not('full_name', 'is', null)
    .not('age', 'is', null)
    .not('primary_language', 'is', null);

  if (error) {
    console.error('Error fetching pending women:', error);
    throw error;
  }

  console.log(`Found ${pendingWomen?.length || 0} pending women with complete profiles`);

  const approvedIds: string[] = [];
  
  for (const woman of pendingWomen || []) {
    // Check if profile is complete enough for auto-approval
    const isComplete = woman.full_name && 
                       woman.photo_url && 
                       woman.age >= 18 && 
                       woman.primary_language;

    if (isComplete) {
      // Auto-approve
      const { error: updateError } = await supabase
        .from('female_profiles')
        .update({
          approval_status: 'approved',
          ai_approved: true,
          auto_approved: true,
          updated_at: new Date().toISOString()
        })
        .eq('id', woman.id);

      if (!updateError) {
        approvedIds.push(woman.id);
        console.log(`Auto-approved woman: ${woman.full_name} (${woman.id})`);

        // Insert into women_availability table
        const { error: availError } = await supabase
          .from('women_availability')
          .upsert({
            user_id: woman.user_id,
            is_available: false,
            is_available_for_calls: false,
            current_chat_count: 0,
            current_call_count: 0,
            max_concurrent_chats: 3,
            max_concurrent_calls: 1,
            last_activity_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          }, { onConflict: 'user_id' });

        if (availError) {
          console.error(`Error creating women_availability for ${woman.full_name}:`, availError);
        } else {
          console.log(`✓ Created women_availability entry for ${woman.full_name}`);
        }

        // Create notification
        await supabase.from('notifications').insert({
          user_id: woman.user_id,
          title: 'Profile Approved!',
          message: 'Your profile has been automatically approved. You can now start chatting!',
          type: 'success'
        });
      }
    }
  }

  return new Response(
    JSON.stringify({ 
      success: true, 
      approved_count: approvedIds.length,
      approved_ids: approvedIds 
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

// Suspend women inactive for more than 15 days
async function suspendInactiveWomen(supabase: any) {
  console.log('Running inactivity check...');

  const fifteenDaysAgo = new Date();
  fifteenDaysAgo.setDate(fifteenDaysAgo.getDate() - 15);

  // Find active women who haven't been active in 15 days
  const { data: inactiveWomen, error } = await supabase
    .from('female_profiles')
    .select('id, user_id, full_name, last_active_at')
    .eq('account_status', 'active')
    .eq('approval_status', 'approved')
    .lt('last_active_at', fifteenDaysAgo.toISOString());

  if (error) {
    console.error('Error fetching inactive women:', error);
    throw error;
  }

  console.log(`Found ${inactiveWomen?.length || 0} inactive women (>15 days)`);

  const suspendedIds: string[] = [];

  for (const woman of inactiveWomen || []) {
    const { error: updateError } = await supabase
      .from('female_profiles')
      .update({
        account_status: 'suspended',
        suspended_at: new Date().toISOString(),
        suspension_reason: 'Inactive for more than 15 days',
        updated_at: new Date().toISOString()
      })
      .eq('id', woman.id);

    if (!updateError) {
      suspendedIds.push(woman.id);
      console.log(`Suspended inactive woman: ${woman.full_name} (${woman.id})`);

      // Create notification
      await supabase.from('notifications').insert({
        user_id: woman.user_id,
        title: 'Account Suspended',
        message: 'Your account has been suspended due to inactivity (15+ days). Please contact support to reactivate.',
        type: 'warning'
      });
    }
  }

  return new Response(
    JSON.stringify({ 
      success: true, 
      suspended_count: suspendedIds.length,
      suspended_ids: suspendedIds 
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

// AI distribution for chat - find best available woman based on load
// CRITICAL: Must check BOTH women_availability.is_available AND user_status.is_online
async function distributeWomanForChat(supabase: any, data: any) {
  const { language, excludeUserIds = [] } = data;
  const normalizedLanguage = (language || 'english').toLowerCase().trim();
  console.log(`[Chat] Finding available ONLINE woman for chat: ${normalizedLanguage}`);

  // Step 1: Get ONLY online users from user_status (critical check!)
  const { data: onlineStatuses } = await supabase
    .from('user_status')
    .select('user_id')
    .eq('is_online', true);

  const onlineUserIds = onlineStatuses?.map((s: any) => s.user_id) || [];
  
  if (onlineUserIds.length === 0) {
    console.log('[Chat] No users online');
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'No users online' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 2: Get women who are available AND online
  const { data: availableWomen, error } = await supabase
    .from('women_availability')
    .select('user_id, current_chat_count, max_concurrent_chats, is_available')
    .eq('is_available', true)
    .lt('current_chat_count', 3)
    .in('user_id', onlineUserIds); // MUST be online

  if (error || !availableWomen?.length) {
    console.log('[Chat] No online available women found');
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'No online available women' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 3: Filter out excluded users and get profiles
  const candidateUserIds = availableWomen
    .map((w: any) => w.user_id)
    .filter((id: string) => !excludeUserIds.includes(id));
  
  if (candidateUserIds.length === 0) {
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'All available women excluded' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 4: Get user languages from user_languages table
  const { data: userLanguages } = await supabase
    .from('user_languages')
    .select('user_id, language_name')
    .in('user_id', candidateUserIds);

  const languageMap = new Map<string, string>();
  (userLanguages || []).forEach((l: any) => {
    languageMap.set(l.user_id, (l.language_name || '').toLowerCase().trim());
  });

  // Step 5: Get profiles for online available women
  const { data: womenProfiles } = await supabase
    .from('female_profiles')
    .select('user_id, full_name, photo_url, primary_language, age')
    .in('user_id', candidateUserIds)
    .eq('approval_status', 'approved')
    .eq('account_status', 'active')
    .not('photo_url', 'is', null);

  if (!womenProfiles?.length) {
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'No matching online profiles' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 6: Prioritize same language, then by lowest load
  const availabilityMap = new Map<string, any>(availableWomen.map((w: any) => [w.user_id, w]));
  
  // Add language info to profiles
  const profilesWithLanguage = womenProfiles.map((w: any) => {
    const womanLanguage = (
      languageMap.get(w.user_id) || 
      w.primary_language || 
      ''
    ).toLowerCase().trim();
    return {
      ...w,
      language: womanLanguage,
      isSameLanguage: womanLanguage === normalizedLanguage,
      currentChats: availabilityMap.get(w.user_id)?.current_chat_count || 0
    };
  });

  // Sort: same language first, then by load
  profilesWithLanguage.sort((a: any, b: any) => {
    if (a.isSameLanguage !== b.isSameLanguage) {
      return a.isSameLanguage ? -1 : 1;
    }
    return a.currentChats - b.currentChats;
  });

  const selectedWoman = profilesWithLanguage[0];
  console.log(`[Chat] Selected ONLINE woman: ${selectedWoman.full_name} (language: ${selectedWoman.language}, same: ${selectedWoman.isSameLanguage})`);

  return new Response(
    JSON.stringify({ 
      success: true, 
      woman: selectedWoman,
      same_language: selectedWoman.isSameLanguage
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

// AI distribution for video call - STRICT: same language + IDLE women only
// Idle = Online + Not in any video call + Not in any chat + Not receiving another call
async function distributeWomanForCall(supabase: any, data: any, authenticatedUserId: string | null = null) {
  const { language, excludeUserIds = [] } = data;
  const normalizedLanguage = (language || "english").toLowerCase().trim();
  console.log(`[VideoCall] Finding IDLE woman for video call: ${normalizedLanguage}`);

  // Auto-cleanup stale ringing/connecting sessions older than 2 minutes
  const { data: staleSessions } = await supabase
    .from('video_call_sessions')
    .update({ status: 'ended', ended_at: new Date().toISOString(), end_reason: 'timeout_cleanup' })
    .in('status', ['ringing', 'connecting'])
    .lt('created_at', new Date(Date.now() - 2 * 60 * 1000).toISOString())
    .select('call_id');
  
  if (staleSessions?.length) {
    console.log(`[VideoCall] Cleaned up ${staleSessions.length} stale sessions`);
  }
  // Step 1: Get ONLY online users
  const { data: onlineStatuses } = await supabase
    .from('user_status')
    .select('user_id')
    .eq('is_online', true);

  const onlineUserIds = onlineStatuses?.map((s: any) => s.user_id) || [];
  
  if (onlineUserIds.length === 0) {
    console.log('[VideoCall] No users online');
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'No users online' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 2: Get women who are online — for video calls, don't filter by is_available
  // (which reflects chat capacity). Instead, get all online women and let Step 3's
  // live-session IDLE check determine true availability for calls.
  const { data: availableWomen, error } = await supabase
    .from('women_availability')
    .select('user_id, current_call_count, current_chat_count, max_concurrent_calls, is_available, is_available_for_calls')
    .in('user_id', onlineUserIds); // MUST be online

  if (error) {
    console.error('[VideoCall] Error querying women_availability:', error);
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'Database error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  if (!availableWomen?.length) {
    console.log('[VideoCall] No available women found in women_availability');
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'No available women right now.' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 3: Recompute IDLE state from live session tables (source of truth)
  const candidateUserIds = availableWomen.map((w: any) => w.user_id);

  const [{ data: activeChatRows }, { data: activeOrRingingCallRows }] = await Promise.all([
    supabase
      .from('active_chat_sessions')
      .select('woman_user_id')
      .eq('status', 'active')
      .in('woman_user_id', candidateUserIds),
    supabase
      .from('video_call_sessions')
      .select('woman_user_id')
      .in('woman_user_id', candidateUserIds)
      .in('status', ['active', 'connecting', 'ringing'])
  ]);

  const womenInActiveChat = new Set((activeChatRows || []).map((r: any) => r.woman_user_id));
  const womenInCallFlow = new Set((activeOrRingingCallRows || []).map((r: any) => r.woman_user_id));

  const idleUserIds = candidateUserIds
    .filter((id: string) => !womenInActiveChat.has(id))
    .filter((id: string) => !womenInCallFlow.has(id))
    .filter((id: string) => !excludeUserIds.includes(id));

  if (idleUserIds.length === 0) {
    console.log('[VideoCall] No idle women available for calls (all are in chat/call/ringing)');
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'No idle women available. All women are currently busy with chats or calls.' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 4: Get user languages from user_languages table
  const { data: userLanguages } = await supabase
    .from('user_languages')
    .select('user_id, language_name')
    .in('user_id', idleUserIds);

  const languageMap = new Map<string, string>();
  (userLanguages || []).forEach((l: any) => {
    languageMap.set(l.user_id, (l.language_name || '').toLowerCase().trim());
  });

  // Step 5: Get profiles for IDLE women
  const { data: womenProfiles } = await supabase
    .from('female_profiles')
    .select('user_id, full_name, photo_url, primary_language, age, country')
    .in('user_id', idleUserIds)
    .eq('approval_status', 'approved')
    .eq('account_status', 'active')
    .not('photo_url', 'is', null);

  if (!womenProfiles?.length) {
    return new Response(
      JSON.stringify({ success: false, woman: null, reason: 'No matching profiles found for idle women' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 6: Filter STRICTLY by same language for video calls
  const sameLanguageWomen = womenProfiles.filter((w: any) => {
    const womanLanguage = (
      languageMap.get(w.user_id) || 
      w.primary_language || 
      ''
    ).toLowerCase().trim();
    return womanLanguage === normalizedLanguage;
  });

  if (sameLanguageWomen.length === 0) {
    console.log(`[VideoCall] No IDLE women available for calls in language: ${normalizedLanguage}`);
    return new Response(
      JSON.stringify({ 
        success: false, 
        woman: null, 
        reason: `No idle women available for video calls in ${language}. Video calls require same language and an idle user.` 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Step 7: Sort randomly for fair distribution among idle users
  // (Since all idle women have 0 chats and 0 calls, load balancing is equal)
  const shuffled = sameLanguageWomen.sort(() => Math.random() - 0.5);
  const selectedWoman = shuffled[0];
  
  console.log(`[VideoCall] Selected IDLE woman: ${selectedWoman.full_name} (language: ${selectedWoman.primary_language})`);

  // Step 8: Create video_call_sessions record server-side (bypasses RLS)
  const manId = authenticatedUserId || data.man_user_id;
  const callId = `call_${manId}_${selectedWoman.user_id}_${Date.now()}`;

  let sessionCreated = false;
  if (manId) {
    const { error: sessionError } = await supabase
      .from('video_call_sessions')
      .insert({
        call_id: callId,
        man_user_id: manId,
        woman_user_id: selectedWoman.user_id,
        status: 'ringing',
        rate_per_minute: 5.00
      });

    if (sessionError) {
      console.error('[VideoCall] Error creating session:', sessionError);
    } else {
      sessionCreated = true;
      console.log(`[VideoCall] Created session: ${callId}`);
    }
  }

  return new Response(
    JSON.stringify({ 
      success: true, 
      woman: selectedWoman,
      same_language: true,
      language: normalizedLanguage,
      idle: true,
      call_id: sessionCreated ? callId : null,
      session_created: sessionCreated
    }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

// Get any available woman (for random matching)
async function getAvailableWoman(supabase: any, data: any) {
  const { type, language, manUserId } = data;
  
  if (type === 'chat') {
    return distributeWomanForChat(supabase, { language, excludeUserIds: [] });
  } else if (type === 'call') {
    return distributeWomanForCall(supabase, { language, excludeUserIds: [] });
  }
  
  return new Response(
    JSON.stringify({ error: 'Invalid type' }),
    { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}

// Create a direct video call session to a specific user
async function createDirectCall(supabase: any, data: any) {
  const { call_id, man_user_id, woman_user_id, rate_per_minute = 8, call_type = 'video' } = data;

  if (!call_id || !man_user_id || !woman_user_id) {
    return new Response(
      JSON.stringify({ success: false, error: 'Missing required fields: call_id, man_user_id, woman_user_id' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const { error } = await supabase
    .from('video_call_sessions')
    .insert({
      call_id,
      man_user_id,
      woman_user_id,
      status: 'ringing',
      rate_per_minute,
      call_type,
    });

  if (error) {
    console.error('[DirectCall] Error creating session:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  console.log(`[DirectCall] Created session: ${call_id} (man: ${man_user_id}, woman: ${woman_user_id})`);
  return new Response(
    JSON.stringify({ success: true, call_id }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}
