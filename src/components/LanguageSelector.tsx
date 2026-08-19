import { useState, useMemo, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Languages, Search, Check, Globe, Save, X } from "lucide-react";
import { cn } from "@/lib/utils";
import { languages, type Language } from "@/data/languages";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";

// Unified language type for the selector
interface ProfileLanguage {
  code: string;
  name: string;
  nativeName: string;
  script?: string;
  rtl?: boolean;
  isIndian?: boolean;
}

// Indian language codes for categorization
const INDIAN_LANGUAGE_CODES = new Set([
  "hi", "bn", "te", "mr", "ta", "gu", "kn", "ml", "or", "pa", "as", "mai", "sat", "ks",
  "kok", "doi", "mni", "brx", "sa", "bho", "hne", "raj", "mwr", "mtr", "bgc", "mag",
  "anp", "bjj", "awa", "bns", "bfy", "gbm", "kfy", "him", "kan", "tcy", "kfa", "bhb",
  "gon", "lmn", "sck", "kru", "unr", "hoc", "khr", "hlb", "khn", "dcc", "wbr", "bhd",
  "mup", "hoj", "dgo", "sjo", "mby", "saz", "bra", "kfk", "lah", "psu", "pgg", "xnr",
  "srx", "jml", "dty", "thl", "bap", "lus", "kha", "grt", "mjw", "trp", "rah", "mrg",
  "njz", "apt", "adi", "lep", "sip", "lif", "njo", "njh", "nsm", "njm", "nmf", "pck",
  "tcz", "nbu", "nst", "nnp", "njb", "nag", "tcx", "bfq", "iru", "kfh", "vav", "abl",
  "wbq", "gok", "kxv", "kff", "kdu", "yed", "sou", "ur", "sd", "ne"
]);

interface LanguageSelectorProps {
  selectedLanguage: string;
  selectedLanguageCode?: string;
  onLanguageChange: (language: string, code: string) => void;
  showAllLanguages?: boolean;
  label?: string;
  description?: string;
  className?: string;
  gender?: 'male' | 'female' | null;
}

export const LanguageSelector = ({
  selectedLanguage,
  selectedLanguageCode,
  onLanguageChange,
  showAllLanguages = true,
  label = "Your Language",
  description,
  className,
  gender,
}: LanguageSelectorProps) => {
  const { toast } = useToast();
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [isUpdating, setIsUpdating] = useState(false);
  const [tempSelectedLanguage, setTempSelectedLanguage] = useState<ProfileLanguage | null>(null);
  const [userGender, setUserGender] = useState<'male' | 'female' | null>(gender || null);

  // Fetch user gender if not provided
  useEffect(() => {
    if (!gender) {
      const fetchUserGender = async () => {
        const { data: { session } } = await supabase.auth.getSession();
        if (session?.user) {
          const user = session.user;
          const { data: profile } = await supabase
            .from("profiles")
            .select("gender")
            .eq("user_id", user.id)
            .maybeSingle();
          if (profile?.gender) {
            setUserGender(profile.gender.toLowerCase() as 'male' | 'female');
          }
        }
      };
      fetchUserGender();
    }
  }, [gender]);

  // Get languages - 1000+ languages available
  const allLanguages: ProfileLanguage[] = useMemo(() => {
    return languages.map(lang => ({
      ...lang,
      isIndian: INDIAN_LANGUAGE_CODES.has(lang.code)
    }));
  }, []);

  // Filter languages based on search
  const filteredLanguages = useMemo(() => {
    if (!searchQuery.trim()) return allLanguages;
    const query = searchQuery.toLowerCase();
    return allLanguages.filter(
      lang => 
        lang.name.toLowerCase().includes(query) ||
        lang.nativeName.toLowerCase().includes(query) ||
        (lang.script && lang.script.toLowerCase().includes(query))
    );
  }, [allLanguages, searchQuery]);

  // Group languages
  const indianLanguages = useMemo(() => 
    filteredLanguages.filter(l => l.isIndian), 
    [filteredLanguages]
  );
  
  const worldLanguages = useMemo(() => 
    filteredLanguages.filter(l => !l.isIndian), 
    [filteredLanguages]
  );

  const handleOpenChange = () => {
    setIsOpen(true);
    setSearchQuery("");
    // Set temp selection to current language
    const currentLang = allLanguages.find(l => l.name === selectedLanguage);
    setTempSelectedLanguage(currentLang || null);
  };

  const handleSelectLanguage = (lang: ProfileLanguage) => {
    setTempSelectedLanguage(lang);
  };

  const handleSaveLanguage = async () => {
    if (!tempSelectedLanguage) return;
    
    setIsUpdating(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) {
        toast({
          title: "Error",
          description: "Please log in to change language",
          variant: "destructive",
        });
        return;
      }
      const user = session.user;

      // Determine user gender for profile sync
      const { data: profileData } = await supabase
        .from("profiles")
        .select("gender")
        .eq("user_id", user.id)
        .maybeSingle();
      const gender = profileData?.gender?.toLowerCase();

      const languageName = tempSelectedLanguage.name;
      const languageCode = tempSelectedLanguage.code;

      const { error: profileError } = await supabase
        .from("profiles")
        .update({
          preferred_language: languageName,
          primary_language: languageName,
        })
        .eq("user_id", user.id);
      if (profileError) throw profileError;

      // Settings screen reads this column — without it, language snaps back to English
      await supabase
        .from("user_settings")
        .upsert(
          { user_id: user.id, language: languageName },
          { onConflict: "user_id" }
        );

      if (gender === "male") {
        await supabase
          .from("male_profiles")
          .update({ primary_language: languageName, preferred_language: languageName })
          .eq("user_id", user.id);
      } else if (gender === "female") {
        await supabase
          .from("female_profiles")
          .update({ primary_language: languageName, preferred_language: languageName })
          .eq("user_id", user.id);
      }

      await supabase.from("user_languages").delete().eq("user_id", user.id);
      const { error: langError } = await supabase.from("user_languages").insert({
        user_id: user.id,
        language_name: languageName,
        language_code: languageCode,
      });
      if (langError) throw langError;

      onLanguageChange(languageName, languageCode);
      setIsOpen(false);
      
      toast({
        title: "Language Saved",
        description: `Your language is now set to ${tempSelectedLanguage.name}`,
      });
    } catch (error) {
      console.error("Error updating language:", error);
      toast({
        title: "Error",
        description: "Failed to save language",
        variant: "destructive",
      });
    } finally {
      setIsUpdating(false);
    }
  };

  const handleCancel = () => {
    setIsOpen(false);
    setTempSelectedLanguage(null);
    setSearchQuery("");
  };

  const LanguageItem = ({ lang }: { lang: ProfileLanguage }) => {
    const isSelected = tempSelectedLanguage?.code === lang.code;
    const isCurrent = selectedLanguage === lang.name;
    
    return (
      <button
        onClick={() => handleSelectLanguage(lang)}
        className={cn(
          "w-full flex items-center justify-between p-3 rounded-lg transition-all text-left",
          isSelected 
            ? "bg-primary/20 border-2 border-primary shadow-sm" 
            : isCurrent
              ? "bg-accent/50 border border-border"
              : "hover:bg-accent border border-transparent"
        )}
      >
        <div className="flex items-center gap-3">
          <div className={cn(
            "w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold bg-gradient-to-br from-primary to-accent text-primary-foreground"
          )}>
            {lang.nativeName.charAt(0)}
          </div>
          <div>
            <p className="font-semibold text-foreground">{lang.name}</p>
            <p className="text-xs text-muted-foreground">
              {lang.nativeName} • {lang.script || 'Latin'}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {isCurrent && !isSelected && (
            <Badge variant="secondary" className="text-xs">Current</Badge>
          )}
          {isSelected && (
            <div className="w-6 h-6 rounded-full bg-primary flex items-center justify-center">
              <Check className="h-4 w-4 text-primary-foreground" />
            </div>
          )}
        </div>
      </button>
    );
  };

  // Check if user has made a new selection (different from current)
  const hasNewSelection = tempSelectedLanguage && tempSelectedLanguage.name !== selectedLanguage;

  return (
    <div className={cn("space-y-2", className)}>
      {label && <Label className="text-sm font-medium">{label}</Label>}
      {description && <p className="text-xs text-muted-foreground">{description}</p>}
      
      {/* Current Language Display with Change/Save Button */}
      <div className="flex items-center gap-3">
        <div className="flex-1 flex items-center gap-3 p-3 rounded-xl bg-background/80 border border-border/50">
          <div className="w-10 h-10 rounded-full flex items-center justify-center text-sm font-bold bg-gradient-to-br from-primary to-accent text-primary-foreground">
            {allLanguages.find(l => l.name === selectedLanguage)?.nativeName?.charAt(0) || selectedLanguage?.charAt(0) || "?"}
          </div>
          <div className="flex-1">
            <p className="font-semibold text-foreground">{selectedLanguage || "Select Language"}</p>
            <p className="text-xs text-muted-foreground">
              {allLanguages.find(l => l.name === selectedLanguage)?.nativeName || "Choose your language"}
            </p>
          </div>
          <Badge variant="outline" className="text-xs">
            {allLanguages.find(l => l.name === selectedLanguage)?.isIndian ? "🇮🇳 India" : "🌍 World"}
          </Badge>
        </div>
        
        {/* Alternate between Change and Save buttons */}
        {!isOpen && !hasNewSelection ? (
          <Button
            variant="outline"
            onClick={handleOpenChange}
            className="gap-2 h-auto py-3 min-w-[100px]"
          >
            <Languages className="h-4 w-4" />
            Change
          </Button>
        ) : hasNewSelection && !isOpen ? (
          <Button
            variant="gradient"
            onClick={handleSaveLanguage}
            disabled={isUpdating}
            className="gap-2 h-auto py-3 min-w-[100px]"
          >
            {isUpdating ? (
              <div className="w-4 h-4 border-2 border-primary-foreground/30 border-t-primary-foreground rounded-full animate-spin" />
            ) : (
              <Save className="h-4 w-4" />
            )}
            Save
          </Button>
        ) : (
          <Button
            variant="outline"
            onClick={handleOpenChange}
            className="gap-2 h-auto py-3 min-w-[100px]"
          >
            <Languages className="h-4 w-4" />
            Change
          </Button>
        )}
      </div>

      {/* Language Selection Dialog */}
      <Dialog open={isOpen} onOpenChange={setIsOpen}>
        <DialogContent className="max-w-lg max-h-[85vh] p-0">
          <DialogHeader className="p-6 pb-0">
            <DialogTitle className="flex items-center gap-2 text-xl">
              <Languages className="h-5 w-5 text-primary" />
              Select Your Language
            </DialogTitle>
            <p className="text-sm text-muted-foreground mt-1">
              Choose from {allLanguages.length} languages ({indianLanguages.length} Indian + {worldLanguages.length} World)
            </p>
          </DialogHeader>
          
          {/* Search Bar */}
          <div className="px-6 py-4 border-b border-border/50 bg-muted/30">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
              <Input
                placeholder="Search languages... (e.g., Hindi, Tamil, French)"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10 h-12 text-base bg-background"
                autoFocus
              />
              {searchQuery && (
                <Button
                  variant="ghost"
                  size="icon"
                  className="absolute right-2 top-1/2 -translate-y-1/2 h-8 w-8"
                  onClick={() => setSearchQuery("")}
                >
                  <X className="h-4 w-4" />
                </Button>
              )}
            </div>
            {searchQuery && (
              <p className="text-xs text-muted-foreground mt-2">
                Found {filteredLanguages.length} language{filteredLanguages.length !== 1 ? 's' : ''}
              </p>
            )}
          </div>
          
          {/* Language List */}
          <ScrollArea className="h-[400px]">
            <div className="p-4 space-y-6">
              {/* Indian Languages Section */}
              {indianLanguages.length > 0 && (
                <div>
                  <div className="flex items-center gap-2 px-2 py-2 mb-3 bg-gradient-to-r from-orange-500/10 to-green-500/10 rounded-lg">
                    <span className="text-xl">🇮🇳</span>
                    <span className="text-sm font-bold text-foreground">
                      Indian Languages
                    </span>
                    <Badge variant="secondary" className="ml-auto text-xs">
                      {indianLanguages.length}
                    </Badge>
                  </div>
                  <div className="grid gap-2">
                    {indianLanguages.map((lang) => (
                      <LanguageItem key={lang.code} lang={lang} />
                    ))}
                  </div>
                </div>
              )}
              
              {/* World Languages Section */}
              {worldLanguages.length > 0 && (
                <div>
                  <div className="flex items-center gap-2 px-2 py-2 mb-3 bg-gradient-to-r from-primary/10 to-secondary/10 rounded-lg">
                    <Globe className="h-5 w-5 text-primary" />
                    <span className="text-sm font-bold text-foreground">
                      World Languages
                    </span>
                    <Badge variant="secondary" className="ml-auto text-xs">
                      {worldLanguages.length}
                    </Badge>
                  </div>
                  <div className="grid gap-2">
                    {worldLanguages.map((lang) => (
                      <LanguageItem key={lang.code} lang={lang} />
                    ))}
                  </div>
                </div>
              )}
              
              {filteredLanguages.length === 0 && (
                <div className="text-center py-12 text-muted-foreground">
                  <Languages className="h-12 w-12 mx-auto mb-3 opacity-50" />
                  <p className="font-medium">No languages found</p>
                  <p className="text-sm mt-1">Try a different search term</p>
                </div>
              )}
            </div>
          </ScrollArea>

          {/* Footer with Cancel and Save - Save only enabled when selection changed */}
          <DialogFooter className="p-6 pt-4 border-t border-border/50 bg-muted/30">
            <div className="flex items-center justify-between w-full gap-3">
              <div className="text-sm text-muted-foreground">
                {tempSelectedLanguage && tempSelectedLanguage.name !== selectedLanguage ? (
                  <span>
                    New selection: <strong className="text-primary">{tempSelectedLanguage.name}</strong>
                  </span>
                ) : (
                  <span>Select a different language to save</span>
                )}
              </div>
              <div className="flex gap-3">
                <Button
                  variant="outline"
                  onClick={handleCancel}
                  className="gap-2"
                >
                  <X className="h-4 w-4" />
                  Cancel
                </Button>
                <Button
                  variant="gradient"
                  onClick={() => {
                    handleSaveLanguage();
                  }}
                  disabled={!tempSelectedLanguage || tempSelectedLanguage.name === selectedLanguage || isUpdating}
                  className="gap-2 min-w-[120px]"
                >
                  {isUpdating ? (
                    <div className="w-4 h-4 border-2 border-primary-foreground/30 border-t-primary-foreground rounded-full animate-spin" />
                  ) : (
                    <Save className="h-4 w-4" />
                  )}
                  {tempSelectedLanguage && tempSelectedLanguage.name !== selectedLanguage ? "Save" : "Select & Save"}
                </Button>
              </div>
            </div>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default LanguageSelector;
