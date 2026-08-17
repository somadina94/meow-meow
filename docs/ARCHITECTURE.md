# Meow Chat - System Architecture

## Table of Contents
1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow](#data-flow)
4. [Database Design](#database-design)
5. [API Architecture](#api-architecture)
6. [Security Architecture](#security-architecture)
7. [Deployment Architecture](#deployment-architecture)

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │   Web Browser   │  │   iOS App       │  │   Android App               │  │
│  │   (React SPA)   │  │   (Capacitor)   │  │   (Capacitor)               │  │
│  └────────┬────────┘  └────────┬────────┘  └──────────────┬──────────────┘  │
│           │                    │                          │                  │
│           └────────────────────┴──────────────────────────┘                  │
│                                │                                             │
│                    ┌───────────▼───────────┐                                 │
│                    │   Supabase Client     │                                 │
│                    │   (supabase-js SDK)   │                                 │
│                    └───────────┬───────────┘                                 │
└────────────────────────────────┼────────────────────────────────────────────┘
                                 │
                                 │ HTTPS/WSS
                                 │
┌────────────────────────────────┼────────────────────────────────────────────┐
│                         SUPABASE PLATFORM                                    │
├────────────────────────────────┼────────────────────────────────────────────┤
│                                │                                             │
│  ┌─────────────────────────────▼─────────────────────────────────────────┐  │
│  │                         API GATEWAY                                    │  │
│  │                    (Kong / Supabase Router)                            │  │
│  └─────────────────────────────┬─────────────────────────────────────────┘  │
│                                │                                             │
│     ┌──────────────┬───────────┼───────────┬──────────────────┐             │
│     │              │           │           │                  │             │
│     ▼              ▼           ▼           ▼                  ▼             │
│  ┌──────┐    ┌──────────┐  ┌────────┐  ┌─────────┐    ┌───────────┐        │
│  │ Auth │    │ PostgREST│  │Realtime│  │ Storage │    │Edge Funcs │        │
│  │      │    │   API    │  │  (WS)  │  │  (S3)   │    │  (Deno)   │        │
│  └──┬───┘    └────┬─────┘  └───┬────┘  └────┬────┘    └─────┬─────┘        │
│     │             │            │            │               │               │
│     └─────────────┴────────────┴────────────┴───────────────┘               │
│                                │                                             │
│                    ┌───────────▼───────────┐                                 │
│                    │      PostgreSQL       │                                 │
│                    │     (Database)        │                                 │
│                    └───────────────────────┘                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                 │
                                 │
┌────────────────────────────────┼────────────────────────────────────────────┐
│                       EXTERNAL SERVICES                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────────────┐   │
│  │ Hugging Face  │  │   Mailjet     │  │   Lovable AI                  │   │
│  │ (Translation) │  │   (Email)     │  │   (Image Gen)                 │   │
│  └───────────────┘  └───────────────┘  └───────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### Frontend Components

```
src/
├── components/                    # Reusable UI components
│   ├── ui/                       # shadcn/ui base components
│   │   ├── button.tsx           # Button with aurora variants
│   │   ├── card.tsx             # Card container
│   │   ├── dialog.tsx           # Modal dialogs
│   │   ├── input.tsx            # Form inputs
│   │   └── ...                  # Other UI primitives
│   │
│   ├── AdminNav.tsx             # Admin navigation sidebar
│   ├── ChatInterface.tsx        # Main chat component
│   ├── MiniChatWindow.tsx       # Floating chat window
│   ├── ParallelChatsContainer.tsx # Multiple chat management
│   ├── ProfileEditDialog.tsx    # Profile editing modal
│   ├── VideoCallModal.tsx       # Video call interface
│   ├── VoiceMessageRecorder.tsx # Audio recording
│   └── ...                      # Feature components
│
├── pages/                        # Route pages
│   ├── AuthScreen.tsx           # Login/Register
│   ├── DashboardScreen.tsx      # Men's dashboard
│   ├── WomenDashboardScreen.tsx # Women's dashboard
│   ├── ChatScreen.tsx           # Chat page
│   ├── WalletScreen.tsx         # Wallet management
│   ├── AdminDashboard.tsx       # Admin panel
│   └── ...                      # Other pages
│
├── hooks/                        # Custom React hooks
│   ├── useI18n.ts               # Internationalization
│   ├── useTranslation.ts        # Dynamic translation
│   ├── useRealtimeSubscription.ts # Supabase realtime
│   ├── useActivityStatus.ts     # User presence
│   ├── useMatchingService.ts    # User matching
│   └── ...                      # Other hooks
│
├── contexts/                     # React context providers
│   └── TranslationContext.tsx   # Translation state
│
├── integrations/                 # External integrations
│   └── supabase/
│       ├── client.ts            # Supabase client instance
│       └── types.ts             # Generated types
│
├── i18n/                         # Internationalization
│   ├── config.ts                # i18next configuration
│   └── locales/                 # Translation files
│       ├── en.json
│       ├── es.json
│       └── ...
│
└── lib/                          # Utility functions
    └── utils.ts                 # Helper functions
```

### Backend Components (Edge Functions)

```
supabase/functions/
├── ai-women-approval/           # AI profile approval
│   └── index.ts
├── ai-women-manager/            # AI women management
│   └── index.ts
├── chat-manager/                # Chat session management
│   └── index.ts
├── content-moderation/          # Message moderation
│   └── index.ts
├── data-cleanup/                # Data maintenance
│   └── index.ts
├── reset-password/              # Password reset emails
│   └── index.ts
├── translate-message/           # Message translation
│   └── index.ts
├── trigger-backup/              # Database backup
│   └── index.ts
└── verify-photo/                # Photo verification
    └── index.ts
```

---

## Data Flow

### Authentication Flow

```
┌─────────┐     ┌─────────────┐     ┌──────────────┐     ┌──────────┐
│  User   │────▶│  Frontend   │────▶│ Supabase Auth│────▶│ Database │
│         │     │             │     │              │     │          │
└─────────┘     └─────────────┘     └──────────────┘     └──────────┘
     │                │                    │                   │
     │  1. Enter      │                    │                   │
     │  credentials   │                    │                   │
     │───────────────▶│                    │                   │
     │                │  2. signInWith     │                   │
     │                │  Password()        │                   │
     │                │───────────────────▶│                   │
     │                │                    │  3. Verify        │
     │                │                    │  credentials      │
     │                │                    │──────────────────▶│
     │                │                    │                   │
     │                │                    │  4. Return user   │
     │                │                    │◀──────────────────│
     │                │  5. Return session │                   │
     │                │◀───────────────────│                   │
     │  6. Redirect   │                    │                   │
     │  to dashboard  │                    │                   │
     │◀───────────────│                    │                   │
```

### Chat Message Flow

```
┌─────────┐     ┌──────────┐     ┌──────────────┐     ┌──────────────┐
│ Sender  │────▶│ Frontend │────▶│   Database   │────▶│  Receiver    │
│         │     │          │     │  + Realtime  │     │   Frontend   │
└─────────┘     └──────────┘     └──────────────┘     └──────────────┘
     │               │                  │                    │
     │ 1. Type       │                  │                    │
     │ message       │                  │                    │
     │──────────────▶│                  │                    │
     │               │                  │                    │
     │               │ 2. Insert        │                    │
     │               │ message          │                    │
     │               │─────────────────▶│                    │
     │               │                  │                    │
     │               │                  │ 3. Trigger         │
     │               │                  │ realtime           │
     │               │                  │ broadcast          │
     │               │                  │───────────────────▶│
     │               │                  │                    │
     │               │ 4. Invoke        │                    │
     │               │ translate-message│                    │
     │               │─────────────────▶│                    │
     │               │                  │                    │
     │               │ 5. Update with   │ 6. Receive         │
     │               │ translation      │ translation        │
     │               │◀─────────────────│───────────────────▶│
     │ 7. Show       │                  │                    │
     │ confirmation  │                  │                    │
     │◀──────────────│                  │                    │
```

### Billing Flow

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           CHAT SESSION BILLING                             │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  1. Session Start                                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ chat-manager (action: start_chat)                                   │ │
│  │ ├── Check man's wallet balance >= minimum                           │ │
│  │ ├── Check woman's availability                                      │ │
│  │ ├── Create active_chat_session record                               │ │
│  │ └── Return chat_id                                                  │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  2. During Chat (Every Minute)                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ chat-manager (action: update_billing)                               │ │
│  │ ├── Calculate elapsed time                                          │ │
│  │ ├── Deduct from man's wallet (rate_per_minute)                      │ │
│  │ ├── Credit woman's wallet (earning_rate)                            │ │
│  │ ├── Update session total_minutes, total_earned                      │ │
│  │ └── Check if man's balance is low → notify                          │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  3. Session End                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ chat-manager (action: end_chat)                                     │ │
│  │ ├── Calculate final billing                                         │ │
│  │ ├── Create transaction records for both users                       │ │
│  │ ├── Update session status to 'ended'                                │ │
│  │ └── Update woman's availability                                     │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## Database Design

### Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   auth.users    │       │    profiles     │       │  user_photos    │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ id (PK)         │◀──────│ user_id (FK)    │◀──────│ user_id (FK)    │
│ email           │       │ id (PK)         │       │ id (PK)         │
│ encrypted_pass  │       │ full_name       │       │ photo_url       │
│ created_at      │       │ gender          │       │ is_primary      │
└─────────────────┘       │ age             │       │ display_order   │
                          │ country         │       └─────────────────┘
                          │ approval_status │
                          │ account_status  │
                          └────────┬────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  chat_messages  │    │     wallets     │    │  user_status    │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ id (PK)         │    │ id (PK)         │    │ id (PK)         │
│ chat_id         │    │ user_id (FK)    │    │ user_id (FK)    │
│ sender_id (FK)  │    │ balance         │    │ is_online       │
│ receiver_id (FK)│    │ currency        │    │ last_seen       │
│ message         │    └────────┬────────┘    └─────────────────┘
│ translated_msg  │             │
│ is_read         │             ▼
│ flagged         │    ┌─────────────────┐
└─────────────────┘    │ wallet_trans    │
                       ├─────────────────┤
                       │ id (PK)         │
                       │ wallet_id (FK)  │
                       │ type            │
                       │ amount          │
                       │ description     │
                       └─────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│active_chat_sess │    │     shifts      │    │  user_roles     │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ id (PK)         │    │ id (PK)         │    │ id (PK)         │
│ chat_id         │    │ user_id (FK)    │    │ user_id (FK)    │
│ man_user_id     │    │ start_time      │    │ role            │
│ woman_user_id   │    │ end_time        │    └─────────────────┘
│ status          │    │ earnings        │
│ rate_per_minute │    │ status          │
│ total_earned    │    └─────────────────┘
└─────────────────┘
```

### Row Level Security (RLS) Policies

```sql
-- profiles: Users can only read/write their own profile
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- chat_messages: Users can only see messages they sent/received
CREATE POLICY "Users can view own messages"
  ON chat_messages FOR SELECT
  USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send messages"
  ON chat_messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- wallets: Users can only see their own wallet
CREATE POLICY "Users can view own wallet"
  ON wallets FOR SELECT
  USING (auth.uid() = user_id);

-- Admin override: Admins can access everything
CREATE POLICY "Admins have full access"
  ON profiles FOR ALL
  USING (public.has_role(auth.uid(), 'admin'));
```

---

## API Architecture

### REST API Endpoints (via PostgREST)

```
GET    /rest/v1/profiles          # List profiles
GET    /rest/v1/profiles?id=eq.X  # Get single profile
POST   /rest/v1/profiles          # Create profile
PATCH  /rest/v1/profiles?id=eq.X  # Update profile
DELETE /rest/v1/profiles?id=eq.X  # Delete profile

GET    /rest/v1/chat_messages     # List messages
POST   /rest/v1/chat_messages     # Send message

GET    /rest/v1/wallets           # Get wallet
GET    /rest/v1/wallet_transactions # Get transactions

# ... similar patterns for all tables
```

### Edge Function Endpoints

```
POST   /functions/v1/chat-manager        # Manage chat sessions
POST   /functions/v1/translate-message   # Translate text
POST   /functions/v1/content-moderation  # Moderate content
POST   /functions/v1/verify-photo        # Verify photos
POST   /functions/v1/ai-women-approval   # AI approval
POST   /functions/v1/reset-password      # Password reset
```

### Realtime Channels

```javascript
// Chat messages
supabase.channel('chat:${chatId}')
  .on('postgres_changes', { table: 'chat_messages' })
  
// User status
supabase.channel('presence')
  .on('presence', { event: 'sync' })
  
// Notifications
supabase.channel('notifications:${userId}')
  .on('postgres_changes', { table: 'notifications' })
```

---

## Security Architecture

### Authentication Layers

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SECURITY LAYERS                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Layer 1: Transport Security                                            │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ • HTTPS/TLS 1.3 for all connections                               │ │
│  │ • WSS for realtime connections                                    │ │
│  │ • Certificate pinning in mobile apps                              │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  Layer 2: Authentication                                                │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ • JWT tokens with short expiry (1 hour)                           │ │
│  │ • Refresh tokens with longer expiry (7 days)                      │ │
│  │ • Secure token storage (httpOnly cookies)                         │ │
│  │ • Password hashing (bcrypt)                                       │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  Layer 3: Authorization (RLS)                                           │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ • Row Level Security on all tables                                │ │
│  │ • Role-based access control                                       │ │
│  │ • User data isolation                                             │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  Layer 4: Input Validation                                              │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ • Zod schema validation on frontend                               │ │
│  │ • PostgreSQL constraints                                          │ │
│  │ • Edge function input validation                                  │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  Layer 5: Content Security                                              │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ • AI content moderation                                           │ │
│  │ • Rate limiting                                                   │ │
│  │ • Audit logging                                                   │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Deployment Architecture

### Production Environment

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         LOVABLE CLOUD                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                        CDN (Edge)                                │   │
│  │                   Global content delivery                        │   │
│  └────────────────────────────┬────────────────────────────────────┘   │
│                               │                                         │
│  ┌────────────────────────────▼────────────────────────────────────┐   │
│  │                     Frontend (Static)                            │   │
│  │              React SPA served from CDN                           │   │
│  └────────────────────────────┬────────────────────────────────────┘   │
│                               │                                         │
└───────────────────────────────┼─────────────────────────────────────────┘
                                │
┌───────────────────────────────┼─────────────────────────────────────────┐
│                         SUPABASE                                         │
├───────────────────────────────┼─────────────────────────────────────────┤
│                               │                                         │
│  ┌────────────────────────────▼────────────────────────────────────┐   │
│  │                      Load Balancer                               │   │
│  └──────┬──────────────┬──────────────┬──────────────┬─────────────┘   │
│         │              │              │              │                  │
│         ▼              ▼              ▼              ▼                  │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │   Auth   │   │ REST API │   │ Realtime │   │  Edge    │            │
│  │ Service  │   │PostgREST │   │   (WS)   │   │Functions │            │
│  └────┬─────┘   └────┬─────┘   └────┬─────┘   └────┬─────┘            │
│       │              │              │              │                   │
│       └──────────────┴──────────────┴──────────────┘                   │
│                               │                                         │
│                    ┌──────────▼──────────┐                             │
│                    │     PostgreSQL      │                             │
│                    │   (Primary + Read   │                             │
│                    │      Replicas)      │                             │
│                    └──────────┬──────────┘                             │
│                               │                                         │
│                    ┌──────────▼──────────┐                             │
│                    │   Object Storage    │                             │
│                    │   (S3 Compatible)   │                             │
│                    └─────────────────────┘                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### CI/CD Pipeline

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Develop   │────▶│   Commit    │────▶│    Build    │────▶│   Deploy    │
│             │     │   (Git)     │     │   (Vite)    │     │  (Lovable)  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                          │                   │                   │
                          │                   │                   │
                          ▼                   ▼                   ▼
                    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
                    │  TypeScript │     │   Bundle    │     │   Preview   │
                    │    Check    │     │  Optimize   │     │    Deploy   │
                    └─────────────┘     └─────────────┘     └─────────────┘
                          │                   │                   │
                          ▼                   ▼                   ▼
                    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
                     │   ESLint    │     │  Generate   │     │ Production  │
                     │    Check    │     │  Artifacts  │     │   Deploy    │
                     └─────────────┘     └─────────────┘     └─────────────┘
```

---

## MVP Architecture Pattern

This project follows the **MVP (Model-View-Presenter)** pattern with clear layer separation.

### Layer Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRONTEND (src/)                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Views     │  │  Presenters │  │       Models            │ │
│  │  (pages/    │◄─┤   (hooks/)  │◄─┤   (services/, types/)   │ │
│  │  components)│  │             │  │                         │ │
│  └─────────────┘  └─────────────┘  └───────────┬─────────────┘ │
└───────────────────────────────────────────────│───────────────┘
                                                 │
                                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                  BACKEND (supabase/functions/)                  │
│              Edge Functions (Deno Runtime)                      │
└───────────────────────────────────────────────│───────────────┘
                                                 │
                                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│              DATABASE (Supabase PostgreSQL)                     │
│        Tables • RLS Policies • Functions • Triggers             │
└─────────────────────────────────────────────────────────────────┘
```

### Frontend Layer Organization

| Folder | Layer | Purpose |
|--------|-------|---------|
| `src/pages/` | View | Route-level components |
| `src/components/` | View | Reusable UI components |
| `src/components/ui/` | View | Design system primitives |
| `src/hooks/` | Presenter | Business logic, state management |
| `src/services/` | Model | API calls to backend |
| `src/types/` | Model | TypeScript interfaces |
| `src/constants/` | Model | Application constants |

### Services (API Layer)

```
src/services/
├── index.ts           # Central export
├── auth.service.ts    # Authentication
├── profile.service.ts # User profiles
├── wallet.service.ts  # Wallet & transactions
├── chat.service.ts    # Chat & messaging
└── admin.service.ts   # Admin operations
```

### Key Principles

1. **Views** only render UI, no business logic
2. **Hooks** handle state, effects, and service calls
3. **Services** are the only layer that talks to Supabase
4. **Types** are centralized for consistency
5. **Database functions** handle atomic operations
