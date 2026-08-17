import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
};

/**
 * Data Cleanup Edge Function
 * 
 * PURPOSE: Implements data retention policy for the platform
 * 
 * DELETION SCHEDULE (configurable via admin_settings):
 * - Chat content & media: Deleted every X minutes (default: 15 min)
 * - Chat history: Deleted after X days (default: 7 days)
 * - Transactions: Preserved for X years (default: 9 years)
 * - User profiles: Maintained while active (no auto-deletion)
 * 
 * This function should be called by a cron job or scheduler every 15 minutes
 */

// Default retention periods (will be overridden by admin_settings)
let CONTENT_DELETION_MINUTES = 5; // Media files deleted every 5 mins
let CHAT_IDLE_MINUTES = 3; // Chat window closes after 3 min idle
let CHAT_HISTORY_RETENTION_DAYS = 7; // Chat history deleted after 7 days
let TRANSACTION_RETENTION_YEARS = 9; // Transaction records deleted after 9 years
let VIDEO_CONTENT_MINUTES = 5; // Video call content available for 5 mins after end

// Helper to load admin settings
async function loadRetentionSettings(supabase: any): Promise<void> {
  try {
    const { data: settings } = await supabase
      .from("admin_settings")
      .select("setting_key, setting_value")
      .in("setting_key", [
        "content_deletion_minutes",
        "chat_history_retention_days",
        "transaction_retention_years"
      ]);

    if (settings) {
      for (const setting of settings) {
        const value = parseInt(setting.setting_value, 10);
        if (isNaN(value)) continue;

        switch (setting.setting_key) {
          case "content_deletion_minutes":
            CONTENT_DELETION_MINUTES = value;
            break;
          case "chat_history_retention_days":
            CHAT_HISTORY_RETENTION_DAYS = value;
            break;
          case "transaction_retention_years":
            TRANSACTION_RETENTION_YEARS = value;
            break;
        }
      }
    }
    console.log(`[CLEANUP CONFIG] content=${CONTENT_DELETION_MINUTES}min, history=${CHAT_HISTORY_RETENTION_DAYS}days, transactions=${TRANSACTION_RETENTION_YEARS}years`);
  } catch (error) {
    console.error("[CLEANUP CONFIG] Error loading settings, using defaults:", error);
  }
}

Deno.serve(async (req) => {
  // Handle CORS preflight
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

    // Load dynamic retention settings
    await loadRetentionSettings(supabase);

    const now = new Date();
    const results = {
      chatContentDeleted: 0,
      chatHistoryDeleted: 0,
      transactionsDeleted: 0,
      chatSessionsClosed: 0,
      settings: {
        content_deletion_minutes: CONTENT_DELETION_MINUTES,
        chat_history_retention_days: CHAT_HISTORY_RETENTION_DAYS,
        transaction_retention_years: TRANSACTION_RETENTION_YEARS,
      },
      errors: [] as string[],
    };

    console.log(`[Data Cleanup] Starting cleanup at ${now.toISOString()}`);

    // ============= 0. CLOSE IDLE CHAT SESSIONS (3 MIN INACTIVITY) =============
    try {
      const idleCutoff = new Date(now.getTime() - CHAT_IDLE_MINUTES * 60 * 1000);
      
      // Close active sessions that have been idle
      const { data: idleSessions, error: idleError } = await supabase
        .from('active_chat_sessions')
        .update({
          status: 'ended',
          end_reason: 'idle_3min',
          ended_at: now.toISOString(),
        })
        .lt('last_activity_at', idleCutoff.toISOString())
        .eq('status', 'active')
        .select('id');

      if (idleError) {
        console.error('[Data Cleanup] Error closing idle sessions:', idleError);
        results.errors.push(`Idle sessions: ${idleError.message}`);
      } else if (idleSessions) {
        console.log(`[Data Cleanup] Closed ${idleSessions.length} idle chat sessions (3min inactivity)`);
      }

      // Also close paused/billing_paused sessions that have been idle for 10+ minutes
      const pausedCutoff = new Date(now.getTime() - 10 * 60 * 1000);
      const { data: pausedSessions, error: pausedError } = await supabase
        .from('active_chat_sessions')
        .update({
          status: 'ended',
          end_reason: 'paused_timeout',
          ended_at: now.toISOString(),
        })
        .lt('last_activity_at', pausedCutoff.toISOString())
        .in('status', ['paused', 'billing_paused'])
        .select('id');

      if (pausedError) {
        console.error('[Data Cleanup] Error closing paused sessions:', pausedError);
        results.errors.push(`Paused sessions: ${pausedError.message}`);
      } else if (pausedSessions) {
        console.log(`[Data Cleanup] Closed ${pausedSessions.length} paused sessions (10min timeout)`);
      }

      // Also run the DB function for idle sessions cleanup
      await supabase.rpc('cleanup_idle_sessions');
      await supabase.rpc('cleanup_expired_data');
    } catch (error: any) {
      console.error('[Data Cleanup] Error in idle session cleanup:', error);
      results.errors.push(`Idle sessions exception: ${error.message}`);
    }

    // ============= 1. DELETE CHAT CONTENT/MEDIA OLDER THAN 5 MINUTES =============
    // This removes message content but preserves metadata for billing purposes
    try {
      const contentCutoff = new Date(now.getTime() - CONTENT_DELETION_MINUTES * 60 * 1000);
      
      // First, get count of messages to be affected
      const { count: messageCount } = await supabase
        .from('chat_messages')
        .select('*', { count: 'exact', head: true })
        .lt('created_at', contentCutoff.toISOString())
        .not('message', 'eq', '[Content deleted per retention policy]');

      if (messageCount && messageCount > 0) {
        // Update messages to remove content but keep metadata
        const { error: messageError } = await supabase
          .from('chat_messages')
          .update({
            message: '[Content deleted per retention policy]',
            translated_message: null,
          })
          .lt('created_at', contentCutoff.toISOString())
          .not('message', 'eq', '[Content deleted per retention policy]');

        if (messageError) {
          console.error('[Data Cleanup] Error clearing chat content:', messageError);
          results.errors.push(`Chat content: ${messageError.message}`);
        } else {
          results.chatContentDeleted = messageCount;
          console.log(`[Data Cleanup] Cleared content from ${messageCount} messages (older than ${CONTENT_DELETION_MINUTES} min)`);
        }
      } else {
        console.log('[Data Cleanup] No chat content to clear');
      }

      // Also run DB function for media cleanup
      await supabase.rpc('cleanup_chat_media');
    } catch (error: any) {
      console.error('[Data Cleanup] Error in chat content cleanup:', error);
      results.errors.push(`Chat content exception: ${error.message}`);
    }

    // ============= 2. DELETE CHAT HISTORY OLDER THAN X DAYS =============
    try {
      const historyCutoff = new Date(now.getTime() - CHAT_HISTORY_RETENTION_DAYS * 24 * 60 * 60 * 1000);
      
      // Get count first
      const { count: oldMessagesCount } = await supabase
        .from('chat_messages')
        .select('*', { count: 'exact', head: true })
        .lt('created_at', historyCutoff.toISOString());

      if (oldMessagesCount && oldMessagesCount > 0) {
        // Delete old messages completely
        const { error: deleteMessagesError } = await supabase
          .from('chat_messages')
          .delete()
          .lt('created_at', historyCutoff.toISOString());

        if (deleteMessagesError) {
          console.error('[Data Cleanup] Error deleting old chat history:', deleteMessagesError);
          results.errors.push(`Chat history: ${deleteMessagesError.message}`);
        } else {
          results.chatHistoryDeleted = oldMessagesCount;
          console.log(`[Data Cleanup] Deleted ${oldMessagesCount} messages older than ${CHAT_HISTORY_RETENTION_DAYS} days`);
        }
      } else {
        console.log('[Data Cleanup] No old chat history to delete');
      }

      // Also close any stale chat sessions older than retention period
      const { data: staleSessions, error: staleSessionsError } = await supabase
        .from('active_chat_sessions')
        .update({
          status: 'ended',
          end_reason: 'auto_cleanup',
          ended_at: now.toISOString(),
        })
        .lt('created_at', historyCutoff.toISOString())
        .eq('status', 'active')
        .select('id');

      if (staleSessionsError) {
        console.error('[Data Cleanup] Error closing stale sessions:', staleSessionsError);
        results.errors.push(`Stale sessions: ${staleSessionsError.message}`);
      } else if (staleSessions) {
        results.chatSessionsClosed = staleSessions.length;
        console.log(`[Data Cleanup] Closed ${staleSessions.length} stale chat sessions`);
      }
    } catch (error: any) {
      console.error('[Data Cleanup] Error in chat history cleanup:', error);
      results.errors.push(`Chat history exception: ${error.message}`);
    }

    // ============= 3. DELETE TRANSACTIONS OLDER THAN X YEARS =============
    try {
      const transactionCutoff = new Date(now.getTime() - TRANSACTION_RETENTION_YEARS * 365 * 24 * 60 * 60 * 1000);
      
      // Get count first
      const { count: oldTransactionsCount } = await supabase
        .from('wallet_transactions')
        .select('*', { count: 'exact', head: true })
        .lt('created_at', transactionCutoff.toISOString());

      if (oldTransactionsCount && oldTransactionsCount > 0) {
        // Delete old transactions
        const { error: deleteTransactionsError } = await supabase
          .from('wallet_transactions')
          .delete()
          .lt('created_at', transactionCutoff.toISOString());

        if (deleteTransactionsError) {
          console.error('[Data Cleanup] Error deleting old transactions:', deleteTransactionsError);
          results.errors.push(`Transactions: ${deleteTransactionsError.message}`);
        } else {
          results.transactionsDeleted = oldTransactionsCount;
          console.log(`[Data Cleanup] Deleted ${oldTransactionsCount} transactions older than ${TRANSACTION_RETENTION_YEARS} years`);
        }
      } else {
        console.log('[Data Cleanup] No old transactions to delete');
      }

      // Also clean up old shift earnings
      const { error: deleteEarningsError } = await supabase
        .from('shift_earnings')
        .delete()
        .lt('created_at', transactionCutoff.toISOString());

      if (deleteEarningsError) {
        console.error('[Data Cleanup] Error deleting old shift earnings:', deleteEarningsError);
        results.errors.push(`Shift earnings: ${deleteEarningsError.message}`);
      }

      // Note: women_earnings legacy table removed; wallet_transactions is the SoT
      // and is retained per data-retention policy (6mo) by other cleanup paths.
    } catch (error: any) {
      console.error('[Data Cleanup] Error in transaction cleanup:', error);
      results.errors.push(`Transactions exception: ${error.message}`);
    }

    // ============= 4. DELETE MEDIA/ATTACHMENTS FROM STORAGE (every 15 min) =============
    try {
      const mediaCutoff = new Date(now.getTime() - CONTENT_DELETION_MINUTES * 60 * 1000);
      
      // Delete old voice messages from storage bucket
      const { data: voiceFiles } = await supabase.storage
        .from('voice-messages')
        .list('', { limit: 1000 });
      
      if (voiceFiles && voiceFiles.length > 0) {
        const oldVoiceFiles = voiceFiles.filter(file => {
          const fileDate = new Date(file.created_at);
          return fileDate < mediaCutoff;
        });
        
        if (oldVoiceFiles.length > 0) {
          const filePaths = oldVoiceFiles.map(f => f.name);
          const { error: voiceDeleteError } = await supabase.storage
            .from('voice-messages')
            .remove(filePaths);
          
          if (voiceDeleteError) {
            console.error('[Data Cleanup] Error deleting voice messages:', voiceDeleteError);
            results.errors.push(`Voice messages: ${voiceDeleteError.message}`);
          } else {
            console.log(`[Data Cleanup] Deleted ${oldVoiceFiles.length} voice messages older than ${CONTENT_DELETION_MINUTES} min`);
          }
        }
      }
      
      // Delete old selfies from storage bucket (verification selfies)
      const { data: selfieFiles } = await supabase.storage
        .from('selfies')
        .list('', { limit: 1000 });
      
      if (selfieFiles && selfieFiles.length > 0) {
        // Delete selfies older than 24 hours (verification is one-time)
        const selfiesCutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        const oldSelfies = selfieFiles.filter(file => {
          const fileDate = new Date(file.created_at);
          return fileDate < selfiesCutoff;
        });
        
        if (oldSelfies.length > 0) {
          const filePaths = oldSelfies.map(f => f.name);
          const { error: selfieDeleteError } = await supabase.storage
            .from('selfies')
            .remove(filePaths);
          
          if (selfieDeleteError) {
            console.error('[Data Cleanup] Error deleting selfies:', selfieDeleteError);
            results.errors.push(`Selfies: ${selfieDeleteError.message}`);
          } else {
            console.log(`[Data Cleanup] Deleted ${oldSelfies.length} verification selfies older than 24 hours`);
          }
        }
      }
      
      console.log('[Data Cleanup] Media cleanup completed');
    } catch (error: any) {
      console.error('[Data Cleanup] Error in media cleanup:', error);
      results.errors.push(`Media cleanup: ${error.message}`);
    }

    // ============= 5. CLEANUP OTHER DATA =============
    try {
      // Delete old processing logs (older than 30 days)
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      
      await supabase
        .from('processing_logs')
        .delete()
        .lt('created_at', thirtyDaysAgo.toISOString())
        .eq('processing_status', 'completed');

      // Delete old password reset tokens (older than 24 hours)
      const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
      
      await supabase
        .from('password_reset_tokens')
        .delete()
        .lt('expires_at', oneDayAgo.toISOString());

      // Delete old chat wait queue entries (older than 1 hour)
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
      
      await supabase
        .from('chat_wait_queue')
        .delete()
        .lt('created_at', oneHourAgo.toISOString())
        .in('status', ['matched', 'expired', 'cancelled']);

      // Delete old system metrics (older than 30 days)
      await supabase
        .from('system_metrics')
        .delete()
        .lt('recorded_at', thirtyDaysAgo.toISOString());
      
      // Delete old group messages (older than 5 minutes as per spec)
      const groupMessageCutoff = new Date(now.getTime() - CONTENT_DELETION_MINUTES * 60 * 1000);
      await supabase
        .from('group_messages')
        .delete()
        .lt('created_at', groupMessageCutoff.toISOString());

      // Delete ended video sessions (content available for 5 mins)
      const videoContentCutoff = new Date(now.getTime() - VIDEO_CONTENT_MINUTES * 60 * 1000);
      await supabase
        .from('video_call_sessions')
        .delete()
        .eq('status', 'ended')
        .lt('ended_at', videoContentCutoff.toISOString());

      // Run DB function for video cleanup
      await supabase.rpc('cleanup_video_sessions');

      console.log('[Data Cleanup] Additional cleanup completed');

      // --- Admin Messages Cleanup (7-day retention) ---
      const adminMsgCutoff = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      const { error: adminBroadcastErr } = await supabase
        .from('admin_broadcast_messages')
        .delete()
        .lt('created_at', adminMsgCutoff.toISOString());
      if (adminBroadcastErr) {
        console.error('[Data Cleanup] Admin broadcast cleanup error:', adminBroadcastErr);
      }
      const { error: adminUserMsgErr } = await supabase
        .from('admin_user_messages')
        .delete()
        .lt('created_at', adminMsgCutoff.toISOString());
      if (adminUserMsgErr) {
        console.error('[Data Cleanup] Admin user messages cleanup error:', adminUserMsgErr);
      }
      console.log('[Data Cleanup] Admin messages older than 7 days cleaned up');
    } catch (error: any) {
      console.error('[Data Cleanup] Error in additional cleanup:', error);
      results.errors.push(`Additional cleanup: ${error.message}`);
    }

    // Log cleanup summary
    console.log('[Data Cleanup] Summary:', JSON.stringify(results));

    // Create audit log entry
    try {
      await supabase
        .from('audit_logs')
        .insert({
          admin_id: '00000000-0000-0000-0000-000000000000', // System action
          action: 'data_cleanup',
          action_type: 'delete',
          resource_type: 'system',
          details: `Automated data cleanup: ${results.chatContentDeleted} messages cleared (${CONTENT_DELETION_MINUTES}min), ${results.chatHistoryDeleted} old messages deleted (${CHAT_HISTORY_RETENTION_DAYS}d), ${results.transactionsDeleted} old transactions deleted (${TRANSACTION_RETENTION_YEARS}y), ${results.chatSessionsClosed} stale sessions closed`,
          status: results.errors.length === 0 ? 'success' : 'partial',
        });
    } catch (auditError) {
      console.error('[Data Cleanup] Failed to create audit log:', auditError);
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Data cleanup completed',
      results,
      timestamp: now.toISOString(),
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: any) {
    console.error('[Data Cleanup] Fatal error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
