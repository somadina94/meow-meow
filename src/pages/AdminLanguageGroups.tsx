import AdminNav from "@/components/AdminNav";
import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { useAdminAccess } from "@/hooks/useAdminAccess";
import { useRealtimeSubscription } from "@/hooks/useRealtimeSubscription";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { ScrollArea } from "@/components/ui/scroll-area";
import { toast } from "sonner";
import { languages } from "@/data/languages";
import { 
  ArrowLeft, 
  Plus, 
  Pencil, 
  Trash2, 
  Search, 
  Languages, 
  Globe2,
  GripVertical,
  X,
  Check,
  Filter,
  Home
} from "lucide-react";

interface LanguageGroup {
  id: string;
  name: string;
  description: string | null;
  languages: string[];
  is_active: boolean;
  priority: number;
  created_at: string;
  updated_at: string;
}

const AdminLanguageGroups = () => {
  const navigate = useNavigate();
  
  const { isAdmin, isLoading: adminLoading } = useAdminAccess();
  const [groups, setGroups] = useState<LanguageGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterActive, setFilterActive] = useState<boolean | null>(null);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<LanguageGroup | null>(null);
  const [languageSearch, setLanguageSearch] = useState("");

  // Form state
  const [formName, setFormName] = useState("");
  const [formDescription, setFormDescription] = useState("");
  const [formLanguages, setFormLanguages] = useState<string[]>([]);
  const [formIsActive, setFormIsActive] = useState(true);
  const [formPriority, setFormPriority] = useState(0);

  const loadGroups = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from("language_groups")
        .select("*")
        .order("priority", { ascending: true })
        .order("name", { ascending: true });

      if (error) throw error;
      setGroups(data || []);
    } catch (error) {
      console.error("Error loading language groups:", error);
      toast.error("Error", { description: "Failed to load language groups" });
    } finally {
      setLoading(false);
    }
  }, []);

  // Real-time subscription for language groups
  useRealtimeSubscription({
    table: "language_groups",
    onUpdate: loadGroups
  });

  useEffect(() => {
    loadGroups();
  }, [loadGroups]);

  const getLanguageName = (code: string) => {
    const lang = languages.find((l) => l.code === code);
    if (lang) return lang.name;
    // Handle regional variants like en-US, hi-IN, ur-PK
    if (code.includes("-")) {
      const [base, region] = code.split("-");
      const baseLang = languages.find((l) => l.code === base);
      if (baseLang) return `${baseLang.name} (${region.toUpperCase()})`;
    }
    return code;
  };

  const getLanguageNativeName = (code: string) => {
    const lang = languages.find((l) => l.code === code);
    if (lang) return lang.nativeName;
    if (code.includes("-")) {
      const [base] = code.split("-");
      const baseLang = languages.find((l) => l.code === base);
      if (baseLang) return baseLang.nativeName;
    }
    return code;
  };

  const filteredGroups = groups.filter((group) => {
    const matchesSearch =
      group.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (group.description?.toLowerCase().includes(searchTerm.toLowerCase()) ?? false) ||
      group.languages.some((code) =>
        getLanguageName(code).toLowerCase().includes(searchTerm.toLowerCase())
      );
    const matchesFilter = filterActive === null || group.is_active === filterActive;
    return matchesSearch && matchesFilter;
  });

  // Build a merged list of available languages: base list + any codes already
  // present in saved groups or in the current form (e.g., regional variants
  // like en-US, hi-IN that aren't in the base list).
  const extraCodes = Array.from(
    new Set([
      ...groups.flatMap((g) => g.languages),
      ...formLanguages,
    ])
  ).filter((code) => !languages.some((l) => l.code === code));

  const allLanguages = [
    ...languages,
    ...extraCodes.map((code) => ({
      code,
      name: getLanguageName(code),
      nativeName: getLanguageNativeName(code),
    })),
  ];

  const filteredLanguages = allLanguages.filter(
    (lang) =>
      lang.name.toLowerCase().includes(languageSearch.toLowerCase()) ||
      lang.nativeName.toLowerCase().includes(languageSearch.toLowerCase()) ||
      lang.code.toLowerCase().includes(languageSearch.toLowerCase())
  );

  const openCreateDialog = () => {
    setEditingGroup(null);
    setFormName("");
    setFormDescription("");
    setFormLanguages([]);
    setFormIsActive(true);
    setFormPriority(groups.length + 1);
    setLanguageSearch("");
    setIsDialogOpen(true);
  };

  const openEditDialog = (group: LanguageGroup) => {
    setEditingGroup(group);
    setFormName(group.name);
    setFormDescription(group.description || "");
    setFormLanguages(group.languages);
    setFormIsActive(group.is_active);
    setFormPriority(group.priority);
    setLanguageSearch("");
    setIsDialogOpen(true);
  };

  const toggleLanguage = (code: string) => {
    setFormLanguages((prev) =>
      prev.includes(code) ? prev.filter((c) => c !== code) : [...prev, code]
    );
  };

  const handleSave = async () => {
    if (!formName.trim()) {
      toast.error("Validation Error", { description: "Group name is required" });
      return;
    }

    if (formLanguages.length === 0) {
      toast.error("Validation Error", { description: "At least one language is required" });
      return;
    }

    try {
      if (editingGroup) {
        const { error } = await supabase
          .from("language_groups")
          .update({
            name: formName.trim(),
            description: formDescription.trim() || null,
            languages: formLanguages,
            is_active: formIsActive,
            priority: formPriority,
          })
          .eq("id", editingGroup.id);

        if (error) throw error;
        toast.success("Success", { description: "Language group updated" });
      } else {
        const { error } = await supabase.from("language_groups").insert({
          name: formName.trim(),
          description: formDescription.trim() || null,
          languages: formLanguages,
          is_active: formIsActive,
          priority: formPriority,
        });

        if (error) throw error;
        toast.success("Success", { description: "Language group created" });
      }

      setIsDialogOpen(false);
      loadGroups();
    } catch (error) {
      console.error("Error saving language group:", error);
      toast.error("Error", { description: "Failed to save language group" });
    }
  };

  const handleDelete = async (group: LanguageGroup) => {
    if (!confirm(`Delete "${group.name}"? This action cannot be undone.`)) return;

    try {
      const { error } = await supabase
        .from("language_groups")
        .delete()
        .eq("id", group.id);

      if (error) throw error;
      toast.success("Success", { description: "Language group deleted" });
      loadGroups();
    } catch (error) {
      console.error("Error deleting language group:", error);
      toast.error("Error", { description: "Failed to delete language group" });
    }
  };

  const toggleGroupActive = async (group: LanguageGroup) => {
    try {
      const { error } = await supabase
        .from("language_groups")
        .update({ is_active: !group.is_active })
        .eq("id", group.id);

      if (error) throw error;
      loadGroups();
    } catch (error) {
      console.error("Error toggling group status:", error);
      toast.error("Error", { description: "Failed to update group status" });
    }
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
      <AdminNav><div className="flex items-center justify-center py-20">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary" />
      </div></AdminNav>
    );
  }

  return (
    <AdminNav>
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-2">
          <Languages className="h-6 w-6 text-primary" />
          <h1 className="text-xl font-semibold">Language Groups</h1>
        </div>
        <Button onClick={openCreateDialog} className="gap-2">
          <Plus className="h-4 w-4" />
          Add Group
        </Button>
      </div>

      <main className="container max-w-6xl mx-auto px-4 py-6 space-y-6">
        {/* Search & Filter */}
        <div className="flex flex-col sm:flex-row gap-4">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search groups or languages..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-9"
            />
          </div>
          <div className="flex gap-2">
            <Button
              variant={filterActive === null ? "secondary" : "outline"}
              size="sm"
              onClick={() => setFilterActive(null)}
            >
              All
            </Button>
            <Button
              variant={filterActive === true ? "secondary" : "outline"}
              size="sm"
              onClick={() => setFilterActive(true)}
              className="gap-1"
            >
              <Check className="h-3 w-3" />
              Active
            </Button>
            <Button
              variant={filterActive === false ? "secondary" : "outline"}
              size="sm"
              onClick={() => setFilterActive(false)}
              className="gap-1"
            >
              <X className="h-3 w-3" />
              Inactive
            </Button>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold">{groups.length}</div>
              <div className="text-sm text-muted-foreground">Total Groups</div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold text-primary">
                {groups.filter((g) => g.is_active).length}
              </div>
              <div className="text-sm text-muted-foreground">Active</div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold">
                {new Set(groups.flatMap((g) => g.languages)).size}
              </div>
              <div className="text-sm text-muted-foreground">Languages Grouped</div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="p-4">
              <div className="text-2xl font-bold">{languages.length}</div>
              <div className="text-sm text-muted-foreground">Available Languages</div>
            </CardContent>
          </Card>
        </div>

        {/* Groups List */}
        <div className="space-y-4">
          {filteredGroups.length === 0 ? (
            <Card>
              <CardContent className="p-8 text-center text-muted-foreground">
                {searchTerm || filterActive !== null
                  ? "No groups match your search criteria"
                  : "No language groups yet. Create one to get started."}
              </CardContent>
            </Card>
          ) : (
            filteredGroups.map((group, index) => (
              <Card
                key={group.id}
                className={`transition-all duration-200 hover:shadow-md ${
                  !group.is_active ? "opacity-60" : ""
                }`}
              >
                <CardHeader className="pb-3">
                  <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3">
                      <div className="flex items-center justify-center w-8 h-8 rounded-full bg-primary/10 text-primary text-sm font-medium">
                        {group.priority}
                      </div>
                      <div>
                        <CardTitle className="text-lg flex items-center gap-2">
                          {group.name}
                          {!group.is_active && (
                            <Badge variant="secondary" className="text-xs">
                              Inactive
                            </Badge>
                          )}
                        </CardTitle>
                        {group.description && (
                          <CardDescription className="mt-1">
                            {group.description}
                          </CardDescription>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <Switch
                        checked={group.is_active}
                        onCheckedChange={() => toggleGroupActive(group)}
                      />
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => openEditDialog(group)}
                      >
                        <Pencil className="h-4 w-4" />
                      </Button>
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => handleDelete(group)}
                        className="text-destructive hover:text-destructive"
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="flex flex-wrap gap-2">
                    {group.languages.map((code) => (
                      <Badge
                        key={code}
                        variant="outline"
                        className="transition-transform hover:scale-105"
                      >
                        <Globe2 className="h-3 w-3 mr-1" />
                        {getLanguageName(code)}
                        <span className="ml-1 text-muted-foreground text-xs">
                          ({getLanguageNativeName(code)})
                        </span>
                      </Badge>
                    ))}
                  </div>
                  <div className="mt-3 text-xs text-muted-foreground">
                    {group.languages.length} language{group.languages.length !== 1 ? "s" : ""}
                  </div>
                </CardContent>
              </Card>
            ))
          )}
        </div>
      </main>

      {/* Create/Edit Dialog */}
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-hidden flex flex-col">
          <DialogHeader>
            <DialogTitle>
              {editingGroup ? "Edit Language Group" : "Create Language Group"}
            </DialogTitle>
            <DialogDescription>
              Group languages together for matching logic and user preferences.
            </DialogDescription>
          </DialogHeader>

          <div className="flex-1 overflow-y-auto space-y-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="name">Group Name *</Label>
                <Input
                  id="name"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="e.g., Indo-Aryan Languages"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="priority">Priority</Label>
                <Input
                  id="priority"
                  type="number"
                  min={0}
                  value={formPriority}
                  onChange={(e) => setFormPriority(parseInt(e.target.value) || 0)}
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                value={formDescription}
                onChange={(e) => setFormDescription(e.target.value)}
                placeholder="Brief description of this language group..."
                rows={2}
              />
            </div>

            <div className="flex items-center gap-2">
              <Switch
                id="active"
                checked={formIsActive}
                onCheckedChange={setFormIsActive}
              />
              <Label htmlFor="active">Active (visible for matching)</Label>
            </div>

            <div className="space-y-2">
              <Label>
                Languages * ({formLanguages.length} selected)
              </Label>

              {/* Selected Languages */}
              {formLanguages.length > 0 && (
                <div className="flex flex-wrap gap-2 p-3 bg-muted/50 rounded-lg">
                  {formLanguages.map((code) => (
                    <Badge
                      key={code}
                      variant="secondary"
                      className="cursor-pointer hover:bg-destructive hover:text-destructive-foreground transition-colors"
                      onClick={() => toggleLanguage(code)}
                    >
                      {getLanguageName(code)}
                      <X className="h-3 w-3 ml-1" />
                    </Badge>
                  ))}
                </div>
              )}

              {/* Language Search */}
              <div className="relative">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  value={languageSearch}
                  onChange={(e) => setLanguageSearch(e.target.value)}
                  placeholder="Search languages..."
                  className="pl-9"
                />
              </div>

              {/* Available Languages */}
              <ScrollArea className="h-48 border rounded-lg">
                <div className="p-2 grid grid-cols-2 gap-1">
                  {(languageSearch ? filteredLanguages : filteredLanguages.slice(0, 100)).map((lang) => (
                    <button
                      key={lang.code}
                      type="button"
                      onClick={() => toggleLanguage(lang.code)}
                      className={`flex items-center gap-2 p-2 rounded text-left text-sm transition-colors ${
                        formLanguages.includes(lang.code)
                          ? "bg-primary/10 text-primary"
                          : "hover:bg-muted"
                      }`}
                    >
                      {formLanguages.includes(lang.code) ? (
                        <Check className="h-4 w-4 flex-shrink-0" />
                      ) : (
                        <div className="h-4 w-4 flex-shrink-0" />
                      )}
                      <span className="truncate">{lang.name}</span>
                      <span className="text-xs text-muted-foreground truncate">
                        {lang.nativeName}
                      </span>
                    </button>
                  ))}
                </div>
              </ScrollArea>
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setIsDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleSave}>
              {editingGroup ? "Save Changes" : "Create Group"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </AdminNav>
  );
};

export default AdminLanguageGroups;
