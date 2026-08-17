/**
 * WomenWalletScreen — Women's Wallet with earnings balance and statement.
 * Balance updates dynamically via Supabase realtime on wallet_transactions changes.
 * Each earning event (chat/audio/video/group/gift) writes one wallet_transactions row,
 * so the subscription fires for every credit as well as every recharge / debit.
 */
import { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { ArrowLeft, Wallet, TrendingUp, IndianRupee } from 'lucide-react';
import { getWomenBalance } from '@/services/ledger-wallet.service';
import { StatementTab } from '@/components/StatementTab';
import { useAppSettings } from '@/hooks/useAppSettings';

const WomenWalletScreen = () => {
  const navigate = useNavigate();
  const [balance, setBalance] = useState(0);
  const [todayEarnings, setTodayEarnings] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const userIdRef = useRef('');
  const { settings } = useAppSettings();
  const showStatements = !!settings.statementsTabVisible;

  const loadData = useCallback(async (uid: string) => {
    try {
      const walletData = await getWomenBalance(uid);
      setBalance(walletData.balance);
      setTodayEarnings(walletData.todayEarnings);
    } catch { /* fallback */ }
  }, []);

  useEffect(() => {
    let channel: ReturnType<typeof supabase.channel> | null = null;

    (async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) { navigate('/'); return; }
      userIdRef.current = user.id;
      await loadData(user.id);
      setIsLoading(false);

      channel = supabase
        .channel('wallet-women-realtime')
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'wallet_transactions',
          filter: `user_id=eq.${user.id}`,
        }, () => { loadData(user.id); })
        .on('postgres_changes', {
          event: '*',
          schema: 'public',
          table: 'wallets',
          filter: `user_id=eq.${user.id}`,
        }, () => { loadData(user.id); })
        .subscribe();
    })();

    return () => { channel?.unsubscribe(); };
  }, [navigate, loadData]);

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
          <div className="flex items-center gap-3 mb-2">
            <div className="w-12 h-12 rounded-full bg-primary-foreground/20 flex items-center justify-center">
              <Wallet className="w-6 h-6" />
            </div>
            <div>
              <p className="text-sm opacity-80">Total Balance</p>
              <p className="text-3xl font-bold">₹{balance.toFixed(2)}</p>
            </div>
          </div>
          <div className="flex items-center gap-2 mt-3 bg-primary-foreground/10 rounded-lg px-3 py-2">
            <TrendingUp className="w-4 h-4" />
            <span className="text-sm">Today's Earnings: ₹{todayEarnings.toFixed(2)}</span>
          </div>
          <Button
            disabled
            aria-disabled="true"
            variant="secondary"
            className="w-full mt-4 gap-2 opacity-50 cursor-not-allowed bg-primary-foreground/20 text-primary-foreground hover:bg-primary-foreground/20"
          >
            <IndianRupee className="w-4 h-4" />
            Withdraw
          </Button>
          <p className="text-[11px] text-primary-foreground/80 mt-2 text-center leading-snug">
            Self-withdrawal is not available. Payouts are processed only by the admin as per the payout schedule.
          </p>
        </Card>
      </div>

      {showStatements && (
        <Tabs defaultValue="statement" className="flex-1 flex flex-col">
          <TabsList className="mx-4 mb-2">
            <TabsTrigger value="statement" className="flex-1">Statement</TabsTrigger>
          </TabsList>
          <TabsContent value="statement" className="flex-1">
            <StatementTab userId={userIdRef.current} gender="female" />
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
};

export default WomenWalletScreen;
