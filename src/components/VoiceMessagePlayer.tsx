/**
 * VoiceMessagePlayer.tsx
 * 
 * Audio player component for voice messages in chat.
 * Displays a compact audio player with playback controls.
 */

import { useState, useRef, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Play, Pause, Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

interface VoiceMessagePlayerProps {
  audioUrl: string;
  isMine: boolean;
  className?: string;
}

export const VoiceMessagePlayer = ({
  audioUrl,
  isMine,
  className
}: VoiceMessagePlayerProps) => {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [duration, setDuration] = useState(0);
  const [currentTime, setCurrentTime] = useState(0);
  const [error, setError] = useState(false);

  const formatTime = (seconds: number): string => {
    if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
  };

  const progress = duration > 0 && Number.isFinite(duration) ? (currentTime / duration) * 100 : 0;

  const togglePlay = () => {
    const audio = audioRef.current;
    if (!audio) return;

    if (isPlaying) {
      audio.pause();
      return;
    }
    void audio.play().catch(() => setError(true));
  };

  const handleSeek = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!audioRef.current || !duration || !Number.isFinite(duration)) return;

    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const percentage = x / rect.width;
    audioRef.current.currentTime = percentage * duration;
  };

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    setError(false);
    setIsLoading(true);
    setIsPlaying(false);
    setCurrentTime(0);
    setDuration(0);

    const applyDuration = () => {
      if (Number.isFinite(audio.duration) && audio.duration > 0) {
        setDuration(audio.duration);
      }
      setIsLoading(false);
    };

    const handleLoadedMetadata = () => applyDuration();
    const handleCanPlay = () => applyDuration();
    const handleTimeUpdate = () => setCurrentTime(audio.currentTime);
    const handlePlay = () => setIsPlaying(true);
    const handlePause = () => setIsPlaying(false);
    const handleEnded = () => {
      setIsPlaying(false);
      setCurrentTime(0);
    };
    const handleError = () => {
      setError(true);
      setIsLoading(false);
    };

    audio.addEventListener("loadedmetadata", handleLoadedMetadata);
    audio.addEventListener("canplay", handleCanPlay);
    audio.addEventListener("timeupdate", handleTimeUpdate);
    audio.addEventListener("play", handlePlay);
    audio.addEventListener("pause", handlePause);
    audio.addEventListener("ended", handleEnded);
    audio.addEventListener("error", handleError);
    audio.load();

    return () => {
      audio.pause();
      audio.removeEventListener("loadedmetadata", handleLoadedMetadata);
      audio.removeEventListener("canplay", handleCanPlay);
      audio.removeEventListener("timeupdate", handleTimeUpdate);
      audio.removeEventListener("play", handlePlay);
      audio.removeEventListener("pause", handlePause);
      audio.removeEventListener("ended", handleEnded);
      audio.removeEventListener("error", handleError);
    };
  }, [audioUrl]);

  if (error) {
    return (
      <div className={cn(
        "flex items-center gap-2 px-3 py-2 rounded-2xl text-sm",
        isMine
          ? "bg-primary/80 text-primary-foreground"
          : "bg-muted text-foreground",
        className
      )}>
        <audio src={audioUrl} controls preload="metadata" crossOrigin="anonymous" className="h-8 max-w-[200px]" />
      </div>
    );
  }

  return (
    <div className={cn(
      "flex items-center gap-2 px-3 py-2 rounded-2xl min-w-[200px] max-w-[280px]",
      isMine 
        ? "bg-primary text-primary-foreground rounded-br-md" 
        : "bg-muted text-foreground rounded-bl-md",
      className
    )}>
      <audio ref={audioRef} src={audioUrl} preload="metadata" crossOrigin="anonymous" />
      
      {/* Play/Pause button */}
      <Button
        type="button"
        size="icon"
        variant="ghost"
        className={cn(
          "rounded-full w-8 h-8 shrink-0",
          isMine 
            ? "hover:bg-primary-foreground/20" 
            : "hover:bg-foreground/10"
        )}
        onClick={togglePlay}
        disabled={isLoading}
      >
        {isLoading ? (
          <Loader2 className="w-4 h-4 animate-spin" />
        ) : isPlaying ? (
          <Pause className="w-4 h-4" />
        ) : (
          <Play className="w-4 h-4 ml-0.5" />
        )}
      </Button>

      {/* Progress bar and time */}
      <div className="flex-1 flex flex-col gap-1">
        {/* Progress bar */}
        <div 
          className={cn(
            "h-1.5 rounded-full cursor-pointer relative overflow-hidden",
            isMine ? "bg-primary-foreground/30" : "bg-foreground/20"
          )}
          onClick={handleSeek}
        >
          <div 
            className={cn(
              "absolute inset-y-0 left-0 rounded-full transition-all",
              isMine ? "bg-primary-foreground" : "bg-primary"
            )}
            style={{ width: `${progress}%` }}
          />
        </div>
        
        {/* Time display */}
        <div className="flex justify-between text-xs opacity-75">
          <span>{formatTime(currentTime)}</span>
          <span>{formatTime(duration)}</span>
        </div>
      </div>
    </div>
  );
};

export default VoiceMessagePlayer;
