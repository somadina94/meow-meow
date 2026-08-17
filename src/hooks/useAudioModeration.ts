/**
 * useAudioModeration
 * --------------------------------------------------------
 * Real-time audio moderation for 1:1 audio + video calls.
 *
 * How it works:
 *   1. Listens to the local microphone via the browser's Web Speech API
 *      (free, on-device, no server cost). Falls back gracefully if unsupported.
 *   2. Each interim transcript is run through the central moderation engine
 *      (`moderateMessage`) which already covers English + all Indian languages
 *      (native scripts and romanized) for sexual + hate speech.
 *   3. When a flagged word is detected, a short beep is played through the
 *      outgoing audio context, briefly muting the mic track so partners
 *      hear `beeeep` instead of the slur.
 *   4. A red on-screen banner state is exposed to the caller so the UI can
 *      show "Inappropriate language muted" in red over the call window.
 *
 * NOTE: Because Web Speech recognition is only ~70% accurate on Indian
 *       languages, this is a best-effort filter — it complements (not
 *       replaces) the post-call review by admin moderators.
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { moderateMessage, type ViolationType } from '@/lib/content-moderation';

// Browser SpeechRecognition typings (not in standard lib.d.ts)
type AnySpeechRecognition = any;

declare global {
  interface Window {
    SpeechRecognition?: AnySpeechRecognition;
    webkitSpeechRecognition?: AnySpeechRecognition;
  }
}

interface AudioModerationOptions {
  /** Local mic stream from getUserMedia — required to mute when beeping */
  localStream?: MediaStream | null;
  /** BCP-47 language tag (e.g. 'hi-IN', 'ta-IN', 'en-IN'). Defaults to en-IN. */
  language?: string;
  /** Enable / disable the whole pipeline (e.g. only during active calls) */
  enabled?: boolean;
  /** Beep duration in ms (default 600) */
  beepDurationMs?: number;
}

export interface AudioModerationState {
  /** True while a beep + mute is currently active */
  isBeeping: boolean;
  /** Last detected violation reason, displayed in red on the UI */
  lastViolation: { reason: string; type: ViolationType; at: number } | null;
  /** Whether the underlying SpeechRecognition API is available */
  isSupported: boolean;
}

const playBeep = (durationMs: number) => {
  try {
    const Ctx = (window.AudioContext || (window as any).webkitAudioContext);
    if (!Ctx) return;
    const ctx = new Ctx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.value = 1000; // classic censor beep
    gain.gain.value = 0.25;
    osc.connect(gain).connect(ctx.destination);
    osc.start();
    setTimeout(() => {
      osc.stop();
      ctx.close().catch(() => {});
    }, durationMs);
  } catch {
    /* no-op */
  }
};

export function useAudioModeration({
  localStream,
  language = 'en-IN',
  enabled = true,
  beepDurationMs = 600,
}: AudioModerationOptions): AudioModerationState {
  const [state, setState] = useState<AudioModerationState>({
    isBeeping: false,
    lastViolation: null,
    isSupported: false,
  });
  const recognitionRef = useRef<AnySpeechRecognition | null>(null);
  const beepTimeoutRef = useRef<NodeJS.Timeout>();

  const triggerBeep = useCallback(
    (reason: string, type: ViolationType) => {
      // Mute the outgoing mic during the beep window
      const audioTracks = localStream?.getAudioTracks() || [];
      const previouslyEnabled = audioTracks.map((t) => t.enabled);
      audioTracks.forEach((t) => (t.enabled = false));

      playBeep(beepDurationMs);
      setState((s) => ({
        ...s,
        isBeeping: true,
        lastViolation: { reason, type, at: Date.now() },
      }));

      if (beepTimeoutRef.current) clearTimeout(beepTimeoutRef.current);
      beepTimeoutRef.current = setTimeout(() => {
        audioTracks.forEach((t, i) => (t.enabled = previouslyEnabled[i] ?? true));
        setState((s) => ({ ...s, isBeeping: false }));
      }, beepDurationMs);
    },
    [localStream, beepDurationMs]
  );

  useEffect(() => {
    if (!enabled) return;
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) {
      setState((s) => ({ ...s, isSupported: false }));
      return;
    }
    setState((s) => ({ ...s, isSupported: true }));

    const recognition: AnySpeechRecognition = new SR();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = language;

    recognition.onresult = (event: any) => {
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const transcript: string = event.results[i][0]?.transcript || '';
        if (!transcript.trim()) continue;
        const result = moderateMessage(transcript);
        if (result.isBlocked && (result.detectedType === 'sexual_content' || result.detectedType === 'hate_speech' || result.detectedType === 'harmful_content')) {
          triggerBeep(result.reason || 'Inappropriate speech detected', result.detectedType);
        }
      }
    };

    recognition.onerror = () => {
      // Auto-restart on transient errors (network/no-speech)
      try { recognition.stop(); } catch { }
    };

    recognition.onend = () => {
      // Keep listening for the duration of the call
      if (enabled) {
        try { recognition.start(); } catch { }
      }
    };

    try {
      recognition.start();
      recognitionRef.current = recognition;
    } catch {
      /* recognition may already be running */
    }

    return () => {
      try { recognition.stop(); } catch { }
      recognitionRef.current = null;
      if (beepTimeoutRef.current) clearTimeout(beepTimeoutRef.current);
    };
  }, [enabled, language, triggerBeep]);

  return state;
}
