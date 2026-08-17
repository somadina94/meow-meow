import { useEffect, useCallback, useRef, useMemo } from "react";
import { supabase } from "@/integrations/supabase/client";
import { RealtimeChannel } from "@supabase/supabase-js";

type TableName = 
  | "profiles"
  | "female_profiles"
  | "male_profiles"
  | "active_chat_sessions"
  | "video_call_sessions"
  | "chat_messages"
  | "wallets"
  | "users_wallet"
  | "wallet_transactions"
  | "user_status"
  | "women_availability"
  | "language_limits"
  | "language_groups"
  | "chat_pricing"
  | "notifications"
  | "gifts"
  | "gift_transactions"
  | "absence_records"
  | "user_settings"
  | "matches"
  | "user_languages"
  | "withdrawal_requests"
  | "moderation_reports"
  | "policy_violation_alerts"
  | "audit_logs"
  | "backup_logs"
  | "system_metrics"
  | "system_alerts"
  | "admin_settings"
  | "legal_documents"
  | "user_roles"
  | "attendance"
  | "user_friends"
  | "user_blocks"
  | "user_warnings"
  | "user_photos"
  | "processing_logs"
  | "app_settings"
  | "chat_wait_queue"
  | "platform_metrics";

interface UseRealtimeSubscriptionOptions {
  table: TableName;
  event?: "INSERT" | "UPDATE" | "DELETE" | "*";
  filter?: string;
  onUpdate: () => void;
  enabled?: boolean;
  debounceMs?: number; // Debounce for high-frequency updates
}

export const useRealtimeSubscription = ({
  table,
  event = "*",
  filter,
  onUpdate,
  enabled = true,
  debounceMs = 100 // Default 100ms debounce for high concurrency
}: UseRealtimeSubscriptionOptions) => {
  const channelRef = useRef<RealtimeChannel | null>(null);
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);
  const onUpdateRef = useRef(onUpdate);
  onUpdateRef.current = onUpdate;

  // Debounced update handler for scale
  const debouncedUpdate = useCallback(() => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    timeoutRef.current = setTimeout(() => onUpdateRef.current(), debounceMs);
  }, [debounceMs]);

  const setupSubscription = useCallback(() => {
    if (!enabled) return;

    // Clean up existing subscription
    if (channelRef.current) {
      supabase.removeChannel(channelRef.current);
    }

    // Include unique ID to avoid channel collision when same table subscribed in multiple components
    const channelName = `rt-${table}${filter ? `-${filter}` : ''}-${Math.random().toString(36).slice(2, 8)}`;
    
    const subscriptionConfig: any = {
      event,
      schema: 'public',
      table
    };

    if (filter) {
      subscriptionConfig.filter = filter;
    }

    channelRef.current = supabase
      .channel(channelName)
      .on('postgres_changes', subscriptionConfig, () => {
        debouncedUpdate();
      })
      .subscribe();

    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current);
        channelRef.current = null;
      }
    };
  }, [table, event, filter, enabled, debouncedUpdate]);

  useEffect(() => {
    const cleanup = setupSubscription();
    return cleanup;
  }, [setupSubscription]);

  return {
    refresh: onUpdate
  };
};

// Hook for multiple table subscriptions - OPTIMIZED for scale
export const useMultipleRealtimeSubscriptions = (
  tables: TableName[],
  onUpdate: () => void,
  enabled = true,
  debounceMs = 150 // Slightly longer debounce for multiple tables
) => {
  const timeoutRef = useRef<NodeJS.Timeout | null>(null);
  const onUpdateRef = useRef(onUpdate);
  onUpdateRef.current = onUpdate;

  // Memoize the tables key to avoid infinite re-subscribe when caller passes inline array literals
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const tablesKey = useMemo(() => tables.slice().sort().join(','), [JSON.stringify(tables)]);

  const debouncedUpdate = useCallback(() => {
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    timeoutRef.current = setTimeout(() => onUpdateRef.current(), debounceMs);
  }, [debounceMs]);

  useEffect(() => {
    if (!enabled || !tablesKey) return;

    const tableList = tablesKey.split(',') as TableName[];
    const channelName = `multi-rt-${tablesKey}`;
    const channel = supabase.channel(channelName);

    tableList.forEach((table) => {
      channel.on(
        'postgres_changes',
        { event: '*', schema: 'public', table },
        () => debouncedUpdate()
      );
    });

    channel.subscribe();

    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
      supabase.removeChannel(channel);
    };
  }, [tablesKey, debouncedUpdate, enabled]);
};