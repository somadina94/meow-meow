import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import AdminNav from "@/components/AdminNav";
import { useState, useEffect, useRef, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Progress } from "@/components/ui/progress";
import { 
  ArrowLeft, 
  RefreshCw, 
  Cpu, 
  HardDrive, 
  Users, 
  Clock,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Activity,
  Wifi,
  WifiOff
} from "lucide-react";
import {
  LineChart,
  Line,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend
} from "recharts";
import { ChartContainer, ChartTooltipContent } from "@/components/ui/chart";
import { toast } from "sonner";

interface SystemMetric {
  id: string;
  cpu_usage: number;
  memory_usage: number;
  active_connections: number;
  response_time: number;
  disk_usage: number | null;
  network_in: number | null;
  network_out: number | null;
  error_rate: number | null;
  recorded_at: string;
}

interface SystemAlert {
  id: string;
  alert_type: string;
  metric_name: string;
  threshold_value: number;
  current_value: number;
  message: string;
  is_resolved: boolean;
  resolved_at: string | null;
  created_at: string;
}

const chartConfig = {
  cpu: { label: "CPU", color: "hsl(var(--chart-1))" },
  memory: { label: "Memory", color: "hsl(var(--chart-2))" },
  connections: { label: "Connections", color: "hsl(var(--chart-3))" },
  responseTime: { label: "Response Time", color: "hsl(var(--chart-4))" },
};

const AdminPerformanceMonitoring = () => {
  const navigate = useNavigate();
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState("1h");
  const [metrics, setMetrics] = useState<SystemMetric[]>([]);
  const [alerts, setAlerts] = useState<SystemAlert[]>([]);
  const [currentMetrics, setCurrentMetrics] = useState<SystemMetric | null>(null);
  const [isLive, setIsLive] = useState(true);
  const isLiveRef = useRef(isLive);
  isLiveRef.current = isLive;
  const noDataToastShownRef = useRef(false);

  const getTimeRangeMinutes = useCallback(() => {
    switch (timeRange) {
      case "15m": return 15;
      case "1h": return 60;
      case "6h": return 360;
      case "24h": return 1440;
      default: return 60;
    }
  }, [timeRange]);

  const loadData = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const minutes = getTimeRangeMinutes();
      const startTime = new Date(Date.now() - minutes * 60 * 1000).toISOString();

      const { data: metricsData, error: metricsError } = await supabase
        .from("system_metrics")
        .select("*")
        .gte("recorded_at", startTime)
        .order("recorded_at", { ascending: true })
        .limit(500);

      if (metricsError) throw metricsError;

      const { data: alertsData, error: alertsError } = await supabase
        .from("system_alerts")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(50);

      if (alertsError) throw alertsError;

      const fetchedMetrics = metricsData || [];
      setMetrics(fetchedMetrics);

      // Show "no data" toast only once per session, not on every realtime tick
      if (fetchedMetrics.length === 0 && !silent && !noDataToastShownRef.current) {
        noDataToastShownRef.current = true;
        toast.info("No metrics data", {
          description: "Ensure the collect-metrics Edge Function is running.",
          duration: 5000,
        });
      } else if (fetchedMetrics.length > 0) {
        noDataToastShownRef.current = false;
      }

      if (fetchedMetrics.length > 0) {
        setCurrentMetrics(fetchedMetrics[fetchedMetrics.length - 1]);
      } else {
        setCurrentMetrics({
          id: '',
          cpu_usage: 0,
          memory_usage: 0,
          active_connections: 0,
          response_time: 0,
          disk_usage: 0,
          network_in: 0,
          network_out: 0,
          error_rate: 0,
          recorded_at: new Date().toISOString(),
        });
      }

      setAlerts(alertsData || []);
    } catch (error: any) {
      console.error('Error loading data:', error);
      if (!silent) {
        toast.error("Metrics unavailable", { description: classifyError(error, "load performance metrics").message });
      }
    } finally {
      if (!silent) setLoading(false);
    }
  }, [getTimeRangeMinutes]);

  useEffect(() => {
    loadData();

    // Realtime subscription — read isLive via ref so toggling Live doesn't tear down the channel
    const channel = supabase
      .channel('performance-metrics-rt')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'system_metrics' }, () => {
        if (isLiveRef.current) loadData(true);
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'system_alerts' }, () => {
        if (isLiveRef.current) loadData(true);
      })
      .subscribe((status) => {
        if (status === 'CHANNEL_ERROR') {
          console.warn('[Performance] Realtime channel error, will auto-reconnect');
        }
      });

    return () => { supabase.removeChannel(channel); };
  }, [timeRange, loadData]);

  const resolveAlert = async (alertId: string) => {
    try {
      const { error } = await supabase
        .from("system_alerts")
        .update({ 
          is_resolved: true, 
          resolved_at: new Date().toISOString() 
        })
        .eq("id", alertId);

      if (error) throw error;

      setAlerts(prev => prev.map(a => 
        a.id === alertId 
          ? { ...a, is_resolved: true, resolved_at: new Date().toISOString() }
          : a
      ));
      toast.success("Alert resolved");
    } catch (error: any) {
      toast.error("Alert not resolved", { description: classifyError(error, "resolve the alert").message });
    }
  };

  const getGaugeColor = (value: number, thresholds: { warning: number; critical: number }) => {
    if (value >= thresholds.critical) return "text-destructive";
    if (value >= thresholds.warning) return "text-amber-500";
    return "text-emerald-500";
  };

  const getProgressColor = (value: number, thresholds: { warning: number; critical: number }) => {
    if (value >= thresholds.critical) return "bg-destructive";
    if (value >= thresholds.warning) return "bg-amber-500";
    return "bg-emerald-500";
  };

  const formatChartData = () => {
    return metrics.map(m => ({
      time: new Date(m.recorded_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
      cpu: m.cpu_usage,
      memory: m.memory_usage,
      connections: m.active_connections,
      responseTime: m.response_time,
    }));
  };

  const GaugeCard = ({ 
    title, 
    value, 
    unit, 
    icon: Icon, 
    thresholds 
  }: { 
    title: string; 
    value: number; 
    unit: string; 
    icon: any;
    thresholds: { warning: number; critical: number };
  }) => {
    // Normalize: if thresholds exceed 100, scale relative to 1.25× critical so the bar always reflects load
    const scaleMax = thresholds.critical > 100 ? thresholds.critical * 1.25 : 100;
    const pct = Math.min(100, Math.max(0, (value / scaleMax) * 100));
    const warnPct = Math.min(100, (thresholds.warning / scaleMax) * 100);
    const critPct = Math.min(100, (thresholds.critical / scaleMax) * 100);

    return (
      <Card className="relative overflow-hidden">
        <CardContent className="p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <Icon className={`h-5 w-5 ${getGaugeColor(value, thresholds)}`} />
              <span className="text-sm font-medium text-muted-foreground">{title}</span>
            </div>
            <Badge 
              variant={value >= thresholds.critical ? "destructive" : value >= thresholds.warning ? "secondary" : "outline"}
              className="text-xs"
            >
              {value >= thresholds.critical ? "Critical" : value >= thresholds.warning ? "Warning" : "Normal"}
            </Badge>
          </div>
          <div className="space-y-3">
            <div className={`text-3xl font-bold ${getGaugeColor(value, thresholds)} transition-all duration-500`}>
              {value.toFixed(1)}{unit}
            </div>
            <div className="relative h-3 bg-secondary rounded-full overflow-hidden">
              <div 
                className={`absolute inset-y-0 left-0 ${getProgressColor(value, thresholds)} rounded-full transition-all duration-700 ease-out`}
                style={{ width: `${pct}%` }}
              />
              <div 
                className="absolute inset-y-0 border-l-2 border-dashed border-amber-500 opacity-50"
                style={{ left: `${warnPct}%` }}
              />
              <div 
                className="absolute inset-y-0 border-l-2 border-dashed border-destructive opacity-50"
                style={{ left: `${critPct}%` }}
              />
            </div>
          </div>
        </CardContent>
      </Card>
    );
  };

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
        <div className="flex items-center justify-center py-20">
          <div className="w-12 h-12 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
        </div>
      </AdminNav>
    );
  }

  return (
    <AdminNav>
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-foreground">Performance Monitoring</h1>
          <p className="text-sm text-muted-foreground">Real-time server & app metrics from database</p>
        </div>
        <div className="flex items-center gap-3">
          <Button
            variant={isLive ? "default" : "outline"}
            size="sm"
            onClick={() => setIsLive(!isLive)}
            className="gap-2"
          >
            {isLive ? <Wifi className="h-4 w-4" /> : <WifiOff className="h-4 w-4" />}
            {isLive ? "Live" : "Paused"}
          </Button>
          <Select value={timeRange} onValueChange={setTimeRange}>
            <SelectTrigger className="w-[120px]">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="15m">Last 15m</SelectItem>
              <SelectItem value="1h">Last 1h</SelectItem>
              <SelectItem value="6h">Last 6h</SelectItem>
              <SelectItem value="24h">Last 24h</SelectItem>
            </SelectContent>
          </Select>
          <Button variant="outline" size="icon" onClick={() => loadData()}>
            <RefreshCw className="h-4 w-4" />
          </Button>
        </div>
      </div>

      <div className="space-y-6">
        {/* Live Indicator */}
        {isLive && (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
            </span>
            Live updates enabled (realtime via Supabase)
          </div>
        )}

        {/* No Data Message */}
        {metrics.length === 0 && (
          <Card className="p-8 text-center">
            <Activity className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
            <h3 className="text-lg font-semibold mb-2">No Metrics Data</h3>
            <p className="text-muted-foreground mb-4">
              No system metrics have been recorded yet. The <code className="text-xs bg-muted px-1.5 py-0.5 rounded">collect-metrics</code> edge function needs to run periodically (via pg_cron or an external scheduler) to populate this data.
            </p>
            <Button
              variant="outline"
              size="sm"
              onClick={async () => {
                try {
                  toast.info("Collecting metrics...");
                  const { error } = await supabase.functions.invoke('collect-metrics');
                  if (error) throw error;
                  toast.success("Metrics collected successfully");
                  loadData();
                } catch (e: any) {
                  toast.error("Failed to collect metrics", { description: e.message });
                }
              }}
            >
              <Activity className="h-4 w-4 mr-2" />
              Collect Metrics Now
            </Button>
          </Card>
        )}

        {/* Gauge Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <GaugeCard
            title="CPU Usage"
            value={currentMetrics?.cpu_usage || 0}
            unit="%"
            icon={Cpu}
            thresholds={{ warning: 70, critical: 85 }}
          />
          <GaugeCard
            title="Memory Usage"
            value={currentMetrics?.memory_usage || 0}
            unit="%"
            icon={HardDrive}
            thresholds={{ warning: 75, critical: 90 }}
          />
          <GaugeCard
            title="Active Connections"
            value={currentMetrics?.active_connections || 0}
            unit=""
            icon={Users}
            thresholds={{ warning: 400, critical: 600 }}
          />
          <GaugeCard
            title="Response Time"
            value={currentMetrics?.response_time || 0}
            unit="ms"
            icon={Clock}
            thresholds={{ warning: 100, critical: 200 }}
          />
        </div>

        {/* Charts */}
        {metrics.length > 0 && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* CPU & Memory Chart */}
            <Card>
              <CardHeader>
                <CardTitle className="text-base flex items-center gap-2">
                  <Activity className="h-4 w-4 text-primary" />
                  CPU & Memory Usage
                </CardTitle>
              </CardHeader>
              <CardContent>
                <ChartContainer config={chartConfig} className="h-[250px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={formatChartData()}>
                      <defs>
                        <linearGradient id="cpuGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="hsl(var(--chart-1))" stopOpacity={0.3} />
                          <stop offset="95%" stopColor="hsl(var(--chart-1))" stopOpacity={0} />
                        </linearGradient>
                        <linearGradient id="memoryGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="hsl(var(--chart-2))" stopOpacity={0.3} />
                          <stop offset="95%" stopColor="hsl(var(--chart-2))" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                      <XAxis dataKey="time" className="text-xs" />
                      <YAxis domain={[0, 100]} className="text-xs" />
                      <Tooltip content={<ChartTooltipContent />} />
                      <Legend />
                      <Area
                        type="monotone"
                        dataKey="cpu"
                        stroke="hsl(var(--chart-1))"
                        fill="url(#cpuGradient)"
                        strokeWidth={2}
                        animationDuration={500}
                      />
                      <Area
                        type="monotone"
                        dataKey="memory"
                        stroke="hsl(var(--chart-2))"
                        fill="url(#memoryGradient)"
                        strokeWidth={2}
                        animationDuration={500}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </ChartContainer>
              </CardContent>
            </Card>

            {/* Response Time Chart */}
            <Card>
              <CardHeader>
                <CardTitle className="text-base flex items-center gap-2">
                  <Clock className="h-4 w-4 text-primary" />
                  Response Time (ms)
                </CardTitle>
              </CardHeader>
              <CardContent>
                <ChartContainer config={chartConfig} className="h-[250px] w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={formatChartData()}>
                      <CartesianGrid strokeDasharray="3 3" className="stroke-muted" />
                      <XAxis dataKey="time" className="text-xs" />
                      <YAxis className="text-xs" />
                      <Tooltip content={<ChartTooltipContent />} />
                      <Line
                        type="monotone"
                        dataKey="responseTime"
                        stroke="hsl(var(--chart-4))"
                        strokeWidth={2}
                        dot={false}
                        animationDuration={500}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </ChartContainer>
              </CardContent>
            </Card>
          </div>
        )}

        {/* Additional Metrics Row */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card className="p-4">
            <div className="text-sm text-muted-foreground">Disk Usage</div>
            <div className="text-2xl font-bold text-foreground mt-1">
              {(currentMetrics?.disk_usage || 0).toFixed(1)}%
            </div>
            <Progress value={currentMetrics?.disk_usage || 0} className="mt-2 h-1.5" />
          </Card>
          <Card className="p-4">
            <div className="text-sm text-muted-foreground">Network In</div>
            <div className="text-2xl font-bold text-foreground mt-1">
              {(currentMetrics?.network_in || 0).toFixed(1)} MB/s
            </div>
          </Card>
          <Card className="p-4">
            <div className="text-sm text-muted-foreground">Network Out</div>
            <div className="text-2xl font-bold text-foreground mt-1">
              {(currentMetrics?.network_out || 0).toFixed(1)} MB/s
            </div>
          </Card>
          <Card className="p-4">
            <div className="text-sm text-muted-foreground">Error Rate</div>
            <div className={`text-2xl font-bold mt-1 ${(currentMetrics?.error_rate || 0) > 1 ? 'text-destructive' : 'text-emerald-500'}`}>
              {(currentMetrics?.error_rate || 0).toFixed(2)}%
            </div>
          </Card>
        </div>

        {/* Alerts Panel */}
        <Card>
          <CardHeader>
            <CardTitle className="text-base flex items-center gap-2">
              <AlertTriangle className="h-4 w-4 text-amber-500" />
              System Alerts
              {alerts.filter(a => !a.is_resolved).length > 0 && (
                <Badge variant="destructive" className="ml-2">
                  {alerts.filter(a => !a.is_resolved).length} Active
                </Badge>
              )}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <ScrollArea className="h-[200px]">
              {alerts.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  <CheckCircle className="h-8 w-8 mx-auto mb-2 text-emerald-500" />
                  <p>No alerts - All systems operational</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {alerts.map((alert) => (
                    <div
                      key={alert.id}
                      className={`p-3 rounded-lg border ${
                        alert.is_resolved
                          ? 'bg-muted/50 border-muted'
                          : alert.alert_type === 'critical'
                          ? 'bg-destructive/10 border-destructive/30'
                          : 'bg-amber-500/10 border-amber-500/30'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex items-start gap-2">
                          {alert.is_resolved ? (
                            <CheckCircle className="h-4 w-4 text-emerald-500 mt-0.5" />
                          ) : alert.alert_type === 'critical' ? (
                            <XCircle className="h-4 w-4 text-destructive mt-0.5" />
                          ) : (
                            <AlertTriangle className="h-4 w-4 text-amber-500 mt-0.5" />
                          )}
                          <div>
                            <p className="text-sm font-medium">{alert.message}</p>
                            <p className="text-xs text-muted-foreground mt-1">
                              {new Date(alert.created_at).toLocaleString()}
                              {alert.is_resolved && alert.resolved_at && (
                                <span className="ml-2 text-emerald-500">
                                  • Resolved {new Date(alert.resolved_at).toLocaleString()}
                                </span>
                              )}
                            </p>
                          </div>
                        </div>
                        {!alert.is_resolved && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => resolveAlert(alert.id)}
                            className="shrink-0"
                          >
                            Resolve
                          </Button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </ScrollArea>
          </CardContent>
        </Card>
      </div>
    </div>
    </AdminNav>
  );
};

export default AdminPerformanceMonitoring;
