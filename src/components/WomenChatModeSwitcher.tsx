import { useState } from "react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { cn } from "@/lib/utils";
import { 
  IndianRupee, 
  Clock, 
  Lock, 
  Zap,
  Timer,
  AlertTriangle,
  CheckCircle2,
  ShieldOff
} from "lucide-react";
import { WomenChatMode } from "@/hooks/useWomenChatMode";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";

interface WomenChatModeSwitcherProps {
  currentMode: WomenChatMode;
  freeMinutesUsed: number;
  freeMinutesLimit: number;
  freeTimeRemaining: number;
  exclusiveFreeLockedUntil: string | null;
  canSwitchToPaid: boolean;
  canSwitchToFree: boolean;
  canSwitchToExclusiveFree: boolean;
  isLoading: boolean;
  isIndian: boolean;
  onSwitchMode: (mode: WomenChatMode) => Promise<boolean>;
  // Force free props (non-Indian only)
  isForceFreeActive?: boolean;
  forceFreeMinutesUsed?: number;
  forceFreeMinutesLimit?: number;
  forceFreeTimeRemaining?: number;
  onToggleForceFree?: () => Promise<boolean>;
}

const formatTime = (seconds: number): string => {
  const mins = Math.floor(seconds / 60);
  const hrs = Math.floor(mins / 60);
  const remainingMins = mins % 60;
  if (hrs > 0) return `${hrs}h ${remainingMins}m`;
  return `${mins}m`;
};

const WomenChatModeSwitcher = ({
  currentMode,
  freeMinutesUsed,
  freeMinutesLimit,
  freeTimeRemaining,
  exclusiveFreeLockedUntil,
  canSwitchToPaid,
  canSwitchToFree,
  canSwitchToExclusiveFree,
  isLoading,
  isIndian,
  onSwitchMode,
  isForceFreeActive = false,
  forceFreeMinutesUsed = 0,
  forceFreeMinutesLimit = 15,
  forceFreeTimeRemaining = 0,
  onToggleForceFree,
}: WomenChatModeSwitcherProps) => {
  const [confirmMode, setConfirmMode] = useState<WomenChatMode | null>(null);
  const [isSwitching, setIsSwitching] = useState(false);

  const isExclusiveLocked = exclusiveFreeLockedUntil && 
    new Date(exclusiveFreeLockedUntil) > new Date();

  const handleSwitch = async () => {
    if (!confirmMode) return;
    setIsSwitching(true);
    await onSwitchMode(confirmMode);
    setIsSwitching(false);
    setConfirmMode(null);
  };

  const getLockedTimeRemaining = (): string => {
    if (!exclusiveFreeLockedUntil) return "";
    const remaining = new Date(exclusiveFreeLockedUntil).getTime() - Date.now();
    if (remaining <= 0) return "";
    const hrs = Math.floor(remaining / 3600000);
    const mins = Math.floor((remaining % 3600000) / 60000);
    return `${hrs}h ${mins}m`;
  };

  const modes: { 
    mode: WomenChatMode; 
    label: string; 
    description: string; 
    icon: React.ReactNode;
    color: string;
    canSwitch: boolean;
  }[] = [
    {
      mode: "paid",
      label: "💰 Paid Mode",
      description: "Earn money chatting with premium men",
      icon: <IndianRupee className="h-5 w-5" />,
      color: "from-emerald-500/20 to-emerald-600/10 border-emerald-500/30",
      canSwitch: canSwitchToPaid,
    },
    {
      mode: "free",
      label: "⏱️ Free Mode",
      description: isIndian ? `1hr/day free chat with regular men (${formatTime(freeTimeRemaining)} left)` : `Unlimited free chat with regular men`,
      icon: <Clock className="h-5 w-5" />,
      color: "from-blue-500/20 to-blue-600/10 border-blue-500/30",
      canSwitch: canSwitchToFree,
    },
    {
      mode: "exclusive_free",
      label: "🔒 Exclusive Free",
      description: "Free chat with regular men (locked for 24hrs)",
      icon: <Lock className="h-5 w-5" />,
      color: "from-purple-500/20 to-purple-600/10 border-purple-500/30",
      canSwitch: canSwitchToExclusiveFree,
    },
  ];

  if (isLoading) {
    return (
      <Card className="p-4 animate-pulse">
        <div className="h-20 bg-muted rounded" />
      </Card>
    );
  }

  const forceFreeExpired = forceFreeMinutesUsed >= forceFreeMinutesLimit;

  return (
    <>
      <Card className="p-4 space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-bold text-foreground flex items-center gap-2">
            <Zap className="h-4 w-4 text-primary" />
            Chat Mode
          </h3>
          {isExclusiveLocked && (
            <Badge variant="outline" className="text-xs text-purple-600 border-purple-500/30">
              <Lock className="h-3 w-3 mr-1" />
              Locked {getLockedTimeRemaining()}
            </Badge>
          )}
        </div>

        <div className={cn("grid gap-2", isIndian ? "grid-cols-3" : "grid-cols-2")}>
          {modes.filter(m => isIndian || m.mode !== "paid").map(({ mode, label, description, color, canSwitch }) => {
            const isActive = currentMode === mode;
            return (
              <button
                key={mode}
                onClick={() => {
                  if (!isActive && canSwitch) setConfirmMode(mode);
                }}
                disabled={isActive || !canSwitch}
                className={cn(
                  "relative rounded-lg p-3 text-left transition-all border",
                  isActive 
                    ? `bg-gradient-to-br ${color} ring-2 ring-primary/50 shadow-md`
                    : canSwitch
                      ? "bg-card hover:bg-muted/50 border-border cursor-pointer"
                      : "bg-muted/30 border-border/50 opacity-50 cursor-not-allowed"
                )}
              >
                {isActive && (
                  <CheckCircle2 className="absolute top-1.5 right-1.5 h-4 w-4 text-primary" />
                )}
                <div className="text-xs font-semibold truncate">{label}</div>
                <div className="text-[10px] text-muted-foreground mt-1 line-clamp-2">
                  {description}
                </div>
              </button>
            );
          })}
        </div>

        {/* Free time progress bar */}
        {(currentMode === "free" || currentMode === "exclusive_free") && (
          <div className="space-y-1">
            <div className="flex justify-between text-[10px] text-muted-foreground">
              <span className="flex items-center gap-1">
                <Timer className="h-3 w-3" />
                {currentMode === "free" && isIndian ? "Free time used" : currentMode === "free" ? "Unlimited free mode" : "Exclusive free (no time limit)"}
              </span>
              {currentMode === "free" && isIndian && (
                <span>{freeMinutesUsed}/{freeMinutesLimit} min</span>
              )}
            </div>
            {currentMode === "free" && isIndian && (
              <div className="w-full bg-muted rounded-full h-1.5">
                <div
                  className={cn(
                    "h-1.5 rounded-full transition-all",
                    freeMinutesUsed >= freeMinutesLimit ? "bg-destructive" : "bg-blue-500"
                  )}
                  style={{ width: `${Math.min(100, (freeMinutesUsed / freeMinutesLimit) * 100)}%` }}
                />
              </div>
            )}
          </div>
        )}

        {/* Force Free Mode Toggle (non-Indian only) */}
        {!isIndian && onToggleForceFree && (
          <div className="border-t border-border pt-3 space-y-2">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <ShieldOff className="h-4 w-4 text-orange-500" />
                <div>
                  <div className="text-xs font-semibold text-foreground">Force Free Mode</div>
                  <div className="text-[10px] text-muted-foreground">
                    {forceFreeExpired 
                      ? "Daily limit reached (resets tomorrow)" 
                      : `Men not charged • ${forceFreeMinutesLimit - forceFreeMinutesUsed}m left today`
                    }
                  </div>
                </div>
              </div>
              <Switch
                checked={isForceFreeActive}
                onCheckedChange={() => onToggleForceFree()}
                disabled={forceFreeExpired && !isForceFreeActive}
              />
            </div>
            {/* Force free progress bar */}
            <div className="w-full bg-muted rounded-full h-1.5">
              <div
                className={cn(
                  "h-1.5 rounded-full transition-all",
                  forceFreeExpired ? "bg-destructive" : isForceFreeActive ? "bg-orange-500" : "bg-muted-foreground/30"
                )}
                style={{ width: `${Math.min(100, (forceFreeMinutesUsed / forceFreeMinutesLimit) * 100)}%` }}
              />
            </div>
          </div>
        )}
      </Card>

      {/* Confirmation Dialog */}
      <AlertDialog open={!!confirmMode} onOpenChange={() => setConfirmMode(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-warning" />
              Switch Chat Mode?
            </AlertDialogTitle>
            <AlertDialogDescription className="space-y-2">
              {confirmMode === "paid" && (
                <p>Switching to <strong>Paid Mode</strong> will disconnect you from regular (non-recharged) men. You&apos;ll earn money chatting with premium men.</p>
              )}
              {confirmMode === "free" && (
                <p>Switching to <strong>Free Mode</strong> gives you {isIndian ? `${freeMinutesLimit - freeMinutesUsed} minutes of` : "unlimited"} free chat with regular men. You won&apos;t earn money. You can switch back to Paid mode anytime.</p>
              )}
              {confirmMode === "exclusive_free" && (
                <p>Switching to <strong>Exclusive Free Mode</strong> locks you in for 24 hours. You can chat with regular men freely but <strong>cannot switch to Paid mode until tomorrow</strong>. No earnings in this mode.</p>
              )}
              <p className="text-sm text-muted-foreground">Active chats with incompatible users will be ended.</p>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={isSwitching}>Cancel</AlertDialogCancel>
            <AlertDialogAction onClick={handleSwitch} disabled={isSwitching}>
              {isSwitching ? "Switching..." : "Confirm Switch"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
};

export default WomenChatModeSwitcher;
