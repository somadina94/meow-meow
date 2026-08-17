/**
 * FriendsBlockedPanel
 * 
 * Full-screen overlay panel for managing friends and blocked users.
 * 
 * Tabs:
 * - Friends: Accepted friends with Chat & Unfriend actions
 * - Requests: Pending incoming requests (Accept/Reject) + Sent requests (Cancel)
 * - Browse: Search opposite-sex users to Add Friend or Block
 * - Blocked: Blocked users with Unblock action
 * 
 * Men's dashboard shows women, Women's dashboard shows men.
 * All validation handled by secure DB functions (see useUserRelationships).
 */

import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Input } from "@/components/ui/input";
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
  Users, 
  ShieldOff, 
  UserMinus, 
  ArrowLeft,
  Loader2,
  UserX,
  Heart,
  MessageCircle,
  UserPlus,
  ShieldBan,
  Search,
  Check,
  X,
  Clock,
  Send,
  Eye
} from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";
import { cn } from "@/lib/utils";
import { useUserRelationships } from "@/hooks/useUserRelationships";

// --- Browse user type (loaded separately) ---
interface BrowseUser {
  userId: string;
  fullName: string;
  photoUrl: string | null;
  age: number | null;
  country: string | null;
  primaryLanguage: string | null;
  isOnline: boolean;
}

interface FriendsBlockedPanelProps {
  currentUserId: string;
  userGender: "male" | "female";
  onClose: () => void;
  onStartChat?: (targetUserId: string, targetName: string) => void;
}

export const FriendsBlockedPanel = ({
  currentUserId,
  userGender,
  onClose,
  onStartChat,
}: FriendsBlockedPanelProps) => {
  const { toast } = useToast();
  const navigate = useNavigate();

  // All relationship data and actions from the hook
  const {
    friends,
    blockedUsers,
    pendingRequests,
    sentRequests,
    isLoading,
    actionLoading,
    sendFriendRequest,
    acceptRequest,
    rejectRequest,
    cancelRequest,
    unfriend,
    blockUser,
    unblockUser,
    isFriend,
    isBlocked,
    hasSentRequest,
    hasPendingRequest,
    getSentRequestId,
    getReceivedRequestId,
  } = useUserRelationships(currentUserId);

  // Browse tab state
  const [browseUsers, setBrowseUsers] = useState<BrowseUser[]>([]);
  const [browseLoading, setBrowseLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");

  // Dialog state
  const [confirmAction, setConfirmAction] = useState<{
    type: "unfriend" | "block" | "unblock";
    userId: string;
    userName: string;
  } | null>(null);

  // Chat starting state
  const [chatStarting, setChatStarting] = useState<string | null>(null);

  // Pending request count for badge
  const pendingCount = pendingRequests.length;

  // --- Browse tab data loading ---
  const loadBrowseUsers = useCallback(async () => {
    setBrowseLoading(true);
    try {
      // Men see women, women see men
      const profileTable = userGender === "male" ? "female_profiles" : "male_profiles";

      const { data: profiles, error } = await supabase
        .from(profileTable)
        .select("user_id, full_name, photo_url, age, country, primary_language")
        .neq("user_id", currentUserId)
        .eq("account_status", "active")
        .limit(200);

      if (error) throw error;
      if (!profiles || profiles.length === 0) {
        setBrowseUsers([]);
        return;
      }

      const userIds = profiles.map(p => p.user_id);

      // Get online status
      const { data: statusData } = await supabase
        .from("user_status")
        .select("user_id, is_online")
        .in("user_id", userIds);

      const statusMap = new Map(
        statusData?.map(s => [s.user_id, s.is_online as boolean] as const) || []
      );

      const list: BrowseUser[] = profiles.map(p => ({
        userId: p.user_id,
        fullName: p.full_name || "Unknown",
        photoUrl: p.photo_url,
        age: p.age,
        country: p.country,
        primaryLanguage: p.primary_language,
        isOnline: statusMap.get(p.user_id) ?? false,
      }));

      // Online users first, then alphabetical
      list.sort((a, b) => {
        if (a.isOnline !== b.isOnline) return a.isOnline ? -1 : 1;
        return a.fullName.localeCompare(b.fullName);
      });

      setBrowseUsers(list);
    } catch (error) {
      console.error("Error loading browse users:", error);
      toast.error("Users unavailable", { description: "Unable to load users. Please refresh the page." });
    } finally {
      setBrowseLoading(false);
    }
  }, [currentUserId, userGender]);

  // --- Chat with friend ---
  const handleStartChat = async (friendId: string, friendName: string, friendOnline: boolean) => {
    if (!friendOnline) {
      toast({ title: "User Offline", description: `${friendName} is currently offline`, variant: "destructive" });
      return;
    }

    setChatStarting(friendId);
    try {
      if (onStartChat) {
        onStartChat(friendId, friendName);
        onClose();
        return;
      }

      // Use chat-manager edge function
      const { data, error } = await supabase.functions.invoke("chat-manager", {
        body: {
          action: "start_chat",
          user_id: currentUserId,
          ...(userGender === "male"
            ? { woman_user_id: friendId }
            : { man_user_id: friendId }),
        },
      });

      if (error) throw error;
      
      // Mark as self-initiated to prevent incoming chat popup
      if (data?.session_id || data?.chat_id) {
        const { markChatAsSelfInitiated } = await import("@/hooks/useIncomingChats");
        markChatAsSelfInitiated(data.session_id, data.chat_id);
      }
      
      if (data?.success) {
        onClose();
        setTimeout(() => {
          toast({ title: "💬 Chat Started", description: `Your chat with ${friendName} is now open below` });
        }, 300);
      } else {
        throw new Error(data?.error || "Failed to start chat");
      }
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Failed to start chat", variant: "destructive" });
    } finally {
      setChatStarting(null);
    }
  };

  // --- Confirm action handler ---
  const handleConfirmAction = async () => {
    if (!confirmAction) return;
    const { type, userId } = confirmAction;

    if (type === "unfriend") await unfriend(userId);
    else if (type === "block") await blockUser(userId);
    else if (type === "unblock") await unblockUser(userId);

    setConfirmAction(null);
  };

  // Filter browse users by search
  const filteredBrowse = browseUsers.filter(u =>
    !searchQuery ||
    u.fullName.toLowerCase().includes(searchQuery.toLowerCase()) ||
    u.country?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    u.primaryLanguage?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // --- Render helpers ---

  const renderEmptyState = (icon: React.ReactNode, title: string, subtitle: string) => (
    <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
      <div className="mb-3 opacity-50">{icon}</div>
      <p className="text-sm">{title}</p>
      <p className="text-xs mt-1">{subtitle}</p>
    </div>
  );

  const renderAvatar = (name: string, photo: string | null, isOnline?: boolean) => (
    <div className="relative flex-shrink-0">
      <Avatar className="h-11 w-11">
        <AvatarImage src={photo || undefined} />
        <AvatarFallback className="bg-primary/10 text-sm">{name.charAt(0)}</AvatarFallback>
      </Avatar>
      {isOnline !== undefined && (
        <div className={cn(
          "absolute bottom-0 right-0 w-3 h-3 rounded-full border-2 border-background",
          isOnline ? "bg-online" : "bg-muted-foreground"
        )} />
      )}
    </div>
  );

  // Helper to get the action button for browse users
  const renderBrowseActions = (user: BrowseUser) => {
    const blocked = isBlocked(user.userId);
    const friend = isFriend(user.userId);
    const sentReq = hasSentRequest(user.userId);
    const receivedReq = hasPendingRequest(user.userId);

    if (blocked) {
      return <Badge variant="destructive" className="text-xs">Blocked</Badge>;
    }

    if (friend) {
      return (
        <Badge variant="secondary" className="text-xs gap-1">
          <Heart className="h-3 w-3" /> Friend
        </Badge>
      );
    }

    if (sentReq) {
      const reqId = getSentRequestId(user.userId);
      return (
        <Button
          variant="outline"
          size="sm"
          className="gap-1 text-xs h-8"
          disabled={actionLoading}
          onClick={() => reqId && cancelRequest(reqId)}
        >
          <Clock className="h-3.5 w-3.5" /> Pending
        </Button>
      );
    }

    if (receivedReq) {
      const reqId = getReceivedRequestId(user.userId);
      return (
        <div className="flex gap-1">
          <Button size="sm" className="gap-1 text-xs h-8" disabled={actionLoading} onClick={() => reqId && acceptRequest(reqId)}>
            <Check className="h-3.5 w-3.5" /> Accept
          </Button>
          <Button variant="outline" size="sm" className="text-xs h-8" disabled={actionLoading} onClick={() => reqId && rejectRequest(reqId)}>
            <X className="h-3.5 w-3.5" />
          </Button>
        </div>
      );
    }

    return (
      <div className="flex gap-1">
        <Button size="sm" className="gap-1 text-xs h-8" disabled={actionLoading} onClick={() => sendFriendRequest(user.userId)}>
          <UserPlus className="h-3.5 w-3.5" /> Add
        </Button>
        <Button
          variant="outline"
          size="sm"
          className="text-xs h-8 text-destructive hover:bg-destructive/10"
          disabled={actionLoading}
          onClick={() => setConfirmAction({ type: "block", userId: user.userId, userName: user.fullName })}
        >
          <ShieldBan className="h-3.5 w-3.5" />
        </Button>
      </div>
    );
  };

  return (
    <div className="fixed inset-0 bg-background z-50 flex flex-col">
      {/* Header */}
      <div className="flex items-center gap-3 p-4 border-b bg-card">
        <Button variant="ghost" size="icon" onClick={onClose}>
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-lg font-semibold">Friends & Blocked Users</h1>
      </div>

      {/* Content */}
      <div className="flex-1 p-4 overflow-hidden">
        <Tabs
          defaultValue="friends"
          className="h-full flex flex-col"
          onValueChange={(val) => {
            if (val === "browse" && browseUsers.length === 0) loadBrowseUsers();
          }}
        >
          <TabsList className="grid w-full grid-cols-4 mb-4">
            <TabsTrigger value="friends" className="gap-1 text-xs">
              <Heart className="h-3.5 w-3.5" />
              <span className="hidden sm:inline">Friends</span> ({friends.length})
            </TabsTrigger>
            <TabsTrigger value="requests" className="gap-1 text-xs relative">
              <Send className="h-3.5 w-3.5" />
              <span className="hidden sm:inline">Requests</span>
              {pendingCount > 0 && (
                <span className="absolute -top-1 -right-1 w-4 h-4 bg-destructive text-destructive-foreground text-[10px] font-bold rounded-full flex items-center justify-center">
                  {pendingCount}
                </span>
              )}
            </TabsTrigger>
            <TabsTrigger value="browse" className="gap-1 text-xs">
              <Search className="h-3.5 w-3.5" />
              <span className="hidden sm:inline">Browse</span>
            </TabsTrigger>
            <TabsTrigger value="blocked" className="gap-1 text-xs">
              <UserX className="h-3.5 w-3.5" />
              <span className="hidden sm:inline">Blocked</span> ({blockedUsers.length})
            </TabsTrigger>
          </TabsList>

          {/* ===== FRIENDS TAB ===== */}
          <TabsContent value="friends" className="flex-1 mt-0">
            <Card className="h-full">
              <CardContent className="p-0">
                <ScrollArea className="h-[calc(100dvh-240px)] min-h-[200px]">
                  {isLoading ? (
                    <div className="flex items-center justify-center py-12">
                      <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                    </div>
                  ) : friends.length === 0 ? (
                    renderEmptyState(
                      <Users className="h-12 w-12" />,
                      "No friends yet",
                      "Go to Browse tab to find and add friends"
                    )
                  ) : (
                    <div className="divide-y">
                      {friends.map((f) => (
                        <div key={f.id} className="flex items-center justify-between p-3 hover:bg-muted/50 transition-colors">
                          <div className="flex items-center gap-3 min-w-0">
                            {renderAvatar(f.friendName, f.friendPhoto, f.isOnline)}
                            <div className="min-w-0">
                              <p className="font-medium text-sm truncate">{f.friendName}</p>
                              <div className="flex items-center gap-1.5">
                                <Badge variant="outline" className={cn("text-[10px] px-1.5 py-0", f.isOnline && "border-online/30 text-online")}>
                                  {f.isOnline ? "Online" : "Offline"}
                                </Badge>
                                {f.primaryLanguage && (
                                  <span className="text-[10px] text-muted-foreground">{f.primaryLanguage}</span>
                                )}
                              </div>
                            </div>
                          </div>
                          <div className="flex items-center gap-1.5">
                            {/* View Profile */}
                            <Button
                              variant="outline"
                              size="sm"
                              className="h-8"
                              onClick={() => navigate(`/profile/${f.friendId}`)}
                            >
                              <Eye className="h-3.5 w-3.5" />
                            </Button>
                            {/* Chat button */}
                            <Button
                              size="sm"
                              className="gap-1 text-xs h-8"
                              disabled={!f.isOnline || chatStarting === f.friendId}
                              onClick={() => handleStartChat(f.friendId, f.friendName, f.isOnline)}
                            >
                              {chatStarting === f.friendId ? (
                                <Loader2 className="h-3.5 w-3.5 animate-spin" />
                              ) : (
                                <MessageCircle className="h-3.5 w-3.5" />
                              )}
                              Chat
                            </Button>
                            {/* Unfriend */}
                            <Button
                              variant="outline"
                              size="sm"
                              className="h-8 text-destructive hover:bg-destructive/10"
                              onClick={() => setConfirmAction({ type: "unfriend", userId: f.friendId, userName: f.friendName })}
                            >
                              <UserMinus className="h-3.5 w-3.5" />
                            </Button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </ScrollArea>
              </CardContent>
            </Card>
          </TabsContent>

          {/* ===== REQUESTS TAB ===== */}
          <TabsContent value="requests" className="flex-1 mt-0">
            <Card className="h-full">
              <CardContent className="p-0">
                <ScrollArea className="h-[calc(100dvh-240px)] min-h-[200px]">
                  {isLoading ? (
                    <div className="flex items-center justify-center py-12">
                      <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                    </div>
                  ) : pendingRequests.length === 0 && sentRequests.length === 0 ? (
                    renderEmptyState(
                      <Send className="h-12 w-12" />,
                      "No pending requests",
                      "Friend requests you send or receive will appear here"
                    )
                  ) : (
                    <div>
                      {/* Incoming requests */}
                      {pendingRequests.length > 0 && (
                        <>
                          <div className="px-4 py-2 bg-muted/30">
                            <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
                              Received ({pendingRequests.length})
                            </p>
                          </div>
                          <div className="divide-y">
                            {pendingRequests.map((req) => (
                              <div key={req.id} className="flex items-center justify-between p-3 hover:bg-muted/50">
                                <div className="flex items-center gap-3 min-w-0">
                                  {renderAvatar(req.fromUserName, req.fromUserPhoto)}
                                  <div className="min-w-0">
                                    <p className="font-medium text-sm truncate">{req.fromUserName}</p>
                                    <div className="flex items-center gap-1.5">
                                      {req.age && <span className="text-[10px] text-muted-foreground">{req.age}y</span>}
                                      {req.country && <span className="text-[10px] text-muted-foreground">{req.country}</span>}
                                    </div>
                                  </div>
                                </div>
                                <div className="flex items-center gap-1.5">
                                  <Button variant="outline" size="sm" className="h-8" onClick={() => navigate(`/profile/${req.fromUserId}`)}>
                                    <Eye className="h-3.5 w-3.5" />
                                  </Button>
                                  <Button size="sm" className="gap-1 text-xs h-8" disabled={actionLoading} onClick={() => acceptRequest(req.id)}>
                                    <Check className="h-3.5 w-3.5" /> Accept
                                  </Button>
                                  <Button
                                    variant="outline"
                                    size="sm"
                                    className="h-8 text-destructive hover:bg-destructive/10"
                                    disabled={actionLoading}
                                    onClick={() => rejectRequest(req.id)}
                                  >
                                    <X className="h-3.5 w-3.5" />
                                  </Button>
                                </div>
                              </div>
                            ))}
                          </div>
                        </>
                      )}

                      {/* Sent requests */}
                      {sentRequests.length > 0 && (
                        <>
                          <div className="px-4 py-2 bg-muted/30">
                            <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
                              Sent ({sentRequests.length})
                            </p>
                          </div>
                          <div className="divide-y">
                            {sentRequests.map((req) => (
                              <div key={req.id} className="flex items-center justify-between p-3 hover:bg-muted/50">
                                <div className="flex items-center gap-3 min-w-0">
                                  {renderAvatar(req.toUserName, req.toUserPhoto)}
                                  <div className="min-w-0">
                                    <p className="font-medium text-sm truncate">{req.toUserName}</p>
                                    <Badge variant="outline" className="text-[10px] px-1.5 py-0">
                                      <Clock className="h-2.5 w-2.5 mr-1" /> Pending
                                    </Badge>
                                  </div>
                                </div>
                                <div className="flex items-center gap-1.5">
                                  <Button variant="outline" size="sm" className="h-8" onClick={() => navigate(`/profile/${req.toUserId}`)}>
                                    <Eye className="h-3.5 w-3.5" />
                                  </Button>
                                  <Button
                                    variant="outline"
                                    size="sm"
                                    className="gap-1 text-xs h-8"
                                    disabled={actionLoading}
                                    onClick={() => cancelRequest(req.id)}
                                  >
                                    <X className="h-3.5 w-3.5" /> Cancel
                                  </Button>
                                </div>
                              </div>
                            ))}
                          </div>
                        </>
                      )}
                    </div>
                  )}
                </ScrollArea>
              </CardContent>
            </Card>
          </TabsContent>

          {/* ===== BROWSE TAB ===== */}
          <TabsContent value="browse" className="flex-1 mt-0">
            <Card className="h-full">
              <CardHeader className="pb-2 pt-3 px-3">
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                  <Input
                    placeholder="Search by name, country, or language..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="pl-9 h-9"
                  />
                </div>
              </CardHeader>
              <CardContent className="p-0">
                <ScrollArea className="h-[calc(100dvh-300px)] min-h-[180px]">
                  {browseLoading ? (
                    <div className="flex items-center justify-center py-12">
                      <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                    </div>
                  ) : filteredBrowse.length === 0 ? (
                    renderEmptyState(
                      <Users className="h-12 w-12" />,
                      searchQuery ? "No users found" : "No users available",
                      searchQuery ? "Try a different search term" : "Check back later"
                    )
                  ) : (
                    <div className="divide-y">
                      {filteredBrowse.map((user) => (
                        <div key={user.userId} className="flex items-center justify-between p-3 hover:bg-muted/50 transition-colors">
                          <div className="flex items-center gap-3 flex-1 min-w-0">
                            {renderAvatar(user.fullName, user.photoUrl, user.isOnline)}
                            <div className="min-w-0">
                              <p className="font-medium text-sm truncate">{user.fullName}</p>
                              <div className="flex items-center gap-1.5 flex-wrap">
                                {user.age && <span className="text-[10px] text-muted-foreground">{user.age}y</span>}
                                {user.country && <span className="text-[10px] text-muted-foreground truncate">{user.country}</span>}
                                {user.primaryLanguage && (
                                  <Badge variant="outline" className="text-[10px] px-1.5 py-0">{user.primaryLanguage}</Badge>
                                )}
                              </div>
                            </div>
                          </div>
                          <div className="flex items-center gap-1.5 flex-shrink-0">
                            <Button variant="outline" size="sm" className="h-8" onClick={() => navigate(`/profile/${user.userId}`)}>
                              <Eye className="h-3.5 w-3.5" />
                            </Button>
                            {renderBrowseActions(user)}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </ScrollArea>
              </CardContent>
            </Card>
          </TabsContent>

          {/* ===== BLOCKED TAB ===== */}
          <TabsContent value="blocked" className="flex-1 mt-0">
            <Card className="h-full">
              <CardContent className="p-0">
                <ScrollArea className="h-[calc(100dvh-240px)] min-h-[200px]">
                  {isLoading ? (
                    <div className="flex items-center justify-center py-12">
                      <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
                    </div>
                  ) : blockedUsers.length === 0 ? (
                    renderEmptyState(
                      <ShieldOff className="h-12 w-12" />,
                      "No blocked users",
                      "Users you block will appear here"
                    )
                  ) : (
                    <div className="divide-y">
                      {blockedUsers.map((user) => (
                        <div key={user.id} className="flex items-center justify-between p-3 hover:bg-muted/50">
                          <div className="flex items-center gap-3">
                            {renderAvatar(user.blockedName, user.blockedPhoto)}
                            <div>
                              <p className="font-medium text-sm">{user.blockedName}</p>
                              <p className="text-[10px] text-muted-foreground">
                                Blocked {new Date(user.blockedAt).toLocaleDateString()}
                              </p>
                            </div>
                          </div>
                          <Button
                            variant="outline"
                            size="sm"
                            className="gap-1 text-xs h-8"
                            disabled={actionLoading}
                            onClick={() => setConfirmAction({ type: "unblock", userId: user.blockedUserId, userName: user.blockedName })}
                          >
                            <ShieldOff className="h-3.5 w-3.5" /> Unblock
                          </Button>
                        </div>
                      ))}
                    </div>
                  )}
                </ScrollArea>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>

      {/* ===== CONFIRMATION DIALOG ===== */}
      <AlertDialog open={!!confirmAction} onOpenChange={(open) => !open && setConfirmAction(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>
              {confirmAction?.type === "unfriend" && `Remove ${confirmAction.userName} from friends?`}
              {confirmAction?.type === "block" && `Block ${confirmAction?.userName}?`}
              {confirmAction?.type === "unblock" && `Unblock ${confirmAction?.userName}?`}
            </AlertDialogTitle>
            <AlertDialogDescription>
              {confirmAction?.type === "unfriend" && "You can add them back later by sending a new friend request."}
              {confirmAction?.type === "block" && "They won't be able to message, call, or send you friend requests. Any existing friendship will be removed."}
              {confirmAction?.type === "unblock" && "They will be able to send you friend requests and messages again."}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={actionLoading}>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleConfirmAction}
              disabled={actionLoading}
              className={cn(
                confirmAction?.type !== "unblock" && "bg-destructive text-destructive-foreground hover:bg-destructive/90"
              )}
            >
              {actionLoading && <Loader2 className="h-4 w-4 animate-spin mr-2" />}
              {confirmAction?.type === "unfriend" && "Unfriend"}
              {confirmAction?.type === "block" && "Block"}
              {confirmAction?.type === "unblock" && "Unblock"}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
};

export default FriendsBlockedPanel;
