import AdminNav from "@/components/AdminNav";
import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { useRealtimeSubscription } from "@/hooks/useRealtimeSubscription";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import {
  ArrowLeft,
  Shield,
  RefreshCw,
  AlertTriangle,
  AlertCircle,
  CheckCircle,
  XCircle,
  MessageSquare,
  Eye,
  Ban,
  Send,
  Search,
  Filter,
  Scan,
  Home,
} from "lucide-react";
import { format } from "date-fns";
import { cn } from "@/lib/utils";

interface PolicyAlert {
  id: string;
  user_id: string;
  alert_type: string;
  violation_type: string;
  severity: string;
  content: string | null;
  source_message_id: string | null;
  source_chat_id: string | null;
  detected_by: string;
  status: string;
  reviewed_by: string | null;
  reviewed_at: string | null;
  action_taken: string | null;
  admin_notes: string | null;
  created_at: string;
}

interface UserProfile {
  id: string;
  user_id: string;
  full_name: string | null;
  gender: string | null;
  photo_url: string | null;
}

const AdminPolicyAlerts = () => {
  const navigate = useNavigate();
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  const [loading, setLoading] = useState(true);
  const [alerts, setAlerts] = useState<PolicyAlert[]>([]);
  const [userProfiles, setUserProfiles] = useState<Record<string, UserProfile>>({});
  const [refreshing, setRefreshing] = useState(false);
  const [scanning, setScanning] = useState(false);
  
  // Filters
  const [statusFilter, setStatusFilter] = useState("pending");
  const [severityFilter, setSeverityFilter] = useState("all");
  const [violationTypeFilter, setViolationTypeFilter] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  
  // Dialog state
  const [selectedAlert, setSelectedAlert] = useState<PolicyAlert | null>(null);
  const [alertDialogOpen, setAlertDialogOpen] = useState(false);
  const [messageDialogOpen, setMessageDialogOpen] = useState(false);
  const [messageContent, setMessageContent] = useState("");
  const [adminNotes, setAdminNotes] = useState("");
  const [actionTaken, setActionTaken] = useState("");

  // Stats
  const [stats, setStats] = useState({
    pending: 0,
    reviewing: 0,
    resolved: 0,
    critical: 0,
    high: 0,
  });

  // Admin access is now handled by useAdminAccess hook

  const loadStats = useCallback(async () => {
    try {
      // Use server-side count queries instead of fetching all rows
      const [pending, reviewing, resolved, critical, high] = await Promise.all([
        supabase.from("policy_violation_alerts").select("*", { count: "exact", head: true }).eq("status", "pending"),
        supabase.from("policy_violation_alerts").select("*", { count: "exact", head: true }).eq("status", "reviewing"),
        supabase.from("policy_violation_alerts").select("*", { count: "exact", head: true }).eq("status", "resolved"),
        supabase.from("policy_violation_alerts").select("*", { count: "exact", head: true }).eq("severity", "critical"),
        supabase.from("policy_violation_alerts").select("*", { count: "exact", head: true }).eq("severity", "high"),
      ]);
      setStats({
        pending: pending.count || 0,
        reviewing: reviewing.count || 0,
        resolved: resolved.count || 0,
        critical: critical.count || 0,
        high: high.count || 0,
      });
    } catch (error) {
      console.error("Error loading stats:", error);
      toast.error("Stats unavailable", { description: "Unable to load policy alert statistics. Please refresh." });
    }
  }, []);

  const loadAlerts = useCallback(async () => {
    try {
      let query = supabase
        .from("policy_violation_alerts")
        .select("*")
        .order("created_at", { ascending: false });

      if (statusFilter !== "all") {
        query = query.eq("status", statusFilter);
      }
      if (severityFilter !== "all") {
        query = query.eq("severity", severityFilter);
      }
      if (violationTypeFilter !== "all") {
        query = query.eq("violation_type", violationTypeFilter);
      }

      const { data, error } = await query.limit(100);

      if (error) throw error;

      setAlerts(data || []);

      // Load user profiles for alerts
      if (data && data.length > 0) {
        const userIds = [...new Set(data.map(a => a.user_id))];
        const { data: profiles } = await supabase
          .from("profiles")
          .select("id, user_id, full_name, gender, photo_url")
          .in("user_id", userIds);

        const profileMap: Record<string, UserProfile> = {};
        profiles?.forEach(p => {
          profileMap[p.user_id] = p;
        });
        setUserProfiles(profileMap);
      }
    } catch (error) {
      console.error("Error loading alerts:", error);
      toast.error("Failed to load alerts");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [statusFilter, severityFilter, violationTypeFilter]);

  // Real-time subscription for policy alerts
  useRealtimeSubscription({
    table: "policy_violation_alerts",
    onUpdate: () => {
      loadAlerts();
      loadStats();
    },
    enabled: isAdmin
  });

  useEffect(() => {
    if (isAdmin) {
      loadAlerts();
      loadStats();
    }
  }, [isAdmin, loadAlerts, loadStats]);

  const handleRefresh = () => {
    setRefreshing(true);
    loadAlerts();
    loadStats();
  };

  const handleScanMessages = async () => {
    setScanning(true);
    try {
      const { data: refreshData, error: refreshError } = await supabase.auth.refreshSession();
      const accessToken = refreshData.session?.access_token;
      if (refreshError || !accessToken) {
        toast.error("Your admin session expired. Please sign in again.");
        await supabase.auth.signOut();
        navigate("/login");
        return;
      }

      const { data, error } = await supabase.functions.invoke('content-moderation', {
        body: { action: "scan_recent_messages" },
        headers: { Authorization: `Bearer ${accessToken}` },
      });

      if (error) throw error;
      if (!data) throw new Error("No response from content moderation function");
      if (data.success) {
        toast.success(`Scan complete: ${data.flagged ?? 0} violations found in ${data.scanned ?? 0} messages`);
        loadAlerts();
        loadStats();
      } else {
        toast.error("Scan failed: " + (data.error || "Unknown error"));
      }
    } catch (error) {
      console.error("Error scanning messages:", error);
      toast.error("Failed to scan messages");
    } finally {
      setScanning(false);
    }
  };

  const openAlertDetails = (alert: PolicyAlert) => {
    setSelectedAlert(alert);
    setAdminNotes(alert.admin_notes || "");
    setActionTaken(alert.action_taken || "");
    setAlertDialogOpen(true);
  };

  const openMessageDialog = (alert: PolicyAlert) => {
    setSelectedAlert(alert);
    setMessageContent("");
    setMessageDialogOpen(true);
  };

  const handleUpdateAlert = async (newStatus: string) => {
    if (!selectedAlert) return;

    try {
      const { data: { session } } = await supabase.auth.getSession();
      const user = session?.user;
      
      const { error } = await supabase
        .from("policy_violation_alerts")
        .update({
          status: newStatus,
          admin_notes: adminNotes,
          action_taken: actionTaken,
          reviewed_by: user?.id,
          reviewed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", selectedAlert.id);

      if (error) throw error;

      toast.success(`Alert marked as ${newStatus}`);
      setAlertDialogOpen(false);
      loadAlerts();
      loadStats();
    } catch (error) {
      console.error("Error updating alert:", error);
      toast.error("Failed to update alert");
    }
  };

  const handleSendMessage = async () => {
    if (!selectedAlert || !messageContent.trim()) return;

    try {
      const { data: { session: s2 } } = await supabase.auth.getSession();
      const user = s2?.user;
      const trimmed = messageContent.trim();

      // Insert notification for the user
      const { error } = await supabase.from("notifications").insert({
        user_id: selectedAlert.user_id,
        title: "Policy Violation Warning",
        message: trimmed,
        type: "warning",
      });

      if (error) throw error;

      // Update alert with action taken + move to reviewing so it leaves the pending queue
      const preview = trimmed.length > 100 ? `${trimmed.slice(0, 100)}…` : trimmed;
      await supabase
        .from("policy_violation_alerts")
        .update({
          action_taken: `Warning sent: ${preview}`,
          status: selectedAlert.status === "pending" ? "reviewing" : selectedAlert.status,
          reviewed_by: user?.id,
          reviewed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", selectedAlert.id);

      toast.success("Warning message sent to user");
      setMessageDialogOpen(false);
      setMessageContent("");
      loadAlerts();
      loadStats();
    } catch (error: any) {
      console.error("Error sending message:", error);
      toast.error("Failed to send message", { description: error?.message });
    }
  };

  const handleBlockUser = async (userId: string) => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const adminId = session?.user?.id;

      // 1) Mark profile blocked
      const { error: profileErr } = await supabase
        .from("profiles")
        .update({ account_status: "blocked", updated_at: new Date().toISOString() })
        .eq("user_id", userId);

      if (profileErr) throw profileErr;

      // 2) Create permanent block record so /admin/moderation reflects it consistently
      const { error: blockErr } = await supabase
        .from("user_blocks")
        .insert({
          blocked_user_id: userId,
          blocked_by: adminId,
          block_type: "permanent",
          reason: selectedAlert
            ? `Policy violation: ${selectedAlert.violation_type} (${selectedAlert.severity})`
            : "Policy violation",
          expires_at: null,
        });
      if (blockErr) {
        // Non-fatal but report it
        console.warn("Block record insert failed:", blockErr);
        toast.warning("Profile blocked, but block record could not be created", {
          description: blockErr.message,
        });
      }

      toast.success("User blocked successfully");

      // 3) Update alert
      if (selectedAlert) {
        await supabase
          .from("policy_violation_alerts")
          .update({
            action_taken: "user_blocked",
            status: "resolved",
            reviewed_by: adminId,
            reviewed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq("id", selectedAlert.id);
      }

      setAlertDialogOpen(false);
      loadAlerts();
      loadStats();
    } catch (error: any) {
      console.error("Error blocking user:", error);
      toast.error("Failed to block user", { description: error?.message });
    }
  };

  const getSeverityBadge = (severity: string) => {
    switch (severity) {
      case "critical":
        return <Badge variant="destructive" className="animate-pulse"><AlertCircle className="h-3 w-3 mr-1" />Critical</Badge>;
      case "high":
        return <Badge variant="destructive"><AlertTriangle className="h-3 w-3 mr-1" />High</Badge>;
      case "medium":
        return <Badge variant="warning"><AlertTriangle className="h-3 w-3 mr-1" />Medium</Badge>;
      case "low":
        return <Badge variant="secondary">Low</Badge>;
      default:
        return <Badge variant="outline">{severity}</Badge>;
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "pending":
        return <Badge variant="warning">Pending</Badge>;
      case "reviewing":
        return <Badge variant="info">Reviewing</Badge>;
      case "resolved":
        return <Badge variant="success"><CheckCircle className="h-3 w-3 mr-1" />Resolved</Badge>;
      case "dismissed":
        return <Badge variant="secondary"><XCircle className="h-3 w-3 mr-1" />Dismissed</Badge>;
      default:
        return <Badge variant="outline">{status}</Badge>;
    }
  };

  const getViolationTypeBadge = (type: string) => {
    // Use primary theme color for all violation types for consistency
    return <Badge variant="destructive">{type.replace(/_/g, " ")}</Badge>;
  };

  const filteredAlerts = alerts.filter(alert => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase().trim();
    const profile = userProfiles[alert.user_id];
    return (
      profile?.full_name?.toLowerCase().includes(q) ||
      alert.content?.toLowerCase().includes(q) ||
      alert.violation_type.toLowerCase().includes(q) ||
      alert.admin_notes?.toLowerCase().includes(q) ||
      alert.action_taken?.toLowerCase().includes(q)
    );
  });

  if (adminLoading || !isAdmin) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  if (loading) {
    return (
      <AdminNav>
        <div className="space-y-6">
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-96 w-full" />
        </div>
      </AdminNav>
    );
  }

  return (
    <AdminNav>
      <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold flex items-center gap-2">
            <AlertTriangle className="h-6 w-6 text-destructive" />
            Policy Violation Alerts
          </h1>
          <p className="text-sm text-muted-foreground hidden md:block">
            Monitor and respond to policy violations
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="auroraOutline" onClick={handleScanMessages} disabled={scanning}>
            <Scan className={cn("h-4 w-4 mr-2", scanning && "animate-spin")} />
            {scanning ? "Scanning..." : "Scan Messages"}
          </Button>
          <Button variant="auroraOutline" size="icon" onClick={handleRefresh} disabled={refreshing}>
            <RefreshCw className={cn("h-4 w-4", refreshing && "animate-spin")} />
          </Button>
        </div>
      </div>

      <div className="space-y-6">
        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
          <Card className={cn(stats.pending > 0 && "border-orange-500")}>
            <CardContent className="p-4">
              <p className="text-sm text-muted-foreground">Pending</p>
              <p className="text-2xl font-bold text-primary">{stats.pending}</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <p className="text-sm text-muted-foreground">Reviewing</p>
              <p className="text-2xl font-bold text-primary">{stats.reviewing}</p>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <p className="text-sm text-muted-foreground">Resolved</p>
              <p className="text-2xl font-bold text-primary">{stats.resolved}</p>
            </CardContent>
          </Card>
          <Card className={cn(stats.critical > 0 && "border-red-500 animate-pulse")}>
            <CardContent className="p-4">
              <p className="text-sm text-muted-foreground">Critical</p>
              <p className="text-2xl font-bold text-destructive">{stats.critical}</p>
            </CardContent>
          </Card>
          <Card className={cn(stats.high > 0 && "border-red-400")}>
            <CardContent className="p-4">
              <p className="text-sm text-muted-foreground">High Severity</p>
              <p className="text-2xl font-bold text-destructive/80">{stats.high}</p>
            </CardContent>
          </Card>
        </div>

        {/* Filters */}
        <Card>
          <CardContent className="p-4">
            <div className="flex flex-col md:flex-row gap-4">
              <div className="flex-1 relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search by user, content, or violation type..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>
              <div className="flex gap-3 flex-wrap">
                <Select value={statusFilter} onValueChange={setStatusFilter}>
                  <SelectTrigger className="w-[130px]">
                    <SelectValue placeholder="Status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Status</SelectItem>
                    <SelectItem value="pending">Pending</SelectItem>
                    <SelectItem value="reviewing">Reviewing</SelectItem>
                    <SelectItem value="resolved">Resolved</SelectItem>
                    <SelectItem value="dismissed">Dismissed</SelectItem>
                  </SelectContent>
                </Select>
                <Select value={severityFilter} onValueChange={setSeverityFilter}>
                  <SelectTrigger className="w-[130px]">
                    <SelectValue placeholder="Severity" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Severity</SelectItem>
                    <SelectItem value="critical">Critical</SelectItem>
                    <SelectItem value="high">High</SelectItem>
                    <SelectItem value="medium">Medium</SelectItem>
                    <SelectItem value="low">Low</SelectItem>
                  </SelectContent>
                </Select>
                <Select value={violationTypeFilter} onValueChange={setViolationTypeFilter}>
                  <SelectTrigger className="w-[160px]">
                    <SelectValue placeholder="Violation Type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Types</SelectItem>
                    <SelectItem value="sexual_content">Sexual Content</SelectItem>
                    <SelectItem value="harassment">Harassment</SelectItem>
                    <SelectItem value="hate_speech">Hate Speech</SelectItem>
                    <SelectItem value="spam">Spam</SelectItem>
                    <SelectItem value="scam">Scam</SelectItem>
                    <SelectItem value="contact_sharing">Contact Sharing</SelectItem>
                    <SelectItem value="tos_violation">TOS Violation</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Alerts Table */}
        <Card>
          <CardHeader>
            <CardTitle>Violation Alerts</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="rounded-md border overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>User</TableHead>
                    <TableHead>Violation</TableHead>
                    <TableHead>Severity</TableHead>
                    <TableHead>Content Preview</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Detected</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredAlerts.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={7} className="text-center py-8 text-muted-foreground">
                        No alerts found
                      </TableCell>
                    </TableRow>
                  ) : (
                    filteredAlerts.map((alert) => {
                      const profile = userProfiles[alert.user_id];
                      return (
                        <TableRow key={alert.id} className={cn(
                          alert.severity === "critical" && "bg-destructive/10",
                          alert.severity === "high" && "bg-destructive/5"
                        )}>
                          <TableCell>
                            <div className="flex items-center gap-2">
                              <div className="h-8 w-8 rounded-full bg-muted overflow-hidden">
                                {profile?.photo_url ? (
                                  <img src={profile.photo_url} alt="" className="h-full w-full object-cover" />
                                ) : (
                                  <div className="h-full w-full flex items-center justify-center text-xs">
                                    {profile?.full_name?.[0] || "?"}
                                  </div>
                                )}
                              </div>
                              <div>
                                <p className="font-medium text-sm">{profile?.full_name || "Unknown"}</p>
                                <p className="text-xs text-muted-foreground">{profile?.gender}</p>
                              </div>
                            </div>
                          </TableCell>
                          <TableCell>{getViolationTypeBadge(alert.violation_type)}</TableCell>
                          <TableCell>{getSeverityBadge(alert.severity)}</TableCell>
                          <TableCell>
                            <p className="text-sm truncate max-w-[200px]" title={alert.content || ""}>
                              {alert.content
                                ? (alert.content.length > 50 ? `${alert.content.slice(0, 50)}…` : alert.content)
                                : "N/A"}
                            </p>
                          </TableCell>
                          <TableCell>{getStatusBadge(alert.status)}</TableCell>
                          <TableCell className="text-sm text-muted-foreground">
                            {format(new Date(alert.created_at), "MMM dd, HH:mm")}
                          </TableCell>
                          <TableCell className="text-right">
                            <div className="flex items-center justify-end gap-1">
                              <Button variant="ghost" size="icon" onClick={() => openAlertDetails(alert)} title="View Details">
                                <Eye className="h-4 w-4" />
                              </Button>
                              <Button variant="ghost" size="icon" onClick={() => openMessageDialog(alert)} title="Send Warning">
                                <MessageSquare className="h-4 w-4" />
                              </Button>
                            </div>
                          </TableCell>
                        </TableRow>
                      );
                    })
                  )}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Alert Details Dialog */}
      <Dialog open={alertDialogOpen} onOpenChange={(open) => { setAlertDialogOpen(open); if (!open) { setSelectedAlert(null); setAdminNotes(""); setActionTaken(""); } }}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-destructive" />
              Alert Details
            </DialogTitle>
          </DialogHeader>
          {selectedAlert && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label className="text-muted-foreground">User</Label>
                  <p className="font-medium">{userProfiles[selectedAlert.user_id]?.full_name || "Unknown"}</p>
                </div>
                <div>
                  <Label className="text-muted-foreground">Violation Type</Label>
                  <div>{getViolationTypeBadge(selectedAlert.violation_type)}</div>
                </div>
                <div>
                  <Label className="text-muted-foreground">Severity</Label>
                  <div>{getSeverityBadge(selectedAlert.severity)}</div>
                </div>
                <div>
                  <Label className="text-muted-foreground">Detected By</Label>
                  <p>{selectedAlert.detected_by}</p>
                </div>
              </div>
              
              <div>
                <Label className="text-muted-foreground">Flagged Content</Label>
                <div className="p-3 bg-muted rounded-lg mt-1">
                  <p className="text-sm whitespace-pre-wrap">{selectedAlert.content || "No content"}</p>
                </div>
              </div>

              <div>
                <Label>Admin Notes</Label>
                <Textarea
                  value={adminNotes}
                  onChange={(e) => setAdminNotes(e.target.value)}
                  placeholder="Add notes about this alert..."
                  className="mt-1"
                />
              </div>

              <div>
                <Label>Action Taken</Label>
                <Select value={actionTaken} onValueChange={setActionTaken}>
                  <SelectTrigger className="mt-1">
                    <SelectValue placeholder="Select action..." />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="warning_sent">Warning Sent</SelectItem>
                    <SelectItem value="user_suspended">User Suspended</SelectItem>
                    <SelectItem value="user_blocked">User Blocked</SelectItem>
                    <SelectItem value="content_removed">Content Removed</SelectItem>
                    <SelectItem value="false_positive">False Positive</SelectItem>
                    <SelectItem value="no_action">No Action Required</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          )}
          <DialogFooter className="flex-col sm:flex-row gap-2">
            <Button variant="destructive" disabled={!selectedAlert} onClick={() => selectedAlert && handleBlockUser(selectedAlert.user_id)}>
              <Ban className="h-4 w-4 mr-2" />
              Block User
            </Button>
            <Button variant="outline" onClick={() => handleUpdateAlert("dismissed")}>
              Dismiss
            </Button>
            <Button variant="outline" onClick={() => handleUpdateAlert("reviewing")}>
              Mark Reviewing
            </Button>
            <Button onClick={() => handleUpdateAlert("resolved")}>
              <CheckCircle className="h-4 w-4 mr-2" />
              Resolve
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Send Message Dialog */}
      <Dialog open={messageDialogOpen} onOpenChange={(open) => { setMessageDialogOpen(open); if (!open) { setMessageContent(""); } }}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <MessageSquare className="h-5 w-5" />
              Send Warning Message
            </DialogTitle>
            <DialogDescription>
              Send a warning notification to {userProfiles[selectedAlert?.user_id || ""]?.full_name || "this user"}
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>Violation</Label>
              <div className="mt-1">{selectedAlert && getViolationTypeBadge(selectedAlert.violation_type)}</div>
            </div>
            <div>
              <Label>Warning Message</Label>
              <Textarea
                value={messageContent}
                onChange={(e) => setMessageContent(e.target.value)}
                placeholder="Your account has been flagged for violating our community guidelines..."
                rows={4}
                className="mt-1"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setMessageDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleSendMessage} disabled={!messageContent.trim()}>
              <Send className="h-4 w-4 mr-2" />
              Send Warning
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </AdminNav>
  );
};

export default AdminPolicyAlerts;
