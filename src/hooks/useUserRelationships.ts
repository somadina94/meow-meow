/**
 * useUserRelationships Hook
 * 
 * Manages friend requests and block operations using secure database functions.
 * All validation (duplicate prevention, block checks, etc.) happens server-side.
 * 
 * Friend flow: Send Request → Accept/Reject → Unfriend
 * Block flow: Block (auto-removes friendship) → Unblock
 */

import { useState, useEffect, useCallback } from "react";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";

// --- Type Definitions ---

interface BlockedUser {
  id: string;
  blockedUserId: string;
  blockedName: string;
  blockedPhoto: string | null;
  blockedAt: string;
}

interface Friend {
  id: string;
  friendId: string;
  friendName: string;
  friendPhoto: string | null;
  age: number | null;
  country: string | null;
  primaryLanguage: string | null;
  status: string;
  isOnline: boolean;
  addedAt: string;
}

interface FriendRequest {
  id: string;
  fromUserId: string;
  fromUserName: string;
  fromUserPhoto: string | null;
  age: number | null;
  country: string | null;
  requestedAt: string;
}

interface SentRequest {
  id: string;
  toUserId: string;
  toUserName: string;
  toUserPhoto: string | null;
  sentAt: string;
}

// --- Hook ---

export const useUserRelationships = (userId: string | null) => {
  const { toast } = useToast();
  const [blockedUsers, setBlockedUsers] = useState<BlockedUser[]>([]);
  const [friends, setFriends] = useState<Friend[]>([]);
  const [pendingRequests, setPendingRequests] = useState<FriendRequest[]>([]);
  const [sentRequests, setSentRequests] = useState<SentRequest[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  // --- Data Loading ---

  const loadRelationships = useCallback(async () => {
    if (!userId) return;
    setIsLoading(true);

    try {
      // Load all data in parallel for performance
      const [blocksResult, friendsResult, pendingResult, sentResult] = await Promise.all([
        // 1. Blocked users
        supabase
          .from("user_blocks")
          .select("id, blocked_user_id, created_at")
          .eq("blocked_by", userId),

        // 2. Accepted friends
        supabase
          .from("user_friends")
          .select("id, user_id, friend_id, status, created_at")
          .or(`user_id.eq.${userId},friend_id.eq.${userId}`)
          .eq("status", "accepted"),

        // 3. Pending requests received (where I am the friend_id)
        supabase
          .from("user_friends")
          .select("id, user_id, created_at")
          .eq("friend_id", userId)
          .eq("status", "pending"),

        // 4. Pending requests I sent (where I am the user_id)
        supabase
          .from("user_friends")
          .select("id, friend_id, created_at")
          .eq("user_id", userId)
          .eq("status", "pending"),
      ]);

      // Collect all user IDs we need profiles for
      const allUserIds = new Set<string>();

      blocksResult.data?.forEach(b => allUserIds.add(b.blocked_user_id));
      friendsResult.data?.forEach(f => {
        allUserIds.add(f.user_id === userId ? f.friend_id : f.user_id);
      });
      pendingResult.data?.forEach(p => allUserIds.add(p.user_id));
      sentResult.data?.forEach(s => allUserIds.add(s.friend_id));

      // Fetch all profiles and online statuses in one go
      const userIdArray = Array.from(allUserIds);

      // Type for profile data
      type ProfileData = { user_id: string; full_name: string | null; photo_url: string | null; age: number | null; country: string | null; primary_language: string | null };
      type StatusData = { user_id: string; is_online: boolean };

      let profileMap = new Map<string, ProfileData>();
      let onlineMap = new Map<string, boolean>();

      if (userIdArray.length > 0) {
        const { fetchPublicProfiles } = await import("@/lib/profile-queries");
        const [profilesData, statusResult] = await Promise.all([
          fetchPublicProfiles(userIdArray),
          supabase
            .from("user_status")
            .select("user_id, is_online")
            .in("user_id", userIdArray),
        ]);

        profileMap = new Map(
          (profilesData as ProfileData[] || []).map(p => [p.user_id, p] as const)
        );
        onlineMap = new Map(
          (statusResult.data as StatusData[] || []).map(s => [s.user_id, s.is_online] as const)
        );
      }

      // --- Build blocked users list ---
      setBlockedUsers(
        (blocksResult.data || []).map(b => {
          const p = profileMap.get(b.blocked_user_id);
          return {
            id: b.id,
            blockedUserId: b.blocked_user_id,
            blockedName: p?.full_name || "Unknown",
            blockedPhoto: p?.photo_url || null,
            blockedAt: b.created_at,
          };
        })
      );

      // --- Build friends list ---
      setFriends(
        (friendsResult.data || []).map(f => {
          const friendId = f.user_id === userId ? f.friend_id : f.user_id;
          const p = profileMap.get(friendId);
          return {
            id: f.id,
            friendId,
            friendName: p?.full_name || "Unknown",
            friendPhoto: p?.photo_url || null,
            age: p?.age ?? null,
            country: p?.country ?? null,
            primaryLanguage: p?.primary_language ?? null,
            status: f.status,
            isOnline: onlineMap.get(friendId) ?? false,
            addedAt: f.created_at,
          };
        })
      );

      // --- Build pending requests (received) ---
      setPendingRequests(
        (pendingResult.data || []).map(r => {
          const p = profileMap.get(r.user_id);
          return {
            id: r.id,
            fromUserId: r.user_id,
            fromUserName: p?.full_name || "Unknown",
            fromUserPhoto: p?.photo_url || null,
            age: p?.age ?? null,
            country: p?.country ?? null,
            requestedAt: r.created_at,
          };
        })
      );

      // --- Build sent requests ---
      setSentRequests(
        (sentResult.data || []).map(s => {
          const p = profileMap.get(s.friend_id);
          return {
            id: s.id,
            toUserId: s.friend_id,
            toUserName: p?.full_name || "Unknown",
            toUserPhoto: p?.photo_url || null,
            sentAt: s.created_at,
          };
        })
      );
    } catch (error) {
      console.error("Error loading relationships:", error);
      // Non-critical - relationship status (friend/blocked) defaults to unknown
    } finally {
      setIsLoading(false);
    }
  }, [userId]);

  // Load on mount and when userId changes
  useEffect(() => {
    loadRelationships();
  }, [loadRelationships]);

  // Real-time subscription for instant updates
  useEffect(() => {
    if (!userId) return;

    const channel = supabase
      .channel(`relationships-${userId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'user_blocks' }, () => loadRelationships())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'user_friends' }, () => loadRelationships())
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [userId, loadRelationships]);

  // --- Actions (all use secure RPC functions) ---

  /** Send a friend request to another user */
  const sendFriendRequest = useCallback(async (targetUserId: string): Promise<boolean> => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('send_friend_request', {
        p_target_user_id: targetUserId,
      });
      if (error) throw error;
      const result = data as unknown as { success: boolean; error?: string; message?: string };
      if (!result.success) {
        toast({ title: "Cannot Send Request", description: result.error, variant: "destructive" });
        return false;
      }
      toast({ title: "Request Sent", description: result.message });
      await loadRelationships();
      return true;
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Failed to send request", variant: "destructive" });
      return false;
    } finally {
      setActionLoading(false);
    }
  }, [toast, loadRelationships]);

  /** Accept a pending friend request */
  const acceptRequest = useCallback(async (requestId: string): Promise<boolean> => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('accept_friend_request', {
        p_request_id: requestId,
      });
      if (error) throw error;
      const result = data as unknown as { success: boolean; error?: string; message?: string };
      if (!result.success) {
        toast({ title: "Error", description: result.error, variant: "destructive" });
        return false;
      }
      toast({ title: "Friend Added!", description: result.message });
      await loadRelationships();
      return true;
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Failed to accept", variant: "destructive" });
      return false;
    } finally {
      setActionLoading(false);
    }
  }, [toast, loadRelationships]);

  /** Reject a pending friend request */
  const rejectRequest = useCallback(async (requestId: string): Promise<boolean> => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('reject_friend_request', {
        p_request_id: requestId,
      });
      if (error) throw error;
      const result = data as unknown as { success: boolean; error?: string; message?: string };
      if (!result.success) {
        toast({ title: "Error", description: result.error, variant: "destructive" });
        return false;
      }
      toast({ title: "Request Rejected", description: result.message });
      await loadRelationships();
      return true;
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Failed to reject", variant: "destructive" });
      return false;
    } finally {
      setActionLoading(false);
    }
  }, [toast, loadRelationships]);

  /** Cancel a friend request I sent */
  const cancelRequest = useCallback(async (requestId: string): Promise<boolean> => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('cancel_friend_request', {
        p_request_id: requestId,
      });
      if (error) throw error;
      const result = data as unknown as { success: boolean; error?: string; message?: string };
      if (!result.success) {
        toast({ title: "Error", description: result.error, variant: "destructive" });
        return false;
      }
      toast({ title: "Request Canceled", description: result.message });
      await loadRelationships();
      return true;
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Failed to cancel", variant: "destructive" });
      return false;
    } finally {
      setActionLoading(false);
    }
  }, [toast, loadRelationships]);

  /** Remove a friend */
  const unfriend = useCallback(async (targetUserId: string): Promise<boolean> => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('unfriend_user', {
        p_target_user_id: targetUserId,
      });
      if (error) throw error;
      const result = data as unknown as { success: boolean; error?: string; message?: string };
      if (!result.success) {
        toast({ title: "Error", description: result.error, variant: "destructive" });
        return false;
      }
      toast({ title: "Unfriended", description: result.message });
      await loadRelationships();
      return true;
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Failed to unfriend", variant: "destructive" });
      return false;
    } finally {
      setActionLoading(false);
    }
  }, [toast, loadRelationships]);

  /** Block a user (auto-removes friendship and pending requests) */
  const blockUser = useCallback(async (targetUserId: string): Promise<boolean> => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('block_user', {
        p_target_user_id: targetUserId,
      });
      if (error) throw error;
      const result = data as unknown as { success: boolean; error?: string; message?: string };
      if (!result.success) {
        toast({ title: "Error", description: result.error, variant: "destructive" });
        return false;
      }
      toast({ title: "User Blocked", description: result.message });
      await loadRelationships();
      return true;
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Failed to block", variant: "destructive" });
      return false;
    } finally {
      setActionLoading(false);
    }
  }, [toast, loadRelationships]);

  /** Unblock a user */
  const unblockUser = useCallback(async (targetUserId: string): Promise<boolean> => {
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('unblock_user', {
        p_target_user_id: targetUserId,
      });
      if (error) throw error;
      const result = data as unknown as { success: boolean; error?: string; message?: string };
      if (!result.success) {
        toast({ title: "Error", description: result.error, variant: "destructive" });
        return false;
      }
      toast({ title: "User Unblocked", description: result.message });
      await loadRelationships();
      return true;
    } catch (err: any) {
      toast({ title: "Error", description: err.message || "Failed to unblock", variant: "destructive" });
      return false;
    } finally {
      setActionLoading(false);
    }
  }, [toast, loadRelationships]);

  // --- Helper checks ---

  const isBlocked = useCallback((targetUserId: string) => {
    return blockedUsers.some(b => b.blockedUserId === targetUserId);
  }, [blockedUsers]);

  const isFriend = useCallback((targetUserId: string) => {
    return friends.some(f => f.friendId === targetUserId);
  }, [friends]);

  const hasPendingRequest = useCallback((targetUserId: string) => {
    return pendingRequests.some(r => r.fromUserId === targetUserId);
  }, [pendingRequests]);

  const hasSentRequest = useCallback((targetUserId: string) => {
    return sentRequests.some(s => s.toUserId === targetUserId);
  }, [sentRequests]);

  const getSentRequestId = useCallback((targetUserId: string) => {
    return sentRequests.find(s => s.toUserId === targetUserId)?.id || null;
  }, [sentRequests]);

  const getReceivedRequestId = useCallback((targetUserId: string) => {
    return pendingRequests.find(r => r.fromUserId === targetUserId)?.id || null;
  }, [pendingRequests]);

  return {
    // Data
    blockedUsers,
    friends,
    pendingRequests,
    sentRequests,
    isLoading,
    actionLoading,

    // Actions
    sendFriendRequest,
    acceptRequest,
    rejectRequest,
    cancelRequest,
    unfriend,
    blockUser,
    unblockUser,

    // Helpers
    isBlocked,
    isFriend,
    hasPendingRequest,
    hasSentRequest,
    getSentRequestId,
    getReceivedRequestId,
    refresh: loadRelationships,
  };
};

export default useUserRelationships;
