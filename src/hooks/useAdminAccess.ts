import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "sonner";

const ADMIN_CHECK_TIMEOUT = 15000; // 15 seconds — generous for slow DBs

// Module-level cache so multiple components share one check per session
const CACHE_TTL = 300_000; // 5 minutes
let cachedResult: { isAdmin: boolean; email: string; userId: string; timestamp: number } | null = null;
let pendingPromise: Promise<{ isAdmin: boolean; email: string; userId: string; timestamp: number } | null> | null = null;

const performAdminCheck = async (): Promise<{ isAdmin: boolean; email: string; userId: string; timestamp: number } | null> => {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session?.user) return null;

  const user = session.user;

  // Retry up to 3 times with backoff
  let roleData: any = null;
  let roleError: any = null;

  for (let attempt = 1; attempt <= 3; attempt++) {
    const result = await supabase
      .from("user_roles")
      .select("role")
      .eq("user_id", user.id)
      .eq("role", "admin")
      .maybeSingle();

    roleData = result.data;
    roleError = result.error;

    if (!roleError || attempt === 3) break;
    console.warn(`[useAdminAccess] Role check attempt ${attempt} failed, retrying...`);
    await new Promise(r => setTimeout(r, 1000 * attempt));
  }

  if (roleError) {
    console.error("[useAdminAccess] Role check error:", roleError);
    throw new Error("Role check failed");
  }

  return {
    isAdmin: !!roleData,
    email: user.email || "",
    userId: user.id,
    timestamp: Date.now(),
  };
};

export const useAdminAccess = () => {
  const navigate = useNavigate();
  const [isLoading, setIsLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);
  const [adminEmail, setAdminEmail] = useState("");
  const [userId, setUserId] = useState("");
  const hasChecked = useRef(false);

  useEffect(() => {
    if (hasChecked.current) return;
    hasChecked.current = true;

    let mounted = true;

    const check = async () => {
      // Fast path: use cached result from another component's check
      if (cachedResult && (Date.now() - cachedResult.timestamp) < CACHE_TTL) {
        if (!mounted) return;
        if (!cachedResult.isAdmin) {
          toast.error("Access Denied", { description: "You don't have admin privileges" });
          navigate("/dashboard");
          return;
        }
        setIsAdmin(true);
        setAdminEmail(cachedResult.email);
        setUserId(cachedResult.userId);
        setIsLoading(false);
        return;
      }

      // Deduplicate: if another hook instance is already checking, wait for it
      if (!pendingPromise) {
        pendingPromise = performAdminCheck().finally(() => {
          pendingPromise = null;
        });
      }

      try {
        const result = await Promise.race([
          pendingPromise,
          new Promise<"timeout">((resolve) =>
            setTimeout(() => resolve("timeout"), ADMIN_CHECK_TIMEOUT)
          ),
        ]);

        if (!mounted) return;

        if (result === "timeout") {
          console.warn("[useAdminAccess] Admin check timed out after 15s");
          toast.error("Admin check timed out", {
            description: "The server took too long to respond. Please try again.",
          });
          setIsLoading(false);
          return; // Stay on page — don't navigate away
        }

        if (!result) {
          // No session
          navigate("/");
          return;
        }

        // Cache for other components
        cachedResult = result;

        if (!result.isAdmin) {
          toast.error("Access Denied", { description: "You don't have admin privileges" });
          navigate("/dashboard");
          return;
        }

        setIsAdmin(true);
        setAdminEmail(result.email);
        setUserId(result.userId);
      } catch (error) {
        console.error("[useAdminAccess] Error:", error);
        if (mounted) {
          toast.error("Access check failed", {
            description: "Unable to verify admin access. Please refresh the page.",
          });
          // Don't navigate away — let admin retry
        }
      } finally {
        if (mounted) setIsLoading(false);
      }
    };

    check();
    return () => { mounted = false; };
  }, [navigate]);

  return { isLoading, isAdmin, adminEmail, userId };
};

// Call on logout to clear cached admin state
export const clearAdminCache = () => {
  cachedResult = null;
  pendingPromise = null;
};
