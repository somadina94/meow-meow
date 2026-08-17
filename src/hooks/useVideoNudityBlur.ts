/**
 * useVideoNudityBlur
 * --------------------------------------------------------
 * Real-time NSFW (nudity) detection on a remote video stream.
 *
 * Policy: Sexy dress / cleavage / swimwear is ALLOWED.
 *         Only explicit nudity (Porn / Hentai categories from NSFWJS) is blurred.
 *
 * How it works:
 *   1. Loads NSFWJS (MobileNetV2 backend) in the browser — first load ~3s,
 *      then runs at ~5 FPS classifications on a hidden canvas.
 *   2. For each frame, fetches probability scores for 5 classes:
 *        Drawing | Hentai | Neutral | Porn | Sexy
 *      We only act on `Porn` and `Hentai` above the configured threshold.
 *      `Sexy` (sexy dress) is intentionally ignored to preserve normal usage.
 *   3. When the threshold is breached for N consecutive frames, a CSS
 *      `filter: blur(40px)` is applied to the live <video> element. It is
 *      removed once frames are clean again.
 *
 * Caller is responsible for rendering the warning text in red over the
 * blurred video using the returned `isBlurred` flag.
 */

import { useEffect, useRef, useState } from 'react';

// Lazy import to keep the model out of the initial bundle
type NSFWModel = {
  classify: (
    img: HTMLImageElement | HTMLVideoElement | HTMLCanvasElement
  ) => Promise<Array<{ className: string; probability: number }>>;
};

let cachedModel: NSFWModel | null = null;
let loadingPromise: Promise<NSFWModel> | null = null;

async function loadModel(): Promise<NSFWModel> {
  if (cachedModel) return cachedModel;
  if (loadingPromise) return loadingPromise;
  loadingPromise = (async () => {
    const [{ load }] = await Promise.all([
      import('nsfwjs'),
      import('@tensorflow/tfjs'),
    ]);
    const model = await load();
    cachedModel = model as unknown as NSFWModel;
    return cachedModel;
  })();
  return loadingPromise;
}

interface VideoNudityOptions {
  /** Ref to the <video> element rendering the remote stream */
  videoRef: React.RefObject<HTMLVideoElement>;
  /** Activate the detector (e.g. only during active calls) */
  enabled?: boolean;
  /** Probability threshold (0–1) for Porn/Hentai. Default 0.7. */
  threshold?: number;
  /** Frames per second of inference. Default 5 — balance perf vs latency. */
  fps?: number;
  /** Number of consecutive flagged frames before blur kicks in. Default 2. */
  consecutiveFrames?: number;
}

export interface VideoNudityState {
  isBlurred: boolean;
  isModelLoading: boolean;
  lastScore: { porn: number; hentai: number; sexy: number } | null;
}

export function useVideoNudityBlur({
  videoRef,
  enabled = true,
  threshold = 0.7,
  fps = 5,
  consecutiveFrames = 2,
}: VideoNudityOptions): VideoNudityState {
  const [state, setState] = useState<VideoNudityState>({
    isBlurred: false,
    isModelLoading: false,
    lastScore: null,
  });
  const flaggedCountRef = useRef(0);
  const cleanCountRef = useRef(0);

  useEffect(() => {
    if (!enabled || !videoRef.current) return;
    const videoEl = videoRef.current;

    let cancelled = false;
    let intervalId: NodeJS.Timeout | null = null;

    setState((s) => ({ ...s, isModelLoading: true }));
    loadModel()
      .then((model) => {
        if (cancelled) return;
        setState((s) => ({ ...s, isModelLoading: false }));

        const tick = async () => {
          if (cancelled || videoEl.readyState < 2 || videoEl.videoWidth === 0) return;
          try {
            const predictions = await model.classify(videoEl);
            const get = (name: string) =>
              predictions.find((p) => p.className === name)?.probability || 0;
            const porn = get('Porn');
            const hentai = get('Hentai');
            const sexy = get('Sexy'); // ALLOWED — informational only

            const isExplicit = porn >= threshold || hentai >= threshold;
            if (isExplicit) {
              flaggedCountRef.current += 1;
              cleanCountRef.current = 0;
            } else {
              cleanCountRef.current += 1;
              flaggedCountRef.current = 0;
            }

            const shouldBlur = flaggedCountRef.current >= consecutiveFrames;
            const shouldUnblur = cleanCountRef.current >= consecutiveFrames;

            setState((s) => {
              const next: VideoNudityState = { ...s, lastScore: { porn, hentai, sexy } };
              if (shouldBlur && !s.isBlurred) next.isBlurred = true;
              if (shouldUnblur && s.isBlurred) next.isBlurred = false;
              return next;
            });
          } catch {
            /* one bad frame should not stop the loop */
          }
        };

        intervalId = setInterval(tick, Math.max(100, Math.floor(1000 / fps)));
      })
      .catch(() => {
        if (!cancelled) setState((s) => ({ ...s, isModelLoading: false }));
      });

    return () => {
      cancelled = true;
      if (intervalId) clearInterval(intervalId);
    };
  }, [enabled, videoRef, threshold, fps, consecutiveFrames]);

  // Apply / remove the visual blur on the underlying <video> element
  useEffect(() => {
    const v = videoRef.current;
    if (!v) return;
    v.style.transition = 'filter 200ms ease-out';
    v.style.filter = state.isBlurred ? 'blur(40px) saturate(0.6)' : '';
    return () => {
      if (v) v.style.filter = '';
    };
  }, [state.isBlurred, videoRef]);

  return state;
}
