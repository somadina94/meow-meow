import { useState, useEffect, useCallback } from "react";
import AdminNav from "@/components/AdminNav";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { useMultipleRealtimeSubscriptions } from "@/hooks/useRealtimeSubscription";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { toast } from "sonner";
import {
  ArrowLeft,
  Users,
  UserCheck,
  Heart,
  IndianRupee,
  TrendingUp,
  TrendingDown,
  Download,
  RefreshCw,
  Activity,
  MessageSquare,
  Calendar,
  BarChart3,
  EyeOff,
  Bell,
  Shield,
  Home,
  Wallet,
} from "lucide-react";
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import { format, subDays } from "date-fns";
import { cn } from "@/lib/utils";

interface AnalyticsData {
  totalUsers: number;
  activeUsers: number;
  totalMatches: number;
  adminProfit: number;
  menRecharges: number;
  menSpent: number;
  womenEarnings: number;
  womenWithdrawals: number;
  newUsersToday: number;
  messagesCount: number;
  avgSessionTime: number;
  conversionRate: number;
}

interface ChartData {
  date: string;
  users: number;
  activeUsers: number;
  matches: number;
  revenue: number;
  messages: number;
}

interface GenderDistribution {
  name: string;
  value: number;
  color: string;
}

const CHART_COLORS = {
  primary: "hsl(var(--primary))",
  secondary: "hsl(var(--secondary))",
  accent: "hsl(var(--accent))",
  muted: "hsl(var(--muted))",
  success: "hsl(var(--success))",
  warning: "hsl(var(--warning))",
  danger: "hsl(var(--destructive))",
  male: "hsl(var(--male))",
  female: "hsl(var(--female))",
};

const AdminAnalyticsDashboard = () => {
  const navigate = useNavigate();
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [dateRange, setDateRange] = useState("7");
  const [analytics, setAnalytics] = useState<AnalyticsData>({
    totalUsers: 0,
    activeUsers: 0,
    totalMatches: 0,
    adminProfit: 0,
    menRecharges: 0,
    menSpent: 0,
    womenEarnings: 0,
    womenWithdrawals: 0,
    newUsersToday: 0,
    messagesCount: 0,
    avgSessionTime: 0,
    conversionRate: 0,
  });
  const [chartData, setChartData] = useState<ChartData[]>([]);
  const [genderDistribution, setGenderDistribution] = useState<GenderDistribution[]>([]);

  const fetchAnalytics = useCallback(async () => {
    try {
      const days = dateRange === "all" ? 365 : parseInt(dateRange);
      const startDate = subDays(new Date(), days);
      const endDate = new Date();

      // Try the server-side RPC first
      const { data, error } = await supabase.rpc("get_analytics_summary" as any, {
        p_start_date: startDate.toISOString(),
        p_end_date: endDate.toISOString(),
      });

      if (!error && data && data.totals) {
        const result = data as any;
        const totals = result.totals;
        const gender = result.gender;
        const chart = result.chart;

        const menRecharges = Number(totals.men_recharges) || 0;
        const womenWithdrawals = Number(totals.women_withdrawals) || 0;
        const adminProfit = menRecharges - womenWithdrawals;
        const totalUsers = Number(totals.total_users) || 0;
        const totalMatches = Number(totals.total_matches) || 0;
        const conversionRate = totalUsers ? (totalMatches / totalUsers) * 100 : 0;

        setAnalytics({
          totalUsers,
          activeUsers: Number(totals.active_users) || 0,
          totalMatches,
          adminProfit,
          menRecharges,
          menSpent: Number(totals.men_spent) || 0,
          womenEarnings: Number(totals.women_earnings) || 0,
          womenWithdrawals,
          newUsersToday: Number(totals.new_users_today) || 0,
          messagesCount: Number(totals.messages_count) || 0,
          avgSessionTime: Math.round(Number(totals.avg_session_minutes) || 0),
          conversionRate,
        });

        setGenderDistribution([
          { name: "Male", value: Number(gender?.male) || 0, color: CHART_COLORS.male },
          { name: "Female", value: Number(gender?.female) || 0, color: CHART_COLORS.female },
          { name: "Other", value: Number(gender?.other) || 0, color: CHART_COLORS.accent },
        ]);

        const chartDataPoints: ChartData[] = (chart || []).map((point: any) => ({
          date: point.date,
          users: Number(point.users) || 0,
          activeUsers: Number(point.activeUsers) || 0,
          matches: Number(point.matches) || 0,
          revenue: Number(point.revenue) || 0,
          messages: Number(point.messages) || 0,
        }));
        setChartData(chartDataPoints);
      } else {
        // Fallback: Direct queries when RPC fails or returns unexpected format
        console.warn("[Analytics] RPC failed or returned unexpected format, using fallback queries");
        const [
          usersRes, activeRes, matchesRes, msgsRes,
          maleRes, femaleRes,
        ] = await Promise.allSettled([
          supabase.from("profiles").select("*", { count: "exact", head: true }),
          supabase.from("user_status").select("*", { count: "exact", head: true }).eq("is_online", true),
          supabase.from("matches").select("*", { count: "exact", head: true }),
          supabase.from("chat_messages").select("*", { count: "exact", head: true }),
          supabase.from("profiles").select("*", { count: "exact", head: true }).eq("gender", "male"),
          supabase.from("profiles").select("*", { count: "exact", head: true }).eq("gender", "female"),
        ]);

        const gc = (r: PromiseSettledResult<any>) => r.status === 'fulfilled' && !r.value.error ? (r.value.count || 0) : 0;
        const totalUsers = gc(usersRes);
        const totalMatches = gc(matchesRes);

        // FIX #8: Show NaN-safe values; adminProfit = -1 signals "N/A" in fallback
        setAnalytics({
          totalUsers,
          activeUsers: gc(activeRes),
          totalMatches,
          adminProfit: -1, // signals N/A — RPC failed
          menRecharges: -1,
          menSpent: -1,
          womenEarnings: -1,
          womenWithdrawals: -1,
          newUsersToday: 0,
          messagesCount: gc(msgsRes),
          avgSessionTime: 0,
          conversionRate: totalUsers ? (totalMatches / totalUsers) * 100 : 0,
        });

        setGenderDistribution([
          { name: "Male", value: gc(maleRes), color: CHART_COLORS.male },
          { name: "Female", value: gc(femaleRes), color: CHART_COLORS.female },
          { name: "Other", value: Math.max(0, totalUsers - gc(maleRes) - gc(femaleRes)), color: CHART_COLORS.accent },
        ]);
        setChartData([]);
      }
    } catch (error) {
      console.error("Error fetching analytics:", error);
      toast.error("Failed to load analytics");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [dateRange]);

  // Reduced realtime subscriptions - only subscribe to tables that materially affect analytics
  useMultipleRealtimeSubscriptions(
    [
      "profiles",
      "wallet_transactions",
      "matches",
    ],
    fetchAnalytics,
    true,
    3000 // 3s debounce - analytics doesn't need instant updates
  );

  useEffect(() => {
    fetchAnalytics();
  }, [fetchAnalytics]);

  const handleRefresh = () => {
    setRefreshing(true);
    fetchAnalytics();
  };

  const handleExport = () => {
    const csvData = [
      ["Metric", "Value"],
      ["Total Deposits (Men)", analytics.menRecharges],
      ["Men Spent", analytics.menSpent],
      ["Women Earnings", analytics.womenEarnings],
      ["Total Withdrawals (Women)", analytics.womenWithdrawals],
      ["Total Profit (Deposits - Withdrawals)", analytics.adminProfit],
      ["Total Users", analytics.totalUsers],
      ["Active Users", analytics.activeUsers],
      ["Total Matches", analytics.totalMatches],
      ["Messages Count", analytics.messagesCount],
      ["Conversion Rate", `${analytics.conversionRate.toFixed(2)}%`],
    ];

    const csvContent = csvData.map(row => row.join(",")).join("\n");
    const blob = new Blob([csvContent], { type: "text/csv" });
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `analytics_${format(new Date(), "yyyy-MM-dd")}.csv`;
    a.click();
    window.URL.revokeObjectURL(url);
    toast.success("Analytics exported successfully!");
  };

  const StatCard = useCallback(({ 
    title, 
    value, 
    icon: Icon, 
    trend, 
    trendValue,
    color = "primary"
  }: {
    title: string;
    value: string | number;
    icon: React.ElementType;
    trend?: "up" | "down";
    trendValue?: string;
    color?: string;
  }) => (
    <Card className="relative overflow-hidden transition-all duration-300 hover:shadow-lg hover:-translate-y-1">
      <div className={cn(
        "absolute top-0 right-0 w-20 h-20 rounded-full opacity-10 -translate-y-1/2 translate-x-1/2",
        color === "primary" && "bg-primary",
        color === "success" && "bg-success",
        color === "warning" && "bg-warning",
        color === "danger" && "bg-destructive",
      )} />
      <CardContent className="p-6">
        <div className="flex items-start justify-between">
          <div>
            <p className="text-sm text-muted-foreground">{title}</p>
            <p className="text-3xl font-bold mt-1 animate-fade-in">{value}</p>
            {trend && trendValue && (
              <div className={cn(
                "flex items-center gap-1 mt-2 text-sm",
                trend === "up" ? "text-success" : "text-destructive"
              )}>
                {trend === "up" ? <TrendingUp className="h-4 w-4" /> : <TrendingDown className="h-4 w-4" />}
                <span>{trendValue}</span>
              </div>
            )}
          </div>
          <div className={cn(
            "p-3 rounded-lg",
            color === "primary" && "bg-primary/10 text-primary",
            color === "success" && "bg-success/10 text-success",
            color === "warning" && "bg-warning/10 text-warning",
            color === "danger" && "bg-destructive/10 text-destructive",
          )}>
            <Icon className="h-6 w-6" />
          </div>
        </div>
      </CardContent>
    </Card>
  ), []);

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
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[...Array(8)].map((_, i) => (
              <Skeleton key={i} className="h-32" />
            ))}
          </div>
          <div className="grid md:grid-cols-2 gap-6">
            <Skeleton className="h-80" />
            <Skeleton className="h-80" />
          </div>
        </div>
      </AdminNav>
    );
  }

  return (
    <AdminNav>
      <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
        <div>
          <h1 className="text-xl md:text-2xl font-bold flex items-center gap-2">
            <BarChart3 className="h-6 w-6 text-primary" />
            Analytics Dashboard
          </h1>
          <p className="text-sm text-muted-foreground hidden md:block">
            Monitor engagement, users, and revenue metrics
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Select value={dateRange} onValueChange={setDateRange}>
            <SelectTrigger className="w-[140px]">
              <Calendar className="h-4 w-4 mr-2" />
              <SelectValue placeholder="Select range" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Time (last 365 days)</SelectItem>
              <SelectItem value="7">Last 7 days</SelectItem>
              <SelectItem value="14">Last 14 days</SelectItem>
              <SelectItem value="30">Last 30 days</SelectItem>
              <SelectItem value="90">Last 90 days</SelectItem>
            </SelectContent>
          </Select>
          <Button
            variant="outline"
            size="icon"
            onClick={handleRefresh}
            disabled={refreshing}
          >
            <RefreshCw className={cn("h-4 w-4", refreshing && "animate-spin")} />
          </Button>
          <Button onClick={handleExport} className="gap-2">
            <Download className="h-4 w-4" />
            <span className="hidden md:inline">Export</span>
          </Button>
        </div>
      </div>

      <div className="space-y-6">
        {/* System Status Banner */}
        {/* Stats Grid */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <StatCard
            title="Total Deposits (Men)"
            value={analytics.menRecharges < 0 ? "N/A" : `₹${analytics.menRecharges.toLocaleString()}`}
            icon={IndianRupee}
            color="success"
          />
          <StatCard
            title="Men Spent"
            value={analytics.menSpent < 0 ? "N/A" : `₹${analytics.menSpent.toLocaleString()}`}
            icon={IndianRupee}
            color="warning"
          />
          <StatCard
            title="Women Earnings"
            value={analytics.womenEarnings < 0 ? "N/A" : `₹${analytics.womenEarnings.toLocaleString()}`}
            icon={IndianRupee}
            color="danger"
          />
          <StatCard
            title="Total Withdrawals (Women)"
            value={analytics.womenWithdrawals < 0 ? "N/A" : `₹${analytics.womenWithdrawals.toLocaleString()}`}
            icon={Wallet}
            color="warning"
          />
          <StatCard
            title="Total Profit (Deposits − Withdrawals)"
            value={analytics.adminProfit < 0 ? "N/A" : `₹${analytics.adminProfit.toLocaleString()}`}
            icon={TrendingUp}
            color={analytics.adminProfit > 0 ? "success" : "danger"}
          />
          <StatCard
            title="Total Users"
            value={analytics.totalUsers.toLocaleString()}
            icon={Users}
            color="primary"
          />
          <StatCard
            title="Active Users"
            value={analytics.activeUsers.toLocaleString()}
            icon={UserCheck}
            color="success"
          />
          <StatCard
            title="Total Matches"
            value={analytics.totalMatches.toLocaleString()}
            icon={Heart}
            color="danger"
          />
          <StatCard
            title="Messages Sent"
            value={analytics.messagesCount.toLocaleString()}
            icon={MessageSquare}
            color="warning"
          />
          <StatCard
            title="Conversion Rate"
            value={`${analytics.conversionRate.toFixed(1)}%`}
            icon={TrendingUp}
            color={analytics.conversionRate > 5 ? "success" : "danger"}
          />
        </div>

        {/* Charts Row 1 */}
        <div className="grid md:grid-cols-2 gap-6">
          {/* User Growth Chart */}
          <Card className="overflow-hidden">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2">
                <Users className="h-5 w-5 text-primary" />
                User Growth
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={chartData}>
                    <defs>
                      <linearGradient id="colorUsers" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="hsl(var(--primary))" stopOpacity={0.3} />
                        <stop offset="95%" stopColor="hsl(var(--primary))" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                    <XAxis dataKey="date" className="text-xs" />
                    <YAxis className="text-xs" />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: "hsl(var(--background))",
                        border: "1px solid hsl(var(--border))",
                        borderRadius: "8px",
                      }}
                    />
                    <Legend />
                    <Area
                      type="monotone"
                      dataKey="users"
                      stroke="hsl(var(--primary))"
                      fillOpacity={1}
                      fill="url(#colorUsers)"
                      name="New Users"
                      animationDuration={1000}
                    />
                    <Area
                      type="monotone"
                      dataKey="activeUsers"
                      stroke={CHART_COLORS.success}
                      fillOpacity={0.3}
                      fill={CHART_COLORS.success}
                      name="Active Users"
                      animationDuration={1200}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          {/* Revenue Chart */}
          <Card className="overflow-hidden">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2">
                <IndianRupee className="h-5 w-5 text-primary" />
                Revenue Trend
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                    <XAxis dataKey="date" className="text-xs" />
                    <YAxis className="text-xs" />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: "hsl(var(--background))",
                        border: "1px solid hsl(var(--border))",
                        borderRadius: "8px",
                      }}
                      formatter={(value) => [`₹${value}`, "Revenue"]}
                    />
                    <Legend />
                    <Bar
                      dataKey="revenue"
                      fill="hsl(var(--primary))"
                      name="Revenue (₹)"
                      radius={[4, 4, 0, 0]}
                      animationDuration={1000}
                    />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Charts Row 2 */}
        <div className="grid md:grid-cols-3 gap-6">
          {/* Matches Chart */}
          <Card className="overflow-hidden">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2">
                <Heart className="h-5 w-5 text-primary" />
                Matches Over Time
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[250px]">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                    <XAxis dataKey="date" className="text-xs" />
                    <YAxis className="text-xs" />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: "hsl(var(--background))",
                        border: "1px solid hsl(var(--border))",
                        borderRadius: "8px",
                      }}
                    />
                    <Line
                      type="monotone"
                      dataKey="matches"
                      stroke={CHART_COLORS.female}
                      strokeWidth={2}
                      dot={{ fill: CHART_COLORS.female, strokeWidth: 2 }}
                      name="Matches"
                      animationDuration={1000}
                    />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          {/* Messages Chart */}
          <Card className="overflow-hidden">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2">
                <MessageSquare className="h-5 w-5 text-primary" />
                Messages Activity
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[250px]">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={chartData}>
                    <defs>
                      <linearGradient id="colorMessages" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor={CHART_COLORS.accent} stopOpacity={0.3} />
                        <stop offset="95%" stopColor={CHART_COLORS.accent} stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                    <XAxis dataKey="date" className="text-xs" />
                    <YAxis className="text-xs" />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: "hsl(var(--background))",
                        border: "1px solid hsl(var(--border))",
                        borderRadius: "8px",
                      }}
                    />
                    <Area
                      type="monotone"
                      dataKey="messages"
                      stroke={CHART_COLORS.accent}
                      fillOpacity={1}
                      fill="url(#colorMessages)"
                      name="Messages"
                      animationDuration={1000}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          {/* Gender Distribution */}
          <Card className="overflow-hidden">
            <CardHeader className="pb-2">
              <CardTitle className="flex items-center gap-2">
                <Users className="h-5 w-5 text-primary" />
                Gender Distribution
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="h-[250px]">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={genderDistribution}
                      cx="50%"
                      cy="50%"
                      innerRadius={50}
                      outerRadius={80}
                      paddingAngle={5}
                      dataKey="value"
                      animationDuration={1000}
                    >
                      {genderDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        backgroundColor: "hsl(var(--background))",
                        border: "1px solid hsl(var(--border))",
                        borderRadius: "8px",
                      }}
                    />
                    <Legend />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Quick Actions */}
        <Card>
          <CardHeader>
            <CardTitle>Quick Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <Button
                variant="outline"
                className="h-auto p-4 flex flex-col items-center gap-2"
                onClick={() => navigate("/admin/chat-monitoring")}
              >
                <EyeOff className="h-6 w-6 text-primary" />
                <span className="text-sm font-medium">Live Chat Monitor</span>
                <span className="text-xs text-muted-foreground">Silent monitoring</span>
              </Button>
              <Button
                variant="outline"
                className="h-auto p-4 flex flex-col items-center gap-2"
                onClick={() => navigate("/admin/moderation")}
              >
                <Shield className="h-6 w-6 text-primary" />
                <span className="text-sm font-medium">Moderation</span>
                <span className="text-xs text-muted-foreground">Reports & blocks</span>
              </Button>
              <Button
                variant="outline"
                className="h-auto p-4 flex flex-col items-center gap-2"
                onClick={() => navigate("/admin/messaging")}
              >
                <Bell className="h-6 w-6 text-primary" />
                <span className="text-sm font-medium">Broadcast</span>
                <span className="text-xs text-muted-foreground">Send notifications</span>
              </Button>
              <Button
                variant="outline"
                className="h-auto p-4 flex flex-col items-center gap-2"
                onClick={() => navigate("/admin/finance-reports")}
              >
                <IndianRupee className="h-6 w-6 text-success" />
                <span className="text-sm font-medium">Finance</span>
                <span className="text-xs text-muted-foreground">Revenue reports</span>
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Quick Insights */}
        <Card>
          <CardHeader>
            <CardTitle>Quick Insights</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              <div className="p-4 rounded-lg bg-muted/50">
                <p className="text-sm text-muted-foreground">New Users Today</p>
                <p className="text-lg font-semibold">{analytics.newUsersToday}</p>
              </div>
              <div className="p-4 rounded-lg bg-muted/50">
                <p className="text-sm text-muted-foreground">Avg Session Time</p>
                <p className="text-lg font-semibold">{analytics.avgSessionTime} min</p>
              </div>
              <div className="p-4 rounded-lg bg-muted/50">
                <p className="text-sm text-muted-foreground">Avg Messages/User</p>
                <p className="text-lg font-semibold">
                  {analytics.totalUsers ? (analytics.messagesCount / analytics.totalUsers).toFixed(1) : 0}
                </p>
              </div>
              <div className="p-4 rounded-lg bg-muted/50">
                <p className="text-sm text-muted-foreground">Match Success Rate</p>
                <p className="text-lg font-semibold">{analytics.conversionRate.toFixed(1)}%</p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </AdminNav>
  );
};

export default AdminAnalyticsDashboard;