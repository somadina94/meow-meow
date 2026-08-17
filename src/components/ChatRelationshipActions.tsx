import { useState, useEffect, useCallback } from "react";
import { Button } from "@/components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  DropdownMenuSub,
  DropdownMenuSubTrigger,
  DropdownMenuSubContent,
} from "@/components/ui/dropdown-menu";
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
  MoreVertical,
  Check,
  X,
  Trash2,
  Eraser,
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";

interface ChatRelationshipActionsProps {
  currentUserId: string;
  targetUserId: string;
  targetUserName: string;
  onBlock?: () => void;
  onUnblock?: () => void;
  onCleared?: () => void;
  className?: string;
}

interface FriendshipStatus {
  isFriend: boolean;
  isPending: boolean; // I sent a request, waiting
  isRequested: boolean; // They sent me a request
  pendingRecordId: string | null;
}

type ClearMode = "for_me" | "for_everyone" | null;

export const ChatRelationshipActions = ({
  currentUserId,
  targetUserId,
  targetUserName,
  onBlock,
  onUnblock,
  onCleared,
  className,
}: ChatRelationshipActionsProps) => {
  const { toast } = useToast();
  const [isBlocked, setIsBlocked] = useState(false);
  const [friendshipStatus, setFriendshipStatus] = useState<FriendshipStatus>({
    isFriend: false,
    isPending: false,
    isRequested: false,
    pendingRecordId: null,
  });
  const [isLoading, setIsLoading] = useState(false);
  const [showBlockDialog, setShowBlockDialog] = useState(false);
  const [showUnfriendDialog, setShowUnfriendDialog] = useState(false);
  const [clearMode, setClearMode] = useState<ClearMode>(null);

  // ============= LOAD RELATIONSHIP =============
  const loadUserRelationship = useCallback(async () => {
    if (!currentUserId || !targetUserId) return;
    try {
      const { data: blockData } = await supabase
        .from("user_blocks")
        .select("id")
        .eq("blocked_by", currentUserId)
        .eq("blocked_user_id", targetUserId)
        .maybeSingle();
      setIsBlocked(!!blockData);

      const { data: friendData } = await supabase
        .from("user_friends")
        .select("id, status, user_id")
        .or(
          `and(user_id.eq.${currentUserId},friend_id.eq.${targetUserId}),and(user_id.eq.${targetUserId},friend_id.eq.${currentUserId})`
        )
        .maybeSingle();

      if (friendData) {
        setFriendshipStatus({
          isFriend: friendData.status === "accepted",
          isPending: friendData.status === "pending" && friendData.user_id === currentUserId,
          isRequested: friendData.status === "pending" && friendData.user_id === targetUserId,
          pendingRecordId: friendData.id,
        });
      } else {
        setFriendshipStatus({ isFriend: false, isPending: false, isRequested: false, pendingRecordId: null });
      }
    } catch (error) {
      console.error("Error loading user relationship:", error);
    }
  }, [currentUserId, targetUserId]);

  useEffect(() => {
    loadUserRelationship();
  }, [loadUserRelationship]);

  useEffect(() => {
    if (!currentUserId || !targetUserId) return;
    const channel = supabase
      .channel(`chat-relationship-${currentUserId}-${targetUserId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "user_blocks" }, () => loadUserRelationship())
      .on("postgres_changes", { event: "*", schema: "public", table: "user_friends" }, () => loadUserRelationship())
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [currentUserId, targetUserId, loadUserRelationship]);

  // ============= RPC HELPER =============
  const callRpc = async (
    fnName: "send_friend_request" | "accept_friend_request" | "reject_friend_request" |
            "cancel_friend_request" | "unfriend_user" | "block_user" | "unblock_user",
    params: Record<string, string>,
    successTitle: string
  ): Promise<boolean> => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase.rpc(fnName as any, params);
      if (error) throw error;
      const result = data as unknown as { success: boolean; error?: string; message?: string };
      if (!result?.success) {
        toast({ title: "Error", description: result?.error || "Action failed", variant: "destructive" });
        return false;
      }
      toast({ title: successTitle, description: result.message });
      await loadUserRelationship();
      return true;
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Action failed", variant: "destructive" });
      return false;
    } finally {
      setIsLoading(false);
    }
  };

  // ============= FRIEND ACTIONS (use secure RPCs) =============
  const handleSendFriendRequest = () =>
    callRpc("send_friend_request", { p_target_user_id: targetUserId }, "Friend Request Sent");

  const handleAcceptFriendRequest = async () => {
    if (!friendshipStatus.pendingRecordId) return;
    await callRpc("accept_friend_request", { p_request_id: friendshipStatus.pendingRecordId }, "Friend Added!");
  };

  const handleRejectFriendRequest = async () => {
    if (!friendshipStatus.pendingRecordId) return;
    await callRpc("reject_friend_request", { p_request_id: friendshipStatus.pendingRecordId }, "Request Rejected");
  };

  const handleCancelRequest = async () => {
    if (!friendshipStatus.pendingRecordId) return;
    await callRpc("cancel_friend_request", { p_request_id: friendshipStatus.pendingRecordId }, "Request Canceled");
  };

  const handleUnfriend = async () => {
    const ok = await callRpc("unfriend_user", { p_target_user_id: targetUserId }, "Unfriended");
    if (ok) setShowUnfriendDialog(false);
  };

  const handleBlock = async () => {
    const ok = await callRpc("block_user", { p_target_user_id: targetUserId }, "User Blocked");
    if (ok) {
      setShowBlockDialog(false);
      onBlock?.();
    }
  };

  const handleUnblock = async () => {
    const ok = await callRpc("unblock_user", { p_target_user_id: targetUserId }, "User Unblocked");
    if (ok) onUnblock?.();
  };

  // ============= CLEAR CHAT (delete all messages) =============
  const chatId = [currentUserId, targetUserId].sort().join("_");

  const handleClearChat = async () => {
    if (!clearMode) return;
    setIsLoading(true);
    try {
      if (clearMode === "for_everyone") {
        // Mark every message in this chat as deleted for everyone
        const { error } = await supabase
          .from("chat_messages")
          .update({
            deleted_for_everyone: true,
            deleted_for_sender: true,
            deleted_for_receiver: true,
            deleted_at: new Date().toISOString(),
          } as any)
          .eq("chat_id", chatId);
        if (error) throw error;

        toast({
          title: "Chat cleared for everyone",
          description: `All messages between you and ${targetUserName} have been deleted.`,
        });
      } else {
        // For me only: hide my sent + received copies
        const [{ error: e1 }, { error: e2 }] = await Promise.all([
          supabase
            .from("chat_messages")
            .update({ deleted_for_sender: true } as any)
            .eq("chat_id", chatId)
            .eq("sender_id", currentUserId),
          supabase
            .from("chat_messages")
            .update({ deleted_for_receiver: true } as any)
            .eq("chat_id", chatId)
            .eq("receiver_id", currentUserId),
        ]);
        if (e1) throw e1;
        if (e2) throw e2;

        toast({
          title: "Chat cleared",
          description: `All messages with ${targetUserName} have been removed from your view.`,
        });
      }
      onCleared?.();
    } catch (err: any) {
      console.error("Error clearing chat:", err);
      toast({
        title: "Error",
        description: err.message || "Failed to clear chat",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
      setClearMode(null);
    }
  };

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="ghost"
            size="icon"
            className={cn("hover:bg-muted", className)}
            disabled={isLoading}
            title="More actions"
          >
            <MoreVertical className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="min-w-[200px]">
          {/* Friendship Actions */}
          {friendshipStatus.isFriend ? (
            <DropdownMenuItem onClick={() => setShowUnfriendDialog(true)}>
              <UserMinus className="mr-2 h-4 w-4" />
              Unfriend
            </DropdownMenuItem>
          ) : friendshipStatus.isPending ? (
            <DropdownMenuItem onClick={handleCancelRequest}>
              <X className="mr-2 h-4 w-4" />
              Cancel Request
            </DropdownMenuItem>
          ) : friendshipStatus.isRequested ? (
            <>
              <DropdownMenuItem onClick={handleAcceptFriendRequest}>
                <Check className="mr-2 h-4 w-4 text-green-500" />
                Accept Request
              </DropdownMenuItem>
              <DropdownMenuItem onClick={handleRejectFriendRequest}>
                <X className="mr-2 h-4 w-4 text-red-500" />
                Reject Request
              </DropdownMenuItem>
            </>
          ) : (
            !isBlocked && (
              <DropdownMenuItem onClick={handleSendFriendRequest}>
                <UserPlus className="mr-2 h-4 w-4" />
                Add Friend
              </DropdownMenuItem>
            )
          )}

          <DropdownMenuSeparator />

          {/* Clear chat submenu (always available) */}
          <DropdownMenuSub>
            <DropdownMenuSubTrigger>
              <Eraser className="mr-2 h-4 w-4" />
              Clear chat
            </DropdownMenuSubTrigger>
            <DropdownMenuSubContent>
              <DropdownMenuItem onClick={() => setClearMode("for_me")}>
                <Trash2 className="mr-2 h-4 w-4" />
                Delete for me
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={() => setClearMode("for_everyone")}
                className="text-destructive focus:text-destructive"
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Delete for everyone
              </DropdownMenuItem>
            </DropdownMenuSubContent>
          </DropdownMenuSub>

          <DropdownMenuSeparator />

          {/* Block Actions */}
          {isBlocked ? (
            <DropdownMenuItem onClick={handleUnblock}>
              <ShieldOff className="mr-2 h-4 w-4" />
              Unblock
            </DropdownMenuItem>
          ) : (
            <DropdownMenuItem
              onClick={() => setShowBlockDialog(true)}
              className="text-destructive focus:text-destructive"
            >
              <Shield className="mr-2 h-4 w-4" />
              Block
            </DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      {/* Block Confirmation */}
      <AlertDialog open={showBlockDialog} onOpenChange={setShowBlockDialog}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Block {targetUserName}?</AlertDialogTitle>
            <AlertDialogDescription>
              This will end any active chats and video calls immediately.
              {friendshipStatus.isFriend && " Your friendship will also be removed."}{" "}
              They won't be able to message you or call you until unblocked.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleBlock}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Block
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Unfriend Confirmation */}
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
            <AlertDialogAction onClick={handleUnfriend}>Unfriend</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Clear chat confirmation */}
      <AlertDialog open={clearMode !== null} onOpenChange={(open) => !open && setClearMode(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {clearMode === "for_everyone"
                ? `Delete all messages for everyone?`
                : `Clear chat with ${targetUserName}?`}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {clearMode === "for_everyone"
                ? `Every message between you and ${targetUserName} will be permanently deleted for both sides. This cannot be undone.`
                : `All messages with ${targetUserName} will be removed from your view. ${targetUserName} will still see them.`}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleClearChat}
              className={
                clearMode === "for_everyone"
                  ? "bg-destructive text-destructive-foreground hover:bg-destructive/90"
                  : ""
              }
            >
              {clearMode === "for_everyone" ? "Delete for everyone" : "Delete for me"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
};

export default ChatRelationshipActions;
