/**
 * useWebCaptureGuard
 *
 * Web/PWA/TWA capture-attempt detection. Browsers do NOT expose a
 * screenshot API, so we log the closest proxies we have:
 *
 *   1. visibilitychange → "hidden": user switched away (often to a
 *      screenshot tool). Logged as `screenshot` (best-effort proxy).
 *   2. getDisplayMedia interception: any code that calls the screen-share
 *      API is logged as `recording_started` and the JS hook surfaces
 *      isRecording=true so the UI can blur.
 *
 * Throttled to one log per 30s per event type to avoid log spam from
 * normal tab switching.
 */

import { useEffect, useState } from "react";
import { Capacitor } from "@capacitor/core";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";

const THROTTLE_MS = 30_000;

export function useWebCaptureGuard() {
  const [isSharing, setIsSharing] = useState(false);

  useEffect(() => {
    // Skip on native — Android/iOS hooks handle their own platforms.
    if (Capacitor.isNativePlatform()) return;

    const lastLogged: Record<string, number> = {};

    const log = async (
      event_type: "screenshot" | "recording_started" | "recording_stopped",
    ) => {
      const now = Date.now();
      if (now - (lastLogged[event_type] ?? 0) < THROTTLE_MS) return;
      lastLogged[event_type] = now;
      try {
        const { data } = await supabase.auth.getUser();
        if (!data.user) return;
        await supabase.from("screen_capture_events").insert({
          user_id: data.user.id,
          event_type,
          platform: "web",
          user_agent: navigator.userAgent,
        });
      } catch {
        /* best-effort */
      }
    };

    // Visibility change → proxy for screenshot intent
    const onVis = () => {
      if (document.visibilityState === "hidden") void log("screenshot");
    };
    document.addEventListener("visibilitychange", onVis);

    // Intercept getDisplayMedia (screen-share API) — only signal we have
    // for active recording in the browser.
    const md = navigator.mediaDevices as MediaDevices & {
      _origGetDisplayMedia?: typeof navigator.mediaDevices.getDisplayMedia;
    };
    let restored: (() => void) | null = null;
    if (md && md.getDisplayMedia && !md._origGetDisplayMedia) {
      const orig = md.getDisplayMedia.bind(md);
      md._origGetDisplayMedia = orig;
      md.getDisplayMedia = async (
        constraints?: DisplayMediaStreamOptions,
      ): Promise<MediaStream> => {
        const stream = await orig(constraints);
        setIsSharing(true);
        toast.warning("Screen sharing detected", {
          description: "This activity has been logged for security review.",
        });
        void log("recording_started");
        // Detect when the user stops sharing (track ended).
        stream.getVideoTracks().forEach((t) => {
          t.addEventListener("ended", () => {
            setIsSharing(false);
            void log("recording_stopped");
          });
        });
        return stream;
      };
      restored = () => {
        md.getDisplayMedia = orig;
        delete md._origGetDisplayMedia;
      };
    }

    return () => {
      document.removeEventListener("visibilitychange", onVis);
      restored?.();
    };
  }, []);

  return { isSharing };
}
