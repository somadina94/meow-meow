import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
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
import { 
  UserPlus, 
  UserMinus, 
  ShieldOff, 
  Shield, 
  PhoneOff,
  Circle,
  LogOut
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";

interface MiniChatActionsProps {
  currentUserId: string;
  targetUserId: string;
  targetUserName: string;
  isPartnerOnline: boolean;
  onBlock?: () => void;
  onStopChat?: () => void;
  onLogOff?: () => void;
  className?: string;
}

export const MiniChatActions = ({
  currentUserId,
  targetUserId,
  targetUserName,
  isPartnerOnline,
  onBlock,
  onStopChat,
  onLogOff,
  className
}: MiniChatActionsProps) => {
  const { toast } = useToast();
  const [isBlocked, setIsBlocked] = useState(false);
  const [isFriend, setIsFriend] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [showBlockDialog, setShowBlockDialog] = useState(false);
  const [showUnfriendDialog, setShowUnfriendDialog] = useState(false);
  const [showStopDialog, setShowStopDialog] = useState(false);
  const [showLogOffDialog, setShowLogOffDialog] = useState(false);

  useEffect(() => {
    if (currentUserId && targetUserId) {
      loadUserRelationship();
    }
  }, [currentUserId, targetUserId]);

  // Subscribe to real-time changes
  useEffect(() => {
    if (!currentUserId || !targetUserId) return;

    const channel = supabase
      .channel(`mini-chat-actions-${currentUserId}-${targetUserId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'user_blocks' },
        () => loadUserRelationship()
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'user_friends' },
        () => loadUserRelationship()
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [currentUserId, targetUserId]);

  const loadUserRelationship = async () => {
    try {
      // Check if blocked
      const { data: blockData } = await supabase
        .from("user_blocks")
        .select("id")
        .eq("blocked_by", currentUserId)
        .eq("blocked_user_id", targetUserId)
        .maybeSingle();

      setIsBlocked(!!blockData);

      // Check friendship status
      const { data: friendData } = await supabase
        .from("user_friends")
        .select("id, status")
        .or(`and(user_id.eq.${currentUserId},friend_id.eq.${targetUserId}),and(user_id.eq.${targetUserId},friend_id.eq.${currentUserId})`)
        .eq("status", "accepted")
        .maybeSingle();

      setIsFriend(!!friendData);
    } catch (error) {
      console.error("Error loading user relationship:", error);
    }
  };

  const handleBlock = async () => {
    setIsLoading(true);
    try {
      await supabase
        .from("user_blocks")
        .insert({
          blocked_by: currentUserId,
          blocked_user_id: targetUserId
        });

      // Remove friendship if exists
      await supabase
        .from("user_friends")
        .delete()
        .or(`and(user_id.eq.${currentUserId},friend_id.eq.${targetUserId}),and(user_id.eq.${targetUserId},friend_id.eq.${currentUserId})`);

      // End any active chat sessions
      await supabase
        .from("active_chat_sessions")
        .update({
          status: "ended",
          ended_at: new Date().toISOString(),
          end_reason: "user_blocked"
        })
        .or(`and(man_user_id.eq.${currentUserId},woman_user_id.eq.${targetUserId}),and(man_user_id.eq.${targetUserId},woman_user_id.eq.${currentUserId})`)
        .eq("status", "active");

      // End any active video call sessions
      await supabase
        .from("video_call_sessions")
        .update({
          status: "ended",
          ended_at: new Date().toISOString(),
          end_reason: "user_blocked"
        })
        .or(`and(man_user_id.eq.${currentUserId},woman_user_id.eq.${targetUserId}),and(man_user_id.eq.${targetUserId},woman_user_id.eq.${currentUserId})`)
        .in("status", ["ringing", "active", "connecting"]);

      setIsBlocked(true);
      setIsFriend(false);
      setShowBlockDialog(false);
      
      toast({
        title: "User Blocked",
        description: `${targetUserName} has been blocked`
      });
      
      onBlock?.();
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to block user",
        variant: "destructive"
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleUnblock = async () => {
    setIsLoading(true);
    try {
      await supabase
        .from("user_blocks")
        .delete()
        .eq("blocked_by", currentUserId)
        .eq("blocked_user_id", targetUserId);

      setIsBlocked(false);
      toast({
        title: "User Unblocked",
        description: `${targetUserName} has been unblocked`
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to unblock user",
        variant: "destructive"
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddFriend = async () => {
    if (isBlocked) return;
    setIsLoading(true);
    try {
      // Check if there's already a pending request
      const { data: existing } = await supabase
        .from("user_friends")
        .select("id, status")
        .or(`and(user_id.eq.${currentUserId},friend_id.eq.${targetUserId}),and(user_id.eq.${targetUserId},friend_id.eq.${currentUserId})`)
        .maybeSingle();

      if (existing) {
        if (existing.status === "pending") {
          // Accept the existing request
          await supabase
            .from("user_friends")
            .update({ status: "accepted" })
            .eq("id", existing.id);
          
          setIsFriend(true);
          toast({
            title: "Friend Added",
            description: `You are now friends with ${targetUserName}`
          });
        }
        return;
      }

      await supabase
        .from("user_friends")
        .insert({
          user_id: currentUserId,
          friend_id: targetUserId,
          status: "accepted", // Direct add since they're already chatting
          created_by: currentUserId
        });

      setIsFriend(true);
      toast({
        title: "Friend Added",
        description: `${targetUserName} is now your friend`
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to add friend",
        variant: "destructive"
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleUnfriend = async () => {
    setIsLoading(true);
    try {
      await supabase
        .from("user_friends")
        .delete()
        .or(`and(user_id.eq.${currentUserId},friend_id.eq.${targetUserId}),and(user_id.eq.${targetUserId},friend_id.eq.${currentUserId})`);

      setIsFriend(false);
      setShowUnfriendDialog(false);
      toast({
        title: "Unfriended",
        description: `${targetUserName} has been removed from your friends`
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to unfriend user",
        variant: "destructive"
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleStopChat = async () => {
    setShowStopDialog(false);
    onStopChat?.();
  };

  const handleLogOff = async () => {
    setShowLogOffDialog(false);
    // End the chat session first
    onStopChat?.();
    // Then trigger log off
    onLogOff?.();
  };

  return (
    <TooltipProvider>
      <div className={cn("flex items-center gap-0.5", className)}>
        {/* Online/Offline Status */}
        <Tooltip>
          <TooltipTrigger asChild>
            <div className="h-5 w-5 flex items-center justify-center">
              <Circle 
                className={cn(
                  "h-2.5 w-2.5",
                  isPartnerOnline ? "fill-green-500 text-green-500" : "fill-muted-foreground text-muted-foreground"
                )} 
              />
            </div>
          </TooltipTrigger>
          <TooltipContent>
            <p>{isPartnerOnline ? "Online" : "Offline"}</p>
          </TooltipContent>
        </Tooltip>

        {/* Add Friend / Unfriend */}
        {isFriend ? (
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="h-5 w-5 hover:bg-primary/20"
                onClick={(e) => { e.stopPropagation(); setShowUnfriendDialog(true); }}
                disabled={isLoading}
              >
                <UserMinus className="h-2.5 w-2.5 text-primary" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>Unfriend</p>
            </TooltipContent>
          </Tooltip>
        ) : (
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="h-5 w-5 hover:bg-primary/20"
                onClick={(e) => { e.stopPropagation(); handleAddFriend(); }}
                disabled={isLoading || isBlocked}
              >
                <UserPlus className="h-2.5 w-2.5 text-primary" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>Add Friend</p>
            </TooltipContent>
          </Tooltip>
        )}

        {/* Block / Unblock */}
        {isBlocked ? (
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="h-5 w-5 hover:bg-primary/20"
                onClick={(e) => { e.stopPropagation(); handleUnblock(); }}
                disabled={isLoading}
              >
                <ShieldOff className="h-2.5 w-2.5 text-primary" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>Unblock</p>
            </TooltipContent>
          </Tooltip>
        ) : (
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="h-5 w-5 hover:bg-destructive/20"
                onClick={(e) => { e.stopPropagation(); setShowBlockDialog(true); }}
                disabled={isLoading}
              >
                <Shield className="h-2.5 w-2.5 text-destructive" />
              </Button>
            </TooltipTrigger>
            <TooltipContent>
              <p>Block</p>
            </TooltipContent>
          </Tooltip>
        )}

        {/* Stop Chat */}
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="h-5 w-5 hover:bg-destructive/20"
              onClick={(e) => { e.stopPropagation(); setShowStopDialog(true); }}
              disabled={isLoading}
            >
              <PhoneOff className="h-2.5 w-2.5 text-destructive" />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>End Chat</p>
          </TooltipContent>
        </Tooltip>

        {/* Log Off */}
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              variant="ghost"
              size="icon"
              className="h-5 w-5 hover:bg-primary/20"
              onClick={(e) => { e.stopPropagation(); setShowLogOffDialog(true); }}
              disabled={isLoading}
            >
              <LogOut className="h-2.5 w-2.5 text-primary" />
            </Button>
          </TooltipTrigger>
          <TooltipContent>
            <p>Log Off</p>
          </TooltipContent>
        </Tooltip>

        {/* Block Confirmation Dialog */}
        <AlertDialog open={showBlockDialog} onOpenChange={setShowBlockDialog}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Block {targetUserName}?</AlertDialogTitle>
              <AlertDialogDescription>
                This will end any active chats and video calls immediately. 
                {isFriend && " Your friendship will also be removed."}
                {" "}They won't be able to message you or call you until unblocked.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction onClick={handleBlock} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
                Block
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>

        {/* Unfriend Confirmation Dialog */}
        <AlertDialog open={showUnfriendDialog} onOpenChange={setShowUnfriendDialog}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Remove {targetUserName} from friends?</AlertDialogTitle>
              <AlertDialogDescription>
                Are you sure you want to remove {targetUserName} from your friends list?
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction onClick={handleUnfriend}>
                Unfriend
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>

        {/* Stop Chat Confirmation Dialog */}
        <AlertDialog open={showStopDialog} onOpenChange={setShowStopDialog}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>End chat with {targetUserName}?</AlertDialogTitle>
              <AlertDialogDescription>
                This will close the chat window. You can start a new chat anytime.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction onClick={handleStopChat} className="bg-destructive text-destructive-foreground hover:bg-destructive/90">
                End Chat
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>

        {/* Log Off Confirmation Dialog */}
        <AlertDialog open={showLogOffDialog} onOpenChange={setShowLogOffDialog}>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Log off from this chat session?</AlertDialogTitle>
              <AlertDialogDescription>
                This will end the chat with {targetUserName} and close this window. You will remain logged into the app.
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction onClick={handleLogOff} className="bg-primary text-primary-foreground hover:bg-primary/90">
                Log Off
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    </TooltipProvider>
  );
};

export default MiniChatActions;