import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { supabase } from "@/integrations/supabase/client";
import AdminNav from "@/components/AdminNav";
import ScrollToggleFab from "@/components/ScrollToggleFab";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { useMultipleRealtimeSubscriptions } from "@/hooks/useRealtimeSubscription";
import { runAllCleanups } from "@/services/cleanup.service";
import { toast } from "sonner";
import {
  Users,
  MessageSquare,
  BarChart3,
  Settings,
  Shield,
  FileText,
  Clock,
  DollarSign,
  Bell,
  Activity,
  Gift,
  Globe,
  Database,
  AlertTriangle,
  Languages,
  ChevronRight,
  TrendingUp,
  MessageCircle,
  UserPlus,
  Trash2,
  Search
} from "lucide-react";

interface DashboardStats {
  totalUsers: number;
  onlineUsers: number;
  totalChats: number;
  activeChats: number;
  todayEarnings: number;
  pendingApprovals: number;
  policyAlerts: number;
}

const AdminDashboard = () => {
  const navigate = useNavigate();
  const { isLoading, isAdmin, adminEmail } = useAdminAccess();
  const [stats, setStats] = useState<DashboardStats>({
    totalUsers: 0,
    onlineUsers: 0,
    totalChats: 0,
    activeChats: 0,
    todayEarnings: 0,
    pendingApprovals: 0,
    policyAlerts: 0
  });
  const [seedingUsers, setSeedingUsers] = useState(false);
  const [runningCleanup, setRunningCleanup] = useState(false);

  const handleRunCleanup = async () => {
    setRunningCleanup(true);
    try {
      const results = await runAllCleanups();
      
      const successCount = [results.dataCleanup, results.groupCleanup, results.videoCleanup]
        .filter(r => r.success).length;
      
      if (successCount === 3) {
        toast.success("All cleanup tasks completed successfully!");
      } else if (successCount > 0) {
        toast.warning(`${successCount}/3 cleanup tasks completed`);
      } else {
        toast.error("Cleanup tasks failed");
      }
      
      loadStats();
    } catch (error) {
      console.error("Cleanup error:", error);
      toast.error("Failed to run cleanup tasks");
    } finally {
      setRunningCleanup(false);
    }
  };

  const handleSeedSuperUsers = async () => {
    setSeedingUsers(true);
    try {
      const { data: result, error } = await supabase.functions.invoke('seed-super-users', {
        method: 'POST',
      });

      if (error) {
        toast.error(error.message || "Failed to seed super users");
        return;
      }
      
      if (result?.success) {
        const created = (result.results?.females?.filter((f: any) => f.status === 'created').length || 0) +
                       (result.results?.males?.filter((m: any) => m.status === 'created').length || 0) +
                       (result.results?.admins?.filter((a: any) => a.status === 'created').length || 0);
        const existing = (result.results?.females?.filter((f: any) => f.status === 'already exists').length || 0) +
                        (result.results?.males?.filter((m: any) => m.status === 'already exists').length || 0) +
                        (result.results?.admins?.filter((a: any) => a.status === 'already exists').length || 0);
        
        toast.success(`Super users seeded! Created: ${created}, Already existed: ${existing}`);
        loadStats();
      } else {
        toast.error(result?.error || "Failed to seed super users");
      }
    } catch (error) {
      console.error("Error seeding super users:", error);
      toast.error("Failed to seed super users");
    } finally {
      setSeedingUsers(false);
    }
  };

  const adminModules = [
    {
      title: "User Management",
      description: "Manage users, roles, and permissions",
      icon: <Users className="h-6 w-6" />,
      path: "/admin/users",
      badge: stats.pendingApprovals > 0 ? `${stats.pendingApprovals} pending` : undefined
    },
    {
      title: "User Lookup",
      description: "Search users by name, email, or phone",
      icon: <Search className="h-6 w-6" />,
      path: "/admin/user-lookup",
    },
    {
      title: "KYC Management",
      description: "Review and approve KYC submissions",
      icon: <Shield className="h-6 w-6" />,
      path: "/admin/kyc",
    },
    {
      title: "Analytics Dashboard",
      description: "View platform analytics and insights",
      icon: <BarChart3 className="h-6 w-6" />,
      path: "/admin/analytics",
    },
    {
      title: "Chat Monitoring",
      description: "Monitor active chats and conversations",
      icon: <MessageSquare className="h-6 w-6" />,
      path: "/admin/chat-monitoring",
      badge: stats.activeChats > 0 ? `${stats.activeChats} active` : undefined
    },
    {
      title: "Live Messenger",
      description: "Online users, chat threads & TL — free admin chat/calls",
      icon: <MessageCircle className="h-6 w-6" />,
      path: "/admin/messenger",
    },
    {
      title: "Admin Messaging",
      description: "Inbox, broadcast, and direct user messaging",
      icon: <Bell className="h-6 w-6" />,
      path: "/admin/messaging",
    },
    {
      title: "Finance Dashboard",
      description: "Revenue, transactions, and payouts — Monthly statements admin view",
      icon: <DollarSign className="h-6 w-6" />,
      path: "/admin/finance",
    },
    {
      title: "Transaction History",
      description: "View all user transactions",
      icon: <Activity className="h-6 w-6" />,
      path: "/admin/transactions",
    },
    {
      title: "Chat Pricing",
      description: "Configure chat and video call rates",
      icon: <Clock className="h-6 w-6" />,
      path: "/admin/chat-pricing",
    },
    {
      title: "Gift Management",
      description: "Manage virtual gifts and pricing",
      icon: <Gift className="h-6 w-6" />,
      path: "/admin/gifts",
    },
    {
      title: "Language Groups",
      description: "Manage language-based user groups",
      icon: <Globe className="h-6 w-6" />,
      path: "/admin/languages",
    },
    {
      title: "Language Limits",
      description: "Set language capacity limits",
      icon: <Languages className="h-6 w-6" />,
      path: "/admin/language-limits",
    },
    {
      title: "Content Moderation",
      description: "Review flagged content and reports",
      icon: <Shield className="h-6 w-6" />,
      path: "/admin/moderation",
    },
    {
      title: "Policy Alerts",
      description: "View policy violation alerts",
      icon: <AlertTriangle className="h-6 w-6" />,
      path: "/admin/policy-alerts",
      badge: stats.policyAlerts > 0 ? `${stats.policyAlerts} alerts` : undefined
    },
    {
      title: "Performance",
      description: "System performance metrics",
      icon: <Activity className="h-6 w-6" />,
      path: "/admin/performance",
    },
    {
      title: "Finance Reports",
      description: "Detailed financial reports",
      icon: <FileText className="h-6 w-6" />,
      path: "/admin/finance-reports",
    },
    {
      title: "Monthly Statements",
      description: "Women monthly earning statements",
      icon: <TrendingUp className="h-6 w-6" />,
      path: "/admin/statements",
    },
    {
      title: "Legal Documents",
      description: "Manage terms, policies, and legal docs",
      icon: <FileText className="h-6 w-6" />,
      path: "/admin/legal-documents",
    },
    {
      title: "Backup Management",
      description: "Database backups and restoration",
      icon: <Database className="h-6 w-6" />,
      path: "/admin/backups",
    },
    {
      title: "Audit Logs",
      description: "View admin activity logs",
      icon: <FileText className="h-6 w-6" />,
      path: "/admin/audit-logs",
    },
    {
      title: "Admin Settings",
      description: "Platform configuration settings",
      icon: <Settings className="h-6 w-6" />,
      path: "/admin/settings",
    },
    {
      title: "Enable / Disable Features",
      description: "Toggle Statements tab visibility for all users",
      icon: <Settings className="h-6 w-6" />,
      path: "/admin/enable-disable",
    }
  ];

  const loadStats = useCallback(async () => {
    try {
      const today = new Date().toISOString().split("T")[0];

      // Run all independent queries in parallel
      const [
        totalUsersRes,
        onlineUsersRes,
        activeChatsRes,
        totalChatsRes,
        pendingApprovalsRes,
        policyAlertsRes,
        earningsRes,
      ] = await Promise.allSettled([
        supabase.from("profiles").select("*", { count: "exact", head: true }),
        supabase.from("user_status").select("*", { count: "exact", head: true }).eq("is_online", true),
        supabase.from("active_chat_sessions").select("*", { count: "exact", head: true }).eq("status", "active"),
        supabase.from("chat_messages").select("*", { count: "exact", head: true }),
        supabase.from("female_profiles").select("*", { count: "exact", head: true }).eq("approval_status", "pending"),
        supabase.from("policy_violation_alerts").select("*", { count: "exact", head: true }).eq("status", "pending"),
        supabase.from("wallet_transactions").select("amount").eq("transaction_type", "recharge").eq("type","credit").gte("created_at", `${today}T00:00:00`).lte("created_at", `${today}T23:59:59`),
      ]);

      const getCount = (res: PromiseSettledResult<any>) => 
        res.status === 'fulfilled' && !res.value.error ? (res.value.count || 0) : 0;

      let todayEarnings = 0;
      if (earningsRes.status === 'fulfilled' && !earningsRes.value.error) {
        todayEarnings = earningsRes.value.data?.reduce((acc: number, t: any) => acc + Number(t.amount), 0) || 0;
      }

      setStats({
        totalUsers: getCount(totalUsersRes),
        onlineUsers: getCount(onlineUsersRes),
        totalChats: getCount(totalChatsRes),
        activeChats: getCount(activeChatsRes),
        todayEarnings,
        pendingApprovals: getCount(pendingApprovalsRes),
        policyAlerts: getCount(policyAlertsRes),
      });
    } catch (error) {
      console.error("[AdminDashboard] Error loading stats:", error);
      toast.error("Stats unavailable", { description: ERROR_MESSAGES.admin.loadFailed });
    }
  }, []);

  // Real-time subscriptions for dashboard stats
  useMultipleRealtimeSubscriptions(
    ["profiles", "user_status", "active_chat_sessions", "policy_violation_alerts", "wallet_transactions"],
    loadStats,
    isAdmin
  );

  useEffect(() => {
    if (isAdmin) {
      loadStats();
    }
  }, [isAdmin, loadStats]);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="w-12 h-12 border-4 border-primary/30 border-t-primary rounded-full animate-spin mx-auto" />
          <p className="text-muted-foreground">Loading admin dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <AdminNav>
      <div className="space-y-4 sm:space-y-8">
        {/* Welcome Section */}
        <div className="animate-fade-in flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
          <div className="min-w-0">
            <h1 className="text-xl sm:text-3xl font-bold text-foreground">Admin Dashboard</h1>
            <p className="text-xs sm:text-sm text-muted-foreground mt-1 truncate">
              Manage & monitor • {adminEmail}
            </p>
          </div>
          <div className="flex gap-2 shrink-0 flex-wrap">
            <Button 
              onClick={handleRunCleanup} 
              disabled={runningCleanup}
              variant="outline"
              size="sm"
              className="text-xs sm:text-sm"
              aria-label={runningCleanup ? "Running cleanup" : "Run cleanup tasks"}
            >
              <Trash2 className="w-3.5 h-3.5 sm:w-4 sm:h-4 mr-1.5" />
              {runningCleanup ? "Cleaning..." : "Cleanup"}
            </Button>
            {!import.meta.env.PROD && (
              <Button 
                onClick={handleSeedSuperUsers} 
                disabled={seedingUsers}
                size="sm"
                className="bg-gradient-to-r from-primary to-secondary text-xs sm:text-sm"
                aria-label={seedingUsers ? "Seeding users" : "Seed super users"}
              >
                <UserPlus className="w-3.5 h-3.5 sm:w-4 sm:h-4 mr-1.5" />
                {seedingUsers ? "Seeding..." : "Seed Users"}
              </Button>
            )}
          </div>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-2 gap-2.5 sm:gap-4 md:grid-cols-4 animate-fade-in" style={{ animationDelay: "0.1s" }}>
          <Card className="p-2.5 sm:p-4 bg-gradient-to-br from-primary/10 to-primary/5 border-primary/20">
            <div className="flex items-center gap-2 sm:gap-3">
              <div className="p-1.5 sm:p-2 rounded-lg sm:rounded-xl bg-primary/20">
                <Users className="w-4 h-4 sm:w-5 sm:h-5 text-primary" />
              </div>
              <div className="min-w-0">
                <p className="text-lg sm:text-2xl font-bold">{stats.totalUsers}</p>
                <p className="text-[10px] sm:text-xs text-muted-foreground">Total Users</p>
              </div>
            </div>
          </Card>

          <Card className="p-2.5 sm:p-4 bg-gradient-to-br from-[#25D366]/10 to-[#25D366]/5 border-[#25D366]/20">
            <div className="flex items-center gap-2 sm:gap-3">
              <div className="p-1.5 sm:p-2 rounded-lg sm:rounded-xl bg-[#25D366]/20 relative">
                <TrendingUp className="w-4 h-4 sm:w-5 sm:h-5 text-[#25D366]" />
                <span className="absolute -top-0.5 -right-0.5 w-2.5 h-2.5 bg-[#25D366] rounded-full animate-ping" />
                <span className="absolute -top-0.5 -right-0.5 w-2.5 h-2.5 bg-[#25D366] rounded-full" />
              </div>
              <div className="min-w-0">
                <p className="text-lg sm:text-2xl font-bold">{stats.onlineUsers}</p>
                <p className="text-[10px] sm:text-xs text-muted-foreground">Online Now</p>
              </div>
            </div>
          </Card>

          <Card className="p-2.5 sm:p-4 bg-gradient-to-br from-primary/10 to-primary/5 border-primary/20">
            <div className="flex items-center gap-2 sm:gap-3">
              <div className="p-1.5 sm:p-2 rounded-lg sm:rounded-xl bg-primary/20">
                <MessageCircle className="w-4 h-4 sm:w-5 sm:h-5 text-primary" />
              </div>
              <div className="min-w-0">
                <p className="text-lg sm:text-2xl font-bold">{stats.activeChats}</p>
                <p className="text-[10px] sm:text-xs text-muted-foreground">Active Chats</p>
              </div>
            </div>
          </Card>

          <Card className="p-2.5 sm:p-4 bg-gradient-to-br from-primary/10 to-primary/5 border-primary/20">
            <div className="flex items-center gap-2 sm:gap-3">
              <div className="p-1.5 sm:p-2 rounded-lg sm:rounded-xl bg-primary/20">
                <DollarSign className="w-4 h-4 sm:w-5 sm:h-5 text-primary" />
              </div>
              <div className="min-w-0">
                <p className="text-lg sm:text-2xl font-bold">₹{stats.todayEarnings}</p>
                <p className="text-[10px] sm:text-xs text-muted-foreground">Today Deposits</p>
              </div>
            </div>
          </Card>
        </div>

        {/* Admin Modules Grid */}
        <div className="animate-fade-in" style={{ animationDelay: "0.2s" }}>
          <h2 className="text-base sm:text-lg font-semibold text-foreground mb-3 sm:mb-4">Admin Modules</h2>
          <div className="space-y-1">
            {adminModules.map((module) => (
              <button
                key={module.path}
                className="w-full flex items-center gap-3 px-3 py-3 rounded-lg hover:bg-muted/50 transition-colors group"
                onClick={() => navigate(module.path)}
              >
                <div className="p-2 rounded-full bg-[#25D366]/15 text-[#075E54] shrink-0">
                  {module.icon}
                </div>
                <div className="flex-1 text-left min-w-0">
                  <h3 className="font-semibold text-sm text-foreground leading-tight">
                    {module.title}
                  </h3>
                  <p className="text-xs text-muted-foreground mt-0.5 truncate hidden sm:block">
                    {module.description}
                  </p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  {module.badge && (
                    <Badge className="text-[10px] bg-[#25D366] text-white border-0">
                      {module.badge}
                    </Badge>
                  )}
                  <ChevronRight className="w-4 h-4 text-muted-foreground group-hover:text-foreground transition-colors" />
                </div>
              </button>
            ))}
          </div>
        </div>



        {/* Alerts Section */}
        {(stats.pendingApprovals > 0 || stats.policyAlerts > 0) && (
          <Card className="p-3 sm:p-6 bg-gradient-to-r from-warning/10 to-warning/10 border-warning/20 animate-fade-in" style={{ animationDelay: "0.3s" }}>
            <div className="flex flex-col sm:flex-row sm:items-center gap-3 sm:gap-4">
              <div className="flex items-center gap-3 flex-1 min-w-0">
                <div className="p-2 sm:p-3 rounded-lg sm:rounded-xl bg-warning/20 shrink-0">
                  <Bell className="w-5 h-5 sm:w-6 sm:h-6 text-warning" />
                </div>
                <div className="min-w-0">
                  <h3 className="font-semibold text-sm sm:text-base text-foreground">Pending Actions</h3>
                  <p className="text-xs sm:text-sm text-muted-foreground">
                    {stats.pendingApprovals > 0 && `${stats.pendingApprovals} approvals. `}
                    {stats.policyAlerts > 0 && `${stats.policyAlerts} alerts.`}
                  </p>
                </div>
              </div>
              <div className="flex gap-2 shrink-0">
                {stats.pendingApprovals > 0 && (
                  <Button size="sm" variant="outline" className="text-xs" onClick={() => navigate("/admin/users")}>
                    Review
                  </Button>
                )}
                {stats.policyAlerts > 0 && (
                  <Button size="sm" variant="outline" className="text-xs" onClick={() => navigate("/admin/policy-alerts")}>
                    Alerts
                  </Button>
                )}
              </div>
            </div>
          </Card>
        )}
      </div>
      <ScrollToggleFab />
    </AdminNav>
  );
};

export default AdminDashboard;
