/**
 * Admin dialog to assign service roles to a user.
 * Used from /admin/user-management.
 */
import { useEffect, useState } from 'react';
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Label } from '@/components/ui/label';
import { Loader2, Shield } from 'lucide-react';
import { toast } from 'sonner';
import { fetchUserServiceRoles, setUserServiceRoles, type ServiceRole } from '@/hooks/useServiceRoles';

interface Props {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  userId: string | null;
  userName?: string | null;
}

const ROLE_OPTIONS: { value: ServiceRole; label: string; hint: string }[] = [
  { value: 'chat_role',  label: 'Chat',              hint: 'Text chat' },
  { value: 'audio_role', label: 'Audio Call',        hint: 'Voice calls' },
  { value: 'video_role', label: 'Video Call',        hint: 'Video calls' },
  { value: 'group_role', label: 'Private Group Call', hint: 'Group video rooms' },
  { value: 'all_role',   label: 'All Access',        hint: 'Full access (overrides others)' },
  { value: 'tl_role',    label: 'Team Lead (TL)',    hint: 'Women only — unlocks TL tab & free chat with admin' },
];

export function AdminServiceRolesDialog({ open, onOpenChange, userId, userName }: Props) {
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [selected, setSelected] = useState<Set<ServiceRole>>(new Set());

  useEffect(() => {
    if (!open || !userId) return;
    setLoading(true);
    fetchUserServiceRoles(userId)
      .then(roles => setSelected(new Set(roles)))
      .catch(err => toast.error(err.message ?? 'Failed to load roles'))
      .finally(() => setLoading(false));
  }, [open, userId]);

  const toggle = (role: ServiceRole) => {
    setSelected(prev => {
      const next = new Set(prev);
      if (next.has(role)) next.delete(role); else next.add(role);
      return next;
    });
  };

  const handleSave = async () => {
    if (!userId) return;
    if (selected.size === 0) {
      toast.error('Assign at least one role');
      return;
    }
    setSaving(true);
    try {
      await setUserServiceRoles(userId, Array.from(selected));
      toast.success('Service roles updated');
      onOpenChange(false);
    } catch (err: any) {
      toast.error(err.message ?? 'Failed to save roles');
    } finally {
      setSaving(false);
    }
  };

  const hasAll = selected.has('all_role');

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-primary" /> Service Roles
          </DialogTitle>
          <DialogDescription>
            {userName ? `Assign which services ${userName} can access.` : 'Assign which services this user can access.'}
            {' '}<strong>All Access</strong> grants every service.
          </DialogDescription>
        </DialogHeader>

        {loading ? (
          <div className="flex justify-center py-6"><Loader2 className="h-6 w-6 animate-spin text-primary" /></div>
        ) : (
          <div className="space-y-3 py-2">
            {ROLE_OPTIONS.map(opt => {
              const checked = selected.has(opt.value);
              const disabled = hasAll && opt.value !== 'all_role' && opt.value !== 'tl_role';
              return (
                <label
                  key={opt.value}
                  className={`flex items-start gap-3 p-3 border rounded-lg cursor-pointer transition-colors ${disabled ? 'opacity-50' : 'hover:bg-muted/50'}`}
                >
                  <Checkbox
                    checked={checked}
                    disabled={disabled}
                    onCheckedChange={() => toggle(opt.value)}
                  />
                  <div className="flex-1">
                    <Label className="cursor-pointer font-medium">{opt.label}</Label>
                    <p className="text-xs text-muted-foreground">{opt.hint}</p>
                  </div>
                </label>
              );
            })}
          </div>
        )}

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={saving}>Cancel</Button>
          <Button onClick={handleSave} disabled={saving || loading}>
            {saving && <Loader2 className="h-4 w-4 mr-2 animate-spin" />}
            Save
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
