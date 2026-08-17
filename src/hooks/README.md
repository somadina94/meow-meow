# Hooks Layer (Presenter)

This folder contains the **Presenter** layer of the MVP architecture.
Hooks connect Views (components) to Models (services).

## Structure

```
hooks/
├── Core Hooks
│   ├── use-mobile.tsx      # Mobile detection
│   ├── use-toast.ts        # Toast notifications
│   └── useDeviceDetect.ts  # Device detection
│
├── Auth Hooks
│   ├── useAdminAccess.ts   # Admin role checking
│   └── useSuperUser.ts     # Super user detection
│
├── Feature Hooks
│   ├── useChatPricing.ts   # Chat pricing logic
│   ├── useActivityStatus.ts
│   ├── useIncomingCalls.ts
│   ├── useMatchingService.ts
│   └── ...
│
└── Utility Hooks
    ├── useAutoReconnect.ts
    ├── useOfflineSync.ts
    ├── useRealtimeSubscription.ts
    └── ...
```

## Guidelines

### 1. Hook Responsibility
- Manage component state
- Call services for data
- Handle side effects
- Transform data for display

### 2. Naming Convention
- Prefix with `use`
- Describe the functionality: `useChatPricing`, `useWallet`

### 3. Pattern
```typescript
import { useState, useEffect } from 'react';
import { getWallet } from '@/services';

export function useWallet(userId: string) {
  const [wallet, setWallet] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    async function fetch() {
      setIsLoading(true);
      try {
        const data = await getWallet(userId);
        setWallet(data);
      } catch (err) {
        setError(err);
      } finally {
        setIsLoading(false);
      }
    }
    fetch();
  }, [userId]);

  return { wallet, isLoading, error };
}
```

### 4. Avoid
- Direct API calls in components
- Business logic in components
- Complex state management in components
