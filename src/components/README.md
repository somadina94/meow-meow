# Components Layer (Views)

This folder contains reusable UI components (part of the View layer).

## Structure

```
components/
├── ui/           # Design system primitives (shadcn)
│   ├── button.tsx
│   ├── card.tsx
│   ├── dialog.tsx
│   └── ...
│
├── Feature Components
│   ├── ChatInterface.tsx
│   ├── VideoCallModal.tsx
│   ├── WalletCard.tsx
│   └── ...
│
└── Layout Components
    ├── MobileLayout.tsx
    ├── AdminNav.tsx
    └── ...
```

## Guidelines

### 1. Component Types

| Type | Location | Purpose |
|------|----------|---------|
| UI Primitives | `ui/` | Design system (buttons, inputs) |
| Feature Components | Root | Domain-specific reusable UI |
| Layout Components | Root | Page structure components |

### 2. Pattern
```typescript
interface WalletCardProps {
  balance: number;
  currency: string;
}

export function WalletCard({ balance, currency }: WalletCardProps) {
  return (
    <Card>
      <CardContent>
        <p>{formatCurrency(balance, currency)}</p>
      </CardContent>
    </Card>
  );
}
```

### 3. Avoid
- API calls (use hooks in parent)
- Complex state (lift to parent or use hook)
- Hardcoded colors (use design tokens)

### 4. Design System
All colors and styles should use tokens from:
- `src/index.css` (CSS variables)
- `tailwind.config.ts` (Tailwind theme)
