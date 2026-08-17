import { useEffect, useState } from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import { MessageCircle, X, Check, Clock, Volume2 } from "lucide-react";

interface IncomingChatPopupProps {
  sessionId: string;
  chatId: string;
  partnerId: string;
  partnerName: string;
  partnerPhoto: string | null;
  partnerLanguage: string;
  ratePerMinute: number;
  startedAt: string;
  userGender: "male" | "female";
  onAccept: (sessionId: string) => void;
  onReject: (sessionId: string, reason?: 'manual' | 'auto_timeout') => void;
}

// Sound is managed globally by useIncomingChats hook - no duplicate sound here

const IncomingChatPopup = ({
  sessionId,
  partnerName,
  partnerPhoto,
  partnerLanguage,
  ratePerMinute,
  startedAt,
  userGender,
  onAccept,
  onReject
}: IncomingChatPopupProps) => {
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [isVisible, setIsVisible] = useState(true);
  const [isExiting, setIsExiting] = useState(false);

  // Calculate elapsed time since chat started
  useEffect(() => {
    const startTime = new Date(startedAt).getTime();
    
    const updateElapsed = () => {
      const elapsed = Math.floor((Date.now() - startTime) / 1000);
      setElapsedSeconds(elapsed);
    };

    updateElapsed();
    const interval = setInterval(updateElapsed, 1000);

    // Auto-reject after 60 seconds of no response
    const timeout = setTimeout(() => {
      handleAutoReject();
    }, 60000);

    return () => {
      clearInterval(interval);
      clearTimeout(timeout);
    };
  }, [startedAt]);

  const handleAccept = () => {
    onAccept(sessionId);
    setIsExiting(true);
  };

  const handleReject = () => {
    onReject(sessionId, 'manual');
    setIsExiting(true);
  };

  const handleAutoReject = () => {
    onReject(sessionId, 'auto_timeout');
    setIsExiting(true);
  };

  const formatTime = (seconds: number) => {
    const mins = Math.ceil(seconds / 60);
    return `${mins} min`;
  };

  if (!isVisible) return null;

  return (
    <Card className={cn(
      "w-72 p-4 shadow-2xl border-2 border-primary/50 bg-background",
      "animate-in slide-in-from-bottom-5 fade-in duration-300",
      "z-[9999] relative",
      isExiting && "animate-out slide-out-to-right fade-out duration-200"
    )}>
      {/* Pulsing indicator with sound icon */}
      <div className="absolute -top-1 -right-1 flex items-center gap-1">
        <span className="relative flex h-4 w-4">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75" />
          <span className="relative inline-flex rounded-full h-4 w-4 bg-primary items-center justify-center">
            <Volume2 className="h-2.5 w-2.5 text-primary-foreground" />
          </span>
        </span>
      </div>

      {/* Header */}
      <div className="flex items-center gap-3 mb-3">
        <div className="relative">
          <Avatar className="h-12 w-12 border-2 border-primary/30 animate-pulse">
            <AvatarImage src={partnerPhoto || undefined} />
            <AvatarFallback className="bg-primary/20 text-primary font-semibold">
              {partnerName.charAt(0).toUpperCase()}
            </AvatarFallback>
          </Avatar>
          <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full bg-online border-2 border-background" />
        </div>
        
        <div className="flex-1 min-w-0">
          <p className="font-semibold text-foreground truncate">{partnerName}</p>
          <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <MessageCircle className="h-3 w-3 animate-bounce" />
            <span>wants to chat with you!</span>
          </div>
        </div>
      </div>

      {/* Info badges */}
      <div className="flex flex-wrap gap-1.5 mb-3">
        <Badge variant="secondary" className="text-xs">
          {partnerLanguage}
        </Badge>
        <Badge variant="outline" className="text-xs flex items-center gap-1">
          <Clock className="h-2.5 w-2.5" />
          {formatTime(elapsedSeconds)}
        </Badge>
      </div>

      {/* Action buttons */}
      <div className="flex gap-2">
        <Button
          variant="outline"
          size="sm"
          className="flex-1 gap-1.5 hover:bg-destructive/10 hover:text-destructive hover:border-destructive"
          onClick={handleReject}
        >
          <X className="h-4 w-4" />
          Decline
        </Button>
        <Button
          size="sm"
          className="flex-1 gap-1.5 bg-primary hover:bg-primary/90 animate-pulse"
          onClick={handleAccept}
        >
          <Check className="h-4 w-4" />
          Accept
        </Button>
      </div>

      {/* Auto-close warning */}
      {elapsedSeconds > 45 && (
        <p className="text-[10px] text-center text-destructive mt-2 animate-pulse font-medium">
          ⚠️ Auto-declining in {60 - elapsedSeconds}s...
        </p>
      )}
    </Card>
  );
};

export default IncomingChatPopup;
