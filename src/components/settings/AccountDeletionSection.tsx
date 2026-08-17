import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { toast } from "sonner";
import { Trash2, AlertTriangle, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";


interface AccountDeletionSectionProps {
  compact?: boolean;
}

export const AccountDeletionSection = ({ compact = false }: AccountDeletionSectionProps) => {
  const navigate = useNavigate();
  const t = (key: string, def: string) => def;
  const [confirmText, setConfirmText] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);

  const CONFIRM_PHRASE = "DELETE";

  const handleDeleteAccount = async () => {
    if (confirmText !== CONFIRM_PHRASE) return;

    setDeleting(true);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session?.user) {
        toast.error("Session expired. Please log in again.");
        navigate("/");
        return;
      }

      // Call the admin-delete-user edge function to handle full cascading deletion
      const { data, error } = await supabase.functions.invoke("admin-delete-user", {
        method: "POST",
        body: { userId: session.user.id, selfDelete: true },
      });

      if (error) throw error;

      // Sign out locally after deletion
      await supabase.auth.signOut();
      toast.success(t("accountDeleted", "Your account has been permanently deleted."));
      navigate("/", { replace: true });
    } catch (error) {
      console.error("Error deleting account:", error);
      toast.error(t("accountDeleteFailed", "Failed to delete account. Please try again or contact support."));
    } finally {
      setDeleting(false);
    }
  };

  return (
    <Card className="border-destructive/30">
      <CardHeader className={cn("pb-3", compact && "py-3 px-4")}>
        <CardTitle className="flex items-center gap-2 text-lg text-destructive">
          <Trash2 className="h-5 w-5" />
          {t("dangerZone", "Danger Zone")}
        </CardTitle>
        <CardDescription>
          {t("dangerZoneDesc", "Irreversible actions that permanently affect your account")}
        </CardDescription>
      </CardHeader>
      <CardContent className={compact ? "px-4 pb-4" : undefined}>
        <div className="space-y-3">
          <p className="text-sm text-muted-foreground">
            {t(
              "deleteAccountWarning",
              "Deleting your account will permanently remove all your data including your profile, messages, matches, wallet balance, and transaction history. This action cannot be undone."
            )}
          </p>

          <AlertDialog open={dialogOpen} onOpenChange={(open) => {
            setDialogOpen(open);
            if (!open) setConfirmText("");
          }}>
            <AlertDialogTrigger asChild>
              <Button variant="destructive" className="gap-2">
                <Trash2 className="h-4 w-4" />
                {t("deleteMyAccount", "Delete My Account")}
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle className="flex items-center gap-2 text-destructive">
                  <AlertTriangle className="h-5 w-5" />
                  {t("confirmAccountDeletion", "Confirm Account Deletion")}
                </AlertDialogTitle>
                <AlertDialogDescription className="space-y-3 text-left">
                  <span className="block">
                    {t(
                      "deleteConfirmMessage",
                      "This will permanently delete your account and all associated data. You will lose:"
                    )}
                  </span>
                  <ul className="list-disc pl-5 space-y-1 text-sm">
                    <li>{t("deleteItemProfile", "Your profile and photos")}</li>
                    <li>{t("deleteItemMessages", "All messages and chat history")}</li>
                    <li>{t("deleteItemMatches", "Your matches and connections")}</li>
                    <li>{t("deleteItemWallet", "Wallet balance and transaction history")}</li>
                    <li>{t("deleteItemEarnings", "Any pending earnings")}</li>
                  </ul>
                  <span className="block font-medium mt-2">
                    {t("typeDeleteToConfirm", 'Type "DELETE" below to confirm:')}
                  </span>
                </AlertDialogDescription>
              </AlertDialogHeader>
              <div className="py-2">
                <Label htmlFor="confirm-delete" className="sr-only">
                  {t("confirmDeletion", "Confirm deletion")}
                </Label>
                <Input
                  id="confirm-delete"
                  value={confirmText}
                  onChange={(e) => setConfirmText(e.target.value.toUpperCase())}
                  placeholder='DELETE'
                  className="border-destructive/50 focus-visible:ring-destructive"
                  autoComplete="off"
                />
              </div>
              <AlertDialogFooter>
                <AlertDialogCancel disabled={deleting}>
                  {t("cancel", "Cancel")}
                </AlertDialogCancel>
                <AlertDialogAction
                  onClick={handleDeleteAccount}
                  disabled={confirmText !== CONFIRM_PHRASE || deleting}
                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                >
                  {deleting ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin mr-2" />
                      {t("deleting", "Deleting...")}
                    </>
                  ) : (
                    <>
                      <Trash2 className="h-4 w-4 mr-2" />
                      {t("permanentlyDelete", "Permanently Delete")}
                    </>
                  )}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </div>
      </CardContent>
    </Card>
  );
};
