import { toast } from "sonner";
import { useState, useEffect, useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";

const STORAGE_KEY = "parallel_chat_settings";
const DEFAULT_MAX_CHATS = 3;

interface ParallelChatSettings {
  maxParallelChats: number;
}

interface UseParallelChatSettingsResult {
  maxParallelChats: number;
  setMaxParallelChats: (count: number) => Promise<void>;
  isLoading: boolean;
}

export const useParallelChatSettings = (userId?: string): UseParallelChatSettingsResult => {
  const [maxParallelChats, setMaxChats] = useState<number>(DEFAULT_MAX_CHATS);
  const [isLoading, setIsLoading] = useState(true);

  // Load settings on mount
  useEffect(() => {
    const loadSettings = async () => {
      if (!userId) {
        setIsLoading(false);
        return;
      }

      try {
        // Try to load from database first
        const { data: appSettings } = await supabase
          .from("app_settings")
          .select("setting_value")
          .eq("setting_key", `user_${userId}_parallel_chats`)
          .maybeSingle();

        if (appSettings?.setting_value) {
          const value = typeof appSettings.setting_value === 'number' 
            ? appSettings.setting_value 
            : Number(appSettings.setting_value);
          if (value >= 1 && value <= 5) {
            setMaxChats(value);
          }
        } else {
          // Fall back to localStorage
          const storedSettings = localStorage.getItem(`${STORAGE_KEY}_${userId}`);
          if (storedSettings) {
            const parsed: ParallelChatSettings = JSON.parse(storedSettings);
            if (parsed.maxParallelChats >= 1 && parsed.maxParallelChats <= 5) {
              setMaxChats(parsed.maxParallelChats);
            }
          }
        }
      } catch (error) {
        console.error("Error loading parallel chat settings:", error);
      toast.error("Settings unavailable", { description: "Unable to load your chat settings. Default settings will be used." });
        // Fall back to localStorage on error
        try {
          const storedSettings = localStorage.getItem(`${STORAGE_KEY}_${userId}`);
          if (storedSettings) {
            const parsed: ParallelChatSettings = JSON.parse(storedSettings);
            if (parsed.maxParallelChats >= 1 && parsed.maxParallelChats <= 5) {
              setMaxChats(parsed.maxParallelChats);
            }
          }
        } catch {
          // Use default
        }
      } finally {
        setIsLoading(false);
      }
    };

    loadSettings();
  }, [userId]);

  const setMaxParallelChats = useCallback(async (count: number) => {
    if (count < 1 || count > 5) {
      console.error("Max parallel chats must be between 1 and 5");
      toast.error("Invalid setting", { description: "Parallel chats must be set between 1 and 5." });
      return;
    }

    setMaxChats(count);

    if (!userId) {
      localStorage.setItem(`${STORAGE_KEY}_anonymous`, JSON.stringify({ maxParallelChats: count }));
      return;
    }

    // Save to localStorage immediately for responsiveness
    localStorage.setItem(`${STORAGE_KEY}_${userId}`, JSON.stringify({ maxParallelChats: count }));

    // Try to save to database
    try {
      const settingKey = `user_${userId}_parallel_chats`;
      
      // Check if setting exists
      const { data: existing } = await supabase
        .from("app_settings")
        .select("id")
        .eq("setting_key", settingKey)
        .maybeSingle();

      if (existing) {
        // Update existing
        await supabase
          .from("app_settings")
          .update({ 
            setting_value: count,
            updated_at: new Date().toISOString()
          })
          .eq("setting_key", settingKey);
      } else {
        // Insert new
        await supabase
          .from("app_settings")
          .insert({
            setting_key: settingKey,
            setting_value: count,
            setting_type: "number",
            category: "user_preferences",
            description: "Maximum parallel chat windows preference",
            is_public: false
          });
      }
    } catch (error) {
      console.error("Error saving parallel chat settings to database:", error);
      toast.error("Settings not saved", { description: "Unable to save your parallel chat settings. Please try again." });
      // Settings are still saved in localStorage, so this is not critical
    }
  }, [userId]);

  return {
    maxParallelChats,
    setMaxParallelChats,
    isLoading
  };
};
