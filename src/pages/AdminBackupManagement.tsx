import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import AdminNav from "@/components/AdminNav";
import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { useRealtimeSubscription } from "@/hooks/useRealtimeSubscription";
import { 
  ArrowLeft, 
  Database, 
  Download, 
  RefreshCw, 
  HardDrive,
  Clock,
  CheckCircle2,
  XCircle,
  Loader2,
  Calendar,
  Shield,
  Home
} from "lucide-react";
import { format, formatDistanceToNow } from "date-fns";

interface BackupLog {
  id: string;
  backup_type: string;
  status: string;
  size_bytes: number | null;
  storage_path: string | null;
  triggered_by: string | null;
  error_message: string | null;
  started_at: string;
  completed_at: string | null;
  created_at: string;
}

const AdminBackupManagement = () => {
  const navigate = useNavigate();
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  
  const [backups, setBackups] = useState<BackupLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [triggeringBackup, setTriggeringBackup] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const fetchBackupsCb = useCallback(() => { fetchBackups(); }, []);

  useEffect(() => {
    // Mark any backups stuck in 'in_progress' for >30min as failed, then load
    (async () => {
      try { await supabase.rpc('mark_stalled_backups'); } catch (e) { /* non-fatal */ }
      fetchBackups();
    })();
  }, []);

  // Real-time subscription using standardized hook
  useRealtimeSubscription({
    table: "backup_logs",
    onUpdate: fetchBackupsCb,
  });

  const fetchBackups = async () => {
    try {
      const { data, error } = await supabase
        .from('backup_logs')
        .select('*')
        .order('started_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      setBackups(data || []);
    } catch (error: any) {
      console.error("Error fetching backups:", error);
      toast.error("Error", { description: "Failed to load backup logs" });
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      await supabase.rpc('mark_stalled_backups').then(() => {}).catch(() => {});
      await fetchBackups();
      toast.success("Refreshed", { description: "Backup list updated" });
    } finally {
      setRefreshing(false);
    }
  };

  const triggerManualBackup = async () => {
    setTriggeringBackup(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      const response = await supabase.functions.invoke('trigger-backup', {
        body: { backup_type: 'manual' }
      });

      if (response.error) {
        throw new Error(classifyError(response.error, "create backup").message);
      }

      toast.success("Backup Started", { description: "Manual backup has been initiated" });
      
      await fetchBackups();
    } catch (error: any) {
      console.error("Error triggering backup:", error);
      toast.error("Backup Failed", { description: classifyError(error, "trigger the backup").message });
    } finally {
      setTriggeringBackup(false);
    }
  };

  const handleDownloadBackup = async (backup: BackupLog) => {
    if (!backup.storage_path) {
      toast.error("No backup file available", {
        description: "This backup has no stored file. Trigger a fresh manual backup to download.",
      });
      return;
    }

    toast("Downloading Backup", { description: "Fetching backup file from storage..." });
    try {
      const { data, error } = await supabase.storage
        .from('backups')
        .download(backup.storage_path);

      if (error) throw error;

      const url = URL.createObjectURL(data);
      const a = document.createElement('a');
      a.href = url;
      const ext = backup.storage_path.endsWith('.sql.gz') ? 'sql.gz' : 'json';
      a.download = `meow_backup_${format(new Date(backup.started_at), 'yyyy-MM-dd_HHmm')}.${ext}`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      // Defer revoke so download can start
      setTimeout(() => URL.revokeObjectURL(url), 1000);

      toast.success("Backup Downloaded", { description: `Downloaded ${formatBytes(backup.size_bytes)}` });
    } catch (error: any) {
      console.error("Storage download error:", error);
      toast.error("Download Failed", {
        description: error?.message?.includes('Object not found') || error?.message?.includes('not found')
          ? "Backup file no longer exists in storage. Trigger a fresh backup."
          : `Could not download backup: ${error?.message || 'Unknown error'}`,
      });
    }
  };

  const formatBytes = (bytes: number | null) => {
    if (!bytes) return "—";
    const sizes = ["Bytes", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return `${(bytes / Math.pow(1024, i)).toFixed(2)} ${sizes[i]}`;
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case "completed":
        return (
          <Badge variant="success">
            <CheckCircle2 className="w-3 h-3 mr-1" />
            Completed
          </Badge>
        );
      case "in_progress":
        return (
          <Badge variant="warning">
            <Loader2 className="w-3 h-3 mr-1 animate-spin" />
            In Progress
          </Badge>
        );
      case "failed":
        return (
          <Badge variant="destructive">
            <XCircle className="w-3 h-3 mr-1" />
            Failed
          </Badge>
        );
      default:
        return (
          <Badge className="bg-muted text-muted-foreground">
            <Clock className="w-3 h-3 mr-1" />
            {status}
          </Badge>
        );
    }
  };

  const stats = {
    total: backups.length,
    completed: backups.filter(b => b.status === "completed").length,
    failed: backups.filter(b => b.status === "failed").length,
    inProgress: backups.filter(b => b.status === "in_progress").length,
    totalSize: backups
      .filter(b => b.status === "completed" && b.size_bytes)
      .reduce((acc, b) => acc + (b.size_bytes || 0), 0),
  };

  const lastSuccessfulBackup = backups.find(b => b.status === "completed");

  if (adminLoading || !isAdmin) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
          <p className="text-muted-foreground">Loading backup logs...</p>
        </div>
      </div>
    );
  }

  return (
    <AdminNav>
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-foreground flex items-center gap-2">
            <Database className="w-5 h-5 text-primary" />
            Backup Management
          </h1>
          <p className="text-sm text-muted-foreground">
            Schedule and monitor database backups
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={handleRefresh}
            disabled={refreshing}
          >
            <RefreshCw className={`w-4 h-4 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          <Button
            size="sm"
            onClick={triggerManualBackup}
            disabled={triggeringBackup || stats.inProgress > 0}
            className="bg-primary hover:bg-primary/90"
          >
            {triggeringBackup ? (
              <Loader2 className="w-4 h-4 mr-2 animate-spin" />
            ) : (
              <HardDrive className="w-4 h-4 mr-2" />
            )}
            Manual Backup
          </Button>
        </div>
      </div>

      <div className="space-y-6">
        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <Card className="bg-card border-border">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Total Backups</p>
                  <p className="text-2xl font-bold text-foreground">{stats.total}</p>
                </div>
                <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <Database className="w-6 h-6 text-primary" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-card border-border">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Successful</p>
                  <p className="text-2xl font-bold text-emerald-400">{stats.completed}</p>
                </div>
                <div className="w-12 h-12 rounded-full bg-emerald-500/10 flex items-center justify-center">
                  <CheckCircle2 className="w-6 h-6 text-emerald-400" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-card border-border">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Failed</p>
                  <p className="text-2xl font-bold text-destructive">{stats.failed}</p>
                </div>
                <div className="w-12 h-12 rounded-full bg-destructive/10 flex items-center justify-center">
                  <XCircle className="w-6 h-6 text-destructive" />
                </div>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-card border-border">
            <CardContent className="p-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Total Size</p>
                  <p className="text-2xl font-bold text-foreground">{formatBytes(stats.totalSize)}</p>
                </div>
                <div className="w-12 h-12 rounded-full bg-info/10 flex items-center justify-center">
                  <HardDrive className="w-6 h-6 text-info" />
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Last Backup Info */}
        {lastSuccessfulBackup && (
          <Card className="bg-gradient-to-r from-primary/10 to-primary/5 border-primary/20">
            <CardContent className="p-4">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-primary/20 flex items-center justify-center">
                  <Shield className="w-6 h-6 text-primary" />
                </div>
                <div className="flex-1">
                  <p className="text-sm text-muted-foreground">Last Successful Backup</p>
                  <p className="text-lg font-semibold text-foreground">
                    {formatDistanceToNow(new Date(lastSuccessfulBackup.completed_at!), { addSuffix: true })}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-sm text-muted-foreground">Size</p>
                  <p className="text-lg font-semibold text-foreground">
                    {formatBytes(lastSuccessfulBackup.size_bytes)}
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* In Progress Backup */}
        {stats.inProgress > 0 && (
          <Card className="bg-warning/5 border-warning/20">
            <CardContent className="p-4">
              <div className="flex items-center gap-4">
                <Loader2 className="w-8 h-8 text-warning animate-spin" />
                <div className="flex-1">
                  <p className="font-medium text-foreground">Backup in Progress</p>
                  <p className="text-sm text-muted-foreground">Please wait while the backup completes...</p>
                  <Progress value={undefined} className="mt-2 h-2" />
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Backup List */}
        <Card className="bg-card border-border">
          <CardHeader>
            <CardTitle className="text-foreground">Backup History</CardTitle>
            <CardDescription>View and manage all database backups</CardDescription>
          </CardHeader>
          <CardContent>
            {backups.length === 0 ? (
              <div className="text-center py-12">
                <Database className="w-12 h-12 mx-auto text-muted-foreground/50 mb-4" />
                <p className="text-muted-foreground">No backups yet</p>
                <p className="text-sm text-muted-foreground">Click "Manual Backup" to create your first backup</p>
              </div>
            ) : (
              <div className="space-y-3">
                {backups.map((backup, index) => (
                  <div
                    key={backup.id}
                    className={`p-4 rounded-lg border transition-all duration-300 ${
                      backup.status === "in_progress" 
                        ? "bg-warning/5 border-warning/20 animate-pulse" 
                        : "bg-muted/30 border-border hover:bg-muted/50"
                    }`}
                    style={{ animationDelay: `${index * 50}ms` }}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-4">
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center ${
                          backup.status === "completed" 
                            ? "bg-success/10" 
                            : backup.status === "failed" 
                            ? "bg-destructive/10" 
                            : "bg-warning/10"
                        }`}>
                          {backup.status === "in_progress" ? (
                            <Loader2 className="w-5 h-5 text-warning animate-spin" />
                          ) : backup.status === "completed" ? (
                            <CheckCircle2 className="w-5 h-5 text-success" />
                          ) : (
                            <XCircle className="w-5 h-5 text-destructive" />
                          )}
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <p className="font-medium text-foreground">
                              {backup.backup_type === "manual" ? "Manual Backup" : "Scheduled Backup"}
                            </p>
                            {getStatusBadge(backup.status)}
                          </div>
                          <div className="flex items-center gap-4 mt-1 text-sm text-muted-foreground">
                            <span className="flex items-center gap-1">
                              <Calendar className="w-3 h-3" />
                              {format(new Date(backup.started_at), "MMM dd, yyyy HH:mm")}
                            </span>
                            {backup.size_bytes && (
                              <span className="flex items-center gap-1">
                                <HardDrive className="w-3 h-3" />
                                {formatBytes(backup.size_bytes)}
                              </span>
                            )}
                            {backup.completed_at && (
                              <span className="flex items-center gap-1">
                                <Clock className="w-3 h-3" />
                                {Math.round((new Date(backup.completed_at).getTime() - new Date(backup.started_at).getTime()) / 1000)}s
                              </span>
                            )}
                          </div>
                          {backup.error_message && (
                            <p className="text-sm text-destructive mt-1">{backup.error_message}</p>
                          )}
                        </div>
                      </div>
                      {backup.status === "completed" && backup.storage_path && (
                        <Button 
                          variant="ghost" 
                          size="sm" 
                          className="text-muted-foreground hover:text-foreground"
                          onClick={() => handleDownloadBackup(backup)}
                          title="Download backup file"
                        >
                          <Download className="w-4 h-4" />
                        </Button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Backup Schedule Info */}
        <Card className="bg-card border-border">
          <CardHeader>
            <CardTitle className="text-foreground">Automatic Backups</CardTitle>
            <CardDescription>Supabase automatically manages point-in-time recovery backups</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-start gap-4 p-4 rounded-lg bg-muted/30">
                <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center flex-shrink-0">
                  <Shield className="w-5 h-5 text-primary" />
                </div>
                <div>
                  <p className="font-medium text-foreground">Point-in-Time Recovery</p>
                  <p className="text-sm text-muted-foreground mt-1">
                    Supabase Pro plans include automatic daily backups with point-in-time recovery. 
                    Manual backups shown here are for additional snapshot management.
                  </p>
                </div>
              </div>
              <div className="flex items-start gap-4 p-4 rounded-lg bg-muted/30">
                <div className="w-10 h-10 rounded-full bg-info/10 flex items-center justify-center flex-shrink-0">
                  <Clock className="w-5 h-5 text-info" />
                </div>
                <div>
                  <p className="font-medium text-foreground">Backup Retention</p>
                  <p className="text-sm text-muted-foreground mt-1">
                    Automatic backups are retained based on your Supabase plan. 
                    Manual backups logged here help track administrative actions.
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
    </AdminNav>
  );
};

export default AdminBackupManagement;