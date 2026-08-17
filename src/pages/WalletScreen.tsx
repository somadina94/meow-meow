/**
 * WalletScreen — Men's Wallet with balance, recharge, and statement.
 * Balance updates dynamically via Supabase realtime on wallet_transactions changes.
 */
import { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { ArrowLeft, Wallet, CreditCard } from 'lucide-react';
import { StatementTab } from '@/components/StatementTab';
import { useAppSettings } from '@/hooks/useAppSettings';

const WalletScreen = () => {
  const navigate = useNavigate();
  const [balance, setBalance] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const userIdRef = useRef('');
  const { settings } = useAppSettings();
  const showStatements = !!settings.statementsTabVisible;

  const loadBalance = useCallback(async (uid: string) => {
    try {
      const { data } = await supabase.rpc('get_men_wallet_balance', { p_user_id: uid });
      setBalance(Number((data as Record<string, number>)?.balance) || 0);
    } catch { /* fallback 0 */ }
  }, []);

  useEffect(() => {
    let channel: ReturnType<typeof supabase.channel> | null = null;

    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { navigate('/'); return; }
      userIdRef.current = user.id;
      await loadBalance(user.id);
      setIsLoading(false);

      channel = supabase
        .channel('wallet-men-realtime')
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'wallet_transactions',
          filter: `user_id=eq.${user.id}`,
        }, () => { loadBalance(user.id); })
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'wallets',
          filter: `user_id=eq.${user.id}`,
        }, () => { loadBalance(user.id); })
        .subscribe();
    })();

    return () => { channel?.unsubscribe(); };
  }, [navigate, loadBalance]);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background p-4 space-y-4">
        <Skeleton className="h-40 w-full rounded-xl" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background flex flex-col">
      <div className="sticky top-0 z-40 bg-primary text-primary-foreground px-4 py-3 flex items-center gap-3">
        <Button variant="ghost" size="icon" className="text-primary-foreground" onClick={() => navigate(-1)}>
          <ArrowLeft className="w-5 h-5" />
        </Button>
        <h1 className="text-lg font-semibold flex-1">Wallet</h1>
      </div>

      <div className="p-4">
        <Card className="bg-gradient-to-br from-primary to-primary/80 text-primary-foreground p-6 rounded-2xl">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-12 h-12 rounded-full bg-primary-foreground/20 flex items-center justify-center">
              <Wallet className="w-6 h-6" />
            </div>
            <div>
              <p className="text-sm opacity-80">Available Balance</p>
              <p className="text-3xl font-bold">₹{balance.toFixed(2)}</p>
            </div>
          </div>
          <Button
            className="w-full bg-primary-foreground/20 hover:bg-primary-foreground/30 text-primary-foreground"
            onClick={() => navigate('/dashboard')}
          >
            <CreditCard className="w-4 h-4 mr-2" /> Recharge
          </Button>
        </Card>
      </div>

      {showStatements && (
        <Tabs defaultValue="statement" className="flex-1 flex flex-col">
          <TabsList className="mx-4 mb-2">
            <TabsTrigger value="statement" className="flex-1">Statement</TabsTrigger>
          </TabsList>
          <TabsContent value="statement" className="flex-1">
            <StatementTab userId={userIdRef.current} gender="male" />
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
};

export default WalletScreen;
