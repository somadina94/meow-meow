import { useNavigate } from "react-router-dom";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Home, Settings } from "lucide-react";

import { SettingsPanel } from "@/components/SettingsPanel";
import { supabase } from "@/integrations/supabase/client";

const SettingsScreen = () => {
  const navigate = useNavigate();
  const t = (key: string, def: string) => def;
  const [homePath, setHomePath] = useState("/dashboard");

  useEffect(() => {
    const detectHome = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) return;
      const { data: profile } = await supabase
        .from("profiles")
        .select("gender")
        .eq("user_id", session.user.id)
        .single();
      if (profile?.gender?.toLowerCase() === "female") {
        setHomePath("/women-dashboard");
      }
    };
    detectHome();
  }, []);

  return (
    <div className="min-h-screen bg-background pb-24">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 border-b border-border">
        <div className="max-w-md mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Button
              variant="auroraGhost"
              size="icon"
              onClick={() => navigate(-1)}
              className="rounded-full"
            >
              <ArrowLeft className="h-5 w-5" />
            </Button>
            <Button
              variant="auroraGhost"
              size="icon"
              onClick={() => navigate(homePath)}
              className="rounded-full"
            >
              <Home className="h-5 w-5" />
            </Button>
            <h1 className="text-xl font-semibold flex items-center gap-2">
              <Settings className="h-5 w-5" />
              {t('settings', 'Settings')}
            </h1>
          </div>
        </div>
      </div>

      <div className="max-w-md mx-auto p-4">
        <SettingsPanel />
      </div>
    </div>
  );
};

export default SettingsScreen;
