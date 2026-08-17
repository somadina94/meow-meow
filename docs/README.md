# Meow Meow — Complete Application Documentation

> **Version:** 1.0.0 | **Last Updated:** March 2026  
> **Platform:** Web (PWA) + Mobile (Flutter) + Desktop (Electron)

---

## Table of Contents

| Document | Description |
|----------|-------------|
| [APPLICATION-MAP.md](./APPLICATION-MAP.md) | Complete file-by-file documentation of every module |
| [ARCHITECTURE.md](./ARCHITECTURE.md) | System architecture and design patterns |
| [API-REFERENCE.md](./API-REFERENCE.md) | Edge function API reference |
| [WEBRTC-DEPLOYMENT-GUIDE.md](./WEBRTC-DEPLOYMENT-GUIDE.md) | P2P & SFU server deployment |
| [SRS-SERVER-GUIDE.md](./SRS-SERVER-GUIDE.md) | SRS media server operations |
| [DEPLOYMENT.md](./DEPLOYMENT.md) | Frontend deployment guide |
| [DEVICE-SUPPORT.md](./DEVICE-SUPPORT.md) | Platform and device support matrix |
| [REQUIREMENTS.md](./REQUIREMENTS.md) | Feature requirements specification |

---

## Quick Start

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build
```

---

## Application Summary

**Meow Meow** is a real-time social matching platform connecting men and women through:
- **Text Chat** — Per-minute billing with real-time translation
- **Video Calls** — P2P WebRTC (1-on-1) and SFU (group calls via SRS)
- **Gift System** — Virtual gifts with wallet integration
- **Private Group Rooms** — 10 flower-themed rooms (Rose, Lily, Jasmine, Orchid, Sunflower, Tulip, Lotus, Daisy, Lavender, Marigold)
- **Community Elections** — AI-managed democratic leader elections per language group
- **Admin Dashboard** — Full platform management with analytics, finance, moderation

### User Roles

| Role | Description |
|------|-------------|
| **Men (Male)** | Pay per minute for chat/video. Recharge wallet. Send gifts. |
| **Women (Female)** | Earn per minute from chat/video. KYC verified. Shift-based. |
| **Admin** | Super users with full platform control via `/admin/*` routes. |

### Revenue Model

| Activity | Men Pay | Women Earn (Indian) | Women Earn (Non-Indian) | Platform Revenue |
|----------|---------|---------------------|-------------------------|-----------------|
| Text Chat | ₹4/min | ₹2/min | ₹0 | ₹2-4/min |
| Video Call | ₹8/min | ₹4/min | ₹0 | ₹4-8/min |
| Group Call | ₹4/min per man | ₹2/min per man | ₹0 | ₹2/min per man |
| Gifts | Full price | 50% | 50% | 50% |

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | React 18 + TypeScript | Single-page web application |
| **Styling** | Tailwind CSS + shadcn/ui | Component library and design system |
| **State** | TanStack React Query | Server state management and caching |
| **Routing** | React Router v6 | Client-side routing |
| **Backend** | Supabase | PostgreSQL + Auth + Edge Functions + Realtime |
| **Video (P2P)** | WebRTC + coturn | 1-on-1 video calls |
| **Video (SFU)** | SRS v5 | Group video calls |
| **Mobile** | Flutter + Dart | iOS/Android native app |
| **Desktop** | Electron | Windows/Mac desktop app |
| **PWA** | Workbox + vite-plugin-pwa | Offline support and installability |
| **i18n** | i18next | 16 languages supported |
| **Build** | Vite | Fast dev server and production builds |

---

## Directory Structure

```
meow-meow/
├── docs/                          # Documentation files
├── flutter/                       # Flutter mobile app (iOS/Android)
│   ├── lib/
│   │   ├── core/                  # Config, services, theme
│   │   ├── features/              # Feature modules (auth, chat, etc.)
│   │   └── shared/                # Shared models, widgets, providers
│   └── pubspec.yaml               # Flutter dependencies
├── electron/                      # Electron desktop app
├── public/                        # Static assets, PWA manifest, legal docs
├── scripts/                       # Deployment and management scripts
│   ├── unix/                      # Linux/Mac scripts
│   └── windows/                   # Windows scripts
├── src/                           # React source code
│   ├── components/                # Reusable UI components
│   │   ├── ui/                    # shadcn/ui base components
│   │   ├── chat/                  # Chat-specific components
│   │   └── community/             # Community feature components
│   ├── constants/                 # Application constants
│   ├── contexts/                  # React context providers
│   ├── data/                      # Static data (countries, languages)
│   ├── hooks/                     # Custom React hooks
│   ├── i18n/                      # Internationalization config + locales
│   ├── integrations/supabase/     # Supabase client and auto-gen types
│   ├── lib/                       # Utility libraries
│   │   ├── api/                   # API client, caching, network monitor
│   │   └── fonts/                 # Font loader utilities
│   ├── pages/                     # Route page components
│   ├── services/                  # API service layer
│   └── types/                     # TypeScript type definitions
├── supabase/
│   ├── functions/                 # Edge Functions (serverless backend)
│   └── migrations/                # Database schema migrations
├── requirements.txt               # Server infrastructure requirements
├── package.json                   # Node.js dependencies
└── vite.config.ts                 # Vite build configuration
```
