# Services Layer (Model)

This folder contains the **Model** layer of the MVP architecture.
Services are responsible for all communication with the backend (Supabase).

## Structure

```
services/
├── index.ts           # Central export for all services
├── auth.service.ts    # Authentication operations
├── profile.service.ts # User profile operations
├── wallet.service.ts  # Wallet & transactions
├── chat.service.ts    # Chat sessions & messages
├── admin.service.ts   # Admin operations
└── README.md          # This file
```

## Guidelines

### 1. Service Responsibility
- Each service handles one domain (auth, wallet, chat, etc.)
- Services call Supabase APIs and database functions
- Services return typed responses

### 2. Type Definitions
- Service-specific types are defined in each service file
- Shared frontend types are in `src/types/index.ts`
- Database types are in `src/integrations/supabase/types.ts` (auto-generated)

### 3. Error Handling
- All services return structured responses with `success` and `error` fields
- Never throw errors from services; return error objects instead

### 4. Usage in Hooks
```typescript
// In hooks (Presenter layer)
import { getWallet, processTransaction } from '@/services';

function useWallet(userId: string) {
  const [wallet, setWallet] = useState(null);
  
  useEffect(() => {
    getWallet(userId).then(setWallet);
  }, [userId]);
  
  return wallet;
}
```

### 5. Adding New Services
1. Create `[domain].service.ts` file
2. Define types at the top
3. Export functions for each operation
4. Add export to `index.ts`
