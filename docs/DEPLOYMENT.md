# Meow Chat - Complete Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Environment Setup](#environment-setup)
4. [Database Configuration](#database-configuration)
5. [Edge Functions](#edge-functions)
6. [Frontend Deployment](#frontend-deployment)
7. [Production Deployment](#production-deployment)
8. [Monitoring & Maintenance](#monitoring--maintenance)

---

## Overview

Meow Chat is a real-time chat application built with:
- **Frontend**: React 18 + TypeScript + Vite + Tailwind CSS
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Authentication**: Supabase Auth (Email/Password)
- **Real-time**: Supabase Realtime subscriptions
- **Storage**: Supabase Storage for profile photos and voice messages
- **Mobile**: Capacitor for iOS/Android builds

### Architecture Diagram
```
┌─────────────────────────────────────────────────────────────┐
│                      Client Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Web App   │  │  iOS App    │  │   Android App       │  │
│  │   (React)   │  │ (Capacitor) │  │   (Capacitor)       │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
└─────────┼────────────────┼────────────────────┼─────────────┘
          │                │                    │
          └────────────────┼────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                    Supabase Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Auth      │  │  Realtime   │  │   Edge Functions    │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                    │              │
│  ┌──────▼────────────────▼────────────────────▼──────────┐  │
│  │                   PostgreSQL                          │  │
│  │  - profiles, chat_messages, wallets, shifts, etc.     │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Storage Buckets                     │  │
│  │  - profile-photos, voice-messages, legal-documents    │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### System Requirements
- **Node.js**: v18.0.0 or higher
- **npm**: v9.0.0 or higher (or bun/yarn)
- **Git**: v2.30.0 or higher
- **Supabase CLI**: v1.100.0 or higher (for local development)

### Required Accounts
1. **Supabase Account**: https://supabase.com
2. **GitHub Account**: For version control and CI/CD
3. **Lovable Account**: For cloud deployment

### Environment Variables Required
```bash
# Supabase Configuration
VITE_SUPABASE_URL=https://www.meow-meow.co.in:8443
VITE_SUPABASE_PUBLISHABLE_KEY=your-anon-key

# Edge Function Secrets (set in Supabase Dashboard)
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
SUPABASE_DB_URL=postgresql://...
HUGGING_FACE_ACCESS_TOKEN=your-hf-token
MAILJET_API_KEY=your-mailjet-api-key
MAILJET_SECRET_KEY=your-mailjet-secret-key
LOVABLE_API_KEY=your-lovable-api-key
```

---

## Environment Setup

### 1. Clone Repository
```bash
# Clone the repository
git clone https://github.com/your-org/meow-chat.git
cd meow-chat

# Install dependencies
npm install
# OR
bun install
```

### 2. Configure Environment
```bash
# Copy environment template
cp .env.example .env

# Edit with your Supabase credentials
nano .env
```

### 3. Start Development Server
```bash
# Start Vite development server
npm run dev

# Application available at http://localhost:5173
```

---

## Database Configuration

### Database Schema Overview
The application uses the following main tables:

| Table | Description |
|-------|-------------|
| `profiles` | User profile information (both men and women) |
| `female_profiles` | Extended profile data for female users |
| `male_profiles` | Extended profile data for male users |
| `chat_messages` | All chat messages between users |
| `active_chat_sessions` | Currently active chat sessions with billing |
| `wallets` | User wallet balances |
| `wallet_transactions` | All wallet transactions |
| `shifts` | Women's work shifts |
| `women_earnings` | Earnings records for women |
| `user_roles` | Role-based access control |
| `audit_logs` | Admin action audit trail |

### Row Level Security (RLS)
All tables have RLS enabled with policies for:
- User can only read/write their own data
- Admin can read/write all data
- Public data accessible to authenticated users

### Database Migrations
```bash
# Run pending migrations
npx supabase db push

# Create new migration
npx supabase migration new my_migration_name

# Reset database (CAUTION: destroys all data)
npx supabase db reset
```

---

## Edge Functions

### Available Functions

| Function | Purpose | Auth Required |
|----------|---------|---------------|
| `ai-women-approval` | AI-powered profile approval | Yes |
| `ai-women-manager` | AI management for women users | Yes |
| `chat-manager` | Chat session management | Yes |
| `content-moderation` | Message content moderation | Yes |
| `data-cleanup` | Scheduled data cleanup | Service Role |
| `reset-password` | Password reset emails | No |
| `seed-legal-documents` | Seed legal documents | Service Role |
| `seed-sample-users` | Seed sample users for testing | Service Role |
| `seed-super-users` | Create admin users | Service Role |

| `translate-message` | Real-time message translation | Yes |
| `trigger-backup` | Database backup trigger | Service Role |
| `verify-photo` | Photo verification with AI | Yes |

### Deploying Edge Functions
```bash
# Deploy all functions
npx supabase functions deploy

# Deploy specific function
npx supabase functions deploy chat-manager

# View function logs
npx supabase functions logs chat-manager
```

---

## Frontend Deployment

### Build for Production
```bash
# Create production build
npm run build

# Preview production build locally
npm run preview
```

### Build Output
- Output directory: `dist/`
- Static assets: `dist/assets/`
- Entry point: `dist/index.html`

---

## Production Deployment

### Option 1: Lovable Cloud (Recommended)
1. Push changes to main branch
2. Click "Publish" in Lovable editor
3. Click "Update" to deploy frontend changes
4. Edge functions deploy automatically

### Option 2: Self-Hosted
See `scripts/` directory for deployment scripts.

### Option 3: Docker Deployment
```bash
# Build Docker image
docker build -t meow-chat:latest .

# Run container
docker run -p 80:80 meow-chat:latest
```

---

## Monitoring & Maintenance

### Health Checks
- **Frontend**: Check `/` returns 200
- **Database**: Query `SELECT 1` on PostgreSQL
- **Edge Functions**: Call `/functions/v1/health`

### Logs
- **Frontend**: Browser DevTools Console
- **Edge Functions**: Supabase Dashboard → Edge Functions → Logs
- **Database**: Supabase Dashboard → Database → Logs

### Performance Metrics
- Monitor in Supabase Dashboard → Reports
- Track API response times
- Monitor database query performance

---

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure Edge Functions include CORS headers
   - Check Supabase project settings

2. **Authentication Failures**
   - Verify JWT tokens are not expired
   - Check Supabase Auth configuration

3. **Database Connection Issues**
   - Verify connection string
   - Check RLS policies
   - Ensure user has proper permissions

4. **Build Failures**
   - Clear `node_modules` and reinstall
   - Check TypeScript errors
   - Verify all imports are correct

### Support
- **Documentation**: https://docs.lovable.dev
- **Supabase Docs**: https://supabase.com/docs
- **Discord**: https://discord.gg/lovable
