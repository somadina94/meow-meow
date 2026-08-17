/**
 * useIOSCaptureGuard
 *
 * Listens for iOS screenshot + screen-recording events emitted by the native
 * Capacitor plugin defined in `ios-patches/ScreenCapturePlugin.swift`.
 *
 * iOS does NOT allow blocking screenshots (Apple policy). This hook gives
 * the next-best thing:
 *   - Auto-blur the entire UI while screen recording is active
 *     (UIScreen.isCaptured) and clear it when recording stops.
 *   - Toast + server-side audit-log entry every time a screenshot is taken
 *     (UIApplication.userDidTakeScreenshotNotification).
 *
 * Safe no-op on Android, web, PWA, and TWA — those platforms either block
 * screenshots natively (Android FLAG_SECURE) or cannot detect them at all.
 */

import { useEffect, useState } from "react";
import { Capacitor } from "@capacitor/core";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";

interface ScreenCapturePlugin {
  addListener(
    event: "screenshotTaken" | "recordingChanged",
    cb: (data: { isRecording?: boolean }) => void,
  ): Promise<{ remove: () => Promise<void> }>;
}

export function useIOSCaptureGuard() {
  const [isRecording, setIsRecording] = useState(false);

  useEffect(() => {
    if (Capacitor.getPlatform() !== "ios") return;

    const plugin = (Capacitor as unknown as {
      Plugins: { ScreenCapture?: ScreenCapturePlugin };
    }).Plugins.ScreenCapture;
    if (!plugin) return; // plugin not yet installed in the native shell

    const subs: Array<{ remove: () => Promise<void> }> = [];

    plugin
      .addListener("screenshotTaken", async () => {
        toast.warning("Screenshot detected", {
          description: "This action has been logged for security review.",
        });
        try {
          const { data } = await supabase.auth.getUser();
          if (data.user) {
            await supabase.from("screen_capture_events").insert({
              user_id: data.user.id,
              event_type: "screenshot",
              platform: "ios",
              user_agent: navigator.userAgent,
            });
          }
        } catch {
          /* best-effort audit log */
        }
      })
      .then((s) => subs.push(s));

    plugin
      .addListener("recordingChanged", async ({ isRecording: rec }) => {
        setIsRecording(!!rec);
        if (rec) {
          try {
            const { data } = await supabase.auth.getUser();
            if (data.user) {
              await supabase.from("screen_capture_events").insert({
                user_id: data.user.id,
                event_type: "recording_started",
                platform: "ios",
                user_agent: navigator.userAgent,
              });
            }
          } catch {
            /* best-effort */
          }
        }
      })
      .then((s) => subs.push(s));

    return () => {
      subs.forEach((s) => s.remove());
    };
  }, []);

  return { isRecording };
}
