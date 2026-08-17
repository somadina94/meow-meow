import { useEffect, useRef, useState } from 'react';
import { Phone, PhoneOff, Mic, MicOff, Video, VideoOff, Volume2 } from 'lucide-react';
import { ActiveCall, CallStatus } from '@/hooks/useAppCall';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { cn } from '@/lib/utils';
import { SendGiftButton } from '@/components/SendGiftButton';

interface CallScreenProps {
  status: CallStatus;
  activeCall: ActiveCall | null;
  isMuted: boolean;
  isCameraOff: boolean;
  onAccept?: () => void;
  onDecline?: () => void;
  onEnd: () => void;
  onToggleMute: () => void;
  onToggleCamera: () => void;
  userGender?: 'male' | 'female';
}

// Per-minute rates (synced with chat_pricing defaults)
const RATES = {
  audio: { male: 6, female: 3 },
  video: { male: 8, female: 4 },
} as const;

export const CallScreen = ({
  status, activeCall,
  isMuted, isCameraOff,
  onAccept, onDecline, onEnd,
  onToggleMute, onToggleCamera,
  userGender = 'male',
}: CallScreenProps) => {
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const remoteVideoRef = useRef<HTMLVideoElement>(null);
  const remoteAudioRef = useRef<HTMLAudioElement>(null);
  const [elapsed, setElapsed] = useState(0);

  // Attach local stream
  useEffect(() => {
    if (localVideoRef.current && activeCall?.localStream) {
      localVideoRef.current.srcObject = activeCall.localStream;
    }
  }, [activeCall?.localStream]);

  // Attach remote stream
  useEffect(() => {
    if (activeCall?.remoteStream) {
      if (activeCall.callType === 'video' && remoteVideoRef.current) {
        remoteVideoRef.current.srcObject = activeCall.remoteStream;
      }
      if (remoteAudioRef.current) {
        remoteAudioRef.current.srcObject = activeCall.remoteStream;
      }
    }
  }, [activeCall?.remoteStream, activeCall?.callType]);

  // Call duration timer
  useEffect(() => {
    if (status !== 'active') { setElapsed(0); return; }
    const t = setInterval(() => setElapsed(s => s + 1), 1000);
    return () => clearInterval(t);
  }, [status]);

  const fmtDuration = (s: number) => {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`;
  };

  if (!activeCall || status === 'idle' || status === 'ended') return null;

  const isVideo = activeCall.callType === 'video';
  const isRinging = status === 'ringing';
  const isCalling = status === 'calling';
  const isActive = status === 'active';

  return (
    <div className="fixed inset-0 z-[9999] bg-black flex flex-col">
      {/* Remote video fullscreen background for video calls */}
      {isVideo && activeCall.remoteStream && (
        <video
          ref={remoteVideoRef}
          autoPlay
          playsInline
          className="absolute inset-0 w-full h-full object-cover"
        />
      )}

      {/* Hidden audio element for remote audio */}
      <audio ref={remoteAudioRef} autoPlay playsInline />

      {/* Dark overlay for non-video or when connecting */}
      {(!isVideo || !activeCall.remoteStream) && (
        <div className="absolute inset-0 bg-gradient-to-b from-zinc-900 via-zinc-800 to-zinc-900" />
      )}

      {/* Top info strip */}
      <div className="relative z-10 flex flex-col items-center pt-[max(env(safe-area-inset-top),2rem)] px-4">
        <Avatar className="h-24 w-24 border-4 border-white/20 shadow-2xl mb-4">
          <AvatarImage src={activeCall.remotePhoto || undefined} />
          <AvatarFallback className="bg-primary text-primary-foreground text-3xl">
            {activeCall.remoteName[0]?.toUpperCase()}
          </AvatarFallback>
        </Avatar>

        <h2 className="text-white text-2xl font-semibold mb-1">{activeCall.remoteName}</h2>

        <p className="text-white/70 text-sm mb-2">
          {isCalling && 'Ringing...'}
          {isRinging && (isVideo ? 'Incoming video call' : 'Incoming audio call')}
          {status === 'connecting' && 'Connecting...'}
          {isActive && fmtDuration(elapsed)}
        </p>

        {isActive && (() => {
          const rate = RATES[activeCall.callType][userGender];
          // Pro-rated per-second amount
          const amount = (rate / 60) * elapsed;
          const isMan = userGender === 'male';
          return (
            <div className="flex flex-col items-center gap-1">
              <span className="px-2 py-0.5 rounded-full bg-white/10 text-white/60 text-xs">
                {isMan ? 'Cost' : 'Earned'}: ₹{amount.toFixed(2)} · ₹{rate}/min
              </span>
            </div>
          );
        })()}
      </div>

      {/* Local video PIP (video calls only) */}
      {isVideo && activeCall.localStream && (
        <div className="absolute bottom-36 right-4 z-20 w-28 h-40 rounded-xl overflow-hidden border-2 border-white/30 shadow-xl">
          <video
            ref={localVideoRef}
            autoPlay
            playsInline
            muted
            className={cn("w-full h-full object-cover", isCameraOff && "hidden")}
          />
          {isCameraOff && (
            <div className="w-full h-full bg-zinc-700 flex items-center justify-center">
              <VideoOff className="w-8 h-8 text-white/50" />
            </div>
          )}
        </div>
      )}

      {/* Bottom controls */}
      <div className="relative z-10 mt-auto pb-[max(env(safe-area-inset-bottom),2rem)] px-6">
        {/* INCOMING (woman) — Accept + Decline */}
        {isRinging && !activeCall.isInitiator && (
          <div className="flex justify-around items-center">
            <button
              onClick={onDecline}
              className="w-16 h-16 rounded-full bg-red-600 flex items-center justify-center shadow-lg active:scale-95 transition-transform"
            >
              <PhoneOff className="w-7 h-7 text-white" />
            </button>
            <button
              onClick={onAccept}
              className="w-16 h-16 rounded-full bg-green-600 flex items-center justify-center shadow-lg active:scale-95 transition-transform"
            >
              <Phone className="w-7 h-7 text-white" />
            </button>
          </div>
        )}

        {/* OUTGOING (man waiting) — Cancel only */}
        {isCalling && (
          <div className="flex justify-center">
            <button
              onClick={onEnd}
              className="w-16 h-16 rounded-full bg-red-600 flex items-center justify-center shadow-lg active:scale-95 transition-transform"
            >
              <PhoneOff className="w-7 h-7 text-white" />
            </button>
          </div>
        )}

        {/* ACTIVE — Mute | Camera | Speaker | End */}
        {isActive && (
          <div className="flex justify-around items-center">
            <CallControlButton
              icon={isMuted ? <MicOff className="w-6 h-6" /> : <Mic className="w-6 h-6" />}
              label={isMuted ? 'Unmute' : 'Mute'}
              active={isMuted}
              onPress={onToggleMute}
            />

            {isVideo && (
              <CallControlButton
                icon={isCameraOff ? <VideoOff className="w-6 h-6" /> : <Video className="w-6 h-6" />}
                label={isCameraOff ? 'Camera off' : 'Camera'}
                active={isCameraOff}
                onPress={onToggleCamera}
              />
            )}

            <CallControlButton
              icon={<Volume2 className="w-6 h-6" />}
              label="Speaker"
              onPress={() => {}}
            />

            {userGender === 'male' && activeCall.remoteUserId && (
              <SendGiftButton
                recipientUserId={activeCall.remoteUserId}
                context={isVideo ? 'video_call' : 'audio_call'}
                variant="control"
              />
            )}

            <button
              onClick={onEnd}
              className="w-16 h-16 rounded-full bg-red-600 flex items-center justify-center shadow-lg active:scale-95 transition-transform"
            >
              <PhoneOff className="w-7 h-7 text-white" />
            </button>
          </div>
        )}

        {/* CONNECTING — Cancel */}
        {status === 'connecting' && (
          <div className="flex justify-center">
            <button
              onClick={onEnd}
              className="w-16 h-16 rounded-full bg-red-600 flex items-center justify-center shadow-lg active:scale-95 transition-transform"
            >
              <PhoneOff className="w-7 h-7 text-white" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

const CallControlButton = ({
  icon, label, active = false, onPress,
}: { icon: React.ReactNode; label: string; active?: boolean; onPress: () => void }) => (
  <button
    onClick={onPress}
    className={cn(
      "flex flex-col items-center gap-1 p-3 rounded-full transition-colors",
      active ? "bg-white/30" : "bg-white/10"
    )}
  >
    <span className="text-white">{icon}</span>
    <span className="text-white/70 text-[10px]">{label}</span>
  </button>
);

export default CallScreen;
