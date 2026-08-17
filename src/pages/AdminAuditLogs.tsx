import AdminNav from "@/components/AdminNav";
import { useState, useEffect, useMemo, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { useRealtimeSubscription } from "@/hooks/useRealtimeSubscription";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Calendar } from "@/components/ui/calendar";
import { toast } from "sonner";
import { format } from "date-fns";
import { 
  ArrowLeft, 
  Search, 
  Download, 
  RefreshCw,
  Calendar as CalendarIcon,
  Shield,
  Filter,
  FileText,
  User,
  Settings,
  Trash2,
  Plus,
  Edit,
  LogIn,
  AlertTriangle,
  CheckCircle,
  XCircle,
  ChevronLeft,
  ChevronRight
} from "lucide-react";

interface AuditLog {
  id: string;
  admin_id: string;
  admin_email: string | null;
  action: string;
  action_type: string;
  resource_type: string;
  resource_id: string | null;
  old_value: any;
  new_value: any;
  ip_address: string | null;
  details: string | null;
  status: string;
  created_at: string;
}

const ACTION_TYPE_ICONS: Record<string, any> = {
  create: Plus,
  update: Edit,
  delete: Trash2,
  auth: LogIn,
  view: FileText,
};

const ACTION_TYPE_COLORS: Record<string, string> = {
  create: "bg-primary/10 text-primary border-primary/20",
  update: "bg-primary/10 text-primary border-primary/20",
  delete: "bg-destructive/10 text-destructive border-destructive/20",
  auth: "bg-primary/10 text-primary border-primary/20",
  view: "bg-muted text-muted-foreground border-muted",
};

const RESOURCE_TYPE_ICONS: Record<string, any> = {
  users: User,
  settings: Settings,
  security: Shield,
  gifts: FileText,
  messages: FileText,
  backup: FileText,
  session: LogIn,
  withdrawals: FileText,
  language_groups: FileText,
};

const AdminAuditLogs = () => {
  const navigate = useNavigate();
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  const [loading, setLoading] = useState(true);
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [actionTypeFilter, setActionTypeFilter] = useState<string>("all");
  const [resourceTypeFilter, setResourceTypeFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [dateRange, setDateRange] = useState<{ from: Date | undefined; to: Date | undefined }>({
    from: undefined,
    to: undefined,
  });
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 20;

  const loadLogs = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from("audit_logs")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(500);

      if (error) throw error;
      setLogs((data as AuditLog[]) || []);
    } catch (error) {
      console.error("Error loading logs:", error);
      toast.error("Error", { description: "Failed to load audit logs" });
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Real-time subscription for audit logs
  useRealtimeSubscription({
    table: "audit_logs",
    onUpdate: loadLogs
  });

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  const filteredLogs = useMemo(() => {
    return logs.filter(log => {
      // Search filter
      const searchLower = searchQuery.toLowerCase();
      const matchesSearch = !searchQuery || 
        log.action.toLowerCase().includes(searchLower) ||
        log.admin_email?.toLowerCase().includes(searchLower) ||
        log.details?.toLowerCase().includes(searchLower) ||
        log.resource_type.toLowerCase().includes(searchLower);

      // Action type filter
      const matchesActionType = actionTypeFilter === "all" || log.action_type === actionTypeFilter;

      // Resource type filter
      const matchesResourceType = resourceTypeFilter === "all" || log.resource_type === resourceTypeFilter;

      // Status filter
      const matchesStatus = statusFilter === "all" || log.status === statusFilter;

      // Date range filter
      const logDate = new Date(log.created_at);
      const matchesDateFrom = !dateRange.from || logDate >= dateRange.from;
      const matchesDateTo = !dateRange.to || logDate <= new Date(dateRange.to.getTime() + 86400000);

      return matchesSearch && matchesActionType && matchesResourceType && matchesStatus && matchesDateFrom && matchesDateTo;
    });
  }, [logs, searchQuery, actionTypeFilter, resourceTypeFilter, statusFilter, dateRange]);

  const paginatedLogs = useMemo(() => {
    const startIndex = (currentPage - 1) * itemsPerPage;
    return filteredLogs.slice(startIndex, startIndex + itemsPerPage);
  }, [filteredLogs, currentPage]);

  const totalPages = Math.ceil(filteredLogs.length / itemsPerPage);

  const uniqueActionTypes = [...new Set(logs.map(l => l.action_type))];
  const uniqueResourceTypes = [...new Set(logs.map(l => l.resource_type))];

  const exportCSV = () => {
    const headers = ["Timestamp", "Admin", "Action", "Type", "Resource", "Details", "Status"];
    const rows = filteredLogs.map(log => [
      new Date(log.created_at).toISOString(),
      log.admin_email || log.admin_id,
      log.action,
      log.action_type,
      log.resource_type,
      log.details || "",
      log.status,
    ]);

    const csvContent = [headers, ...rows]
      .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(","))
      .join("\n");

    const blob = new Blob([csvContent], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = `audit_logs_${format(new Date(), "yyyy-MM-dd_HH-mm")}.csv`;
    link.click();
    URL.revokeObjectURL(url);

    toast.success("Export complete", { description: `Exported ${filteredLogs.length} log entries` });
  };

  const clearFilters = () => {
    setSearchQuery("");
    setActionTypeFilter("all");
    setResourceTypeFilter("all");
    setStatusFilter("all");
    setDateRange({ from: undefined, to: undefined });
    setCurrentPage(1);
  };

  const hasActiveFilters = searchQuery || actionTypeFilter !== "all" || resourceTypeFilter !== "all" || statusFilter !== "all" || dateRange.from || dateRange.to;

  if (adminLoading || !isAdmin) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-primary/30 border-t-primary rounded-full animate-spin" />
      </div>
    );
  }

  if (loading) {
    return (
      <AdminNav><div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-primary border-t-transparent" />
      </div></AdminNav>
    );
  }

  return (
    <AdminNav>
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-6 gap-3">
        <div>
          <h1 className="text-lg sm:text-xl font-bold text-foreground flex items-center gap-2">
            <Shield className="h-5 w-5 text-primary" />
            Audit Logs
          </h1>
          <p className="text-sm text-muted-foreground">Track admin actions for compliance</p>
        </div>
        <div className="flex items-center gap-2 flex-wrap">
          <Button variant="outline" size="sm" onClick={loadLogs} className="gap-2">
            <RefreshCw className="h-4 w-4" />
            <span className="hidden sm:inline">Refresh</span>
          </Button>
          <Button size="sm" onClick={exportCSV} className="gap-2">
            <Download className="h-4 w-4" />
            <span className="hidden sm:inline">Export CSV</span>
          </Button>
        </div>
      </div>

      <div className="space-y-6">
        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card className="p-4">
            <div className="text-2xl font-bold text-foreground">{logs.length}</div>
            <div className="text-sm text-muted-foreground">Total Logs</div>
          </Card>
          <Card className="p-4">
            <div className="text-2xl font-bold text-primary">
              {logs.filter(l => l.status === "success").length}
            </div>
            <div className="text-sm text-muted-foreground">Successful</div>
          </Card>
          <Card className="p-4">
            <div className="text-2xl font-bold text-destructive">
              {logs.filter(l => l.status === "failed").length}
            </div>
            <div className="text-sm text-muted-foreground">Failed</div>
          </Card>
          <Card className="p-4">
            <div className="text-2xl font-bold text-foreground">
              {new Set(logs.map(l => l.admin_email)).size}
            </div>
            <div className="text-sm text-muted-foreground">Active Admins</div>
          </Card>
        </div>

        {/* Filters */}
        <Card>
          <CardHeader className="pb-4">
            <CardTitle className="text-base flex items-center gap-2">
              <Filter className="h-4 w-4 text-primary" />
              Filters
              {hasActiveFilters && (
                <Button variant="ghost" size="sm" onClick={clearFilters} className="ml-auto text-xs">
                  Clear all
                </Button>
              )}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
              {/* Search */}
              <div className="relative lg:col-span-2">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Search actions, admins, details..."
                  value={searchQuery}
                  onChange={(e) => {
                    setSearchQuery(e.target.value);
                    setCurrentPage(1);
                  }}
                  className="pl-10"
                />
              </div>

              {/* Action Type Filter */}
              <Select value={actionTypeFilter} onValueChange={(v) => { setActionTypeFilter(v); setCurrentPage(1); }}>
                <SelectTrigger className="bg-background">
                  <SelectValue placeholder="Action Type" />
                </SelectTrigger>
                <SelectContent className="bg-popover border border-border z-50">
                  <SelectItem value="all">All Types</SelectItem>
                  {uniqueActionTypes.map(type => (
                    <SelectItem key={type} value={type} className="capitalize">{type}</SelectItem>
                  ))}
                </SelectContent>
              </Select>

              {/* Resource Type Filter */}
              <Select value={resourceTypeFilter} onValueChange={(v) => { setResourceTypeFilter(v); setCurrentPage(1); }}>
                <SelectTrigger className="bg-background">
                  <SelectValue placeholder="Resource" />
                </SelectTrigger>
                <SelectContent className="bg-popover border border-border z-50">
                  <SelectItem value="all">All Resources</SelectItem>
                  {uniqueResourceTypes.map(type => (
                    <SelectItem key={type} value={type} className="capitalize">{type}</SelectItem>
                  ))}
                </SelectContent>
              </Select>

              {/* Status Filter */}
              <Select value={statusFilter} onValueChange={(v) => { setStatusFilter(v); setCurrentPage(1); }}>
                <SelectTrigger className="bg-background">
                  <SelectValue placeholder="Status" />
                </SelectTrigger>
                <SelectContent className="bg-popover border border-border z-50">
                  <SelectItem value="all">All Status</SelectItem>
                  <SelectItem value="success">Success</SelectItem>
                  <SelectItem value="failed">Failed</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Date Range */}
            <div className="mt-4 flex flex-wrap gap-2">
              <Popover>
                <PopoverTrigger asChild>
                  <Button variant="outline" size="sm" className="gap-2">
                    <CalendarIcon className="h-4 w-4" />
                    {dateRange.from ? format(dateRange.from, "MMM dd, yyyy") : "Start Date"}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0 bg-popover border border-border z-50" align="start">
                  <Calendar
                    mode="single"
                    selected={dateRange.from}
                    onSelect={(date) => setDateRange(prev => ({ ...prev, from: date }))}
                    initialFocus
                  />
                </PopoverContent>
              </Popover>

              <Popover>
                <PopoverTrigger asChild>
                  <Button variant="outline" size="sm" className="gap-2">
                    <CalendarIcon className="h-4 w-4" />
                    {dateRange.to ? format(dateRange.to, "MMM dd, yyyy") : "End Date"}
                  </Button>
                </PopoverTrigger>
                <PopoverContent className="w-auto p-0 bg-popover border border-border z-50" align="start">
                  <Calendar
                    mode="single"
                    selected={dateRange.to}
                    onSelect={(date) => setDateRange(prev => ({ ...prev, to: date }))}
                    initialFocus
                  />
                </PopoverContent>
              </Popover>

              {(dateRange.from || dateRange.to) && (
                <Button 
                  variant="ghost" 
                  size="sm" 
                  onClick={() => setDateRange({ from: undefined, to: undefined })}
                >
                  Clear dates
                </Button>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Logs Table */}
        <Card>
          <CardHeader className="pb-0">
            <div className="flex items-center justify-between">
              <CardTitle className="text-base">
                Showing {paginatedLogs.length} of {filteredLogs.length} logs
              </CardTitle>
            </div>
          </CardHeader>
          <CardContent className="p-0">
            <ScrollArea className="h-[500px]">
              <div className="min-w-[800px]">
              <Table>
                <TableHeader className="sticky top-0 bg-background z-10">
                  <TableRow>
                    <TableHead className="w-[180px]">Timestamp</TableHead>
                    <TableHead>Admin</TableHead>
                    <TableHead>Action</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Resource</TableHead>
                    <TableHead className="min-w-[200px]">Details</TableHead>
                    <TableHead>Status</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {paginatedLogs.map((log, index) => {
                    const ActionIcon = ACTION_TYPE_ICONS[log.action_type] || Edit;
                    const ResourceIcon = RESOURCE_TYPE_ICONS[log.resource_type] || FileText;
                    
                    return (
                      <TableRow 
                        key={log.id}
                        className="animate-in fade-in slide-in-from-left-2"
                        style={{ animationDelay: `${index * 20}ms` }}
                      >
                        <TableCell className="font-mono text-xs text-muted-foreground">
                          {format(new Date(log.created_at), "MMM dd, yyyy")}
                          <br />
                          {format(new Date(log.created_at), "HH:mm:ss")}
                        </TableCell>
                        <TableCell>
                          <div className="flex items-center gap-2">
                            <div className="h-7 w-7 rounded-full bg-primary/10 flex items-center justify-center">
                              <User className="h-3.5 w-3.5 text-primary" />
                            </div>
                            <span className="text-sm truncate max-w-[120px]">
                              {log.admin_email || "System"}
                            </span>
                          </div>
                        </TableCell>
                        <TableCell className="font-medium text-foreground">
                          {log.action}
                        </TableCell>
                        <TableCell>
                          <Badge 
                            variant="outline" 
                            className={`gap-1 ${ACTION_TYPE_COLORS[log.action_type] || ACTION_TYPE_COLORS.view}`}
                          >
                            <ActionIcon className="h-3 w-3" />
                            {log.action_type}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          <div className="flex items-center gap-1.5">
                            <ResourceIcon className="h-3.5 w-3.5 text-muted-foreground" />
                            <span className="capitalize text-sm">{log.resource_type}</span>
                          </div>
                        </TableCell>
                        <TableCell>
                          <span className="text-sm text-muted-foreground line-clamp-2">
                            {log.details || "-"}
                          </span>
                        </TableCell>
                        <TableCell>
                          {log.status === "success" ? (
                            <Badge variant="outline" className="bg-primary/10 text-primary border-primary/20 gap-1">
                              <CheckCircle className="h-3 w-3" />
                              Success
                            </Badge>
                          ) : log.status === "failed" ? (
                            <Badge variant="outline" className="bg-destructive/10 text-destructive border-destructive/20 gap-1">
                              <XCircle className="h-3 w-3" />
                              Failed
                            </Badge>
                          ) : (
                            <Badge variant="outline" className="gap-1">
                              <AlertTriangle className="h-3 w-3" />
                              {log.status}
                            </Badge>
                          )}
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
              </div>
              {paginatedLogs.length === 0 && (
                <div className="text-center py-12 text-muted-foreground">
                  <Shield className="h-12 w-12 mx-auto mb-4 opacity-20" />
                  <p>No logs found matching your filters</p>
                </div>
              )}
            </ScrollArea>

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between px-4 py-3 border-t border-border">
                <div className="text-sm text-muted-foreground">
                  Page {currentPage} of {totalPages}
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                    disabled={currentPage === 1}
                  >
                    <ChevronLeft className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                    disabled={currentPage === totalPages}
                  >
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </AdminNav>
  );
};

export default AdminAuditLogs;