import { useRef, useCallback } from 'react';

/**
 * WhatsApp-style new message notification sound.
 * Uses the Web Audio API to generate a loud multi-tone chime
 * with harmonics for maximum audibility.
 */
export function useMessageSound() {
  const audioCtxRef = useRef<AudioContext | null>(null);
  const lastPlayedRef = useRef(0);

  const playMessageSound = useCallback((opts?: { repeat?: number; gapMs?: number }) => {
    const repeat = Math.max(1, Math.min(opts?.repeat ?? 1, 5));
    const gapMs = Math.max(150, opts?.gapMs ?? 550);

    const now = Date.now();
    if (now - lastPlayedRef.current < 500) return;
    lastPlayedRef.current = now;

    try {
      if (!audioCtxRef.current) {
        audioCtxRef.current = new (window.AudioContext || (window as any).webkitAudioContext)();
      }
      const ctx = audioCtxRef.current;
      if (ctx.state === 'suspended') ctx.resume();

      const playChimeAt = (t: number) => {
        const master = ctx.createGain();
        master.gain.setValueAtTime(1.0, t);
        master.connect(ctx.destination);

        // Tone 1 — deep triangle hit
        const osc1 = ctx.createOscillator();
        const g1 = ctx.createGain();
        osc1.type = 'triangle';
        osc1.frequency.setValueAtTime(600, t);
        g1.gain.setValueAtTime(1.0, t);
        g1.gain.exponentialRampToValueAtTime(0.01, t + 0.22);
        osc1.connect(g1).connect(master);
        osc1.start(t); osc1.stop(t + 0.22);

        // Tone 1 harmonic
        const o1h = ctx.createOscillator();
        const g1h = ctx.createGain();
        o1h.type = 'sine';
        o1h.frequency.setValueAtTime(1200, t);
        g1h.gain.setValueAtTime(0.6, t);
        g1h.gain.exponentialRampToValueAtTime(0.01, t + 0.18);
        o1h.connect(g1h).connect(master);
        o1h.start(t); o1h.stop(t + 0.18);

        // Tone 2 — bright mid pop
        const osc2 = ctx.createOscillator();
        const g2 = ctx.createGain();
        osc2.type = 'sine';
        osc2.frequency.setValueAtTime(1050, t + 0.09);
        g2.gain.setValueAtTime(1.0, t + 0.09);
        g2.gain.exponentialRampToValueAtTime(0.01, t + 0.32);
        osc2.connect(g2).connect(master);
        osc2.start(t + 0.09); osc2.stop(t + 0.32);

        // Tone 3 — high bell shimmer
        const osc3 = ctx.createOscillator();
        const g3 = ctx.createGain();
        osc3.type = 'sine';
        osc3.frequency.setValueAtTime(1680, t + 0.18);
        g3.gain.setValueAtTime(0.8, t + 0.18);
        g3.gain.exponentialRampToValueAtTime(0.01, t + 0.48);
        osc3.connect(g3).connect(master);
        osc3.start(t + 0.18); osc3.stop(t + 0.48);
      };

      const base = ctx.currentTime;
      const stepSec = gapMs / 1000;
      for (let i = 0; i < repeat; i++) {
        playChimeAt(base + i * stepSec);
      }
    } catch {
      // Audio not available — ignore silently
    }
  }, []);

  return { playMessageSound };
}
