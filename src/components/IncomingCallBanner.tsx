import { useEffect, useRef } from 'react';
import { Phone, PhoneOff } from 'lucide-react';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';

interface IncomingCallBannerProps {
  callerName: string;
  callerPhoto: string | null;
  callType: 'audio' | 'video';
  onAccept: () => void;
  onDecline: () => void;
}

export const IncomingCallBanner = ({
  callerName, callerPhoto, callType, onAccept, onDecline,
}: IncomingCallBannerProps) => {
  const ringRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const ctxRef = useRef<AudioContext | null>(null);

  const playRing = () => {
    try {
      if (!ctxRef.current || ctxRef.current.state === 'closed') {
        ctxRef.current = new AudioContext();
      }
      const ctx = ctxRef.current;
      const t = ctx.currentTime;

      // Loud old-school phone ring — two bursts with harmonics
      [0, 0.45].forEach(offset => {
        // Primary ring tone
        const osc1 = ctx.createOscillator();
        const g1 = ctx.createGain();
        osc1.type = 'square';
        osc1.frequency.setValueAtTime(2000, t + offset);
        g1.gain.setValueAtTime(0.8, t + offset);
        g1.gain.exponentialRampToValueAtTime(0.01, t + offset + 0.35);
        osc1.connect(g1).connect(ctx.destination);
        osc1.start(t + offset);
        osc1.stop(t + offset + 0.35);

        // Secondary harmonic for fullness
        const osc2 = ctx.createOscillator();
        const g2 = ctx.createGain();
        osc2.type = 'square';
        osc2.frequency.setValueAtTime(2500, t + offset);
        g2.gain.setValueAtTime(0.6, t + offset);
        g2.gain.exponentialRampToValueAtTime(0.01, t + offset + 0.3);
        osc2.connect(g2).connect(ctx.destination);
        osc2.start(t + offset);
        osc2.stop(t + offset + 0.3);

        // Low body tone
        const osc3 = ctx.createOscillator();
        const g3 = ctx.createGain();
        osc3.type = 'triangle';
        osc3.frequency.setValueAtTime(440, t + offset);
        g3.gain.setValueAtTime(0.5, t + offset);
        g3.gain.exponentialRampToValueAtTime(0.01, t + offset + 0.3);
        osc3.connect(g3).connect(ctx.destination);
        osc3.start(t + offset);
        osc3.stop(t + offset + 0.3);
      });
    } catch {}
  };

  useEffect(() => {
    playRing();
    ringRef.current = setInterval(playRing, 2000);
    return () => {
      if (ringRef.current) clearInterval(ringRef.current);
      ctxRef.current?.close().catch(() => {});
    };
  }, []);

  return (
    <div className="fixed inset-0 z-[9999] bg-gradient-to-b from-zinc-900 via-zinc-800 to-zinc-900 flex flex-col items-center justify-between py-20">
      <div className="flex flex-col items-center gap-4">
        <p className="text-white/60 text-sm uppercase tracking-wider">
          Incoming {callType} call
        </p>
        <Avatar className="h-28 w-28 border-4 border-white/20 shadow-2xl">
          <AvatarImage src={callerPhoto || undefined} />
          <AvatarFallback className="bg-primary text-primary-foreground text-4xl">
            {callerName[0]?.toUpperCase()}
          </AvatarFallback>
        </Avatar>
        <h2 className="text-white text-3xl font-semibold">{callerName}</h2>
      </div>

      <div className="flex justify-around w-full max-w-xs">
        {/* Decline */}
        <div className="flex flex-col items-center gap-2">
          <button
            onClick={onDecline}
            className="w-16 h-16 rounded-full bg-red-600 flex items-center justify-center shadow-lg active:scale-95 transition-transform animate-pulse"
          >
            <PhoneOff className="w-7 h-7 text-white" />
          </button>
          <span className="text-white/60 text-xs">Decline</span>
        </div>

        {/* Accept */}
        <div className="flex flex-col items-center gap-2">
          <button
            onClick={onAccept}
            className="w-16 h-16 rounded-full bg-green-600 flex items-center justify-center shadow-lg active:scale-95 transition-transform animate-pulse"
          >
            <Phone className="w-7 h-7 text-white" />
          </button>
          <span className="text-white/60 text-xs">Accept</span>
        </div>
      </div>
    </div>
  );
};

export default IncomingCallBanner;
