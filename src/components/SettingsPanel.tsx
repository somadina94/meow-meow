import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { toast } from "sonner";
import { 
  Bell, 
  Globe, 
  Eye, 
  Palette,
  Volume2,
  Vibrate,
  MessageSquare,
  Heart,
  Megaphone,
  Lock,
  Map,
  Save,
  CheckCircle2,
  Loader2,
  MessageCircle,
  Check
} from "lucide-react";
import { cn } from "@/lib/utils";

import { LanguageSelector } from "@/components/LanguageSelector";
import { useRealtimeSubscription } from "@/hooks/useRealtimeSubscription";
import { ThemeSelector } from "@/components/ThemeSelector";
import { useParallelChatSettings } from "@/hooks/useParallelChatSettings";
import { AccountDeletionSection } from "@/components/settings/AccountDeletionSection";

interface UserSettings {
  theme: string;
  accent_color: string;
  notification_matches: boolean;
  notification_messages: boolean;
  notification_promotions: boolean;
  notification_sound: boolean;
  notification_vibration: boolean;
  language: string;
  auto_translate: boolean;
  show_online_status: boolean;
  show_read_receipts: boolean;
  profile_visibility: string;
  distance_unit: string;
}

const DEFAULT_SETTINGS: UserSettings = {
  theme: "system",
  accent_color: "purple",
  notification_matches: true,
  notification_messages: true,
  notification_promotions: false,
  notification_sound: true,
  notification_vibration: true,
  language: "English",
  auto_translate: true,
  show_online_status: true,
  show_read_receipts: true,
  profile_visibility: "high",
  distance_unit: "km"
};

interface SettingsPanelProps {
  compact?: boolean;
}

export const SettingsPanel = ({ compact = false }: SettingsPanelProps) => {
  const navigate = useNavigate();
  const t = (key: string, def: string) => def; const setLanguage = (l: string) => {};
  const [settings, setSettings] = useState<UserSettings>(DEFAULT_SETTINGS);
  const [originalSettings, setOriginalSettings] = useState<UserSettings>(DEFAULT_SETTINGS);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);
  const [selectedLanguageCode, setSelectedLanguageCode] = useState("eng_Latn");
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);

  // Parallel chat settings
  const { maxParallelChats, setMaxParallelChats, isLoading: parallelSettingsLoading } = 
    useParallelChatSettings(currentUserId || undefined);
  const [selectedParallelChats, setSelectedParallelChats] = useState(maxParallelChats.toString());

  const fetchSettings = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) {
        navigate("/");
        return;
      }
      const user = session.user;

      setCurrentUserId(user.id);

      let { data: settingsData, error } = await supabase
        .from("user_settings")
        .select("*")
        .eq("user_id", user.id)
        .maybeSingle();

      if (error) throw error;

      if (!settingsData) {
        const { data: newSettings, error: createError } = await supabase
          .from("user_settings")
          .insert({ user_id: user.id })
          .select()
          .single();

        if (createError) throw createError;
        settingsData = newSettings;
      }

      const { data: profileLang } = await supabase
        .from("profiles")
        .select("preferred_language, primary_language")
        .eq("user_id", user.id)
        .maybeSingle();

      const persistedLanguage =
        profileLang?.preferred_language ||
        profileLang?.primary_language ||
        settingsData.language ||
        "English";

      const loadedSettings: UserSettings = {
        theme: settingsData.theme,
        accent_color: settingsData.accent_color,
        notification_matches: settingsData.notification_matches,
        notification_messages: settingsData.notification_messages,
        notification_promotions: settingsData.notification_promotions,
        notification_sound: settingsData.notification_sound,
        notification_vibration: settingsData.notification_vibration,
        language: persistedLanguage,
        auto_translate: settingsData.auto_translate,
        show_online_status: settingsData.show_online_status,
        show_read_receipts: settingsData.show_read_receipts,
        profile_visibility: settingsData.profile_visibility,
        distance_unit: settingsData.distance_unit,
      };

      setSettings(loadedSettings);
      setOriginalSettings(loadedSettings);
    } catch (error) {
      console.error("Error fetching settings:", error);
      toast.error("Failed to load settings");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSettings();
  }, []);

  // Only sync from realtime when NOT editing (no unsaved changes)
  useRealtimeSubscription({
    table: "user_settings",
    onUpdate: () => {
      if (!hasChanges) {
        fetchSettings();
      }
    }
  });

  // Update parallel chats selection when loaded
  useEffect(() => {
    setSelectedParallelChats(maxParallelChats.toString());
  }, [maxParallelChats]);

  useEffect(() => {
    const changed = JSON.stringify(settings) !== JSON.stringify(originalSettings) ||
                   selectedParallelChats !== maxParallelChats.toString();
    setHasChanges(changed);
  }, [settings, originalSettings, selectedParallelChats, maxParallelChats]);

  const handleSave = async () => {
    setSaving(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) {
        toast.error("Session expired. Please log in again.");
        navigate("/");
        return;
      }
      const user = session.user;

      // Only send columns that exist in user_settings table
      const updatePayload = {
        theme: settings.theme,
        accent_color: settings.accent_color,
        notification_matches: settings.notification_matches,
        notification_messages: settings.notification_messages,
        notification_promotions: settings.notification_promotions,
        notification_sound: settings.notification_sound,
        notification_vibration: settings.notification_vibration,
        language: settings.language,
        auto_translate: settings.auto_translate,
        show_online_status: settings.show_online_status,
        show_read_receipts: settings.show_read_receipts,
        profile_visibility: settings.profile_visibility,
        distance_unit: settings.distance_unit,
      };

      const { error } = await supabase
        .from("user_settings")
        .update(updatePayload)
        .eq("user_id", user.id);

      if (error) throw error;

      // Sync language change to profiles and user_languages tables
      // so matching/discovery reflects the updated language
      if (settings.language !== originalSettings.language) {
        // Determine user gender for profile sync
        const { data: profileData } = await supabase
          .from("profiles")
          .select("gender")
          .eq("user_id", user.id)
          .maybeSingle();
        const gender = profileData?.gender?.toLowerCase();

        // Sync to all relevant tables
        await supabase
          .from("profiles")
          .update({
            primary_language: settings.language,
            preferred_language: settings.language,
            updated_at: new Date().toISOString(),
          })
          .eq("user_id", user.id);
        await supabase.from("user_languages").delete().eq("user_id", user.id);
        await supabase.from("user_languages").insert({
          user_id: user.id,
          language_name: settings.language,
          language_code: selectedLanguageCode,
        });

        // Sync to gender-specific profile table so dashboard picks up the change
        if (gender === "male") {
          await supabase
            .from("male_profiles")
            .update({ primary_language: settings.language, preferred_language: settings.language })
            .eq("user_id", user.id);
        } else if (gender === "female") {
          await supabase
            .from("female_profiles")
            .update({ primary_language: settings.language, preferred_language: settings.language })
            .eq("user_id", user.id);
        }
      }

      // Save parallel chat settings
      try {
        await setMaxParallelChats(Number(selectedParallelChats));
      } catch (parallelError) {
        console.error("Error saving parallel chat settings:", parallelError);
        toast.error("Settings not saved", { description: "Unable to save your chat settings. Please try again." });
        // Don't fail the whole save for this
      }

      setOriginalSettings({ ...settings });
      setHasChanges(false);
      toast.success("Settings saved successfully!");
    } catch (error) {
      console.error("Error saving settings:", error);
      toast.error("Failed to save settings. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  const updateSetting = <K extends keyof UserSettings>(key: K, value: UserSettings[K]) => {
    setSettings(prev => ({ ...prev, [key]: value }));
  };

  if (loading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-48 w-full rounded-xl" />
        <Skeleton className="h-64 w-full rounded-xl" />
      </div>
    );
  }

  return (
    <div className={cn("space-y-6", compact && "space-y-4")}>
      {/* Parallel Chat Settings */}
      <Card>
        <CardHeader className={cn("pb-3", compact && "py-3 px-4")}>
          <CardTitle className="flex items-center gap-2 text-lg">
            <MessageCircle className="h-5 w-5 text-primary" />
            {t('parallelChats', 'Parallel Chats')}
          </CardTitle>
          <CardDescription>{t('parallelChatsDesc', 'Set how many chat windows you want open at once')}</CardDescription>
        </CardHeader>
        <CardContent className={compact ? "px-4 pb-4" : undefined}>
          <RadioGroup
            value={selectedParallelChats}
            onValueChange={setSelectedParallelChats}
            className="grid grid-cols-5 gap-2"
            disabled={parallelSettingsLoading}
          >
            {[
              { value: "1", label: "1", desc: "Focus" },
              { value: "2", label: "2", desc: "Light" },
              { value: "3", label: "3", desc: "Normal" },
              { value: "4", label: "4", desc: "Busy" },
              { value: "5", label: "5", desc: "Max" }
            ].map((option) => (
              <div key={option.value} className="relative">
                <RadioGroupItem value={option.value} id={`pc-${option.value}`} className="peer sr-only" />
                <Label
                  htmlFor={`pc-${option.value}`}
                  className={cn(
                    "flex flex-col items-center p-2 rounded-lg border-2 cursor-pointer transition-all text-center",
                    "hover:border-primary/50",
                    selectedParallelChats === option.value ? "border-primary bg-primary/10" : "border-border"
                  )}
                >
                  <MessageSquare className={cn("h-4 w-4 mb-1", selectedParallelChats === option.value ? "text-primary" : "text-muted-foreground")} />
                  <span className="font-semibold text-sm">{option.label}</span>
                  <span className="text-[9px] text-muted-foreground">{option.desc}</span>
                  {selectedParallelChats === option.value && (
                    <Check className="absolute top-1 right-1 h-3 w-3 text-primary" />
                  )}
                </Label>
              </div>
            ))}
          </RadioGroup>

          <p className="text-[10px] text-muted-foreground text-center mt-3">
            Old windows auto-close when new chats arrive at max capacity
          </p>
        </CardContent>
      </Card>

      {/* Appearance Settings */}
      <Card>
        <CardHeader className={cn("pb-3", compact && "py-3 px-4")}>
          <CardTitle className="flex items-center gap-2 text-lg">
            <Palette className="h-5 w-5 text-primary" />
            {t('appearance', 'Appearance')}
          </CardTitle>
          <CardDescription>{t('customizeAppLooks', 'Customize how the app looks with 20 beautiful themes')}</CardDescription>
        </CardHeader>
        <CardContent className={compact ? "px-4 pb-4" : undefined}>
          <ThemeSelector compact />
        </CardContent>
      </Card>

      {/* Notification Settings */}
      <Card>
        <CardHeader className={cn("pb-3", compact && "py-3 px-4")}>
          <CardTitle className="flex items-center gap-2 text-lg">
            <Bell className="h-5 w-5 text-primary" />
            {t('notifications', 'Notifications')}
          </CardTitle>
          <CardDescription>{t('manageNotifications', 'Manage your notification preferences')}</CardDescription>
        </CardHeader>
        <CardContent className={cn("space-y-4", compact && "px-4 pb-4")}>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Heart className="h-4 w-4 text-muted-foreground" />
              <Label htmlFor="notification-matches" className="cursor-pointer">{t('newMatches', 'New Matches')}</Label>
            </div>
            <Switch
              id="notification-matches"
              checked={settings.notification_matches}
              onCheckedChange={(checked) => updateSetting("notification_matches", checked)}
            />
          </div>

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <MessageSquare className="h-4 w-4 text-muted-foreground" />
              <Label htmlFor="notification-messages" className="cursor-pointer">{t('messages', 'Messages')}</Label>
            </div>
            <Switch
              id="notification-messages"
              checked={settings.notification_messages}
              onCheckedChange={(checked) => updateSetting("notification_messages", checked)}
            />
          </div>

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Megaphone className="h-4 w-4 text-muted-foreground" />
              <Label htmlFor="notification-promotions" className="cursor-pointer">{t('promotions', 'Promotions')}</Label>
            </div>
            <Switch
              id="notification-promotions"
              checked={settings.notification_promotions}
              onCheckedChange={(checked) => updateSetting("notification_promotions", checked)}
            />
          </div>

          <Separator />

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Volume2 className="h-4 w-4 text-muted-foreground" />
              <Label htmlFor="notification-sound" className="cursor-pointer">{t('sound', 'Sound')}</Label>
            </div>
            <Switch
              id="notification-sound"
              checked={settings.notification_sound}
              onCheckedChange={(checked) => updateSetting("notification_sound", checked)}
            />
          </div>

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Vibrate className="h-4 w-4 text-muted-foreground" />
              <Label htmlFor="notification-vibration" className="cursor-pointer">{t('vibration', 'Vibration')}</Label>
            </div>
            <Switch
              id="notification-vibration"
              checked={settings.notification_vibration}
              onCheckedChange={(checked) => updateSetting("notification_vibration", checked)}
            />
          </div>
        </CardContent>
      </Card>

      {/* Language & Translation */}
      <Card>
        <CardHeader className={cn("pb-3", compact && "py-3 px-4")}>
          <CardTitle className="flex items-center gap-2 text-lg">
            <Globe className="h-5 w-5 text-primary" />
            {t('languageRegion', 'Language & Region')}
          </CardTitle>
          <CardDescription>{t('setLanguagePreferences', 'Set your language and translation preferences')}</CardDescription>
        </CardHeader>
        <CardContent className={cn("space-y-4", compact && "px-4 pb-4")}>
          <LanguageSelector
            selectedLanguage={settings.language}
            selectedLanguageCode={selectedLanguageCode}
            onLanguageChange={(lang, code) => {
              updateSetting("language", lang);
              setSelectedLanguageCode(code);
              setOriginalSettings((prev) => ({ ...prev, language: lang }));
              setLanguage(lang);
            }}
            showAllLanguages={true}
            label={t('appLanguage', 'App Language')}
            description={t('languageDescription', 'Select your preferred language for the app interface')}
          />

          {/* Auto-translate setting removed - feature disabled */}

          <div className="space-y-2">
            <Label className="text-sm font-medium flex items-center gap-2">
              <Map className="h-4 w-4" />
              {t('distanceUnit', 'Distance Unit')}
            </Label>
            <Select
              value={settings.distance_unit}
              onValueChange={(value) => updateSetting("distance_unit", value)}
            >
              <SelectTrigger>
                <SelectValue placeholder={t('select', 'Select')} />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="km">{t('kilometers', 'Kilometers')} (km)</SelectItem>
                <SelectItem value="miles">{t('miles', 'Miles')}</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Privacy Settings */}
      <Card>
        <CardHeader className={cn("pb-3", compact && "py-3 px-4")}>
          <CardTitle className="flex items-center gap-2 text-lg">
            <Lock className="h-5 w-5 text-primary" />
            {t('privacy', 'Privacy')}
          </CardTitle>
          <CardDescription>{t('controlPrivacy', 'Control your privacy and visibility')}</CardDescription>
        </CardHeader>
        <CardContent className={cn("space-y-4", compact && "px-4 pb-4")}>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <Eye className="h-4 w-4 text-muted-foreground" />
              <Label htmlFor="show-online" className="cursor-pointer">{t('showOnlineStatus', 'Show Online Status')}</Label>
            </div>
            <Switch
              id="show-online"
              checked={settings.show_online_status}
              onCheckedChange={(checked) => updateSetting("show_online_status", checked)}
            />
          </div>

          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <CheckCircle2 className="h-4 w-4 text-muted-foreground" />
              <Label htmlFor="read-receipts" className="cursor-pointer">{t('readReceipts', 'Read Receipts')}</Label>
            </div>
            <Switch
              id="read-receipts"
              checked={settings.show_read_receipts}
              onCheckedChange={(checked) => updateSetting("show_read_receipts", checked)}
            />
          </div>

          <div className="space-y-3">
            <Label className="text-sm font-medium flex items-center gap-2">
              <Eye className="h-4 w-4" />
              {t('profileVisibility', 'Profile Visibility')}
            </Label>
            <p className="text-xs text-muted-foreground">
              {t('controlProfileVisibility', 'Control how often your profile appears to others in search results')}
            </p>
            <div className="grid grid-cols-2 gap-2">
              {[
                { value: "low", labelKey: "low", descKey: "rarelyShown", icon: "🔒" },
                { value: "medium", labelKey: "medium", descKey: "sometimesShown", icon: "👁️" },
                { value: "high", labelKey: "high", descKey: "oftenShown", icon: "⭐" },
                { value: "very_high", labelKey: "veryHigh", descKey: "alwaysPrioritized", icon: "🔥" },
              ].map((option) => (
                <button
                  key={option.value}
                  onClick={() => updateSetting("profile_visibility", option.value)}
                  className={cn(
                    "flex flex-col items-center justify-center p-3 rounded-xl border-2 transition-all duration-200 text-center",
                    settings.profile_visibility === option.value
                      ? "border-primary bg-primary/5"
                      : "border-border hover:border-primary/50"
                  )}
                >
                  <span className="text-2xl mb-1">{option.icon}</span>
                  <span className={cn(
                    "text-sm font-medium",
                    settings.profile_visibility === option.value ? "text-primary" : "text-foreground"
                  )}>
                    {t(option.labelKey, option.labelKey.charAt(0).toUpperCase() + option.labelKey.slice(1))}
                  </span>
                  <span className="text-xs text-muted-foreground">
                    {t(option.descKey, option.descKey)}
                  </span>
                </button>
              ))}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Install App */}
      <Card>
        <CardContent className={cn("pt-4", compact && "px-4 pb-4")}>
          <Button
            variant="outline"
            className="w-full justify-start gap-3"
            onClick={() => navigate("/install")}
          >
            <Globe className="h-4 w-4 text-primary" />
            {t('installApp', 'Install App on Your Device')}
          </Button>
        </CardContent>
      </Card>

      {/* Account Deletion */}
      <AccountDeletionSection compact={compact} />

      {/* Save Button - always visible when changes exist */}
      {hasChanges && (
        <div className="sticky bottom-4 z-50 flex justify-center pb-4 pt-2">
          <Button
            variant="aurora"
            size="lg"
            onClick={handleSave}
            disabled={saving}
            className="shadow-glow gap-2 min-w-[200px]"
          >
            {saving ? (
              <>
                <Loader2 className="h-5 w-5 animate-spin" />
                {t('saving', 'Saving...')}
              </>
            ) : (
              <>
                <Save className="h-5 w-5" />
                {t('saveChanges', 'Save Changes')}
              </>
            )}
          </Button>
        </div>
      )}
    </div>
  );
};

export default SettingsPanel;
