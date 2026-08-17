import { useState, useEffect, useCallback, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";

export type WomenChatMode = "paid" | "free" | "exclusive_free";

interface WomenChatModeState {
  currentMode: WomenChatMode;
  isIndian: boolean;
  freeMinutesUsed: number;
  freeMinutesLimit: number;
  exclusiveFreeLockedUntil: string | null;
  isLoading: boolean;
  canSwitchToPaid: boolean;
  canSwitchToFree: boolean;
  canSwitchToExclusiveFree: boolean;
  freeTimeRemaining: number; // in seconds
  // Force free mode (non-Indian only) - 15 min/day where men aren't charged
  isForceFreeActive: boolean;
  forceFreeMinutesUsed: number;
  forceFreeMinutesLimit: number;
  forceFreeTimeRemaining: number; // in seconds
  toggleForceFree: () => Promise<boolean>;
  trackForceFreeMinute: () => Promise<void>;
  switchMode: (newMode: WomenChatMode) => Promise<boolean>;
  trackFreeMinute: () => Promise<void>;
}

export const useWomenChatMode = (userId: string | null, isIndianUser?: boolean): WomenChatModeState => {
  const isIndian = isIndianUser ?? false;
  const defaultMode: WomenChatMode = isIndian ? "paid" : "free";
  const [currentMode, setCurrentMode] = useState<WomenChatMode>(defaultMode);
  const [freeMinutesUsed, setFreeMinutesUsed] = useState(0);
  const [freeMinutesLimit, setFreeMinutesLimit] = useState(isIndian ? 60 : Infinity);
  const [exclusiveFreeLockedUntil, setExclusiveFreeLockedUntil] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isForceFreeActive, setIsForceFreeActive] = useState(false);
  const [forceFreeMinutesUsed, setForceFreeMinutesUsed] = useState(0);
  const [forceFreeMinutesLimit, setForceFreeMinutesLimit] = useState(15);
  const timerRef = useRef<NodeJS.Timeout | null>(null);

  // Load current mode from DB
  useEffect(() => {
    if (!userId) return;

    const loadMode = async () => {
      setIsLoading(true);
      try {
        const { data, error } = await supabase
          .from("women_chat_modes")
          .select("*")
          .eq("user_id", userId)
          .maybeSingle();

        if (error) {
          console.error("[useWomenChatMode] Error:", error);
          setIsLoading(false);
          return;
        }

        if (data) {
          const today = new Date().toISOString().split("T")[0];
          const lastReset = data.last_free_reset_date;

          // Reset free minutes if it's a new day (optimistic lock: only update if date still stale)
           if (lastReset !== today) {
            const { data: resetResult, error: resetError } = await supabase
              .from("women_chat_modes")
              .update({
                free_minutes_used_today: 0,
                force_free_minutes_used_today: 0,
                is_force_free_active: false,
                last_free_reset_date: today,
                // If exclusive free lock expired, reset to default mode
                ...(data.exclusive_free_locked_until && 
                  new Date(data.exclusive_free_locked_until) <= new Date() 
                  ? { current_mode: defaultMode, exclusive_free_locked_until: null }
                  : {}
                )
              })
              .eq("user_id", userId)
              .neq("last_free_reset_date", today)
              .select();

            // If another tab already reset (0 rows updated), re-fetch fresh state
            if (!resetResult?.length) {
              console.log("[useWomenChatMode] Reset already applied by another tab, re-fetching");
              const { data: fresh } = await supabase
                .from("women_chat_modes")
                .select("*")
                .eq("user_id", userId)
                .maybeSingle();
              if (fresh) {
                setCurrentMode(fresh.current_mode as WomenChatMode);
                setFreeMinutesUsed(Number(fresh.free_minutes_used_today) || 0);
                setExclusiveFreeLockedUntil(fresh.exclusive_free_locked_until);
                const ffUsed = Number((fresh as any).force_free_minutes_used_today) || 0;
                const ffLimit = Number((fresh as any).force_free_minutes_limit) || 15;
                const ffActive = (fresh as any).is_force_free_active ?? false;
                setForceFreeMinutesUsed(ffUsed);
                setForceFreeMinutesLimit(ffLimit);
                setIsForceFreeActive(ffActive && ffUsed < ffLimit);
                setFreeMinutesLimit(isIndian ? (Number(fresh.free_minutes_limit) || 60) : Infinity);
              }
              setIsLoading(false);
              return;
            }
            
            setFreeMinutesUsed(0);
            setForceFreeMinutesUsed(0);
            setIsForceFreeActive(false);
            
            // Check if exclusive free lock expired
            if (data.exclusive_free_locked_until && 
                new Date(data.exclusive_free_locked_until) <= new Date()) {
              setCurrentMode(defaultMode);
              setExclusiveFreeLockedUntil(null);
            } else {
              setCurrentMode(data.current_mode as WomenChatMode);
              setExclusiveFreeLockedUntil(data.exclusive_free_locked_until);
            }
          } else {
            setCurrentMode(data.current_mode as WomenChatMode);
            setFreeMinutesUsed(Number(data.free_minutes_used_today) || 0);
            setExclusiveFreeLockedUntil(data.exclusive_free_locked_until);
            // Load force free state
            const ffUsed = Number((data as any).force_free_minutes_used_today) || 0;
            const ffLimit = Number((data as any).force_free_minutes_limit) || 15;
            const ffActive = (data as any).is_force_free_active ?? false;
            setForceFreeMinutesUsed(ffUsed);
            setForceFreeMinutesLimit(ffLimit);
            // Auto-deactivate if limit reached
            setIsForceFreeActive(ffActive && ffUsed < ffLimit);
          }
          setFreeMinutesLimit(isIndian ? (Number(data.free_minutes_limit) || 60) : Infinity);
        } else {
          // Create default record - Indian women default to paid, non-Indian to free
          await supabase.from("women_chat_modes").upsert({
            user_id: userId,
            current_mode: defaultMode,
            free_minutes_used_today: 0,
            free_minutes_limit: 60,
            last_free_reset_date: new Date().toISOString().split("T")[0]
          }, { onConflict: "user_id", ignoreDuplicates: true });
          setCurrentMode(defaultMode);
        }
      } catch (err) {
        console.error("[useWomenChatMode] Error:", err);
      } finally {
        setIsLoading(false);
      }
    };

    loadMode();
  }, [userId]);

  // Determine what modes can be switched to
  const isExclusiveFreeLocked = exclusiveFreeLockedUntil && 
    new Date(exclusiveFreeLockedUntil) > new Date();

  const canSwitchToPaid = currentMode !== "paid" && !isExclusiveFreeLocked;
  const canSwitchToFree = currentMode !== "free" && !isExclusiveFreeLocked && (!isIndian || freeMinutesUsed < freeMinutesLimit);
  const canSwitchToExclusiveFree = currentMode !== "exclusive_free" && !isExclusiveFreeLocked;

  const freeTimeRemaining = isIndian ? Math.max(0, (freeMinutesLimit - freeMinutesUsed) * 60) : Infinity;

  const switchMode = useCallback(async (newMode: WomenChatMode): Promise<boolean> => {
    if (!userId) return false;

    // Validate switch
    if (newMode === "paid" && isExclusiveFreeLocked) {
      return false;
    }

    if (newMode === "free" && freeMinutesUsed >= freeMinutesLimit) {
      return false;
    }

    try {
      const updateData: Record<string, any> = {
        current_mode: newMode,
        mode_switched_at: new Date().toISOString(),
      };

      if (newMode === "exclusive_free") {
        // Lock for 24 hours
        const lockUntil = new Date();
        lockUntil.setHours(lockUntil.getHours() + 24);
        updateData.exclusive_free_locked_until = lockUntil.toISOString();
        setExclusiveFreeLockedUntil(lockUntil.toISOString());
      }

      if (newMode === "paid") {
        updateData.exclusive_free_locked_until = null;
        setExclusiveFreeLockedUntil(null);
      }

      const { error } = await supabase
        .from("women_chat_modes")
        .update(updateData)
        .eq("user_id", userId);

      if (error) {
        console.error("[useWomenChatMode] Switch error:", error);
        return false;
      }

      setCurrentMode(newMode);

      // If switching from free/exclusive_free to paid, end active chats with non-recharged men
      if (newMode === "paid" && (currentMode === "free" || currentMode === "exclusive_free")) {
        // End sessions with zero-balance men
        await endChatsWithNonRechargedMen(userId);
      }

      // If switching to free/exclusive_free from paid, end chats with premium men
      if ((newMode === "free" || newMode === "exclusive_free") && currentMode === "paid") {
        await endChatsWithRechargedMen(userId);
      }

      return true;
    } catch (err) {
      console.error("[useWomenChatMode] Error:", err);
      return false;
    }
  }, [userId, currentMode, isExclusiveFreeLocked, freeMinutesUsed, freeMinutesLimit]);

  // Track free minutes usage
  const trackFreeMinute = useCallback(async () => {
    if (!userId || currentMode === "paid") return;

    const newUsed = freeMinutesUsed + 1;
    setFreeMinutesUsed(newUsed);

    await supabase
      .from("women_chat_modes")
      .update({ free_minutes_used_today: newUsed })
      .eq("user_id", userId);

    // Auto-end chats when free time expires (only for Indian women in free mode with time limit)
    if (isIndian && currentMode === "free" && newUsed >= freeMinutesLimit) {
      await switchMode(defaultMode);
    }
  }, [userId, currentMode, freeMinutesUsed, freeMinutesLimit, switchMode]);

  // Force free mode toggle (non-Indian only) - 15 min/day where men aren't charged
  const forceFreeTimeRemaining = Math.max(0, (forceFreeMinutesLimit - forceFreeMinutesUsed) * 60);

  const toggleForceFree = useCallback(async (): Promise<boolean> => {
    if (!userId || isIndian) return false;

    const newActive = !isForceFreeActive;

    // Can't activate if limit reached
    if (newActive && forceFreeMinutesUsed >= forceFreeMinutesLimit) return false;

    try {
      const { error } = await supabase
        .from("women_chat_modes")
        .update({ is_force_free_active: newActive } as any)
        .eq("user_id", userId);

      if (error) {
        console.error("[useWomenChatMode] Force free toggle error:", error);
        return false;
      }

      setIsForceFreeActive(newActive);
      return true;
    } catch (err) {
      console.error("[useWomenChatMode] Error:", err);
      return false;
    }
  }, [userId, isIndian, isForceFreeActive, forceFreeMinutesUsed, forceFreeMinutesLimit]);

  // Track force free minutes
  const trackForceFreeMinute = useCallback(async () => {
    if (!userId || !isForceFreeActive) return;

    const newUsed = forceFreeMinutesUsed + 1;
    setForceFreeMinutesUsed(newUsed);

    await supabase
      .from("women_chat_modes")
      .update({ force_free_minutes_used_today: newUsed } as any)
      .eq("user_id", userId);

    // Auto-deactivate when limit reached
    if (newUsed >= forceFreeMinutesLimit) {
      setIsForceFreeActive(false);
      await supabase
        .from("women_chat_modes")
        .update({ is_force_free_active: false } as any)
        .eq("user_id", userId);
    }
  }, [userId, isForceFreeActive, forceFreeMinutesUsed, forceFreeMinutesLimit]);

  return {
    currentMode,
    isIndian,
    freeMinutesUsed,
    freeMinutesLimit,
    exclusiveFreeLockedUntil,
    isLoading,
    canSwitchToPaid,
    canSwitchToFree,
    canSwitchToExclusiveFree,
    freeTimeRemaining,
    isForceFreeActive,
    forceFreeMinutesUsed,
    forceFreeMinutesLimit,
    forceFreeTimeRemaining,
    toggleForceFree,
    trackForceFreeMinute,
    switchMode,
    trackFreeMinute,
  };
};

// Helper: End chats with non-recharged men
async function endChatsWithNonRechargedMen(userId: string) {
  try {
    // Get active sessions
    const { data: sessions } = await supabase
      .from("active_chat_sessions")
      .select("id, man_user_id")
      .eq("woman_user_id", userId)
      .eq("status", "active");

    if (!sessions?.length) return;

    const manIds = sessions.map(s => s.man_user_id);
    const { data: wallets } = await supabase
      .from("wallets")
      .select("user_id, balance")
      .in("user_id", manIds);

    const walletMap = new Map(wallets?.map(w => [w.user_id, w.balance as number]) || []);

    // End sessions with men who have zero balance
    for (const session of sessions) {
      const balance = (walletMap.get(session.man_user_id) || 0) as number;
      if (balance <= 0) {
        await supabase
          .from("active_chat_sessions")
          .update({ status: "ended", ended_at: new Date().toISOString(), end_reason: "mode_switch" })
          .eq("id", session.id);
      }
    }
  } catch (err) {
    console.error("[endChatsWithNonRechargedMen] Error:", err);
  }
}

// Helper: End chats with recharged men
async function endChatsWithRechargedMen(userId: string) {
  try {
    const { data: sessions } = await supabase
      .from("active_chat_sessions")
      .select("id, man_user_id")
      .eq("woman_user_id", userId)
      .eq("status", "active");

    if (!sessions?.length) return;

    const manIds = sessions.map(s => s.man_user_id);
    const { data: wallets } = await supabase
      .from("wallets")
      .select("user_id, balance")
      .in("user_id", manIds);

    const walletMap = new Map(wallets?.map(w => [w.user_id, w.balance as number]) || []);

    // End sessions with men who have balance > 0
    for (const session of sessions) {
      const balance = (walletMap.get(session.man_user_id) || 0) as number;
      if (balance > 0) {
        await supabase
          .from("active_chat_sessions")
          .update({ status: "ended", ended_at: new Date().toISOString(), end_reason: "mode_switch" })
          .eq("id", session.id);
      }
    }
  } catch (err) {
    console.error("[endChatsWithRechargedMen] Error:", err);
  }
}
