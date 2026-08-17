import AdminNav from "@/components/AdminNav";
import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { toast } from "sonner";
import { languages } from "@/data/languages";
import { 
  ArrowLeft, 
  Plus, 
  Pencil, 
  Trash2, 
  Search, 
  MessageCircle,
  Video,
  Users,
  Save,
  RefreshCw,
  Home
} from "lucide-react";

interface LanguageLimit {
  id: string;
  language_name: string;
  max_chat_women: number;
  max_call_women: number;
  current_chat_women: number;
  current_call_women: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

const AdminLanguageLimits = () => {
  const navigate = useNavigate();
  
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  const [limits, setLimits] = useState<LanguageLimit[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingLimit, setEditingLimit] = useState<LanguageLimit | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  // Form state
  const [formLanguage, setFormLanguage] = useState("");
  const [formMaxChat, setFormMaxChat] = useState(50);
  const [formMaxCall, setFormMaxCall] = useState(20);
  const [formIsActive, setFormIsActive] = useState(true);

  useEffect(() => {
    if (adminLoading || !isAdmin) return;
    loadLimits();
    
    // Set up real-time subscription
    // FIX #19: Guard channel behind isAdmin and add error handler
    if (!isAdmin) return;
    const channel = supabase
      .channel('language-limits-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'language_limits' },
        () => {
          loadLimits();
        }
      )
      .subscribe((status) => {
        if (status === 'CHANNEL_ERROR') {
          console.warn('[LanguageLimits] Realtime channel error');
        }
      });

    return () => {
      supabase.removeChannel(channel);
    };
  }, [isAdmin, adminLoading]);

  const loadLimits = async () => {
    try {
      const { data, error } = await supabase
        .from("language_limits")
        .select("*")
        .order("language_name", { ascending: true });

      if (error) throw error;
      setLimits(data || []);
    } catch (error) {
      console.error("Error loading language limits:", error);
      toast.error("Error", { description: "Failed to load language limits" });
    } finally {
      setLoading(false);
    }
  };

  const getLanguageDisplayName = (code: string) => {
    const lang = languages.find((l) => l.code === code || l.name.toLowerCase() === code.toLowerCase());
    return lang ? lang.name : code;
  };

  const filteredLimits = limits.filter((limit) =>
    limit.language_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    getLanguageDisplayName(limit.language_name).toLowerCase().includes(searchTerm.toLowerCase())
  );

  const openCreateDialog = () => {
    setEditingLimit(null);
    setFormLanguage("");
    setFormMaxChat(50);
    setFormMaxCall(20);
    setFormIsActive(true);
    setIsDialogOpen(true);
  };

  const openEditDialog = (limit: LanguageLimit) => {
    setEditingLimit(limit);
    setFormLanguage(limit.language_name);
    setFormMaxChat(limit.max_chat_women);
    setFormMaxCall(limit.max_call_women);
    setFormIsActive(limit.is_active);
    setIsDialogOpen(true);
  };

  const handleSave = async () => {
    if (!formLanguage.trim()) {
      toast.error("Validation Error", { description: "Language name is required" });
      return;
    }

    if (formMaxChat < 1 || formMaxCall < 1) {
      toast.error("Validation Error", { description: "Maximum values must be at least 1" });
      return;
    }

    setIsSaving(true);
    try {
      if (editingLimit) {
        const { error } = await supabase
          .from("language_limits")
          .update({
            language_name: formLanguage.trim(),
            max_chat_women: formMaxChat,
            max_call_women: formMaxCall,
            is_active: formIsActive,
            updated_at: new Date().toISOString()
          })
          .eq("id", editingLimit.id);

        if (error) throw error;
        toast.success("Success", { description: "Language limit updated" });
      } else {
        const { error } = await supabase.from("language_limits").insert({
          language_name: formLanguage.trim(),
          max_chat_women: formMaxChat,
          max_call_women: formMaxCall,
          is_active: formIsActive,
        });

        if (error) throw error;
        toast.success("Success", { description: "Language limit created" });
      }

      setIsDialogOpen(false);
      loadLimits();
    } catch (error) {
      console.error("Error saving language limit:", error);
      toast.error("Error", { description: "Failed to save language limit" });
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async (limit: LanguageLimit) => {
    if (!confirm(`Delete limit for "${limit.language_name}"? This action cannot be undone.`)) return;

    try {
      const { error } = await supabase
        .from("language_limits")
        .delete()
        .eq("id", limit.id);

      if (error) throw error;
      toast.success("Success", { description: "Language limit deleted" });
      loadLimits();
    } catch (error) {
      console.error("Error deleting language limit:", error);
      toast.error("Error", { description: "Failed to delete language limit" });
    }
  };

  const toggleLimitActive = async (limit: LanguageLimit) => {
    try {
      const { error } = await supabase
        .from("language_limits")
        .update({ is_active: !limit.is_active })
        .eq("id", limit.id);

      if (error) throw error;
      loadLimits();
    } catch (error) {
      console.error("Error toggling limit status:", error);
      toast.error("Error", { description: "Failed to update limit status" });
    }
  };

  const totalChatCapacity = limits.reduce((sum, l) => sum + l.max_chat_women, 0);
  const totalCallCapacity = limits.reduce((sum, l) => sum + l.max_call_women, 0);
  const currentChatWomen = limits.reduce((sum, l) => sum + l.current_chat_women, 0);
  const currentCallWomen = limits.reduce((sum, l) => sum + l.current_call_women, 0);

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
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary" />
      </div>
    );
  }

  return (
    <AdminNav>
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Users className="h-6 w-6 text-primary" />
          <h1 className="text-xl font-semibold">Language Limits</h1>
        </div>
        <Button onClick={openCreateDialog} className="gap-2">
          <Plus className="h-4 w-4" />
          Add Limit
        </Button>
      </div>

      <div className="space-y-6">
        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center gap-2">
                <MessageCircle className="h-5 w-5 text-primary" />
                <div>
                  <div className="text-2xl font-bold">{currentChatWomen}/{totalChatCapacity}</div>
                  <div className="text-sm text-muted-foreground">Chat Women</div>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="flex items-center gap-2">
                <Video className="h-5 w-5 text-primary" />
                <div>
                  <div className="text-2xl font-bold">{currentCallWomen}/{totalCallCapacity}</div>
                  <div className="text-sm text-muted-foreground">Video Women</div>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold">{limits.length}</div>
              <div className="text-sm text-muted-foreground">Languages</div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold text-primary">
                {limits.filter((l) => l.is_active).length}
              </div>
              <div className="text-sm text-muted-foreground">Active</div>
            </CardContent>
          </Card>
        </div>

        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search languages..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="pl-9"
          />
        </div>

        {/* Limits Table */}
        <Card>
          <CardHeader>
            <CardTitle>Language Capacity Limits</CardTitle>
            <CardDescription>
              Set maximum women per language for chat and video calls
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Language</TableHead>
                  <TableHead className="text-center">Max Chat</TableHead>
                  <TableHead className="text-center">Current Chat</TableHead>
                  <TableHead className="text-center">Max Video</TableHead>
                  <TableHead className="text-center">Current Video</TableHead>
                  <TableHead className="text-center">Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredLimits.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center py-8 text-muted-foreground">
                      {searchTerm ? "No languages match your search" : "No language limits configured yet"}
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredLimits.map((limit) => (
                    <TableRow key={limit.id} className={!limit.is_active ? "opacity-60" : ""}>
                      <TableCell className="font-medium">
                        {getLanguageDisplayName(limit.language_name)}
                      </TableCell>
                      <TableCell className="text-center">
                        <Badge variant="outline" className="bg-primary/5">
                          {limit.max_chat_women}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-center">
                        <span className={limit.current_chat_women >= limit.max_chat_women ? "text-destructive font-semibold" : ""}>
                          {limit.current_chat_women}
                        </span>
                      </TableCell>
                      <TableCell className="text-center">
                        <Badge variant="outline" className="bg-primary/5">
                          {limit.max_call_women}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-center">
                        <span className={limit.current_call_women >= limit.max_call_women ? "text-destructive font-semibold" : ""}>
                          {limit.current_call_women}
                        </span>
                      </TableCell>
                      <TableCell className="text-center">
                        <Switch
                          checked={limit.is_active}
                          onCheckedChange={() => toggleLimitActive(limit)}
                        />
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex items-center justify-end gap-1">
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => openEditDialog(limit)}
                          >
                            <Pencil className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => handleDelete(limit)}
                            className="text-destructive hover:text-destructive"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </div>

      {/* Create/Edit Dialog */}
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {editingLimit ? "Edit Language Limit" : "Add Language Limit"}
            </DialogTitle>
            <DialogDescription>
              Set maximum women capacity for this language
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="language">Language Name *</Label>
              <Input
                id="language"
                value={formLanguage}
                onChange={(e) => setFormLanguage(e.target.value)}
                placeholder="e.g., Hindi, English, Tamil"
                disabled={!!editingLimit}
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="maxChat" className="flex items-center gap-2">
                  <MessageCircle className="h-4 w-4" />
                  Max Chat Women
                </Label>
                <Input
                  id="maxChat"
                  type="number"
                  min={1}
                  value={formMaxChat}
                  onChange={(e) => setFormMaxChat(parseInt(e.target.value) || 1)}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="maxCall" className="flex items-center gap-2">
                  <Video className="h-4 w-4" />
                  Max Video Women
                </Label>
                <Input
                  id="maxCall"
                  type="number"
                  min={1}
                  value={formMaxCall}
                  onChange={(e) => setFormMaxCall(parseInt(e.target.value) || 1)}
                />
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Switch
                id="active"
                checked={formIsActive}
                onCheckedChange={setFormIsActive}
              />
              <Label htmlFor="active">Active</Label>
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setIsDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleSave} disabled={isSaving} className="gap-2">
              {isSaving ? (
                <RefreshCw className="h-4 w-4 animate-spin" />
              ) : (
                <Save className="h-4 w-4" />
              )}
              {editingLimit ? "Update" : "Create"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
    </AdminNav>
  );
};

export default AdminLanguageLimits;