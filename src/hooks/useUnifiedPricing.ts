import { useQuery } from '@tanstack/react-query';
import { fetchUnifiedPricing, PRICING_DEFAULTS } from '@/services/billing.service';

export function useUnifiedPricing() {
  return useQuery({
    queryKey: ['unified-pricing'],
    queryFn: fetchUnifiedPricing,
    staleTime: 5 * 60 * 1000,
    placeholderData: PRICING_DEFAULTS,
  });
}
