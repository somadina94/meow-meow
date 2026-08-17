import AdminNav from "@/components/AdminNav";
import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { useState, useEffect, useMemo, useRef, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";

import { AdminUserSearchDialog } from "@/components/AdminUserSearchDialog";
import { AdminServiceRolesDialog } from "@/components/AdminServiceRolesDialog";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel,
  DropdownMenuSeparator, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  ArrowLeft, Users, Search, MoreHorizontal, Edit, Trash2, UserCheck, UserX,
  Shield, RefreshCw, Filter, ChevronLeft, ChevronRight, ShieldCheck, ShieldAlert,
  Ban, CheckCircle, XCircle, Clock, Pause, Play, Settings, Languages, Bot, Zap,
  Heart, HeartOff, UserPlus, UserMinus, FileText, MessageSquare, Send, Megaphone,
  Eye, ExternalLink, Home, Loader2, AlertTriangle, MinusCircle, TimerOff, Crown,
} from "lucide-react";
import { Textarea } from "@/components/ui/textarea";
import { Slider } from "@/components/ui/slider";
import { format } from "date-fns";
import { cn } from "@/lib/utils";
import { useMultipleRealtimeSubscriptions } from "@/hooks/useRealtimeSubscription";

interface UserProfile {
  id: string;
  user_id: string;
  full_name: string | null;
  email: string | null;
  gender: string | null;
  country: string | null;
  state: string | null;
  verification_status: boolean | null;
  photo_url: string | null;
  created_at: string;
  updated_at: string;
  primary_language: string | null;
  performance_score: number;
  ai_approved: boolean;
  ai_disapproval_reason: string | null;
  account_status: string;
  approval_status: string;
  is_language_leader?: boolean | null;
}

interface UserRole {
  user_id: string;
  role: string;
}

interface LanguageGroup {
  id: string;
  name: string;
  languages: string[];
  max_women_users: number;
  current_women_count: number;
  is_active: boolean;
}

interface WomenKYC {
  id: string;
  user_id: string;
  full_name_as_per_bank: string;
  date_of_birth: string;
  gender: string | null;
  country_of_residence: string;
  aadhaar_number: string | null;
  aadhaar_front_url: string | null;
  aadhaar_back_url: string | null;
  id_type: string;
  id_number: string;
  id_proof_front_url: string | null;
  id_proof_back_url: string | null;
  document_front_url: string | null;
  document_back_url: string | null;
  selfie_url: string | null;
  bank_name: string;
  account_holder_name: string;
  account_number: string;
  ifsc_code: string;
  verification_status: string;
  rejection_reason: string | null;
  verified_at: string | null;
  created_at: string;
  updated_at: string;
}

const PAGE_SIZE_OPTIONS = [25, 50, 100, 200];
const PROTECTED_ADMIN_EMAILS = Array.from({ length: 15 }, (_, i) => `admin${i + 1}@meow-meow.com`);

const AdminUserManagement = () => {
  const navigate = useNavigate();
  
  const [loading, setLoading] = useState(true);
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [userRoles, setUserRoles] = useState<Record<string, string>>({});
  const [totalCount, setTotalCount] = useState(0);
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize, setPageSize] = useState(50);
  const [searchInput, setSearchInput] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [genderFilter, setGenderFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("all");
  const [accountStatusFilter, setAccountStatusFilter] = useState("all");
  const [approvalFilter, setApprovalFilter] = useState("all");
  const [refreshing, setRefreshing] = useState(false);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<UserProfile | null>(null);
  const [editForm, setEditForm] = useState({
    full_name: "",
    gender: "",
    country: "",
    verification_status: false,
  });
  
  // Language group management
  const [languageGroups, setLanguageGroups] = useState<LanguageGroup[]>([]);
  const [languageGroupDialogOpen, setLanguageGroupDialogOpen] = useState(false);
  const [selectedLanguageGroup, setSelectedLanguageGroup] = useState<LanguageGroup | null>(null);
  const [maxWomenInput, setMaxWomenInput] = useState("");

  // Stats
  const [stats, setStats] = useState({
    totalUsers: 0, activeUsers: 0, blockedUsers: 0, suspendedUsers: 0,
    pendingApproval: 0, approvedWomen: 0, aiApprovedWomen: 0,
  });
  
  const [runningAI, setRunningAI] = useState(false);

  // Create User dialog
  const [createUserDialogOpen, setCreateUserDialogOpen] = useState(false);
  const [creatingUser, setCreatingUser] = useState(false);
  const [createUserForm, setCreateUserForm] = useState({
    email: "", password: "", full_name: "", gender: "male",
    country: "India", primary_language: "English", role: "user",
  });

  // Force Free Mode dialog (women)
  const [forceFreeDialogOpen, setForceFreeDialogOpen] = useState(false);
  const [forceFreeUser, setForceFreeUser] = useState<UserProfile | null>(null);
  const [forceFreeDurationMinutes, setForceFreeDurationMinutes] = useState(60);
  const [forcingFree, setForcingFree] = useState(false);

  // Deduct Balance dialog (men)
  const [deductDialogOpen, setDeductDialogOpen] = useState(false);
  const [deductUser, setDeductUser] = useState<UserProfile | null>(null);
  const [deductAmount, setDeductAmount] = useState("");
  const [deductReason, setDeductReason] = useState("");
  const [deducting, setDeducting] = useState(false);
  const [deductUserBalance, setDeductUserBalance] = useState<number | null>(null);

  // Service Roles dialog
  const [serviceRolesDialogOpen, setServiceRolesDialogOpen] = useState(false);
  const [serviceRolesUser, setServiceRolesUser] = useState<UserProfile | null>(null);

  // KYC Viewer
  const [kycDialogOpen, setKycDialogOpen] = useState(false);
  const [kycData, setKycData] = useState<WomenKYC | null>(null);
  const [kycLoading, setKycLoading] = useState(false);
  const [kycUser, setKycUser] = useState<UserProfile | null>(null);

  // Admin Chat / Broadcast
  const [chatDialogOpen, setChatDialogOpen] = useState(false);
  const [chatTargetUser, setChatTargetUser] = useState<UserProfile | null>(null);
  const [chatSubject, setChatSubject] = useState("");
  const [chatMessage, setChatMessage] = useState("");
  const [sendingChat, setSendingChat] = useState(false);

  // Friend dialog
  const [friendDialogOpen, setFriendDialogOpen] = useState(false);
  const [friendTargetUser, setFriendTargetUser] = useState<UserProfile | null>(null);
  const [friendWithUserId, setFriendWithUserId] = useState("");

  // ─── Protected admin check by email ───
  const isProtectedAdmin = (user: UserProfile) => {
    return !!user.email && PROTECTED_ADMIN_EMAILS.includes(user.email.toLowerCase());
  };

  // ─── Create User ───
  const handleCreateUser = async () => {
    const { email, password, full_name, gender, country, primary_language, role } = createUserForm;
    if (!email.trim() || !password.trim() || !full_name.trim()) {
      toast.error("Please fill in all required fields (email, password, full name)");
      return;
    }
    if (!email.includes("@")) { toast.error("Please enter a valid email address"); return; }
    if (password.length < 6) { toast.error("Password must be at least 6 characters"); return; }

    setCreatingUser(true);
    try {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      if (sessionError || !session) throw new Error("Session expired. Please log in again.");

      const { data, error } = await supabase.functions.invoke("admin-create-user", {
        body: {
          email: email.trim().toLowerCase(), password,
          full_name: full_name.trim(), gender,
          country: country.trim() || "India",
          primary_language: primary_language.trim() || "English",
          role: role === "admin" ? "admin" : undefined,
        },
      });

      if (error) {
        let errorMessage = "Failed to create user";
        if (error && typeof error === "object") {
          const httpErr = error as any;
          if (httpErr.context?.json) {
            try { const body = await httpErr.context.json(); errorMessage = body?.error || body?.message || error.message || errorMessage; } catch { errorMessage = error.message || errorMessage; }
          } else { errorMessage = error.message || errorMessage; }
        }
        throw new Error(errorMessage);
      }

      if (!data?.success) {
        const errMsg = data?.error || data?.message || "User creation failed.";
        if (data?.code === "USER_EXISTS") {
          toast.error("User Already Exists", { description: errMsg });
        } else {
          toast.error("Creation Failed", { description: errMsg });
        }
        return;
      }

      toast.success(`User ${email} created successfully`);
      setCreateUserDialogOpen(false);
      setCreateUserForm({ email: "", password: "", full_name: "", gender: "male", country: "India", primary_language: "English", role: "user" });
      handleRefresh();
    } catch (err: any) {
      console.error("[handleCreateUser] Error:", err);
      const msg = err.message || "Failed to create user";
      if (msg.toLowerCase().includes("already") || msg.toLowerCase().includes("exists")) {
        toast.error("User Already Exists", { description: msg });
      } else {
        toast.error(msg);
      }
    } finally { setCreatingUser(false); }
  };

  // Admin access is now handled by useAdminAccess hook

  const loadStats = async () => {
    try {
      // FIX #2: Use female_profiles for women-specific counts (consistent with AdminNav)
      const [total, active, blocked, suspended, pending, approved, aiApproved] = await Promise.all([
        supabase.from("profiles").select("*", { count: "exact", head: true }),
        supabase.from("profiles").select("*", { count: "exact", head: true }).eq("account_status", "active"),
        supabase.from("profiles").select("*", { count: "exact", head: true }).eq("account_status", "blocked"),
        supabase.from("profiles").select("*", { count: "exact", head: true }).eq("account_status", "suspended"),
        supabase.from("female_profiles").select("*", { count: "exact", head: true }).eq("approval_status", "pending"),
        supabase.from("female_profiles").select("*", { count: "exact", head: true }).eq("approval_status", "approved"),
        supabase.from("female_profiles").select("*", { count: "exact", head: true }).eq("ai_approved", true),
      ]);
      setStats({
        totalUsers: total.count || 0,
        activeUsers: active.count || 0,
        blockedUsers: blocked.count || 0,
        suspendedUsers: suspended.count || 0,
        pendingApproval: pending.count || 0,
        approvedWomen: approved.count || 0,
        aiApprovedWomen: aiApproved.count || 0,
      });
    } catch (error) {
      console.error("Error loading stats:", error);
    }
  };
  
  const runAIApproval = async () => {
    setRunningAI(true);
    try {
      const { data: refreshData, error: refreshError } = await supabase.auth.refreshSession();
      const accessToken = refreshData.session?.access_token;
      if (refreshError || !accessToken) {
        toast.error("Your admin session expired. Please sign in again.");
        await supabase.auth.signOut();
        navigate("/login");
        return;
      }

      const { data, error } = await supabase.functions.invoke('ai-women-approval', {
        body: { action: 'auto_approve' },
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      if (error) throw error;
      if (data.success) {
        toast.success(`AI Approval completed: ${data.results.approved} approved, ${data.results.disapproved} disapproved, ${data.results.rotatedOut} rotated out`);
        fetchUsers(); loadStats(); loadLanguageGroups();
      } else { toast.error("AI Approval failed: " + data.error); }
    } catch (error) {
      console.error("Error running AI approval:", error);
      toast.error("Failed to run AI approval");
    } finally { setRunningAI(false); }
  };

  const loadLanguageGroups = async () => {
    try {
      const { data, error } = await supabase
        .from("language_groups").select("id, name, languages, max_women_users, current_women_count, is_active").order("name");
      if (error) throw error;
      setLanguageGroups((data || []) as LanguageGroup[]);
    } catch (error) { console.error("Error loading language groups:", error); }
  };

  const fetchUsers = async () => {
    try {
      let query = supabase.from("profiles").select("*", { count: "exact" });

      if (searchQuery) {
        query = query.or(`full_name.ilike.%${searchQuery}%,email.ilike.%${searchQuery}%,country.ilike.%${searchQuery}%,state.ilike.%${searchQuery}%,phone.ilike.%${searchQuery}%`);
      }
      if (genderFilter !== "all") query = query.eq("gender", genderFilter);
      if (statusFilter !== "all") query = query.eq("verification_status", statusFilter === "verified");
      if (accountStatusFilter !== "all") query = query.eq("account_status", accountStatusFilter);
      if (approvalFilter !== "all") query = query.eq("approval_status", approvalFilter);

      const from = (currentPage - 1) * pageSize;
      const to = from + pageSize - 1;

      const { data, count, error } = await query.order("created_at", { ascending: false }).range(from, to);
      if (error) throw error;

      setUsers((data || []) as UserProfile[]);
      setTotalCount(count || 0);

      if (data && data.length > 0) {
        const userIds = data.map(u => u.user_id);
        const { data: rolesData } = await supabase
          .from("user_roles").select("user_id, role").in("user_id", userIds);
        const rolesMap: Record<string, string> = {};
        rolesData?.forEach(r => { rolesMap[r.user_id] = r.role; });
        setUserRoles(rolesMap);
      }
    } catch (error) {
      console.error("Error fetching users:", error);
      toast.error("Failed to load users");
    } finally { setLoading(false); setRefreshing(false); }
  };

  useEffect(() => {
    loadStats();
  }, []);

  // Debounce search input → searchQuery (avoids fetch per keystroke)
  useEffect(() => {
    const t = setTimeout(() => {
      setSearchQuery(searchInput.trim());
      setCurrentPage(1);
    }, 350);
    return () => clearTimeout(t);
  }, [searchInput]);

  useEffect(() => {
    fetchUsers(); loadLanguageGroups();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentPage, pageSize, searchQuery, genderFilter, statusFilter, accountStatusFilter, approvalFilter]);

  // Debounced realtime refresh — coalesce bursts of profile/role updates
  const realtimeDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const debouncedRealtimeRefresh = useCallback(() => {
    if (realtimeDebounceRef.current) clearTimeout(realtimeDebounceRef.current);
    realtimeDebounceRef.current = setTimeout(() => {
      fetchUsers(); loadLanguageGroups(); loadStats();
    }, 1000);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useEffect(() => () => { if (realtimeDebounceRef.current) clearTimeout(realtimeDebounceRef.current); }, []);

  useMultipleRealtimeSubscriptions(
    ["profiles", "user_roles", "language_groups"],
    debouncedRealtimeRefresh,
    true
  );

  const handleRefresh = () => { setRefreshing(true); fetchUsers(); loadLanguageGroups(); loadStats(); };

  const handleEditUser = (user: UserProfile) => {
    setSelectedUser(user);
    setEditForm({ full_name: user.full_name || "", gender: user.gender || "", country: user.country || "", verification_status: user.verification_status || false });
    setEditDialogOpen(true);
  };

  const handleSaveEdit = async () => {
    if (!selectedUser) return;
    try {
      const { error } = await supabase.from("profiles").update({
        full_name: editForm.full_name, gender: editForm.gender,
        country: editForm.country, verification_status: editForm.verification_status,
        updated_at: new Date().toISOString(),
      }).eq("id", selectedUser.id);
      if (error) throw error;
      toast.success("User updated successfully");
      setEditDialogOpen(false); fetchUsers();
    } catch (error) { console.error("Error updating user:", error); toast.error("Failed to update user"); }
  };

  const handleDeleteUser = (user: UserProfile) => {
    if (isProtectedAdmin(user)) {
      toast.error("Cannot delete protected admin accounts (admin1-15@meow-meow.com).");
      return;
    }
    setSelectedUser(user); setDeleteDialogOpen(true);
  };

  const confirmDeleteUser = async () => {
    if (!selectedUser) return;
    if (isProtectedAdmin(selectedUser)) {
      toast.error("Cannot delete protected admin account");
      setDeleteDialogOpen(false); return;
    }
    try {
      const userId = selectedUser.user_id;

      // Full cleanup + auth deletion is done server-side with the service role
      const { data, error: authError } = await supabase.functions.invoke("admin-delete-user", {
        body: { user_id: userId },
      });
      if (authError) {
        const msg = (authError as any)?.message || "Failed to delete user";
        throw new Error(msg);
      }
      if (data?.cleanupErrors?.length) {
        console.warn("Some cleanup steps failed:", data.cleanupErrors);
      }

      toast.success("User fully deleted (profile + auth account)");
      setDeleteDialogOpen(false);
      fetchUsers();
      loadStats();
    } catch (error: any) {
      console.error("Error deleting user:", error);
      const msg = error?.message || "Failed to delete user";
      if (msg.toLowerCase().includes("protected admin")) {
        toast.error("Cannot delete protected admin account (admin1-15@meow-meow.com)");
      } else {
        toast.error(msg);
      }
    }
  };

  const handleToggleVerification = async (user: UserProfile) => {
    try {
      const { error } = await supabase.from("profiles").update({
        verification_status: !user.verification_status, updated_at: new Date().toISOString(),
      }).eq("id", user.id);
      if (error) throw error;
      toast.success(`User ${user.verification_status ? "unverified" : "verified"} successfully`);
      fetchUsers();
    } catch (error) { console.error("Error toggling verification:", error); toast.error("Failed to update verification status"); }
  };

  const handleSwitchGender = async (user: UserProfile) => {
    const currentGender = user.gender?.toLowerCase();
    const newGender = currentGender === "male" ? "female" : "male";
    try {
      // Update profiles table
      const { error } = await supabase.from("profiles").update({
        gender: newGender, updated_at: new Date().toISOString(),
      }).eq("id", user.id);
      if (error) throw error;

      // If switching to female, ensure female_profiles row exists and remove male_profiles
      if (newGender === "female") {
        await supabase.from("male_profiles").delete().eq("user_id", user.user_id);
        const { data: existing } = await supabase.from("female_profiles").select("id").eq("user_id", user.user_id).maybeSingle();
        if (!existing) {
          await supabase.from("female_profiles").insert({
            user_id: user.user_id, full_name: user.full_name, country: user.country,
            state: user.state, photo_url: user.photo_url, primary_language: user.primary_language,
          });
        }
      } else {
        // Switching to male
        await supabase.from("female_profiles").delete().eq("user_id", user.user_id);
        const { data: existing } = await supabase.from("male_profiles").select("id").eq("user_id", user.user_id).maybeSingle();
        if (!existing) {
          await supabase.from("male_profiles").insert({
            user_id: user.user_id, full_name: user.full_name, country: user.country,
            state: user.state, photo_url: user.photo_url, primary_language: user.primary_language,
          });
        }
      }

      // Audit log
      const { data: { session } } = await supabase.auth.getSession();
      await supabase.from("audit_logs").insert({
        admin_id: session?.user?.id || "",
        action: `Gender switched: ${currentGender} → ${newGender}`,
        action_type: "update",
        resource_type: "user", resource_id: user.user_id,
        details: `Admin switched ${user.full_name || "user"} from ${currentGender} to ${newGender}`,
      });

      toast.success(`Gender switched to ${newGender} for ${user.full_name || "user"}`);
      fetchUsers(); loadStats();
    } catch (error) {
      console.error("Error switching gender:", error);
      toast.error("Failed to switch gender");
    }
  };

  const handleChangeRole = async (userId: string, newRole: string) => {
    try {
      const { data: existingRole } = await supabase.from("user_roles").select("*").eq("user_id", userId).maybeSingle();
      if (existingRole) {
        const { error } = await supabase.from("user_roles").update({ role: newRole as any }).eq("user_id", userId);
        if (error) throw error;
      } else {
        const { error } = await supabase.from("user_roles").insert({ user_id: userId, role: newRole as any });
        if (error) throw error;
      }
      toast.success("Role updated successfully"); fetchUsers();
    } catch (error) { console.error("Error changing role:", error); toast.error("Failed to update role"); }
  };

  const handleBlockUser = async (user: UserProfile) => {
    try {
      const newStatus = user.account_status === "blocked" ? "active" : "blocked";
      const { error } = await supabase.from("profiles").update({ account_status: newStatus, updated_at: new Date().toISOString() }).eq("id", user.id);
      if (error) throw error;
      toast.success(`User ${newStatus === "blocked" ? "blocked" : "unblocked"} successfully`);
      fetchUsers(); loadStats();
    } catch (error) { console.error("Error blocking user:", error); toast.error("Failed to update block status"); }
  };

  const handleSuspendUser = async (user: UserProfile) => {
    try {
      const newStatus = user.account_status === "suspended" ? "active" : "suspended";
      const { error } = await supabase.from("profiles").update({ account_status: newStatus, updated_at: new Date().toISOString() }).eq("id", user.id);
      if (error) throw error;
      toast.success(`User ${newStatus === "suspended" ? "suspended" : "unsuspended"} successfully`);
      fetchUsers(); loadStats();
    } catch (error) { console.error("Error suspending user:", error); toast.error("Failed to update suspend status"); }
  };

  const handleApproveUser = async (user: UserProfile, approve: boolean) => {
    try {
      const newStatus = approve ? "approved" : "disapproved";
      const now = new Date().toISOString();
      // Update both profiles and female_profiles for data consistency
      const { error } = await supabase.from("profiles").update({ approval_status: newStatus, updated_at: now }).eq("id", user.id);
      if (error) throw error;
      // Also sync to female_profiles if user is female
      if (user.gender?.toLowerCase() === "female") {
        await supabase.from("female_profiles").update({ approval_status: newStatus, updated_at: now }).eq("user_id", user.user_id);
      }
      toast.success(`User ${approve ? "approved" : "disapproved"} successfully`);
      fetchUsers(); loadStats();
    } catch (error) { console.error("Error approving user:", error); toast.error("Failed to update approval status"); }
  };

  // ─── Language Leader Badge ───
  const handleToggleLanguageLeader = async (user: UserProfile) => {
    if (user.gender?.toLowerCase() !== "female") {
      toast.error("Leader badge is only for women");
      return;
    }
    const makeLeader = !user.is_language_leader;
    if (makeLeader && !user.primary_language) {
      toast.error("User has no primary language set");
      return;
    }
    if (makeLeader && user.approval_status !== "approved") {
      toast.error("User must be an approved woman first");
      return;
    }
    try {
      const { error } = await supabase.rpc("admin_toggle_language_leader" as any, {
        p_user_id: user.user_id,
        p_make_leader: makeLeader,
      });
      if (error) throw error;
      toast.success(
        makeLeader
          ? `Leader badge assigned for ${user.primary_language}`
          : `Leader badge removed`
      );
      fetchUsers();
    } catch (e: any) {
      console.error("Toggle leader error:", e);
      toast.error(e?.message || "Failed to update leader badge");
    }
  };

  // ─── Force Free Mode for Women ───
  const handleOpenForceFree = (user: UserProfile) => {
    setForceFreeUser(user);
    setForceFreeDurationMinutes(60);
    setForceFreeDialogOpen(true);
  };

  const handleConfirmForceFree = async () => {
    if (!forceFreeUser) return;
    setForcingFree(true);
    try {
      const expiresAt = new Date(Date.now() + forceFreeDurationMinutes * 60 * 1000).toISOString();
      
      // Update female_profiles to set earning ineligible temporarily
      await supabase.from("female_profiles").update({
        is_earning_eligible: false,
        updated_at: new Date().toISOString(),
      }).eq("user_id", forceFreeUser.user_id);

      // Store the force-free record in admin_settings for tracking
      const { data: { session } } = await supabase.auth.getSession();
      await supabase.from("admin_user_messages").insert({
        sender_id: session?.user?.id || forceFreeUser.user_id,
        target_user_id: forceFreeUser.user_id,
        message: `FORCE_FREE_MODE|duration=${forceFreeDurationMinutes}min|expires=${expiresAt}|max_per_user=20min`,
        sender_role: "admin",
        target_group: "individual",
      });

      // Create a notification for the woman
      await supabase.from("notifications").insert({
        user_id: forceFreeUser.user_id,
        title: "Free Mode Activated",
        message: `Admin has switched you to Free Mode for ${forceFreeDurationMinutes >= 60 ? `${Math.round(forceFreeDurationMinutes / 60)} hour(s)` : `${forceFreeDurationMinutes} minutes`}. During this time, you will attend regular users (max 20 min per user) without earning.`,
        type: "system",
      });

      // Log audit
      await supabase.from("audit_logs").insert({
        admin_id: session?.user?.id || "",
        action: `Force Free Mode: ${forceFreeDurationMinutes} min`,
        action_type: "update",
        resource_type: "user",
        resource_id: forceFreeUser.user_id,
        details: `Forced ${forceFreeUser.full_name || "user"} to free mode for ${forceFreeDurationMinutes} minutes. Expires: ${expiresAt}. Max 20 min per user.`,
      });

      toast.success(`${forceFreeUser.full_name || "User"} forced to Free Mode for ${forceFreeDurationMinutes >= 60 ? `${Math.round(forceFreeDurationMinutes / 60)} hour(s)` : `${forceFreeDurationMinutes} min`}. No earnings, 20 min/user limit.`);
      setForceFreeDialogOpen(false);
      fetchUsers();
    } catch (error) {
      console.error("Error forcing free mode:", error);
      toast.error("Failed to force free mode");
    } finally { setForcingFree(false); }
  };

  // ─── Deduct Balance from Men ───
  const handleOpenDeduct = async (user: UserProfile) => {
    setDeductUser(user);
    setDeductAmount("");
    setDeductReason("");
    setDeductUserBalance(null);
    setDeductDialogOpen(true);
    // Load current balance
    try {
      const { data } = await supabase.from("wallets").select("balance").eq("user_id", user.user_id).maybeSingle();
      const walletData = data as any;
      setDeductUserBalance(walletData?.balance ?? 0);
    } catch { setDeductUserBalance(0); }
  };

  const handleConfirmDeduct = async () => {
    if (!deductUser || !deductAmount || parseFloat(deductAmount) <= 0) {
      toast.error("Enter a valid amount to deduct"); return;
    }
    if (!deductReason.trim()) {
      toast.error("Please provide a reason for the deduction"); return;
    }
    const amount = parseFloat(deductAmount);
    if (deductUserBalance !== null && amount > deductUserBalance) {
      toast.error(`Cannot deduct more than current balance (₹${deductUserBalance.toFixed(2)})`); return;
    }

    setDeducting(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();

      // Atomic RPC: wallet update + ledger + notification + audit in one transaction
      const { data, error } = await supabase.rpc("admin_deduct_wallet" as any, {
        p_user_id: deductUser.user_id,
        p_amount: amount,
        p_reason: deductReason.trim(),
        p_admin_id: session?.user?.id || "",
      });

      if (error) throw error;

      const result = data as any;
      toast.success(`₹${amount.toFixed(2)} deducted from ${deductUser.full_name || "user"}'s wallet`);
      setDeductDialogOpen(false);
    } catch (error: any) {
      console.error("Error deducting balance:", error);
      toast.error(error.message || "Failed to deduct balance");
    } finally { setDeducting(false); }
  };

  // ─── KYC ───
  const handleViewKYC = async (user: UserProfile) => {
    setKycUser(user); setKycLoading(true); setKycDialogOpen(true);
    try {
      const { data, error } = await supabase.from("women_kyc").select("*").eq("user_id", user.user_id).maybeSingle();
      if (error) throw error;
      setKycData(data as WomenKYC | null);
    } catch (error) { console.error("Error loading KYC:", error); toast.error("Failed to load KYC details"); }
    finally { setKycLoading(false); }
  };

  // ─── Chat / Broadcast ───
  const handleOpenChat = (user?: UserProfile) => {
    setChatTargetUser(user || null); setChatSubject(""); setChatMessage(""); setChatDialogOpen(true);
  };

  const handleSendChat = async () => {
    if (!chatSubject.trim() || !chatMessage.trim()) { toast.error("Subject and message are required"); return; }
    setSendingChat(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) throw new Error("Not authenticated");
      if (chatTargetUser) {
        const { error } = await supabase.from("admin_user_messages").insert({
          admin_id: session.user.id, sender_id: session.user.id,
          target_user_id: chatTargetUser.user_id, target_group: 'direct',
          sender_role: 'admin', message: `[${chatSubject}] ${chatMessage}`,
        });
        if (error) throw error;
        toast.success(`Message sent to ${chatTargetUser.full_name || "user"}`);
      } else {
        const { error } = await supabase.from("admin_user_messages").insert({
          admin_id: session.user.id, sender_id: session.user.id,
          target_user_id: null, target_group: 'all',
          sender_role: 'admin', message: `[${chatSubject}] ${chatMessage}`,
        });
        if (error) throw error;
        toast.success("Broadcast message sent to all users");
      }
      setChatDialogOpen(false);
    } catch (error) { console.error("Error sending message:", error); toast.error("Failed to send message"); }
    finally { setSendingChat(false); }
  };

  // ─── Friend Management ───
  const handleOpenFriendDialog = (user: UserProfile) => {
    setFriendTargetUser(user); setFriendWithUserId(""); setFriendDialogOpen(true);
  };

  const handleCreateFriendship = async () => {
    if (!friendTargetUser || !friendWithUserId) return;
    try {
      const { data: existing } = await supabase.from("user_friends").select("id")
        .or(`and(user_id.eq.${friendTargetUser.user_id},friend_id.eq.${friendWithUserId}),and(user_id.eq.${friendWithUserId},friend_id.eq.${friendTargetUser.user_id})`)
        .maybeSingle();
      if (existing) { toast.error("Friendship already exists between these users"); return; }
      const { data: { session: currentSession } } = await supabase.auth.getSession();
      const { error } = await supabase.from("user_friends").insert({
        user_id: friendTargetUser.user_id, friend_id: friendWithUserId,
        status: "accepted", created_by: currentSession?.user?.id,
      });
      if (error) throw error;
      toast.success("Friendship created successfully"); setFriendDialogOpen(false);
    } catch (error) { console.error("Error creating friendship:", error); toast.error("Failed to create friendship"); }
  };


  const handleUpdateLanguageGroupLimit = async () => {
    if (!selectedLanguageGroup || !maxWomenInput) return;
    try {
      const { error } = await supabase.from("language_groups").update({ max_women_users: parseInt(maxWomenInput), updated_at: new Date().toISOString() }).eq("id", selectedLanguageGroup.id);
      if (error) throw error;
      toast.success("Language group limit updated successfully");
      setLanguageGroupDialogOpen(false); loadLanguageGroups();
    } catch (error) { console.error("Error updating language group:", error); toast.error("Failed to update language group"); }
  };

  const openLanguageGroupDialog = (group: LanguageGroup) => {
    setSelectedLanguageGroup(group); setMaxWomenInput(group.max_women_users.toString()); setLanguageGroupDialogOpen(true);
  };

  const totalPages = useMemo(() => Math.ceil(totalCount / pageSize), [totalCount, pageSize]);

  const getAccountStatusBadge = (status: string) => {
    switch (status) {
      case "active": return <Badge variant="success"><CheckCircle className="h-3 w-3 mr-1" />Active</Badge>;
      case "blocked": return <Badge variant="destructive"><Ban className="h-3 w-3 mr-1" />Blocked</Badge>;
      case "suspended": return <Badge variant="warning"><Pause className="h-3 w-3 mr-1" />Suspended</Badge>;
      default: return <Badge variant="secondary">{status}</Badge>;
    }
  };

  const getApprovalStatusBadge = (user: UserProfile) => {
    const { approval_status, gender, ai_approved, ai_disapproval_reason, performance_score } = user;
    if (gender?.toLowerCase() === "male") return <Badge variant="success"><CheckCircle className="h-3 w-3 mr-1" />Auto-Approved</Badge>;
    switch (approval_status) {
      case "approved":
        return (
          <div className="flex flex-col gap-1">
            <Badge className={ai_approved ? "bg-secondary text-secondary-foreground" : "bg-success text-success-foreground"}>
              {ai_approved ? <Bot className="h-3 w-3 mr-1" /> : <CheckCircle className="h-3 w-3 mr-1" />}
              {ai_approved ? "AI Approved" : "Approved"}
            </Badge>
            <span className="text-xs text-muted-foreground">Score: {performance_score}/100</span>
          </div>
        );
      case "disapproved":
        return (
          <div className="flex flex-col gap-1">
            <Badge variant="destructive"><XCircle className="h-3 w-3 mr-1" />Disapproved</Badge>
            {ai_disapproval_reason && <span className="text-xs text-muted-foreground truncate max-w-[120px]" title={ai_disapproval_reason}>{ai_disapproval_reason}</span>}
          </div>
        );
      case "pending": return <Badge className="bg-warning text-warning-foreground"><Clock className="h-3 w-3 mr-1" />Pending</Badge>;
      default: return <Badge variant="secondary">{approval_status}</Badge>;
    }
  };

  const getDurationLabel = (mins: number) => {
    if (mins < 60) return `${mins} minutes`;
    if (mins === 60) return "1 hour";
    if (mins < 1440) return `${(mins / 60).toFixed(1)} hours`;
    return "24 hours";
  };

  if (loading) {
    return (
      <AdminNav><div className="space-y-6 py-4">
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-16 w-full" />
        <Skeleton className="h-96 w-full" />
      </div></AdminNav>
    );
  }

  

  return (
    <AdminNav>
      <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold flex items-center gap-2">
            <Users className="h-6 w-6 text-primary" />
            User Management
          </h1>
          <p className="text-sm text-muted-foreground hidden md:block">
            Manage users, approvals, blocks, punishments, and language group limits
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="default" size="sm" onClick={() => setCreateUserDialogOpen(true)} className="gap-1">
            <UserPlus className="h-4 w-4" />
            <span className="hidden md:inline">Create User</span>
          </Button>
          <Button variant="outline" size="sm" onClick={() => handleOpenChat()} className="gap-1">
            <Megaphone className="h-4 w-4" />
            <span className="hidden md:inline">Broadcast All</span>
          </Button>
          <AdminUserSearchDialog />
          <Button variant="outline" size="icon" onClick={handleRefresh} disabled={refreshing}>
            <RefreshCw className={cn("h-4 w-4", refreshing && "animate-spin")} />
          </Button>
        </div>
      </div>

      <div className="space-y-6">
        <Tabs defaultValue="users" className="space-y-6">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="users">User Management</TabsTrigger>
            <TabsTrigger value="language-groups">Language Group Limits</TabsTrigger>
          </TabsList>

          <TabsContent value="users" className="space-y-6">
            {/* AI Approval Section */}
            <Card className="border-primary/50 bg-primary/5">
              <CardContent className="p-4">
                <div className="flex items-center justify-between flex-wrap gap-4">
                  <div className="flex items-center gap-3">
                    <Bot className="h-8 w-8 text-primary" />
                    <div>
                      <h3 className="font-semibold">AI Women Approval System</h3>
                      <p className="text-sm text-muted-foreground">
                        Auto-approves women up to 150 per language. Monitors performance and removes inactive users (30+ days).
                      </p>
                    </div>
                  </div>
                  <Button onClick={runAIApproval} disabled={runningAI}>
                    <Zap className={cn("h-4 w-4 mr-2", runningAI && "animate-pulse")} />
                    {runningAI ? "Running AI..." : "Run AI Approval"}
                  </Button>
                </div>
              </CardContent>
            </Card>

            {/* Stats */}
            <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-3">
              {[
                { label: "Total Users", value: stats.totalUsers, color: "" },
                { label: "Active", value: stats.activeUsers, color: "text-success" },
                { label: "Blocked", value: stats.blockedUsers, color: "text-destructive" },
                { label: "Suspended", value: stats.suspendedUsers, color: "text-warning" },
                { label: "Pending Approval", value: stats.pendingApproval, color: "text-primary" },
                { label: "Approved Women", value: stats.approvedWomen, color: "text-primary" },
                { label: "AI Approved", value: stats.aiApprovedWomen, color: "text-primary" },
              ].map((s) => (
                <Card key={s.label}>
                  <CardContent className="p-4">
                    <p className="text-sm text-muted-foreground">{s.label}</p>
                    <p className={cn("text-2xl font-bold", s.color)}>{s.value}</p>
                  </CardContent>
                </Card>
              ))}
            </div>

            {/* Filters */}
            <Card>
              <CardContent className="p-4">
                <div className="flex flex-col md:flex-row gap-4">
                  <div className="flex-1 relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                      placeholder="Search by name, email, phone, country, or state..."
                      value={searchInput}
                      onChange={(e) => setSearchInput(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                  <div className="flex gap-3 flex-wrap">
                    <Select value={genderFilter} onValueChange={(v) => { setGenderFilter(v); setCurrentPage(1); }}>
                      <SelectTrigger className="w-[130px]"><Filter className="h-4 w-4 mr-2" /><SelectValue placeholder="Gender" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All Genders</SelectItem>
                        <SelectItem value="male">Male</SelectItem>
                        <SelectItem value="female">Female</SelectItem>
                      </SelectContent>
                    </Select>
                    <Select value={accountStatusFilter} onValueChange={(v) => { setAccountStatusFilter(v); setCurrentPage(1); }}>
                      <SelectTrigger className="w-[140px]"><SelectValue placeholder="Account Status" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All Status</SelectItem>
                        <SelectItem value="active">Active</SelectItem>
                        <SelectItem value="blocked">Blocked</SelectItem>
                        <SelectItem value="suspended">Suspended</SelectItem>
                      </SelectContent>
                    </Select>
                    <Select value={approvalFilter} onValueChange={(v) => { setApprovalFilter(v); setCurrentPage(1); }}>
                      <SelectTrigger className="w-[140px]"><SelectValue placeholder="Approval" /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="all">All Approval</SelectItem>
                        <SelectItem value="pending">Pending</SelectItem>
                        <SelectItem value="approved">Approved</SelectItem>
                        <SelectItem value="disapproved">Disapproved</SelectItem>
                      </SelectContent>
                    </Select>
                    <Select value={String(pageSize)} onValueChange={(v) => { setPageSize(Number(v)); setCurrentPage(1); }}>
                      <SelectTrigger className="w-[110px]"><SelectValue placeholder="Per page" /></SelectTrigger>
                      <SelectContent>
                        {PAGE_SIZE_OPTIONS.map(s => <SelectItem key={s} value={String(s)}>{s} / page</SelectItem>)}
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Users Table */}
            <Card>
              <CardHeader className="pb-3">
                <CardTitle>Registered Users ({totalCount})</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="overflow-x-auto -mx-6 px-6">
                  <Table className="min-w-[900px]">
                    <TableHeader>
                      <TableRow>
                        <TableHead>User</TableHead>
                        <TableHead>Email</TableHead>
                        <TableHead>Gender</TableHead>
                        <TableHead>Location</TableHead>
                        <TableHead>Role</TableHead>
                        <TableHead>Account Status</TableHead>
                        <TableHead>Approval</TableHead>
                        <TableHead>Joined</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {users.length === 0 ? (
                        <TableRow>
                          <TableCell colSpan={9} className="text-center py-8 text-muted-foreground">No users found</TableCell>
                        </TableRow>
                      ) : (
                        users.map((user, index) => (
                          <TableRow key={user.id} className="transition-all duration-200 hover:bg-muted/50 animate-fade-in" style={{ animationDelay: `${index * 15}ms` }}>
                            <TableCell>
                              <div className="flex items-center gap-3">
                                <div className="h-10 w-10 rounded-full bg-muted overflow-hidden flex-shrink-0">
                                  {user.photo_url ? (
                                    <img src={user.photo_url} alt={user.full_name || "User"} className="h-full w-full object-cover" />
                                  ) : (
                                    <div className="h-full w-full flex items-center justify-center text-muted-foreground"><Users className="h-5 w-5" /></div>
                                  )}
                                </div>
                                <div>
                                  <p className="font-medium flex items-center gap-1.5">
                                    {user.full_name || "Unknown"}
                                    {user.is_language_leader && (
                                      <span title={`Language Leader (${user.primary_language || ""})`} className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded-full text-[10px] font-semibold bg-amber-100 text-amber-800 border border-amber-300">
                                        <Crown className="h-3 w-3" /> Leader
                                      </span>
                                    )}
                                  </p>
                                  <p className="text-xs text-muted-foreground truncate max-w-[120px]">{user.primary_language || "No language"}</p>
                                </div>
                              </div>
                            </TableCell>
                            <TableCell>
                              <p className="text-xs text-muted-foreground truncate max-w-[160px]" title={user.email || ""}>{user.email || "N/A"}</p>
                            </TableCell>
                            <TableCell>
                              <Badge variant="outline" className={cn(
                                user.gender?.toLowerCase() === "male" && "border-primary text-primary",
                                user.gender?.toLowerCase() === "female" && "border-primary text-primary"
                              )}>
                                {user.gender || "N/A"}
                              </Badge>
                            </TableCell>
                            <TableCell>
                              <div className="text-sm">
                                <p>{user.country || "N/A"}</p>
                                <p className="text-xs text-muted-foreground">{user.state}</p>
                              </div>
                            </TableCell>
                            <TableCell>
                              <Select value={userRoles[user.user_id] || "user"} onValueChange={(value) => handleChangeRole(user.user_id, value)}>
                                <SelectTrigger className="w-[110px] h-8"><SelectValue /></SelectTrigger>
                                <SelectContent>
                                  <SelectItem value="user"><span className="flex items-center gap-1"><Users className="h-3 w-3" /> User</span></SelectItem>
                                  <SelectItem value="moderator"><span className="flex items-center gap-1"><ShieldAlert className="h-3 w-3" /> Moderator</span></SelectItem>
                                  <SelectItem value="admin"><span className="flex items-center gap-1"><ShieldCheck className="h-3 w-3" /> Admin</span></SelectItem>
                                </SelectContent>
                              </Select>
                            </TableCell>
                            <TableCell>{getAccountStatusBadge(user.account_status)}</TableCell>
                            <TableCell>{getApprovalStatusBadge(user)}</TableCell>
                            <TableCell className="text-sm text-muted-foreground">{format(new Date(user.created_at), "MMM dd, yyyy")}</TableCell>
                            <TableCell className="text-right">
                              <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                  <Button variant="ghost" size="icon" className="h-8 w-8"><MoreHorizontal className="h-4 w-4" /></Button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="end" className="w-56">
                                  <DropdownMenuLabel>Actions</DropdownMenuLabel>
                                  <DropdownMenuSeparator />
                                  <DropdownMenuItem onClick={() => handleEditUser(user)}>
                                    <Edit className="h-4 w-4 mr-2" /> Edit User
                                  </DropdownMenuItem>
                                  <DropdownMenuItem onClick={() => handleToggleVerification(user)}>
                                    {user.verification_status ? <><UserX className="h-4 w-4 mr-2" /> Unverify</> : <><UserCheck className="h-4 w-4 mr-2" /> Verify</>}
                                  </DropdownMenuItem>
                                  <DropdownMenuItem onClick={() => handleSwitchGender(user)}>
                                    <RefreshCw className="h-4 w-4 mr-2" /> Switch to {user.gender?.toLowerCase() === "male" ? "Female" : "Male"}
                                  </DropdownMenuItem>
                                  <DropdownMenuSeparator />
                                  <DropdownMenuItem onClick={() => handleBlockUser(user)}>
                                    {user.account_status === "blocked" ? <><Play className="h-4 w-4 mr-2" /> Unblock</> : <><Ban className="h-4 w-4 mr-2" /> Block</>}
                                  </DropdownMenuItem>
                                  <DropdownMenuItem onClick={() => handleSuspendUser(user)}>
                                    {user.account_status === "suspended" ? <><Play className="h-4 w-4 mr-2" /> Unsuspend</> : <><Pause className="h-4 w-4 mr-2" /> Suspend</>}
                                  </DropdownMenuItem>

                                  {/* Women-specific actions */}
                                  {user.gender?.toLowerCase() === "female" && (
                                    <>
                                      <DropdownMenuSeparator />
                                      {user.approval_status !== "approved" && (
                                        <DropdownMenuItem onClick={() => handleApproveUser(user, true)}>
                                          <CheckCircle className="h-4 w-4 mr-2" /> Approve
                                        </DropdownMenuItem>
                                      )}
                                      {user.approval_status !== "disapproved" && (
                                        <DropdownMenuItem onClick={() => handleApproveUser(user, false)}>
                                          <XCircle className="h-4 w-4 mr-2" /> Disapprove
                                        </DropdownMenuItem>
                                      )}
                                      <DropdownMenuItem onClick={() => handleViewKYC(user)}>
                                        <FileText className="h-4 w-4 mr-2" /> View KYC
                                      </DropdownMenuItem>
                                      <DropdownMenuItem onClick={() => handleOpenForceFree(user)}>
                                        <TimerOff className="h-4 w-4 mr-2 text-warning" /> Force Free Mode
                                      </DropdownMenuItem>
                                      <DropdownMenuItem onClick={() => handleToggleLanguageLeader(user)}>
                                        <Crown className={cn("h-4 w-4 mr-2", user.is_language_leader ? "text-muted-foreground" : "text-amber-500")} />
                                        {user.is_language_leader
                                          ? "Remove Leader Badge"
                                          : `Assign Leader Badge${user.primary_language ? ` (${user.primary_language})` : ""}`}
                                      </DropdownMenuItem>
                                    </>
                                  )}

                                  {/* Men-specific: Deduct Balance */}
                                  {user.gender?.toLowerCase() === "male" && (
                                    <>
                                      <DropdownMenuSeparator />
                                      <DropdownMenuItem onClick={() => handleOpenDeduct(user)}>
                                        <MinusCircle className="h-4 w-4 mr-2 text-destructive" /> Deduct Balance (Punish)
                                      </DropdownMenuItem>
                                    </>
                                  )}

                                  <DropdownMenuSeparator />
                                  <DropdownMenuItem onClick={() => { setServiceRolesUser(user); setServiceRolesDialogOpen(true); }}>
                                    <Shield className="h-4 w-4 mr-2" /> Service Roles
                                  </DropdownMenuItem>
                                  <DropdownMenuItem onClick={() => handleOpenChat(user)}>
                                    <MessageSquare className="h-4 w-4 mr-2" /> Send Message
                                  </DropdownMenuItem>
                                  <DropdownMenuItem onClick={() => handleOpenFriendDialog(user)}>
                                    <UserPlus className="h-4 w-4 mr-2" /> Add Friend
                                  </DropdownMenuItem>

                                  {/* Delete - hide for protected admins */}
                                  {!isProtectedAdmin(user) && (
                                    <>
                                      <DropdownMenuSeparator />
                                      <DropdownMenuItem onClick={() => handleDeleteUser(user)} className="text-destructive focus:text-destructive">
                                        <Trash2 className="h-4 w-4 mr-2" /> Delete User
                                      </DropdownMenuItem>
                                    </>
                                  )}
                                </DropdownMenuContent>
                              </DropdownMenu>
                            </TableCell>
                          </TableRow>
                        ))
                      )}
                    </TableBody>
                  </Table>
                </div>

                {/* Pagination */}
                {totalPages > 1 && (
                  <div className="flex items-center justify-between mt-4">
                    <p className="text-sm text-muted-foreground">
                      Showing {((currentPage - 1) * pageSize) + 1} to {Math.min(currentPage * pageSize, totalCount)} of {totalCount} users
                    </p>
                    <div className="flex items-center gap-2">
                      <Button variant="outline" size="sm" onClick={() => setCurrentPage(p => Math.max(1, p - 1))} disabled={currentPage === 1}>
                        <ChevronLeft className="h-4 w-4" />
                      </Button>
                      <span className="text-sm">Page {currentPage} of {totalPages}</span>
                      <Button variant="outline" size="sm" onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))} disabled={currentPage === totalPages}>
                        <ChevronRight className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="language-groups" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2"><Languages className="h-5 w-5" /> Language Group Women Limits</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground mb-4">Set the maximum number of women users allowed per language group.</p>
                <div className="rounded-md border">
                  <Table>
                    <TableHeader>
                      <TableRow>
                        <TableHead>Language Group</TableHead>
                        <TableHead>Languages</TableHead>
                        <TableHead>Current Women</TableHead>
                        <TableHead>Max Women</TableHead>
                        <TableHead>Status</TableHead>
                        <TableHead className="text-right">Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {languageGroups.length === 0 ? (
                        <TableRow><TableCell colSpan={6} className="text-center py-8 text-muted-foreground">No language groups found</TableCell></TableRow>
                      ) : (
                        languageGroups.map((group) => (
                          <TableRow key={group.id}>
                            <TableCell className="font-medium">{group.name}</TableCell>
                            <TableCell>
                              <div className="flex flex-wrap gap-1">
                                {group.languages.slice(0, 3).map((lang, i) => <Badge key={i} variant="outline" className="text-xs">{lang}</Badge>)}
                                {group.languages.length > 3 && <Badge variant="secondary" className="text-xs">+{group.languages.length - 3} more</Badge>}
                              </div>
                            </TableCell>
                            <TableCell><span className={cn("font-medium", group.current_women_count >= group.max_women_users && "text-destructive")}>{group.current_women_count}</span></TableCell>
                            <TableCell><Badge variant="secondary">{group.max_women_users}</Badge></TableCell>
                            <TableCell>
                              {group.current_women_count >= group.max_women_users
                                ? <Badge variant="destructive">Full</Badge>
                                : <Badge className="bg-primary text-primary-foreground">Available</Badge>}
                            </TableCell>
                            <TableCell className="text-right">
                              <Button variant="outline" size="sm" onClick={() => openLanguageGroupDialog(group)}>
                                <Settings className="h-4 w-4 mr-1" /> Set Limit
                              </Button>
                            </TableCell>
                          </TableRow>
                        ))
                      )}
                    </TableBody>
                  </Table>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>

      {/* ─── Edit Dialog ─── */}
      <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit User</DialogTitle>
            <DialogDescription>Update user information</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="edit-name">Full Name</Label>
              <Input id="edit-name" value={editForm.full_name} onChange={(e) => setEditForm(prev => ({ ...prev, full_name: e.target.value }))} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-gender">Gender</Label>
              <Select value={editForm.gender} onValueChange={(value) => setEditForm(prev => ({ ...prev, gender: value }))}>
                <SelectTrigger><SelectValue placeholder="Select gender" /></SelectTrigger>
                <SelectContent><SelectItem value="male">Male</SelectItem><SelectItem value="female">Female</SelectItem></SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="edit-country">Country</Label>
              <Input id="edit-country" value={editForm.country} onChange={(e) => setEditForm(prev => ({ ...prev, country: e.target.value }))} />
            </div>
            <div className="flex items-center gap-2">
              <input type="checkbox" id="edit-verified" checked={editForm.verification_status} onChange={(e) => setEditForm(prev => ({ ...prev, verification_status: e.target.checked }))} className="h-4 w-4 rounded border-gray-300" />
              <Label htmlFor="edit-verified">Verified User</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleSaveEdit}>Save Changes</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Delete Dialog ─── */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-destructive"><AlertTriangle className="h-5 w-5" /> Delete User</DialogTitle>
            <DialogDescription>This will permanently delete the user and all their data from the database. This action cannot be undone.</DialogDescription>
          </DialogHeader>
          <div className="py-4 space-y-2">
            <p className="text-sm">User: <strong>{selectedUser?.full_name || "Unknown"}</strong></p>
            <p className="text-sm text-muted-foreground">Email: {selectedUser?.email || "N/A"}</p>
            <p className="text-xs text-destructive">All related data (wallet, transactions, chats, matches, friends, photos) will be removed.</p>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)}>Cancel</Button>
            <Button variant="destructive" onClick={confirmDeleteUser}>Delete Permanently</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Force Free Mode Dialog (Women) ─── */}
      <Dialog open={forceFreeDialogOpen} onOpenChange={setForceFreeDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><TimerOff className="h-5 w-5 text-warning" /> Force Free Mode</DialogTitle>
            <DialogDescription>
              Switch {forceFreeUser?.full_name || "this user"} to Free Mode. During this time she will not earn money, will attend regular users, and each user session will be limited to 20 minutes max.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-6 py-4">
            <div className="space-y-3">
              <Label>Duration: <strong>{getDurationLabel(forceFreeDurationMinutes)}</strong></Label>
              <div className="flex gap-2 flex-wrap">
                {[5, 15, 30, 60, 120, 360, 720, 1440].map((m) => (
                  <Button key={m} variant={forceFreeDurationMinutes === m ? "default" : "outline"} size="sm"
                    onClick={() => setForceFreeDurationMinutes(m)}>
                    {m < 60 ? `${m}m` : m === 60 ? "1h" : m < 1440 ? `${m / 60}h` : "24h"}
                  </Button>
                ))}
              </div>
            </div>
            <div className="p-3 bg-warning/10 border border-warning/30 rounded-lg space-y-1">
              <p className="text-sm font-medium text-warning flex items-center gap-1"><AlertTriangle className="h-4 w-4" /> Punishment Rules:</p>
              <ul className="text-xs text-muted-foreground space-y-1 ml-5 list-disc">
                <li>No earnings during this period</li>
                <li>Free time will NOT be deducted from her allowance</li>
                <li>Will attend regular (non-recharged) users</li>
                <li>Max 20 minutes per user during punishment</li>
                <li>User will be notified</li>
              </ul>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setForceFreeDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleConfirmForceFree} disabled={forcingFree} variant="destructive">
              {forcingFree ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <TimerOff className="h-4 w-4 mr-2" />}
              {forcingFree ? "Applying..." : "Apply Punishment"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Deduct Balance Dialog (Men) ─── */}
      <Dialog open={deductDialogOpen} onOpenChange={setDeductDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><MinusCircle className="h-5 w-5 text-destructive" /> Deduct Wallet Balance</DialogTitle>
            <DialogDescription>
              Punish {deductUser?.full_name || "this user"} by deducting rupees from their wallet balance.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {deductUserBalance !== null && (
              <div className="p-3 bg-muted rounded-lg">
                <p className="text-sm"><strong>Current Balance:</strong> ₹{deductUserBalance.toFixed(2)}</p>
              </div>
            )}
            <div className="space-y-2">
              <Label htmlFor="deduct-amount">Amount to Deduct (₹)</Label>
              <Input id="deduct-amount" type="number" min="1" step="0.01" placeholder="e.g. 50"
                value={deductAmount} onChange={(e) => setDeductAmount(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="deduct-reason">Reason for Deduction *</Label>
              <Textarea id="deduct-reason" placeholder="e.g. Inappropriate behavior, policy violation..."
                rows={3} value={deductReason} onChange={(e) => setDeductReason(e.target.value)} />
            </div>
            <div className="p-3 bg-destructive/10 border border-destructive/30 rounded-lg">
              <p className="text-xs text-muted-foreground">
                This will immediately deduct the specified amount from the user's wallet and create a ledger entry. The user will be notified. This action cannot be reversed automatically.
              </p>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeductDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleConfirmDeduct} disabled={deducting || !deductAmount || !deductReason.trim()} variant="destructive">
              {deducting ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <MinusCircle className="h-4 w-4 mr-2" />}
              {deducting ? "Deducting..." : `Deduct ₹${deductAmount || "0"}`}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Language Group Limit Dialog ─── */}
      <Dialog open={languageGroupDialogOpen} onOpenChange={setLanguageGroupDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Set Maximum Women Users</DialogTitle>
            <DialogDescription>Set the maximum number of women users allowed for {selectedLanguageGroup?.name}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="max-women">Maximum Women Users</Label>
              <Input id="max-women" type="number" min="0" value={maxWomenInput} onChange={(e) => setMaxWomenInput(e.target.value)} />
            </div>
            <div className="text-sm text-muted-foreground">Current count: {selectedLanguageGroup?.current_women_count || 0} women</div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setLanguageGroupDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleUpdateLanguageGroupLimit}>Save Limit</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Friend Dialog ─── */}
      <Dialog open={friendDialogOpen} onOpenChange={setFriendDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><Heart className="h-5 w-5 text-primary" /> Add Friend for {friendTargetUser?.full_name || "User"}</DialogTitle>
            <DialogDescription>Create a friendship between this user and another user</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="friend-user-id">Friend's User ID</Label>
              <Input id="friend-user-id" placeholder="Enter the user_id of the friend" value={friendWithUserId} onChange={(e) => setFriendWithUserId(e.target.value)} />
              <p className="text-xs text-muted-foreground">You can find the user_id in the user table. Enter the UUID of the user to friend.</p>
            </div>
            <div className="p-3 bg-muted rounded-lg">
              <p className="text-sm"><strong>Current User:</strong> {friendTargetUser?.full_name || "Unknown"}</p>
              <p className="text-xs text-muted-foreground">ID: {friendTargetUser?.user_id}</p>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setFriendDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleCreateFriendship} disabled={!friendWithUserId}><Heart className="h-4 w-4 mr-2" /> Create Friendship</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── KYC Details Dialog ─── */}
      <Dialog open={kycDialogOpen} onOpenChange={setKycDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><FileText className="h-5 w-5 text-primary" /> KYC Details - {kycUser?.full_name || "User"}</DialogTitle>
            <DialogDescription>Complete KYC verification information</DialogDescription>
          </DialogHeader>
          {kycLoading ? (
            <div className="space-y-3 py-4"><Skeleton className="h-6 w-full" /><Skeleton className="h-6 w-3/4" /><Skeleton className="h-32 w-full" /></div>
          ) : !kycData ? (
            <div className="py-8 text-center text-muted-foreground"><FileText className="h-12 w-12 mx-auto mb-3 opacity-40" /><p>No KYC data submitted yet</p></div>
          ) : (
            <div className="space-y-6 py-4">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium">Status:</span>
                <Badge variant={kycData.verification_status === 'approved' ? 'success' : kycData.verification_status === 'rejected' ? 'destructive' : 'secondary'}>{kycData.verification_status}</Badge>
                {kycData.rejection_reason && <span className="text-xs text-destructive">({kycData.rejection_reason})</span>}
              </div>
              <div>
                <h4 className="text-sm font-semibold mb-2 text-primary">Personal Information</h4>
                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div><span className="text-muted-foreground">Name (Bank):</span> <span className="font-medium">{kycData.full_name_as_per_bank}</span></div>
                  <div><span className="text-muted-foreground">DOB:</span> <span className="font-medium">{kycData.date_of_birth}</span></div>
                  <div><span className="text-muted-foreground">Gender:</span> <span className="font-medium">{kycData.gender || "N/A"}</span></div>
                  <div><span className="text-muted-foreground">Country:</span> <span className="font-medium">{kycData.country_of_residence}</span></div>
                </div>
              </div>
              <div>
                <h4 className="text-sm font-semibold mb-2 text-primary">Address Proof (Aadhaar)</h4>
                <p className="text-sm mb-2"><span className="text-muted-foreground">Aadhaar Number:</span> <span className="font-medium">{kycData.aadhaar_number || "N/A"}</span></p>
                <div className="grid grid-cols-2 gap-3">
                  {kycData.aadhaar_front_url && <div><p className="text-xs text-muted-foreground mb-1">Front</p><a href={kycData.aadhaar_front_url} target="_blank" rel="noopener noreferrer"><img src={kycData.aadhaar_front_url} alt="Aadhaar Front" className="w-full h-32 object-cover rounded border" /></a></div>}
                  {kycData.aadhaar_back_url && <div><p className="text-xs text-muted-foreground mb-1">Back</p><a href={kycData.aadhaar_back_url} target="_blank" rel="noopener noreferrer"><img src={kycData.aadhaar_back_url} alt="Aadhaar Back" className="w-full h-32 object-cover rounded border" /></a></div>}
                </div>
              </div>
              <div>
                <h4 className="text-sm font-semibold mb-2 text-primary">ID Proof ({kycData.id_type})</h4>
                <p className="text-sm mb-2"><span className="text-muted-foreground">ID Number:</span> <span className="font-medium">{kycData.id_number}</span></p>
                <div className="grid grid-cols-2 gap-3">
                  {(kycData.id_proof_front_url || kycData.document_front_url) && <div><p className="text-xs text-muted-foreground mb-1">Front</p><a href={kycData.id_proof_front_url || kycData.document_front_url || "#"} target="_blank" rel="noopener noreferrer"><img src={kycData.id_proof_front_url || kycData.document_front_url || ""} alt="ID Front" className="w-full h-32 object-cover rounded border" /></a></div>}
                  {(kycData.id_proof_back_url || kycData.document_back_url) && <div><p className="text-xs text-muted-foreground mb-1">Back</p><a href={kycData.id_proof_back_url || kycData.document_back_url || "#"} target="_blank" rel="noopener noreferrer"><img src={kycData.id_proof_back_url || kycData.document_back_url || ""} alt="ID Back" className="w-full h-32 object-cover rounded border" /></a></div>}
                </div>
              </div>
              {kycData.selfie_url && <div><h4 className="text-sm font-semibold mb-2 text-primary">Selfie</h4><a href={kycData.selfie_url} target="_blank" rel="noopener noreferrer"><img src={kycData.selfie_url} alt="Selfie" className="w-32 h-32 object-cover rounded border" /></a></div>}
              <div>
                <h4 className="text-sm font-semibold mb-2 text-primary">Bank Details</h4>
                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div><span className="text-muted-foreground">Bank:</span> <span className="font-medium">{kycData.bank_name}</span></div>
                  <div><span className="text-muted-foreground">Account Holder:</span> <span className="font-medium">{kycData.account_holder_name}</span></div>
                  <div><span className="text-muted-foreground">Account No:</span> <span className="font-medium">{kycData.account_number}</span></div>
                  <div><span className="text-muted-foreground">IFSC:</span> <span className="font-medium">{kycData.ifsc_code}</span></div>
                </div>
              </div>
              <div className="text-xs text-muted-foreground border-t pt-3">
                <p>Submitted: {format(new Date(kycData.created_at), "MMM dd, yyyy HH:mm")}</p>
                {kycData.verified_at && <p>Verified: {format(new Date(kycData.verified_at), "MMM dd, yyyy HH:mm")}</p>}
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* ─── Admin Chat / Broadcast Dialog ─── */}
      <Dialog open={chatDialogOpen} onOpenChange={setChatDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              {chatTargetUser ? <><MessageSquare className="h-5 w-5 text-primary" /> Message {chatTargetUser.full_name || "User"}</> : <><Megaphone className="h-5 w-5 text-primary" /> Broadcast to All Users</>}
            </DialogTitle>
            <DialogDescription>{chatTargetUser ? "Send a direct message to this user" : "This message will be sent to all registered users"}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="chat-subject">Subject</Label>
              <Input id="chat-subject" placeholder="Message subject..." value={chatSubject} onChange={(e) => setChatSubject(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="chat-message">Message</Label>
              <Textarea id="chat-message" placeholder="Type your message..." rows={4} value={chatMessage} onChange={(e) => setChatMessage(e.target.value)} />
            </div>
            {chatTargetUser && <div className="p-3 bg-muted rounded-lg"><p className="text-sm"><strong>To:</strong> {chatTargetUser.full_name || "Unknown"}</p><p className="text-xs text-muted-foreground">ID: {chatTargetUser.user_id}</p></div>}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setChatDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleSendChat} disabled={sendingChat || !chatSubject.trim() || !chatMessage.trim()}>
              <Send className="h-4 w-4 mr-2" />
              {sendingChat ? "Sending..." : chatTargetUser ? "Send Message" : "Broadcast"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Create User Dialog ─── */}
      <Dialog open={createUserDialogOpen} onOpenChange={setCreateUserDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2"><UserPlus className="h-5 w-5 text-primary" /> Create New User</DialogTitle>
            <DialogDescription>Create a male, female, or admin user. Photos and gender verification are not required.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label>Email *</Label>
              <Input type="email" placeholder="user@example.com" value={createUserForm.email} onChange={(e) => setCreateUserForm(f => ({ ...f, email: e.target.value }))} />
            </div>
            <div className="space-y-2">
              <Label>Password *</Label>
              <Input type="text" placeholder="Min 6 characters" value={createUserForm.password} onChange={(e) => setCreateUserForm(f => ({ ...f, password: e.target.value }))} />
            </div>
            <div className="space-y-2">
              <Label>Full Name *</Label>
              <Input placeholder="Full Name" value={createUserForm.full_name} onChange={(e) => setCreateUserForm(f => ({ ...f, full_name: e.target.value }))} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>Gender *</Label>
                <Select value={createUserForm.gender} onValueChange={(v) => setCreateUserForm(f => ({ ...f, gender: v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent><SelectItem value="male">Male</SelectItem><SelectItem value="female">Female</SelectItem></SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Role</Label>
                <Select value={createUserForm.role} onValueChange={(v) => setCreateUserForm(f => ({ ...f, role: v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent><SelectItem value="user">Regular User</SelectItem><SelectItem value="admin">Admin</SelectItem></SelectContent>
                </Select>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-2">
                <Label>Country</Label>
                <Input placeholder="India" value={createUserForm.country} onChange={(e) => setCreateUserForm(f => ({ ...f, country: e.target.value }))} />
              </div>
              <div className="space-y-2">
                <Label>Language</Label>
                <Input placeholder="English" value={createUserForm.primary_language} onChange={(e) => setCreateUserForm(f => ({ ...f, primary_language: e.target.value }))} />
              </div>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreateUserDialogOpen(false)}>Cancel</Button>
            <Button onClick={handleCreateUser} disabled={creatingUser || !createUserForm.email || !createUserForm.password || !createUserForm.full_name}>
              {creatingUser ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <UserPlus className="h-4 w-4 mr-2" />}
              {creatingUser ? "Creating..." : "Create User"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <AdminServiceRolesDialog
        open={serviceRolesDialogOpen}
        onOpenChange={setServiceRolesDialogOpen}
        userId={serviceRolesUser?.user_id ?? null}
        userName={serviceRolesUser?.full_name}
      />
    </AdminNav>
  );
};

export default AdminUserManagement;
