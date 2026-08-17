/**
 * AdminEnableDisable — Global feature visibility / availability toggles.
 *
 * Controls:
 *  - Statements tab visibility inside user wallet screens.
 *  - Chat availability (Chats tab + new chat starts).
 *  - Audio call availability (call buttons + new audio calls).
 *  - Video call availability (call buttons + new video calls).
 *  - Private group calls availability (Groups tab + entering rooms).
 *
 * IMPORTANT:
 *  - Wallet balance and recharge are NEVER affected by these toggles.
 *  - Toggles only block NEW entry points. Users currently in a chat /
 *    call / group session are NOT disconnected — they finish naturally.
 *  - Designed for use under heavy system load to prevent crashes by
 *    stopping new sessions from starting.
 */
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";
import { useToast } from "@/hooks/use-toast";
import {
  ArrowLeft, FileText, Eye, EyeOff,
  MessageCircle, Phone, Video, Users, AlertTriangle,
} from "lucide-react";
import { useAppSettings } from "@/hooks/useAppSettings";

type ToggleKey =
  | "statements_tab_visible"
  | "chat_enabled"
  | "audio_call_enabled"
  | "video_call_enabled"
  | "private_groups_enabled";

interface ToggleConfig {
  key: ToggleKey;
  settingsField:
    | "statementsTabVisible"
    | "chatEnabled"
    | "audioCallEnabled"
    | "videoCallEnabled"
    | "privateGroupsEnabled";
  title: string;
  description: string;
  icon: React.ReactNode;
  onLabel: string;
  offLabel: string;
  onToastTitle: string;
  offToastTitle: string;
  onToastDesc: string;
  offToastDesc: string;
  defaultOn: boolean; // default state if row missing
}

const TOGGLES: ToggleConfig[] = [
  {
    key: "statements_tab_visible",
    settingsField: "statementsTabVisible",
    title: "Statements Tab (Wallet)",
    description:
      "Show or hide the Statements tab inside user wallet screens for all users (men & women). Wallet balance & recharge are unaffected.",
    icon: <FileText className="w-5 h-5 text-primary" />,
    onLabel: "Visible to all users",
    offLabel: "Hidden for all users",
    onToastTitle: "Statements tab enabled",
    offToastTitle: "Statements tab hidden",
    onToastDesc: "All users can now see the Statements tab inside their wallet.",
    offToastDesc: "Statements tab is now hidden for all users. Wallet balance and recharge remain unaffected.",
    defaultOn: false,
  },
  {
    key: "chat_enabled",
    settingsField: "chatEnabled",
    title: "Chat (Text Messaging)",
    description:
      "Allow new chat conversations to start. When OFF: Chats tab is hidden and new chats are blocked on both dashboards. Active conversations continue normally.",
    icon: <MessageCircle className="w-5 h-5 text-primary" />,
    onLabel: "Chat available for all users",
    offLabel: "Chat disabled for new users",
    onToastTitle: "Chat enabled",
    offToastTitle: "Chat disabled",
    onToastDesc: "Users can now start new chats.",
    offToastDesc: "New chats are blocked. Users currently chatting are not disconnected.",
    defaultOn: true,
  },
  {
    key: "audio_call_enabled",
    settingsField: "audioCallEnabled",
    title: "Audio Calls",
    description:
      "Allow new audio (voice) calls to be placed. When OFF: audio call buttons are hidden and new audio calls are blocked. Active calls continue.",
    icon: <Phone className="w-5 h-5 text-primary" />,
    onLabel: "Audio calls available",
    offLabel: "Audio calls disabled for new calls",
    onToastTitle: "Audio calls enabled",
    offToastTitle: "Audio calls disabled",
    onToastDesc: "Users can now start audio calls.",
    offToastDesc: "New audio calls are blocked. Active calls are not affected.",
    defaultOn: true,
  },
  {
    key: "video_call_enabled",
    settingsField: "videoCallEnabled",
    title: "Video Calls",
    description:
      "Allow new video calls to be placed. When OFF: video call buttons are hidden and new video calls are blocked. Active calls continue.",
    icon: <Video className="w-5 h-5 text-primary" />,
    onLabel: "Video calls available",
    offLabel: "Video calls disabled for new calls",
    onToastTitle: "Video calls enabled",
    offToastTitle: "Video calls disabled",
    onToastDesc: "Users can now start video calls.",
    offToastDesc: "New video calls are blocked. Active calls are not affected.",
    defaultOn: true,
  },
  {
    key: "private_groups_enabled",
    settingsField: "privateGroupsEnabled",
    title: "Private Group Calls",
    description:
      "Allow users to enter or start private group call rooms. When OFF: Groups tab is hidden and entering rooms is blocked. Active group sessions continue.",
    icon: <Users className="w-5 h-5 text-primary" />,
    onLabel: "Private groups available",
    offLabel: "Private groups disabled for new entries",
    onToastTitle: "Private group calls enabled",
    offToastTitle: "Private group calls disabled",
    onToastDesc: "Users can now enter private group rooms.",
    offToastDesc: "New entries to private group rooms are blocked. Active rooms are not affected.",
    defaultOn: true,
  },
];

const AdminEnableDisable = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const { settings, isLoading, refetch } = useAppSettings();
  const [savingKey, setSavingKey] = useState<ToggleKey | null>(null);
  const [localValues, setLocalValues] = useState<Record<ToggleKey, boolean>>({
    statements_tab_visible: false,
    chat_enabled: true,
    audio_call_enabled: true,
    video_call_enabled: true,
    private_groups_enabled: true,
  });

  useEffect(() => {
    setLocalValues({
      statements_tab_visible: !!settings.statementsTabVisible,
      chat_enabled: settings.chatEnabled !== false,
      audio_call_enabled: settings.audioCallEnabled !== false,
      video_call_enabled: settings.videoCallEnabled !== false,
      private_groups_enabled: settings.privateGroupsEnabled !== false,
    });
  }, [
    settings.statementsTabVisible,
    settings.chatEnabled,
    settings.audioCallEnabled,
    settings.videoCallEnabled,
    settings.privateGroupsEnabled,
  ]);

  const handleToggle = async (cfg: ToggleConfig, next: boolean) => {
    setSavingKey(cfg.key);
    setLocalValues((prev) => ({ ...prev, [cfg.key]: next })); // optimistic
    try {
      const { error } = await supabase
        .from("app_settings")
        .upsert(
          {
            setting_key: cfg.key,
            setting_value: next as unknown as any,
            setting_type: "json",
            is_public: true,
            description: cfg.description,
          },
          { onConflict: "setting_key" }
        );
      if (error) throw error;
      toast({
        title: next ? cfg.onToastTitle : cfg.offToastTitle,
        description: next ? cfg.onToastDesc : cfg.offToastDesc,
      });
      await refetch();
    } catch (err: any) {
      setLocalValues((prev) => ({ ...prev, [cfg.key]: !next })); // revert
      toast({
        title: "Failed to update setting",
        description: err?.message ?? "Please try again.",
        variant: "destructive",
      });
    } finally {
      setSavingKey(null);
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <div className="sticky top-0 z-40 bg-primary text-primary-foreground px-4 py-3 flex items-center gap-3">
        <Button
          variant="ghost"
          size="icon"
          className="text-primary-foreground"
          onClick={() => navigate("/admin")}
        >
          <ArrowLeft className="w-5 h-5" />
        </Button>
        <h1 className="text-lg font-semibold flex-1">Enable / Disable Features</h1>
      </div>

      <div className="max-w-2xl mx-auto p-4 space-y-4">
        <Card className="p-4 border-amber-300/60 bg-amber-50 dark:bg-amber-950/20">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
            <div className="text-xs text-amber-900 dark:text-amber-200 leading-relaxed">
              <strong>Heavy load control:</strong> Use these toggles when the
              system is under high load to stop NEW chats, calls, or group
              entries from starting. Users already in an active chat, call, or
              group room will continue without interruption — only new entries
              are blocked.
              <br />
              Wallet balance, recharge, and login flows are never affected.
            </div>
          </div>
        </Card>

        {isLoading ? (
          <>
            <Skeleton className="h-32 w-full rounded-xl" />
            <Skeleton className="h-32 w-full rounded-xl" />
            <Skeleton className="h-32 w-full rounded-xl" />
          </>
        ) : (
          TOGGLES.map((cfg) => {
            const value = localValues[cfg.key];
            const isStatement = cfg.key === "statements_tab_visible";
            // For statements: ON=Visible. For others: ON=Available.
            return (
              <Card key={cfg.key} className="p-5">
                <div className="flex items-start gap-4">
                  <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                    {cfg.icon}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-3">
                      <div className="min-w-0">
                        <h2 className="font-semibold text-base">{cfg.title}</h2>
                        <p className="text-xs text-muted-foreground mt-0.5">
                          {cfg.description}
                        </p>
                      </div>
                      <Switch
                        checked={value}
                        disabled={savingKey === cfg.key}
                        onCheckedChange={(next) => handleToggle(cfg, next)}
                        aria-label={`Toggle ${cfg.title}`}
                      />
                    </div>

                    <div className="mt-3 flex items-center gap-2 text-xs">
                      {value ? (
                        <>
                          <Eye className="w-3.5 h-3.5 text-green-600" />
                          <span className="text-green-700 dark:text-green-400 font-medium">
                            {cfg.onLabel}
                          </span>
                        </>
                      ) : (
                        <>
                          <EyeOff className="w-3.5 h-3.5 text-muted-foreground" />
                          <span className="text-muted-foreground font-medium">
                            {cfg.offLabel}
                          </span>
                        </>
                      )}
                    </div>

                    {!isStatement && !value && (
                      <div className="mt-3 rounded-lg bg-muted/50 p-3 text-xs text-muted-foreground">
                        <strong className="text-foreground">Active sessions safe:</strong>{" "}
                        Users currently using this feature continue without
                        interruption. Only new {cfg.title.toLowerCase()} are blocked.
                      </div>
                    )}
                  </div>
                </div>
              </Card>
            );
          })
        )}
      </div>
    </div>
  );
};

export default AdminEnableDisable;
