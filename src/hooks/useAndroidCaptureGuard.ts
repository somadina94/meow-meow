/**
 * useAndroidCaptureGuard
 *
 * Listens for screenshot + recording events from the native Capacitor
 * plugin defined in `android-patches/ScreenCapturePlugin.kt`.
 *
 * Note: FLAG_SECURE in MainActivity.java already BLOCKS screenshots from
 * producing a usable image — but Android still writes a (black) file to
 * MediaStore, which is what we observe here. So we know WHEN the user
 * attempted a capture, even though the image itself is black.
 *
 * Safe no-op on iOS, web, PWA, and TWA.
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

export function useAndroidCaptureGuard() {
  const [isRecording, setIsRecording] = useState(false);

  useEffect(() => {
    if (Capacitor.getPlatform() !== "android") return;

    const plugin = (Capacitor as unknown as {
      Plugins: { ScreenCapture?: ScreenCapturePlugin };
    }).Plugins.ScreenCapture;
    if (!plugin) return;

    const subs: Array<{ remove: () => Promise<void> }> = [];

    plugin
      .addListener("screenshotTaken", async () => {
        toast.warning("Screenshot attempt detected", {
          description: "Capture is blocked and the attempt has been logged.",
        });
        try {
          const { data } = await supabase.auth.getUser();
          if (data.user) {
            await supabase.from("screen_capture_events").insert({
              user_id: data.user.id,
              event_type: "screenshot",
              platform: "android",
              user_agent: navigator.userAgent,
            });
          }
        } catch {
          /* best-effort */
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
                platform: "android",
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
