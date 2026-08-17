# Frontend Types

This folder contains **frontend-specific** TypeScript types and interfaces.

## Important Distinction

| Location | Purpose |
|----------|---------|
| `src/types/index.ts` | Frontend-specific types, UI data structures |
| `src/integrations/supabase/types.ts` | Database types (auto-generated, DO NOT EDIT) |
| `src/services/*.ts` | Service-specific types for API responses |

## Guidelines

### 1. When to Add Types Here
- UI-specific data structures
- Transformed/derived data from database
- Component prop types that are reused
- Application state types

### 2. When NOT to Add Types Here
- Database table structures (use auto-generated types)
- One-off component prop types (define inline)
- Types specific to one service (define in service file)

### 3. Naming Conventions
```typescript
// Interfaces for objects
interface User { ... }
interface ChatSession { ... }

// Types for unions/primitives
type Platform = 'web' | 'ios' | 'android';
type AccountStatus = 'active' | 'suspended' | 'banned';
```

### 4. Exporting
All types in `index.ts` are automatically exported.
Import them like:
```typescript
import { User, ChatSession, Platform } from '@/types';
```
