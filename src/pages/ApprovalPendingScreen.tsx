import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Clock, CheckCircle, XCircle, RefreshCw, LogOut, Shield, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import MeowLogo from "@/components/MeowLogo";
import { supabase } from "@/integrations/supabase/client";
import { toast } from "@/hooks/use-toast";

type ApprovalStatus = "pending" | "approved" | "disapproved" | "inactive";

const ApprovalPendingScreen = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [status, setStatus] = useState<ApprovalStatus>("pending");
  const [disapprovalReason, setDisapprovalReason] = useState<string | null>(null);
  const [userName, setUserName] = useState<string>("");
  const [userId, setUserId] = useState<string | null>(null);

  useEffect(() => {
    checkApprovalStatus();
  }, []);

  // Realtime subscription for approval status changes
  useEffect(() => {
    if (!userId) return;

    const channel = supabase
      .channel(`approval-status-${userId}`)
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "profiles",
          filter: `user_id=eq.${userId}`,
        },
        (payload) => {
          const newStatus = payload.new.approval_status as ApprovalStatus;
          const newReason = payload.new.ai_disapproval_reason as string | null;

          setStatus(newStatus);
          setDisapprovalReason(newReason);

          if (newStatus === "approved") {
            toast({
              title: "Welcome! 🎉",
              description: "Your account has been approved. Enjoy earning!",
            });
            navigate("/women-dashboard");
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId, navigate]);

  const checkApprovalStatus = async () => {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) {
        navigate("/");
        return;
      }
      const user = session.user;
      setUserId(user.id);
      const { data: profile, error } = await supabase
        .from("profiles")
        .select("approval_status, ai_disapproval_reason, full_name, gender")
        .eq("user_id", user.id)
        .single();

      if (error) throw error;

      // If not female, redirect to regular dashboard
      if (profile?.gender?.toLowerCase() !== "female") {
        navigate("/dashboard");
        return;
      }

      setUserName(profile?.full_name || "");
      setStatus(profile?.approval_status as ApprovalStatus || "pending");
      setDisapprovalReason(profile?.ai_disapproval_reason || null);

      // If approved, redirect to women dashboard
      if (profile?.approval_status === "approved") {
        toast({
          title: "Welcome! 🎉",
          description: "Your account has been approved. Enjoy earning!",
        });
        navigate("/women-dashboard");
        return;
      }
    } catch (error: any) {
      console.error("Error checking approval:", error);
      toast({
        title: "Error",
        description: "Failed to check approval status",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    await checkApprovalStatus();
    setRefreshing(false);
    
    if (status === "pending") {
      toast({
        title: "Status Updated",
        description: "Your application is still being reviewed.",
      });
    }
  };

  const handleLogout = async () => {
    // Get current user to set offline status
    const { data: { session } } = await supabase.auth.getSession();
    if (session?.user) {
      const user = session.user;
      const now = new Date().toISOString();
      await supabase
        .from('user_status')
        .update({ is_online: false, last_seen: now })
        .eq('user_id', user.id);
    }
    await supabase.auth.signOut();
    navigate("/");
  };

  const handleReapply = async () => {
    try {
      setLoading(true);
      const { data: { session: s } } = await supabase.auth.getSession();
      if (!s?.user) return;
      const user = s.user;

      // Show processing message
      toast({
        title: "Processing Request",
        description: "Your reapproval request is being processed. Please wait...",
      });

      // Call the edge function for immediate approval
      const { data, error } = await supabase.functions.invoke('ai-women-approval', {
        body: { action: 'request_reapproval', user_id: user.id }
      });

      if (error) throw error;

      if (data?.success) {
        setStatus("approved");
        setDisapprovalReason(null);
        
        toast({
          title: "✅ Approved Successfully!",
          description: "Your account has been reactivated. You are now a Free User and can start chatting. Perform well to earn a badge!",
        });

        // Navigate to dashboard after short delay
        setTimeout(() => {
          navigate("/women-dashboard");
        }, 2000);
      } else {
        throw new Error(data?.error || "Approval failed");
      }
    } catch (error: any) {
      console.error("Reapply error:", error);
      toast({
        title: "Reapproval Failed",
        description: error?.message || "Failed to process your request. Please try again later.",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen gradient-hero flex items-center justify-center">
        <div className="text-center">
          <MeowLogo size="lg" className="mx-auto mb-4 animate-pulse" />
          <p className="text-muted-foreground">Checking approval status...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen gradient-hero flex flex-col">
      {/* Header */}
      <header className="px-6 py-4 flex items-center justify-between">
        <MeowLogo size="sm" />
        <Button variant="auroraGhost" size="sm" onClick={handleLogout}>
          <LogOut className="w-4 h-4 mr-2" />
          Logout
        </Button>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex items-center justify-center px-6 pb-8">
        <Card className="w-full max-w-md bg-card/90 backdrop-blur-sm border-border/30 shadow-xl">
          <CardHeader className="text-center pb-4">
            {status === "pending" && (
              <>
                <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-warning/20 flex items-center justify-center">
                  <Clock className="w-10 h-10 text-warning animate-pulse" />
                </div>
                <CardTitle className="text-2xl">Approval Pending</CardTitle>
                <CardDescription>
                  Hi {userName || "there"}! Your account is being reviewed.
                </CardDescription>
              </>
            )}
            
            {(status === "disapproved" || status === "inactive") && (
              <>
                <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-destructive/20 flex items-center justify-center">
                  {status === "inactive" ? (
                    <Clock className="w-10 h-10 text-warning" />
                  ) : (
                    <XCircle className="w-10 h-10 text-destructive" />
                  )}
                </div>
                <CardTitle className="text-2xl">
                  {status === "inactive" ? "Account Inactive" : "Application Declined"}
                </CardTitle>
                <CardDescription>
                  {status === "inactive" 
                    ? `Hi ${userName || "there"}! Your account became inactive due to inactivity. You can reactivate it below.`
                    : "We're sorry, but your application was not approved at this time."}
                </CardDescription>
              </>
            )}
          </CardHeader>

          <CardContent className="space-y-6">
            {status === "pending" && (
              <>
                <div className="bg-warning/10 rounded-xl p-4 border border-warning/20">
                  <h4 className="font-semibold text-warning mb-2 flex items-center gap-2">
                    <Shield className="w-4 h-4" />
                    What happens next?
                  </h4>
                  <ul className="text-sm text-muted-foreground space-y-2">
                    <li className="flex items-start gap-2">
                      <CheckCircle className="w-4 h-4 mt-0.5 text-success flex-shrink-0" />
                      <span>Our AI system reviews your profile automatically</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <CheckCircle className="w-4 h-4 mt-0.5 text-success flex-shrink-0" />
                      <span>Approval depends on language group availability</span>
                    </li>
                    <li className="flex items-start gap-2">
                      <CheckCircle className="w-4 h-4 mt-0.5 text-green-500 flex-shrink-0" />
                      <span>You'll be notified once approved</span>
                    </li>
                  </ul>
                </div>

                <div className="text-center">
                  <Badge variant="secondary" className="mb-4">
                    <Clock className="w-3 h-3 mr-1" />
                    Usually takes 24-48 hours
                  </Badge>
                </div>

                <Button
                  variant="auroraOutline"
                  className="w-full"
                  onClick={handleRefresh}
                  disabled={refreshing}
                >
                  {refreshing ? (
                    <RefreshCw className="w-4 h-4 mr-2 animate-spin" />
                  ) : (
                    <RefreshCw className="w-4 h-4 mr-2" />
                  )}
                  Check Status
                </Button>
              </>
            )}

            {(status === "disapproved" || status === "inactive") && (
              <>
                {disapprovalReason && (
                  <div className="bg-destructive/10 rounded-xl p-4 border border-destructive/20">
                    <h4 className="font-semibold text-destructive mb-2">Reason</h4>
                    <p className="text-sm text-muted-foreground">{disapprovalReason}</p>
                  </div>
                )}

                <div className="bg-muted/50 rounded-xl p-4">
                  <h4 className="font-semibold mb-2 flex items-center gap-2">
                    <Star className="w-4 h-4 text-primary" />
                    Tips for approval
                  </h4>
                  <ul className="text-sm text-muted-foreground space-y-1">
                    <li>• Complete your profile fully</li>
                    <li>• Upload a clear profile photo</li>
                    <li>• Stay active on the platform</li>
                    <li>• Maintain good response times</li>
                  </ul>
                </div>

                <Button
                  variant="aurora"
                  className="w-full"
                  onClick={handleReapply}
                  disabled={loading}
                >
                  <RefreshCw className="w-4 h-4 mr-2" />
                  Reapply for Approval
                </Button>
              </>
            )}
          </CardContent>
        </Card>
      </main>

      {/* Footer */}
      <footer className="px-6 py-4 text-center">
        <p className="text-xs text-muted-foreground">
          Have questions? Contact support for assistance.
        </p>
      </footer>

      {/* Decorative Elements */}
      <div className="fixed top-20 left-4 w-32 h-32 rounded-full bg-primary/5 blur-3xl pointer-events-none" />
      <div className="fixed bottom-32 right-4 w-40 h-40 rounded-full bg-accent/10 blur-3xl pointer-events-none" />
    </div>
  );
};

export default ApprovalPendingScreen;
