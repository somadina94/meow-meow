/**
 * useChatPricing — Fetches live pricing from chat_pricing table.
 * Used by dashboards and billing displays.
 */
import { useState, useEffect } from 'react';
import { fetchChatPricing, type ChatPricingData } from '@/services/ledger-wallet.service';

export function useChatPricing() {
  const [pricing, setPricing] = useState<ChatPricingData>({
    ratePerMinute: 4, womenEarningRate: 2,
    audioRatePerMinute: 6, audioWomenEarningRate: 3,
    videoRatePerMinute: 8, videoWomenEarningRate: 4,
    groupCallRatePerMinute: 4, groupCallWomenEarningRate: 1,
    giftWomenPercent: 50, withdrawalFeePercent: 5, minWithdrawalBalance: 5000,
  });
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetchChatPricing()
      .then(setPricing)
      .catch(() => { /* use defaults */ })
      .finally(() => setIsLoading(false));
  }, []);

  const hasSufficientBalance = (balance: number, sessionType: 'chat' | 'audio' | 'video' | 'group' = 'chat') => {
    const rateMap = {
      chat: pricing.ratePerMinute,
      audio: pricing.audioRatePerMinute,
      video: pricing.videoRatePerMinute,
      group: pricing.groupCallRatePerMinute,
    };
    return balance >= rateMap[sessionType];
  };

  const formatPrice = (amount: number) => `₹${amount.toFixed(2)}`;

  return { pricing, isLoading, hasSufficientBalance, formatPrice };
}

export default useChatPricing;
