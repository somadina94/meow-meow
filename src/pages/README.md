# Pages Layer (Views)

This folder contains the **View** layer of the MVP architecture.
Pages are route-level components that compose the UI.

## Guidelines

### 1. Page Responsibility
- Compose components into a full page
- Use hooks for data and logic
- Handle routing concerns
- Minimal business logic

### 2. Pattern
```typescript
import { useWallet } from '@/hooks/useWallet';
import { WalletCard } from '@/components/WalletCard';
import { TransactionList } from '@/components/TransactionList';

export default function WalletScreen() {
  const { wallet, transactions, isLoading } = useWallet();

  if (isLoading) return <LoadingSpinner />;

  return (
    <div>
      <WalletCard balance={wallet.balance} />
      <TransactionList transactions={transactions} />
    </div>
  );
}
```

### 3. Avoid
- Direct API calls (use hooks)
- Complex business logic (put in hooks)
- Inline styles (use Tailwind)
- Large files (extract components)
