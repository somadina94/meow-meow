/**
 * Service Roles Hook
 *
 * Returns the current user's service-role set + helpers to check whether they
 * can access a specific service (chat / audio / video / group). `all_role`
 * grants access to every service.
 *
 * Single source of truth: `public.user_service_roles` table.
 */
import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuthReady } from '@/hooks/useAuthReady';

export type ServiceRole = 'chat_role' | 'audio_role' | 'video_role' | 'group_role' | 'all_role' | 'tl_role';
export type ServiceKey = 'chat' | 'audio' | 'video' | 'group';

const SERVICE_TO_ROLE: Record<ServiceKey, ServiceRole> = {
  chat: 'chat_role',
  audio: 'audio_role',
  video: 'video_role',
  group: 'group_role',
};

interface State {
  roles: ServiceRole[];
  loading: boolean;
}

export function useServiceRoles() {
  const { user, isReady } = useAuthReady();
  const [state, setState] = useState<State>({ roles: [], loading: true });

  const fetchRoles = useCallback(async (uid: string) => {
    setState(s => ({ ...s, loading: true }));
    const { data, error } = await supabase
      .from('user_service_roles')
      .select('role')
      .eq('user_id', uid);
    if (error) {
      console.warn('[useServiceRoles] fetch error', error);
      setState({ roles: [], loading: false });
      return;
    }
    setState({ roles: (data ?? []).map(r => r.role as ServiceRole), loading: false });
  }, []);

  useEffect(() => {
    if (!isReady) return;
    if (!user) { setState({ roles: [], loading: false }); return; }
    fetchRoles(user.id);

    // Live updates so admin changes propagate without refresh
    const channel = supabase
      .channel(`service-roles-${user.id}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'user_service_roles', filter: `user_id=eq.${user.id}` },
        () => fetchRoles(user.id)
      )
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [user?.id, isReady, fetchRoles]);

  const canAccess = useCallback((service: ServiceKey) => {
    if (state.roles.includes('all_role')) return true;
    return state.roles.includes(SERVICE_TO_ROLE[service]);
  }, [state.roles]);

  return {
    roles: state.roles,
    loading: state.loading,
    canChat: canAccess('chat'),
    canAudio: canAccess('audio'),
    canVideo: canAccess('video'),
    canGroup: canAccess('group'),
    isTL: state.roles.includes('tl_role'),
    canAccess,
    refresh: () => user && fetchRoles(user.id),
  };
}

/** Admin helper — fetch the service roles of an arbitrary user (RLS allows admins). */
export async function fetchUserServiceRoles(userId: string): Promise<ServiceRole[]> {
  const { data, error } = await supabase
    .from('user_service_roles')
    .select('role')
    .eq('user_id', userId);
  if (error) throw error;
  return (data ?? []).map(r => r.role as ServiceRole);
}

/** Admin helper — set the exact set of service roles a user holds. */
export async function setUserServiceRoles(userId: string, roles: ServiceRole[]): Promise<void> {
  const current = await fetchUserServiceRoles(userId);
  const toAdd = roles.filter(r => !current.includes(r));
  const toRemove = current.filter(r => !roles.includes(r));

  if (toRemove.length) {
    const { error } = await supabase
      .from('user_service_roles')
      .delete()
      .eq('user_id', userId)
      .in('role', toRemove);
    if (error) throw error;
  }
  if (toAdd.length) {
    const { data: { user } } = await supabase.auth.getUser();
    const { error } = await supabase
      .from('user_service_roles')
      .insert(toAdd.map(role => ({ user_id: userId, role, assigned_by: user?.id })));
    if (error) throw error;
  }
}
