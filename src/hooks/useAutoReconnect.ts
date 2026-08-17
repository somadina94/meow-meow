/**
 * useAutoReconnect Hook
 * 
 * Handles automatic reconnection when a connected woman becomes busy.
 * Finds the next available woman globally with same-language priority.
 */

import { useState, useCallback, useRef } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useToast } from '@/hooks/use-toast';

export interface ReconnectableWoman {
  userId: string;
  fullName: string;
  photoUrl: string | null;
  motherTongue: string;
  country: string | null;
  currentChatCount: number;
  isBusy: boolean;
}

export interface AutoReconnectResult {
  isReconnecting: boolean;
  reconnectAttempts: number;
  maxAttempts: number;
  findNextAvailableWoman: (excludeUserId?: string) => Promise<ReconnectableWoman | null>;
  initiateReconnect: (excludeUserId?: string) => Promise<ReconnectableWoman | null>;
  resetReconnectAttempts: () => void;
}

const MAX_RECONNECT_ATTEMPTS = 3;

export const useAutoReconnect = (
  currentUserId: string,
  userLanguage: string
): AutoReconnectResult => {
  const { toast } = useToast();
  const [isReconnecting, setIsReconnecting] = useState(false);
  const reconnectAttempts = useRef(0);

  const resetReconnectAttempts = useCallback(() => {
    reconnectAttempts.current = 0;
  }, []);

  /**
   * Find the next available woman based on language matching rules
   * Priority: Same language > Indian language women (for non-Indian men)
   * Load balancing: Prefer women with fewer active chats
   */
  const findNextAvailableWoman = useCallback(async (
    excludeUserId?: string
  ): Promise<ReconnectableWoman | null> => {
    try {
      // Call the backend chat-manager to find a match
      const { data, error } = await supabase.functions.invoke("chat-manager", {
        body: {
          action: "find_match",
          man_user_id: currentUserId,
          preferred_language: userLanguage,
          exclude_user_ids: excludeUserId ? [excludeUserId] : []
        }
      });

      if (error) {
        console.error("Backend matching failed:", error);
      // Non-critical auto-reconnect attempt
        // Fall back to local matching
        return await findLocalMatch(excludeUserId);
      }

      if (data?.success && data?.woman_user_id) {
        return {
          userId: data.woman_user_id,
          fullName: data.profile?.full_name || "User",
          photoUrl: data.profile?.photo_url || null,
          motherTongue: data.profile?.primary_language || "Unknown",
          country: data.profile?.country || null,
          currentChatCount: data.current_load || 0,
          isBusy: false
        };
      }

      // No match from backend, try local
      return await findLocalMatch(excludeUserId);
    } catch (error) {
      console.error("Error finding next available woman:", error);
      // Non-critical auto-reconnect attempt
      return null;
    }
  }, [currentUserId, userLanguage]);

  /**
   * Local fallback matching when backend is unavailable
   * Global matching - all languages supported with translation
   */
  const findLocalMatch = async (
    excludeUserId?: string
  ): Promise<ReconnectableWoman | null> => {
    try {
      // Get online women
      const { data: onlineStatuses } = await supabase
        .from("user_status")
        .select("user_id")
        .eq("is_online", true);

      const onlineUserIds = onlineStatuses?.map(s => s.user_id) || [];
      if (onlineUserIds.length === 0) return null;

      // Filter out excluded user
      const filteredIds = excludeUserId 
        ? onlineUserIds.filter(id => id !== excludeUserId)
        : onlineUserIds;

      if (filteredIds.length === 0) return null;

      // Get female profiles (global - no country/language restrictions)
      const { data: profiles } = await supabase
        .from("profiles")
        .select("user_id, full_name, photo_url, primary_language, preferred_language, country")
        .or("gender.eq.Female,gender.eq.female")
        .in("user_id", filteredIds);

      if (!profiles || profiles.length === 0) return null;

      // Get availability
      const { data: availability } = await supabase
        .from("women_availability")
        .select("user_id, current_chat_count, max_concurrent_chats, is_available")
        .in("user_id", filteredIds);

      const availabilityMap = new Map(
        (availability as any[] || []).map(a => [a.user_id, a])
      );

      // Get languages
      const { data: languages } = await supabase
        .from("user_languages")
        .select("user_id, language_name")
        .in("user_id", filteredIds);

      const languageMap = new Map(
        languages?.map(l => [l.user_id, l.language_name]) || []
      );

      // Filter and sort women (no language/country restrictions - global app)
      const eligibleWomen: ReconnectableWoman[] = [];

      for (const profile of profiles) {
        const avail = availabilityMap.get(profile.user_id);
        const maxChats = avail?.max_concurrent_chats || 3;
        const currentChats = avail?.current_chat_count || 0;
        const isAvailable = avail?.is_available !== false;

        // Skip busy or unavailable women
        if (currentChats >= maxChats || !isAvailable) continue;

        const womanLanguage = languageMap.get(profile.user_id) || 
                             profile.primary_language || 
                             profile.preferred_language || 
                             "Unknown";

        eligibleWomen.push({
          userId: profile.user_id,
          fullName: profile.full_name || "Anonymous",
          photoUrl: profile.photo_url,
          motherTongue: womanLanguage,
          country: profile.country,
          currentChatCount: currentChats,
          isBusy: false
        });
      }

      if (eligibleWomen.length === 0) return null;

      // Sort: same language first, then by load
      const userLangLower = userLanguage.toLowerCase();
      eligibleWomen.sort((a, b) => {
        const aIsSameLanguage = a.motherTongue.toLowerCase() === userLangLower;
        const bIsSameLanguage = b.motherTongue.toLowerCase() === userLangLower;
        
        if (aIsSameLanguage !== bIsSameLanguage) {
          return aIsSameLanguage ? -1 : 1;
        }
        return a.currentChatCount - b.currentChatCount;
      });

      return eligibleWomen[0];
    } catch (error) {
      console.error("Error in local match:", error);
      // Non-critical local matching fallback
      return null;
    }
  };

  /**
   * Initiate reconnection to a new woman
   * Returns the new woman if found, null otherwise
   */
  const initiateReconnect = useCallback(async (
    excludeUserId?: string
  ): Promise<ReconnectableWoman | null> => {
    if (reconnectAttempts.current >= MAX_RECONNECT_ATTEMPTS) {
      toast({
        title: "Connection Failed",
        description: "Unable to find available users. Please try again later.",
        variant: "destructive"
      });
      reconnectAttempts.current = 0;
      return null;
    }

    setIsReconnecting(true);
    reconnectAttempts.current += 1;

    try {
      const nextWoman = await findNextAvailableWoman(excludeUserId);

      if (nextWoman) {
        toast({
          title: "Reconnecting...",
          description: `Connecting you to ${nextWoman.fullName}`
        });
        return nextWoman;
      } else {
        toast({
          title: "No One Available",
          description: "All users are currently busy. Please wait.",
          variant: "destructive"
        });
        return null;
      }
    } finally {
      setIsReconnecting(false);
    }
  }, [findNextAvailableWoman, toast]);

  return {
    isReconnecting,
    reconnectAttempts: reconnectAttempts.current,
    maxAttempts: MAX_RECONNECT_ATTEMPTS,
    findNextAvailableWoman,
    initiateReconnect,
    resetReconnectAttempts
  };
};

export default useAutoReconnect;
