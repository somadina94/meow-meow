/**
 * use-mobile.tsx
 * 
 * PURPOSE: Detect mobile viewport using dynamic breakpoint from settings.
 * Loads breakpoint from app_settings table for configurability.
 * 
 * DYNAMIC CONFIGURATION:
 * - Breakpoint loaded from database on mount
 * - Falls back to default if database unavailable
 * - Re-evaluates when breakpoint changes
 */

import * as React from "react";
import { supabase } from "@/integrations/supabase/client";

// Default breakpoint (used while loading or if fetch fails)
const DEFAULT_MOBILE_BREAKPOINT = 768;

export function useIsMobile() {
  const [isMobile, setIsMobile] = React.useState<boolean | undefined>(undefined);
  const [mobileBreakpoint, setMobileBreakpoint] = React.useState(DEFAULT_MOBILE_BREAKPOINT);

  // Fetch breakpoint from settings on mount
  React.useEffect(() => {
    const fetchBreakpoint = async () => {
      try {
        const { data } = await supabase
          .from("app_settings")
          .select("setting_value")
          .eq("setting_key", "mobile_breakpoint")
          .maybeSingle();
        
        if (data?.setting_value) {
          const value = parseInt(String(data.setting_value));
          if (!isNaN(value) && value > 0) {
            setMobileBreakpoint(value);
          }
        }
      } catch (error) {
        console.warn("Failed to fetch mobile breakpoint, using default:", error);
      }
    };
    
    fetchBreakpoint();
  }, []);

  // Detect mobile based on dynamic breakpoint
  React.useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < mobileBreakpoint);
    };

    // Initial check
    checkMobile();

    // Listen for resize
    const mql = window.matchMedia(`(max-width: ${mobileBreakpoint - 1}px)`);
    const onChange = () => checkMobile();
    
    mql.addEventListener("change", onChange);
    window.addEventListener("resize", checkMobile);
    
    return () => {
      mql.removeEventListener("change", onChange);
      window.removeEventListener("resize", checkMobile);
    };
  }, [mobileBreakpoint]);

  return !!isMobile;
}
