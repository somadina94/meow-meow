import { useState, useMemo, lazy, Suspense } from "react";
import { useRegistrationGuard } from "@/hooks/useRegistrationGuard";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import MeowLogo from "@/components/MeowLogo";
import ProgressIndicator from "@/components/ProgressIndicator";
import { useToast } from "@/hooks/use-toast";
import { Languages, Search, X, Check, Loader2, Globe2, ArrowLeft } from "lucide-react";
import { languages } from "@/data/languages";
import { supabase } from "@/integrations/supabase/client";
import { isIndianLanguageInput, NON_INDIA_ERROR } from "@/lib/indianValidation";

const AuroraBackground = lazy(() => import("@/components/AuroraBackground"));

interface SelectedLanguage {
  code: string;
  name: string;
}

const LanguagePreferencesScreen = () => {
  const navigate = useNavigate();
  useRegistrationGuard([{ key: "userEmail" }, { key: "userGender" }], "/basic-info");
  const { toast } = useToast();
  const [isLoading, setIsLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedLanguages, setSelectedLanguages] = useState<SelectedLanguage[]>([]);
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);

  const filteredLanguages = useMemo(() => {
    if (!searchQuery.trim()) return languages.slice(0, 20);
    return languages.filter(
      (lang) =>
        lang.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        lang.code.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [searchQuery]);

  const toggleLanguage = (lang: { code: string; name: string }) => {
    setSelectedLanguages((prev) => {
      const exists = prev.find((l) => l.code === lang.code);
      if (exists) {
        return prev.filter((l) => l.code !== lang.code);
      }
      if (!isIndianLanguageInput(lang.code)) {
        toast({ ...NON_INDIA_ERROR, variant: "destructive" });
        return prev;
      }
      return [...prev, { code: lang.code, name: lang.name }];
    });
  };

  const removeLanguage = (code: string) => {
    setSelectedLanguages((prev) => prev.filter((l) => l.code !== code));
  };

  const isSelected = (code: string) => {
    return selectedLanguages.some((l) => l.code === code);
  };

  const handleSubmit = async () => {
    setIsLoading(true);

    try {
      const { data: { session } } = await supabase.auth.getSession();

      if (!session?.user) {
        // During registration, no session yet — save to localStorage and continue
        if (selectedLanguages.length > 0) {
          sessionStorage.setItem("userLanguagePreferences", JSON.stringify(selectedLanguages));
          sessionStorage.setItem("userPrimaryLanguage", selectedLanguages[0].code);
        }
        toast({
          title: "Preferences saved!",
          description: selectedLanguages.length > 0
            ? `${selectedLanguages.length} language(s) selected.`
            : "Skipped — you can update this later.",
        });
        navigate("/password-setup");
        return;
      }
      const user = session.user;

      // Delete existing language preferences
      await supabase
        .from("user_languages")
        .delete()
        .eq("user_id", user.id);

      // Insert new language preferences
      if (selectedLanguages.length > 0) {
        const languageRecords = selectedLanguages.map((lang) => ({
          user_id: user.id,
          language_code: lang.code,
          language_name: lang.name,
        }));

        const { error } = await supabase
          .from("user_languages")
          .insert(languageRecords);

        if (error) throw error;
      }

      toast({
        title: "Preferences saved!",
        description: `${selectedLanguages.length} language(s) selected for translation.`,
      });

      navigate("/password-setup");
    } catch (error) {
      console.error("Error saving languages:", error);
      toast({
        title: "Error",
        description: "Failed to save language preferences. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col relative bg-background text-foreground">
      {/* Aurora Background */}
      <Suspense fallback={
        <div className="fixed inset-0 -z-10 bg-gradient-to-br from-background via-background to-secondary/30" />
      }>
        <AuroraBackground />
      </Suspense>

      {/* Header */}
      <header className="px-6 pt-8 pb-4 relative z-10">
        <div className="flex items-center gap-4 mb-4">
          <Button
            variant="ghost"
            size="icon"
            onClick={() => navigate("/location-setup")}
            className="shrink-0 text-muted-foreground hover:text-foreground"
          >
            <ArrowLeft className="w-5 h-5" />
          </Button>
          <div className="flex-1">
            <ProgressIndicator currentStep={7} totalSteps={10} />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex items-center justify-center p-6 relative z-10">
        <Card className="w-full max-w-lg p-8 space-y-6 bg-card/70 backdrop-blur-xl border-primary/20 shadow-[0_0_40px_hsl(var(--primary)/0.1)]">
          <div className="text-center space-y-2">
            <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10 mb-4">
              <Languages className="w-8 h-8 text-primary" />
            </div>
            <h1 className="text-2xl font-display font-bold text-foreground">Language Preferences</h1>
            <p className="text-muted-foreground">
              Select languages you'd like for translation support
            </p>
          </div>

          {/* Selected Languages Tags */}
          {selectedLanguages.length > 0 && (
            <div className="flex flex-wrap gap-2 animate-fade-in">
              {selectedLanguages.map((lang, index) => (
                <div
                  key={lang.code}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-primary/10 text-primary rounded-full text-sm font-medium animate-scale-in"
                  style={{ animationDelay: `${index * 50}ms` }}
                >
                  <Globe2 className="w-3.5 h-3.5" />
                  <span>{lang.name}</span>
                  <button
                    onClick={() => removeLanguage(lang.code)}
                    className="ml-1 p-0.5 hover:bg-primary/20 rounded-full transition-colors"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
              ))}
            </div>
          )}

          {/* Search and Dropdown */}
          <div className="relative">
            <div className="relative">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-muted-foreground" />
              <Input
                placeholder="Search languages..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onFocus={() => setIsDropdownOpen(true)}
                className="pl-12 h-12 text-base"
              />
            </div>

            {/* Dropdown List */}
            {isDropdownOpen && (
              <div className="absolute z-50 w-full mt-2 bg-popover border border-border rounded-xl shadow-lg max-h-64 overflow-y-auto animate-fade-in">
                {filteredLanguages.length === 0 ? (
                  <div className="px-4 py-8 text-center text-muted-foreground">
                    No languages found
                  </div>
                ) : (
                  filteredLanguages.map((lang, index) => (
                    <button
                      key={lang.code}
                      type="button"
                      onClick={() => toggleLanguage(lang)}
                      className={`w-full flex items-center justify-between px-4 py-3 transition-colors hover:bg-accent ${
                        isSelected(lang.code) ? "bg-primary/5" : ""
                      }`}
                      style={{ animationDelay: `${index * 20}ms` }}
                    >
                      <div className="flex items-center gap-3">
                        <Globe2 className="w-5 h-5 text-muted-foreground" />
                        <div className="text-left">
                          <div className="font-medium text-foreground">{lang.name}</div>
                          <div className="text-xs text-muted-foreground uppercase">{lang.code}</div>
                        </div>
                      </div>
                      {isSelected(lang.code) && (
                        <Check className="w-5 h-5 text-primary animate-scale-in" />
                      )}
                    </button>
                  ))
                )}
              </div>
            )}
          </div>

          {/* Click outside to close */}
          {isDropdownOpen && (
            <div
              className="fixed inset-0 z-40"
              onClick={() => setIsDropdownOpen(false)}
            />
          )}

          {/* Info Text */}
          <p className="text-sm text-muted-foreground text-center">
            {selectedLanguages.length === 0
              ? "You can skip this step if you don't need translation"
              : `${selectedLanguages.length} language${selectedLanguages.length > 1 ? "s" : ""} selected`}
          </p>

          {/* Submit Button */}
          <Button
            onClick={handleSubmit}
            disabled={isLoading}
            className="w-full h-12 text-base font-medium"
            variant="aurora"
          >
            {isLoading ? (
              <>
                <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                Saving...
              </>
            ) : selectedLanguages.length === 0 ? (
              "Skip"
            ) : (
              "Continue"
            )}
          </Button>
        </Card>
      </main>
    </div>
  );
};

export default LanguagePreferencesScreen;
