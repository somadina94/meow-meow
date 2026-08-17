# Meow Chat - Complete Setup & Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Environment Configuration](#environment-configuration)
4. [Local Development Setup](#local-development-setup)
5. [Database Setup](#database-setup)
6. [Edge Functions](#edge-functions)
7. [Deployment Instructions](#deployment-instructions)
8. [Scripts Reference](#scripts-reference)
9. [Troubleshooting](#troubleshooting)

---

## Overview

Meow Chat is a real-time dating/chat application with:
- **Frontend**: React 18 + TypeScript + Vite + Tailwind CSS + shadcn/ui
- **Backend**: Supabase (PostgreSQL + Edge Functions + Realtime + Auth + Storage)
- **Mobile**: Capacitor for iOS/Android builds
- **AI Features**: Hugging Face (translation, photo verification, voice-to-text)
- **Email**: Mailjet for password reset emails

### Architecture
```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CLIENT LAYER                                   │
├─────────────────┬─────────────────┬─────────────────────────────────────┤
│   Web App       │   iOS App       │   Android App                       │
│   (React/Vite)  │   (Capacitor)   │   (Capacitor)                       │
└────────┬────────┴────────┬────────┴────────────────┬────────────────────┘
         │                 │                         │
         └─────────────────┴─────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         SUPABASE LAYER                                   │
├─────────────────┬─────────────────┬─────────────────┬───────────────────┤
│   Auth          │   Realtime      │   Edge Funcs    │   Storage         │
│   (Email/Pass)  │   (WebSocket)   │   (Deno)        │   (S3-compatible) │
├─────────────────┴─────────────────┴─────────────────┴───────────────────┤
│                           PostgreSQL                                     │
│   Tables: profiles, chat_messages, wallets, shifts, etc.                │
│   RLS Policies: User-scoped data access                                 │
│   Functions: process_wallet_transaction, process_chat_billing, etc.    │
└─────────────────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       EXTERNAL SERVICES                                  │
├─────────────────┬─────────────────┬─────────────────────────────────────┤
│   Hugging Face  │   Mailjet       │   Lovable Cloud                     │
│   (AI Models)   │   (Email API)   │   (AI Features)                     │
└─────────────────┴─────────────────┴─────────────────────────────────────┘
```

---

## System Requirements

### Minimum Requirements
| Component | Version | Purpose |
|-----------|---------|---------|
| Node.js | v18.0.0+ | JavaScript runtime |
| npm | v9.0.0+ | Package manager |
| Git | v2.30.0+ | Version control |
| Supabase CLI | v1.100.0+ | Database management |

### Optional (for mobile builds)
| Component | Version | Purpose |
|-----------|---------|---------|
| Xcode | 15.0+ | iOS builds |
| Android Studio | Hedgehog+ | Android builds |
| Java JDK | 17+ | Android builds |

### Check Versions
```bash
# Check Node.js version
node -v  # Should be v18.0.0 or higher

# Check npm version
npm -v  # Should be v9.0.0 or higher

# Check Git version
git --version

# Check Supabase CLI
supabase --version  # Install with: npm install -g supabase
```

---

## Environment Configuration

### Frontend Variables (.env file)
Create a `.env` file in the project root:

```bash
# Copy the template
cp .env.example .env
```

The following variables are **PUBLIC** and safe to commit:
```env
# Supabase Project Configuration
VITE_SUPABASE_PROJECT_ID="supabase"
VITE_SUPABASE_PUBLISHABLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR2bmVvaG5nZXJhY2lwamFqem9zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5ODgxNDEsImV4cCI6MjA4MDU2NDE0MX0.3YgATF-HMODDQe5iJbpiUuL2SlycM5Z5XmAdKbnjg_A"
VITE_SUPABASE_URL="https://www.meow-meow.co.in:8443"
```

### Supabase Edge Function Secrets
Configure these in **Supabase Dashboard > Settings > Edge Functions > Secrets**:

| Secret Name | Required | Source | Purpose |
|-------------|----------|--------|---------|
| `SUPABASE_URL` | Auto | Supabase | Database URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Auto | Supabase | Admin access |
| `SUPABASE_ANON_KEY` | Auto | Supabase | Public access |
| `SUPABASE_DB_URL` | Auto | Supabase | Direct DB connection |
| `HUGGING_FACE_ACCESS_TOKEN` | Yes | [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) | AI translation, photo verification |
| `MAILJET_API_KEY` | Yes | [app.mailjet.com/account/apikeys](https://app.mailjet.com/account/apikeys) | Password reset emails |
| `MAILJET_SECRET_KEY` | Yes | Mailjet | Email authentication |
| `LOVABLE_API_KEY` | Optional | Auto (Lovable Cloud) | Lovable AI features |

---

## Local Development Setup

### Step 1: Clone Repository
```bash
# Clone the repository
git clone https://github.com/your-org/meow-chat.git
cd meow-chat
```

### Step 2: Install Dependencies
```bash
# Using npm
npm install

# OR using bun (faster)
bun install
```

### Step 3: Configure Environment
```bash
# Copy environment template
cp .env.example .env

# Edit if needed (values are pre-filled for this project)
nano .env
```

### Step 4: Start Development Server
```bash
# Start Vite development server
npm run dev

# Application available at http://localhost:5173
```

### Step 5: Build for Production
```bash
# Create production build
npm run build

# Preview production build
npm run preview
```

---

## Database Setup

### Database Schema Overview
The application uses 50+ PostgreSQL tables. Key tables:

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles (all users) |
| `female_profiles` | Extended female user data |
| `male_profiles` | Extended male user data |
| `chat_messages` | All chat messages |
| `active_chat_sessions` | Active chats with billing |
| `wallets` | User wallet balances |
| `wallet_transactions` | All transactions |
| `women_earnings` | Female user earnings |
| `shifts` | Work shifts |
| `user_roles` | Role-based access |
| `audit_logs` | Admin audit trail |
| `gifts` | Virtual gifts catalog |
| `gift_transactions` | Gift purchase records |

### Database Functions
The database includes these key functions:

| Function | Purpose |
|----------|---------|
| `process_wallet_transaction` | Atomic wallet operations |
| `process_chat_billing` | Chat session billing |
| `process_video_billing` | Video call billing |
| `process_gift_transaction` | Gift purchases |
| `process_atomic_transfer` | User-to-user transfers |
| `process_withdrawal_request` | Withdrawal handling |
| `is_super_user` | Check test user status |
| `should_bypass_balance` | Balance bypass for test users |

### Row Level Security (RLS)
All tables have RLS enabled:
- Users can only read/write their own data
- Admins can access all data
- Some tables are publicly readable (e.g., sample users)

---

## Edge Functions

### Available Functions

| Function | Purpose | Auth | Endpoint |
|----------|---------|------|----------|
| `ai-women-approval` | AI profile approval | Yes | `/functions/v1/ai-women-approval` |
| `ai-women-manager` | AI women management | Yes | `/functions/v1/ai-women-manager` |
| `chat-manager` | Chat session control | Yes | `/functions/v1/chat-manager` |
| `content-moderation` | Message moderation | Yes | `/functions/v1/content-moderation` |
| `data-cleanup` | Scheduled cleanup | Service | `/functions/v1/data-cleanup` |
| `group-cleanup` | Group data cleanup | Service | `/functions/v1/group-cleanup` |
| `reset-password` | Password reset emails | No | `/functions/v1/reset-password` |
| `seed-legal-documents` | Seed legal docs | Service | `/functions/v1/seed-legal-documents` |
| `seed-super-users` | Create test users | Service | `/functions/v1/seed-super-users` |

| `translate-message` | Message translation | Yes | `/functions/v1/translate-message` |
| `trigger-backup` | Database backup | Service | `/functions/v1/trigger-backup` |
| `verify-photo` | Photo verification | Yes | `/functions/v1/verify-photo` |
| `video-call-server` | Video call management | Yes | `/functions/v1/video-call-server` |
| `video-cleanup` | Video session cleanup | Service | `/functions/v1/video-cleanup` |

### Deploy Edge Functions
```bash
# Deploy all functions
npx supabase functions deploy --project-ref supabase

# Deploy specific function
npx supabase functions deploy chat-manager --project-ref meowmeow

# View logs
npx supabase functions logs chat-manager --project-ref meowmeow
```

---

## Deployment Instructions

### Option 1: Lovable Cloud (Recommended)
1. Push changes to GitHub main branch
2. Open Lovable editor
3. Click **Publish** button (top-right)
4. Click **Update** to deploy frontend changes
5. Edge functions deploy automatically

### Option 2: Self-Hosted (Linux/Unix)

#### Using Deployment Scripts
```bash
# Navigate to scripts directory
cd scripts/unix

# Make scripts executable
chmod +x *.sh

# Deploy full application
./deploy.sh

# Deploy frontend only
./deploy.sh --frontend-only

# Deploy backend only
./deploy.sh --backend-only

# Dry run (preview changes)
./deploy.sh --dry-run
```

#### Manual Deployment
```bash
# 1. Build frontend
npm run build

# 2. Deploy to web server
rsync -avz dist/ user@server:/var/www/meow-chat/

# 3. Deploy edge functions
npx supabase functions deploy --project-ref supabase
```

### Option 3: Docker Deployment
```bash
# Build image
docker build -t meow-chat:latest .

# Run container
docker run -d -p 80:80 --name meow-chat meow-chat:latest

# View logs
docker logs -f meow-chat
```

---

## Scripts Reference

All scripts are located in `scripts/unix/` (Linux/Unix) and `scripts/windows/` (Windows).

### startup.sh - Start Application
```bash
# Start development server
./startup.sh development

# Start preview server
./startup.sh staging

# Start production server
./startup.sh production
```

### shutdown.sh - Stop Application
```bash
# Stop the running application
./shutdown.sh
```

### restart.sh - Restart Application
```bash
# Restart with same environment
./restart.sh

# Restart with different environment
./restart.sh production
```

### deploy.sh - Deploy Application
```bash
# Full deployment
./deploy.sh

# Options:
#   --frontend-only    Deploy only frontend
#   --backend-only     Deploy only backend
#   --skip-tests       Skip tests
#   --skip-build       Use existing build
#   --dry-run          Preview changes
```

### undeploy.sh - Undeploy Application
```bash
# Remove deployed application
./undeploy.sh

# Options:
#   --keep-data        Keep database data
#   --force            Skip confirmation
```

### backup.sh - Create Backup
```bash
# Full backup
./backup.sh --full

# Options:
#   --code-only        Backup code only
#   --db-only          Backup database only
#   --storage-only     Backup storage only
#   --compress         Compress backup
#   --output-dir DIR   Custom output directory
```

### restore.sh - Restore Backup
```bash
# Restore from backup
./restore.sh /path/to/backup

# Options:
#   --code-only        Restore code only
#   --db-only          Restore database only
#   --dry-run          Preview restore
```

---

## Troubleshooting

### Common Issues

#### 1. "Module not found" Errors
```bash
# Clear cache and reinstall
rm -rf node_modules
rm package-lock.json
npm install
```

#### 2. CORS Errors
- Check Edge Functions include CORS headers
- Verify Supabase project URL is correct
- Check browser console for specific errors

#### 3. Authentication Failures
- Verify JWT tokens are valid
- Check Supabase Auth configuration
- Ensure user email is confirmed

#### 4. Database Connection Issues
- Check RLS policies
- Verify connection string
- Check user permissions

#### 5. Edge Function Errors
```bash
# Check logs
npx supabase functions logs function-name --project-ref meowmeow

# Redeploy function
npx supabase functions deploy function-name --project-ref meowmeow
```

#### 6. Build Failures
```bash
# Clear cache
npm cache clean --force

# Check TypeScript errors
npx tsc --noEmit

# Run linter
npm run lint
```

### Support Resources
- **Lovable Docs**: https://docs.lovable.dev
- **Supabase Docs**: https://supabase.com/docs
- **Discord Community**: https://discord.gg/lovable

---

## Quick Reference

### URLs
| Resource | URL |
|----------|-----|
| Supabase Dashboard | https://supabase.com/dashboard/project/meowmeow |
| Edge Functions | https://supabase.com/dashboard/project/meowmeow/functions |
| Database | https://supabase.com/dashboard/project/meowmeow/editor |
| Auth | https://supabase.com/dashboard/project/meowmeow/auth/users |
| Storage | https://supabase.com/dashboard/project/meowmeow/storage/buckets |
| Secrets | https://supabase.com/dashboard/project/meowmeow/settings/functions |

### Commands
```bash
# Development
npm run dev           # Start dev server
npm run build         # Build for production
npm run preview       # Preview production build
npm run lint          # Run linter

# Database
npx supabase db push  # Apply migrations
npx supabase db reset # Reset database (CAUTION)

# Edge Functions
npx supabase functions deploy        # Deploy all
npx supabase functions logs [name]   # View logs
```
