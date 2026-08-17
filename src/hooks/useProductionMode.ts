/**
 * useProductionMode.ts
 * Hook to check if the app is running in production mode.
 * In production mode, mock/seed data utilities should be disabled.
 */

import { useState, useEffect } from "react";
import { supabase } from "@/integrations/supabase/client";

export const useProductionMode = () => {
  const [isProduction, setIsProduction] = useState(true); // Default to production (safer)
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkProductionMode = async () => {
      try {
        // Check app_settings for production_mode flag
        const { data, error } = await supabase
          .from("app_settings")
          .select("setting_value")
          .eq("setting_key", "production_mode")
          .maybeSingle();

        if (error) {
          console.error("Error checking production mode:", error);
          // Default to production mode if check fails (safer)
          setIsProduction(true);
        } else if (data) {
          // Parse the JSON setting value
          const value = typeof data.setting_value === 'object' 
            ? data.setting_value 
            : JSON.parse(data.setting_value as string);
          setIsProduction(value === true || value === "true");
        } else {
          // No setting found - default to production
          setIsProduction(true);
        }
      } catch (err) {
        console.error("Error parsing production mode:", err);
        setIsProduction(true);
      } finally {
        setLoading(false);
      }
    };

    checkProductionMode();
  }, []);

  return { isProduction, loading };
};
