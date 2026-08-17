# Application Map — Complete File Documentation

> Every file in the Meow Meow application explained with its purpose,
> key functions, dependencies, and how it connects to other modules.

---

## Table of Contents

1. [Entry Points](#1-entry-points)
2. [Pages (Route Components)](#2-pages)
3. [Components](#3-components)
4. [Hooks](#4-hooks)
5. [Services](#5-services)
6. [Contexts](#6-contexts)
7. [Types & Constants](#7-types--constants)
8. [Utilities & Libraries](#8-utilities--libraries)
9. [i18n (Internationalization)](#9-i18n)
10. [Data Files](#10-data-files)
11. [Supabase Edge Functions](#11-supabase-edge-functions)
12. [Flutter Mobile App](#12-flutter-mobile-app)
13. [Scripts](#13-scripts)
14. [Configuration Files](#14-configuration-files)

---

## 1. Entry Points

### `src/main.tsx`
- **Purpose:** Application bootstrap — mounts React to DOM
- **What it does:** Imports `App.tsx`, renders it into the root `<div>` element
- **Key:** Registers PWA service worker for offline support

### `src/App.tsx`
- **Purpose:** Root component — sets up routing, providers, and lazy loading
- **What it does:**
  - Wraps entire app in providers: `ThemeProvider` → `QueryClientProvider` → `I18nProvider` → `TranslationProvider` → `TooltipProvider`
  - Defines all routes using React Router v6
  - Lazy-loads all pages except `AuthScreen` (eagerly loaded for instant render)
  - Preloads dashboard routes during idle time for fast navigation
  - Configures React Query with 15-minute stale time and offline-first mode
- **Key patterns:**
  - `LazyRoute` wrapper for code-split route components
  - `AppShell` memoized wrapper prevents unnecessary re-renders
  - `startTransition` for non-blocking preloading
- **Connects to:** Every page component, all context providers

### `index.html`
- **Purpose:** HTML shell for the SPA
- **What it does:** Contains meta tags, PWA manifest link, favicon, root div
- **SEO:** Includes Open Graph tags, description, viewport settings

---

## 2. Pages

### Authentication Pages

| File | Route | Purpose |
|------|-------|---------|
| `AuthScreen.tsx` | `/` | **Login page** — Email/password login. Eagerly loaded (not lazy). Checks existing session and redirects to dashboard. Supports i18n language selector. |
| `ForgotPasswordScreen.tsx` | `/forgot-password` | **Password reset request** — Takes email, sends reset link via Supabase auth. Shows success/error feedback. |
| `PasswordResetScreen.tsx` | `/reset-password` | **Password reset form** — Takes new password + confirmation. Validates password strength. Called from email link. |
| `PasswordResetSuccessScreen.tsx` | `/password-reset-success` | **Reset confirmation** — Shows success message with redirect to login. |

### Registration Flow (Multi-step)

The registration flow is a multi-step wizard. Each step saves data to `localStorage` and navigates to the next step. The final step creates the user in Supabase.

| File | Route | Step | Purpose |
|------|-------|------|---------|
| `LanguageCountryScreen.tsx` | `/register` | 1 | **Language & Country** — Select primary language and country. Determines if user is Indian (affects earning eligibility). |
| `BasicInfoScreen.tsx` | `/basic-info` | 2 | **Basic Info** — Full name, gender (male/female only), date of birth, email. Gender determines which dashboard they see. |
| `PersonalDetailsScreen.tsx` | `/personal-details` | 3 | **Personal Details** — Bio, occupation, education, religion, marital status, height, body type, interests. |
| `PhotoUploadScreen.tsx` | `/photo-upload` | 4 | **Photo Upload** — Upload profile photo. Image is stored in Supabase Storage. Face verification runs via `face-api.js`. |
| `LocationSetupScreen.tsx` | `/location-setup` | 5 | **Location** — State/province selection within chosen country. Used for matching proximity. |
| `LanguagePreferencesScreen.tsx` | `/language-preferences` | 6 | **Languages** — Select up to 5 languages user speaks. Stored in `user_languages` table. Critical for same-language matching. |
| `TermsAgreementScreen.tsx` | `/terms-agreement` | 7 | **Legal Agreement** — Accept terms of service, privacy policy, content guidelines. Must accept all to proceed. |
| `PasswordSetupScreen.tsx` | `/password-setup` | 8 | **Password** — Create password with strength requirements (8+ chars, uppercase, lowercase, digit). |
| `AIProcessingScreen.tsx` | `/ai-processing` | 9 | **AI Processing** — Animated screen shown while backend processes registration. For women: triggers AI approval check. |
| `WelcomeTutorialScreen.tsx` | `/welcome-tutorial` | 10 | **Tutorial** — Swipeable onboarding tutorial explaining app features. |
| `RegistrationCompleteScreen.tsx` | `/registration-complete` | 11 | **Complete** — Congratulations screen. Redirects to appropriate dashboard. |
| `ApprovalPendingScreen.tsx` | `/approval-pending` | — | **Women Only** — Shown when woman's profile is pending AI/admin approval. Cannot access dashboard until approved. |

### Main App Pages

| File | Route | Purpose |
|------|-------|---------|
| `DashboardScreen.tsx` | `/dashboard` | **Men's Dashboard** — Main hub for male users. Shows: online women (sorted by same language → wallet balance), quick action buttons (wallet, matches, profile, settings), parallel chat windows, video call buttons, private group rooms. Real-time updates via Supabase Realtime subscriptions. ~1500 lines. |
| `WomenDashboardScreen.tsx` | `/women-dashboard` | **Women's Dashboard** — Main hub for female users. Shows: online men (sorted by load balancing → same language → wallet balance), earnings display, golden badge status, shift compliance, private group hosting. Only shows Indian women's earning stats. ~1500 lines. |
| `OnlineUsersScreen.tsx` | `/online-users` | **Browse Online Users** — Full-screen grid of currently online opposite-gender users with filters. |
| `MatchingScreen.tsx` | `/find-match` | **Smart Matching** — AI-powered match suggestions based on language, interests, location. Uses `matchScoreCalculator.ts`. |
| `MatchDiscoveryScreen.tsx` | `/match-discovery` | **Match Discovery** — Browse potential matches with swipe-like interface. |
| `ProfileDetailScreen.tsx` | `/profile/:userId` | **User Profile** — Detailed view of another user's profile. Shows photos, bio, interests, languages. Includes chat/call/gift action buttons. |
| `WalletScreen.tsx` | `/wallet` | **Men's Wallet** — Balance display, recharge options, transaction history. Recharge amounts fetched from database. |
| `WomenWalletScreen.tsx` | `/women-wallet` | **Women's Wallet** — Earnings display, withdrawal requests (min ₹10,000), earning history. |
| `TransactionHistoryScreen.tsx` | `/transaction-history` | **Transaction History** — Paginated list of all wallet transactions with filters (chat, video, gift, recharge, withdrawal). |
| `GiftSendingScreen.tsx` | `/send-gift/:receiverId` | **Send Gift** — Browse gift catalog, select gift, add message, send. Deducts from sender wallet, credits 50% to receiver. |
| `SettingsScreen.tsx` | `/settings` | **User Settings** — Theme, language, notification preferences, account management, logout. |
| `ShiftComplianceScreen.tsx` | `/shift-compliance` | **Women Only** — View assigned shifts, check-in/check-out, attendance records. Women must be on-shift to earn. |
| `InstallApp.tsx` | `/install` | **PWA Install** — Instructions for installing the app as a PWA on different devices. |

### Admin Pages

All admin pages are protected — only users in the `super_users` table can access them.

| File | Route | Purpose |
|------|-------|---------|
| `AdminDashboard.tsx` | `/admin` | **Admin Home** — Overview metrics: total users, active users, revenue, active chats. Navigation to all admin sections. |
| `AdminAnalyticsDashboard.tsx` | `/admin/analytics` | **Analytics** — Charts and graphs: user growth, revenue trends, chat activity, matching stats. Uses `recharts`. |
| `AdminUserManagement.tsx` | `/admin/users` | **User Management** — Search, view, edit, suspend, ban users. View user profiles and activity. |
| `AdminUserLookup.tsx` | `/admin/user-lookup` | **User Lookup** — Quick search by email, name, or ID. Detailed user info panel. |
| `AdminKYCManagement.tsx` | `/admin/kyc` | **KYC Management** — Review and approve/reject women's KYC applications. Photo verification. |
| `AdminChatMonitoring.tsx` | `/admin/chat-monitoring` | **Chat Monitor** — View active chat sessions, flagged messages, moderation actions. |
| `AdminModerationScreen.tsx` | `/admin/moderation` | **Content Moderation** — Review flagged content, take moderation actions (warn, suspend, ban). |
| `AdminChatPricing.tsx` | `/admin/chat-pricing` | **Pricing Config** — Set chat/video per-minute rates, women's earning rates, minimum withdrawal. Dynamic pricing saved to `chat_pricing` table. |
| `AdminGiftPricing.tsx` | `/admin/gifts` | **Gift Management** — Add/edit/remove virtual gifts. Set prices, categories, emojis. |
| `AdminFinanceDashboard.tsx` | `/admin/finance` | **Finance Overview** — Revenue breakdown, pending withdrawals, platform earnings. |
| `AdminFinanceReports.tsx` | `/admin/finance-reports` | **Finance Reports** — Detailed financial reports with date range filters. Export capability. |
| `AdminTransactionHistory.tsx` | `/admin/transactions` | **All Transactions** — Platform-wide transaction log with search and filters. |
| `AdminLanguageGroups.tsx` | `/admin/languages` | **Language Groups** — Manage language communities, member counts, group settings. |
| `AdminLanguageLimits.tsx` | `/admin/language-limits` | **Language Limits** — Set maximum women per language group to ensure even distribution. |
| `AdminSettings.tsx` | `/admin/settings` | **Platform Settings** — Global app settings stored in `admin_settings` table. |
| `AdminLegalDocuments.tsx` | `/admin/legal-documents` | **Legal Docs** — Edit terms of service, privacy policy, and other legal documents. |
| `AdminBackupManagement.tsx` | `/admin/backups` | **Database Backups** — Trigger and manage database backups. View backup history. |
| `AdminPerformanceMonitoring.tsx` | `/admin/performance` | **Performance** — Server metrics, response times, error rates. |
| `AdminAuditLogs.tsx` | `/admin/audit-logs` | **Audit Trail** — All admin actions logged with timestamps, IPs, old/new values. |
| `AdminPolicyAlerts.tsx` | `/admin/policy-alerts` | **Policy Violations** — Automated alerts for policy violations (inappropriate content, suspicious activity). |
| `AdminMessaging.tsx` | `/admin/messaging` | **Admin Messaging** — Send broadcast messages or direct messages to users. |

---

## 3. Components

### Core UI Components (`src/components/ui/`)

These are shadcn/ui base components — pre-styled, accessible, and themeable.

| Component | Purpose |
|-----------|---------|
| `button.tsx` | Button with variants: default, destructive, outline, secondary, ghost, link |
| `card.tsx` | Card container with header, content, footer sections |
| `dialog.tsx` | Modal dialog with backdrop overlay |
| `input.tsx` | Text input with consistent styling |
| `select.tsx` | Dropdown select with search capability |
| `badge.tsx` | Status badges with color variants |
| `avatar.tsx` | User avatar with fallback initials |
| `tabs.tsx` | Tab navigation with animated indicator |
| `toast.tsx` / `sonner.tsx` | Notification toasts (two systems: radix-based and sonner) |
| `skeleton.tsx` | Loading placeholder animations |
| `switch.tsx` | Toggle switch for boolean settings |
| `scroll-area.tsx` | Custom scrollable containers |
| `sheet.tsx` | Slide-out side panel (mobile-friendly) |
| `drawer.tsx` | Bottom drawer for mobile interactions |
| `table.tsx` | Data table with responsive layout |
| `form.tsx` | Form wrapper with react-hook-form integration |
| `popover.tsx` | Floating content popover |
| `dropdown-menu.tsx` | Right-click or button-triggered dropdown menus |
| `sidebar.tsx` | Collapsible sidebar navigation |

### Chat Components

| File | Purpose |
|------|---------|
| `ChatInterface.tsx` | **Main chat window** — Full chat UI with message list, input, translation, typing indicators. Handles real-time message sync via Supabase Realtime. Per-minute billing display. |
| `chat/ChatMessageList.tsx` | **Message list** — Scrollable message history with auto-scroll to bottom. Shows sender name, timestamp, translation toggle. |
| `chat/ChatMessageInput.tsx` | **Message input** — Text input with send button, character counter (max 2000), voice input toggle. |
| `chat/ChatUserList.tsx` | **User list** — Sidebar showing chat contacts with unread counts, online status, last message preview. |
| `MiniChatWindow.tsx` | **Floating mini chat** — Minimized chat window for parallel chats. Draggable, resizable. Shows on dashboard. |
| `DraggableMiniChatWindow.tsx` | **Draggable wrapper** — Makes mini chat windows draggable with position persistence. |
| `EnhancedParallelChatsContainer.tsx` | **Parallel chats manager** — Manages up to 3 simultaneous chat windows. Handles opening, closing, minimizing. |
| `ParallelChatsContainer.tsx` | **Basic parallel container** — Simpler version of parallel chat management. |
| `ParallelChatSettingsPanel.tsx` | **Chat settings** — Configure parallel chat behavior, notification sounds. |
| `ChatBillingDisplay.tsx` | **Billing info** — Shows current chat cost, rate per minute, elapsed time for the active session. |
| `ChatEarningsDisplay.tsx` | **Earnings info** — Women's version — shows earnings accumulated from current chat session. |
| `ChatRelationshipActions.tsx` | **Relationship buttons** — Friend request, block, report buttons within chat. |
| `IncomingChatPopup.tsx` | **Chat notification** — Popup notification when a new chat request arrives. Accept/decline buttons. |
| `WomenChatModeSwitcher.tsx` | **Mode toggle** — Women can switch between earning mode (₹2/min) and free mode. |
| `MiniChatActions.tsx` | **Mini chat buttons** — Action buttons for minimized chat windows (maximize, close, mute). |

### Video Call Components

| File | Purpose |
|------|---------|
| `VideoCallModal.tsx` | **Video call UI** — Full-screen video call interface with local/remote video streams, controls (mic, camera, end call), call timer, billing display. |
| `P2PVideoCallModal.tsx` | **P2P call modal** — Wraps `useP2PCall` hook for 1-on-1 WebRTC calls. Handles SDP exchange via Supabase Realtime. |
| `SRSVideoCallModal.tsx` | **SRS call modal** — Uses SRS media server for call routing. Fallback when P2P fails. |
| `DirectVideoCallButton.tsx` | **Call button (per user)** — Button to initiate video call with a specific user. Checks: same language, Indian only, wallet balance ≥ 2 min. |
| `VideoCallButton.tsx` | **Random call button** — Initiates video call with any available matching user. |
| `VideoCallMiniButton.tsx` | **Compact call button** — Smaller call button for inline use in user cards. |
| `IncomingCallModal.tsx` | **Incoming call** — Modal shown when receiving a video call. Shows caller info. Accept/decline/auto-decline timer. |
| `IncomingVideoCallWindow.tsx` | **Incoming call window** — Alternative incoming call UI with preview. |
| `DraggableVideoCallWindow.tsx` | **PiP video call** — Picture-in-picture draggable video call window. |
| `GroupVideoCall.tsx` | **Group call UI** — Multi-participant video call grid. Used with SFU architecture. |
| `PrivateGroupCallWindow.tsx` | **Private group room** — Combined chat + video interface for flower rooms. Shows participant list, chat messages, host controls, billing. Teams-style layout. |
| `TeamsStyleGroupWindow.tsx` | **Teams layout** — Microsoft Teams-style layout with video grid + chat sidebar. |
| `LiveStreamButton.tsx` | **Go live button** — Button for women to start live streaming in a private group. |
| `LiveStreamViewer.tsx` | **Stream viewer** — UI for watching a live stream with viewer count and chat. |

### Private Group Components

| File | Purpose |
|------|---------|
| `PrivateGroupsSection.tsx` | **Host view** — Women see their assigned flower rooms (Rose through Marigold). Go Live/Stop Live buttons. Shows participant count. 10 rooms total. |
| `AvailableGroupsSection.tsx` | **Viewer view** — Men see currently live flower rooms. Join button with wallet balance check (min ₹20). Shows host name, viewer count, rate (₹4/min). |
| `PrivateGroupCallWindow.tsx` | **Combined interface** — Chat + video in one window. Real-time message sync, participant list, billing (₹4/min per man, ₹2/min host earnings). |

### Navigation & Layout

| File | Purpose |
|------|---------|
| `NavHeader.tsx` | **App header** — Top navigation bar with logo, back button, title, action buttons. |
| `NavLink.tsx` | **Nav link** — Styled navigation link with active state indicator. |
| `AdminNav.tsx` | **Admin sidebar** — Admin panel navigation with links to all admin sections. |
| `MobileLayout.tsx` | **Mobile wrapper** — Responsive layout wrapper for mobile devices. Handles safe areas, notch. |
| `ScreenLayout.tsx` | **Screen wrapper** — Consistent page layout with header, content area, optional footer. |
| `ScreenTitle.tsx` | **Page title** — Consistent page title component with back button. |
| `ResponsiveContainer.tsx` | **Container** — Max-width container with responsive padding. |
| `MeowLogo.tsx` | **Logo** — App logo component with size variants (sm, md, lg). |
| `AuroraBackground.tsx` | **Animated background** — Decorative animated gradient background for auth pages. |

### User Profile Components

| File | Purpose |
|------|---------|
| `ProfileEditDialog.tsx` | **Edit profile** — Dialog for editing user profile (name, bio, interests, photos). Saves to Supabase. |
| `ProfilePhotosSection.tsx` | **Photo gallery** — Photo upload/management section. Up to 6 photos. Protected images. |
| `ProtectedImage.tsx` | **Secure image** — Image component with screenshot protection (CSS-based). |
| `UserActionButtons.tsx` | **Action buttons** — Chat, video call, gift, friend, block buttons for user cards. |
| `FriendsBlockedPanel.tsx` | **Relationships** — Panel showing friends list and blocked users with manage actions. |

### Wallet & Payment

| File | Purpose |
|------|---------|
| `TransactionHistoryWidget.tsx` | **Transaction list** — Paginated transaction history with category filters. |
| `AdminTransactionHistoryWidget.tsx` | **Admin transactions** — Admin version with all users' transactions and search. |
| `PaymentStatusIndicator.tsx` | **Payment status** — Shows current payment/billing status indicator. |
| `GiftSendButton.tsx` | **Gift button** — Button to send gift to a user. Opens gift selection dialog. |
| `MenFreeMinutesBadge.tsx` | **Free minutes** — Badge showing remaining free chat minutes for new users. |

### Settings & Preferences

| File | Purpose |
|------|---------|
| `SettingsPanel.tsx` | **Settings UI** — Full settings panel with theme, language, notification, account sections. |
| `ThemeSelector.tsx` | **Theme picker** — Light/dark/system theme selector with live preview. |
| `I18nLanguageSelector.tsx` | **Language picker** — Interface language selector (16 languages). |
| `AuthLanguageSelector.tsx` | **Auth language** — Language selector shown on login/register pages. |
| `LanguageSelector.tsx` | **Generic selector** — Reusable language dropdown component. |

### Community & Elections

| File | Purpose |
|------|---------|
| `LanguageCommunityPanel.tsx` | **Community hub** — Language community panel with members, announcements, elections. |
| `LanguageGroupChat.tsx` | **Group chat** — Language-based group chat for community members. |
| `LanguageGroupShiftsPanel.tsx` | **Shift management** — Community leader's shift management panel. |
| `AIElectionPanel.tsx` | **Election UI** — AI-managed election interface: nomination, voting, results. |
| `AIShiftDisplay.tsx` | **AI shift display** — Shows AI-generated shift schedules. |
| `community/ElectionPanel.tsx` | **Election details** — Detailed election panel with candidates, vote counts. |
| `community/LeaderDashboard.tsx` | **Leader tools** — Dashboard for elected community leaders. |
| `community/DisputeReportButton.tsx` | **Report button** — Button to file disputes within community. |

### Search & Matching

| File | Purpose |
|------|---------|
| `MatchFiltersPanel.tsx` | **Search filters** — Filter panel for matching: age range, language, country, distance, habits. |
| `SearchableSelect.tsx` | **Searchable dropdown** — Select component with type-ahead search. |
| `RandomChatButton.tsx` | **Random match** — Button to start chat with a random online user. |

### Utility Components

| File | Purpose |
|------|---------|
| `ErrorBoundary.tsx` | **Error handler** — Catches React render errors and shows fallback UI. |
| `I18nProvider.tsx` | **i18n setup** — Initializes i18next with browser language detection. |
| `SecurityProvider.tsx` | **Security layer** — Implements screenshot protection, content security. |
| `AutoLogoutWrapper.tsx` | **Auto logout** — Automatically logs out inactive users after timeout. |
| `NetworkStatusIndicator.tsx` | **Network status** — Shows online/offline connectivity status. |
| `PWAInstallPrompt.tsx` | **PWA prompt** — Shows install prompt for Progressive Web App. |
| `DirectionToggle.tsx` | **RTL toggle** — Toggles between LTR and RTL text direction (for Arabic, Urdu). |
| `FormCard.tsx` | **Form container** — Styled card wrapper for registration form steps. |
| `ProgressIndicator.tsx` | **Progress bar** — Multi-step registration progress indicator. |
| `GboardHintMarquee.tsx` | **Keyboard hint** — Scrolling hint about keyboard language switching. |
| `PhoneInputWithCode.tsx` | **Phone input** — International phone input with country code selector. |
| `VirtualList.tsx` | **Virtualized list** — Renders only visible items for performance with large lists. |
| `VoiceMessagePlayer.tsx` | **Voice player** — Audio player for voice messages with waveform display. |
| `RecentActivityWidget.tsx` | **Activity feed** — Shows recent user activity (chats, gifts, calls). |
| `WomenKYCForm.tsx` | **KYC form** — Women's identity verification form (Aadhaar, PAN, etc.). |
| `AdminUserSearchDialog.tsx` | **User search** — Admin dialog for searching and selecting users. |
| `UserAdminChat.tsx` | **Admin chat** — Direct messaging between admin and users. |

---

## 4. Hooks

### Authentication & User

| Hook | Purpose |
|------|---------|
| `useOptimizedAuth.ts` | **Auth management** — Handles login, logout, session persistence. Caches user data. Checks account status. Redirects based on gender and approval status. |
| `useAdminAccess.ts` | **Admin check** — Checks if current user is in `super_users` table. Used to protect admin routes. |
| `useSuperUser.ts` | **Super user** — Extended admin access check with permissions. |

### Chat & Communication

| Hook | Purpose |
|------|---------|
| `useChatPricing.ts` | **Pricing data** — Fetches active chat/video pricing from `chat_pricing` table. Returns rates per minute for men and women. |
| `useIncomingChats.ts` | **Chat notifications** — Listens for incoming chat requests via Supabase Realtime. Shows popup notification. |
| `useIncomingCalls.ts` | **Call notifications** — Listens for incoming video call requests. Shows call modal. |
| `useParallelChatSettings.ts` | **Chat config** — Manages parallel chat settings (max 3 simultaneous chats). |
| `useWomenChatMode.ts` | **Chat mode** — Toggles between earning mode (₹2/min) and free mode for women. |
| `useBlockCheck.ts` | **Block check** — Checks if users have blocked each other before allowing chat/call. |
| `useUserRelationships.ts` | **Relationships** — Manages friend requests, blocks, reports between users. |

### Video Calls

| Hook | Purpose |
|------|---------|
| `useP2PCall.ts` | **P2P WebRTC** — Full P2P video call lifecycle. Creates RTCPeerConnection, handles SDP offer/answer exchange via Supabase Realtime, manages ICE candidates. STUN (Google) + TURN (coturn fallback). Billing timer. 994 lines. |
| `useSFUGroupCall.ts` | **SFU Group Call** — Multi-participant call via SRS server. Host publishes stream, viewers subscribe. Supabase Realtime for signaling between peers. 439 lines. |
| `useMediaServerCall.ts` | **Media Server Call** — Alternative 1-on-1 call using SRS as relay. Fallback for P2P failures. 421 lines. |
| `useSRSCall.ts` | **SRS Call** — Direct SRS WebRTC integration for calls and live streaming. |
| `usePrivateGroupCall.ts` | **Private Group** — Manages flower room calls: billing (₹4/min per man), host earnings (₹2/min per man), participant management (max 100), auto-kick for low balance. |

### Matching & Discovery

| Hook | Purpose |
|------|---------|
| `useMatchingService.ts` | **Smart matching** — Fetches and scores potential matches using `matchScoreCalculator.ts`. Considers language, distance, interests, online status. |
| `useActivityBasedStatus.ts` | **Activity status** — Updates user's online/offline status based on app activity. |
| `useActivityStatus.ts` | **Status display** — Provides formatted status text (online, away, offline) for user cards. |

### Community & Elections

| Hook | Purpose |
|------|---------|
| `useElectionSystem.ts` | **Elections** — Manages community elections: nomination, voting, result tallying. |
| `useAIElectionSystem.ts` | **AI Elections** — AI-managed elections with automatic officer assignment and scheduling. |

### Infrastructure

| Hook | Purpose |
|------|---------|
| `useI18n.ts` | **Translation** — Provides `t()` function for translating UI strings. Wraps i18next. |
| `useAppSettings.ts` | **App config** — Fetches dynamic settings from `app_settings` table. |
| `usePWA.ts` | **PWA utilities** — Detect PWA install state, trigger install prompt. |
| `useNativeApp.ts` | **Native detection** — Detect if running in Capacitor (mobile) or Electron (desktop). |
| `useDeviceDetect.ts` | **Device info** — Detect device type (mobile, tablet, desktop), screen size, platform. |
| `useBrowserCompat.ts` | **Browser compat** — Check browser support for WebRTC, notifications, etc. |
| `useNetworkStatus.ts` | **Online/offline** — Monitor network connectivity changes. |
| `useAutoReconnect.ts` | **Auto reconnect** — Automatically reconnect Supabase Realtime channels on network recovery. |
| `useRealtimeSubscription.ts` | **Realtime helper** — Simplified Supabase Realtime subscription management with cleanup. |
| `useConnectionManager.ts` | **Connection pool** — Manages WebSocket connections to prevent excess connections. |
| `useScreenProtection.ts` | **Screenshot guard** — CSS-based screenshot/screen recording prevention. |
| `useFontLoader.ts` | **Font loading** — Loads custom fonts with fallback handling. |
| `useNLLBVisibility.ts` | **Translation UI** — Controls visibility of translation-related UI elements. |
| `useProductionMode.ts` | **Env detection** — Detects production vs development environment. |

### Performance & Optimization

| Hook | Purpose |
|------|---------|
| `useDebounce.ts` | **Debounce** — Debounces rapidly changing values (search input, resize events). |
| `useOptimizedQuery.ts` | **Query optimization** — Enhanced React Query wrapper with caching strategies. |
| `useRequestQueue.ts` | **Request queue** — Queues API requests to prevent rate limiting. |
| `useOfflineSync.ts` | **Offline sync** — Queues mutations when offline, syncs when connection restored. |
| `useApiRequest.ts` | **API wrapper** — Standard API request wrapper with loading/error states. |
| `useAtomicTransaction.ts` | **Atomic ops** — Ensures database operations complete atomically (all-or-nothing). |

### Payments & Wallet

| Hook | Purpose |
|------|---------|
| `usePayment.ts` | **Payments** — Handles wallet recharge, payment processing, transaction creation. |
| `useMenFreeMinutes.ts` | **Free minutes** — Tracks and manages free chat minutes for new male users. |

### Media & Face Verification

| Hook | Purpose |
|------|---------|
| `useFaceVerification.ts` | **Face detection** — Uses `face-api.js` to verify uploaded photos contain a real human face. |
| `useVoiceInput.ts` | **Voice input** — Browser speech-to-text for voice message input. |
| `useGenderClassification.ts` | **Gender check** — AI-based gender classification of uploaded photos. |

---

## 5. Services

### `src/services/auth.service.ts`
- **Purpose:** Authentication operations
- **Functions:** `signIn()`, `signUp()`, `signOut()`, `resetPassword()`, `updatePassword()`
- **Connects to:** Supabase Auth, `profiles` table

### `src/services/profile.service.ts`
- **Purpose:** User profile CRUD
- **Functions:** `getProfile()`, `updateProfile()`, `uploadPhoto()`, `getOnlineUsers()`
- **Connects to:** `profiles`, `female_profiles`, `user_status` tables, Supabase Storage

### `src/services/wallet.service.ts`
- **Purpose:** Wallet and transaction operations
- **Functions:** `getBalance()`, `recharge()`, `deduct()`, `requestWithdrawal()`, `getTransactions()`
- **Connects to:** `wallets`, `wallet_transactions`, `women_earnings` tables

### `src/services/chat.service.ts`
- **Purpose:** Chat session and message management
- **Functions:** `createChat()`, `sendMessage()`, `getMessages()`, `endChat()`, `getChatSessions()`
- **Connects to:** `chats`, `chat_messages`, `active_chat_sessions` tables

### `src/services/admin.service.ts`
- **Purpose:** Admin operations
- **Functions:** `getMetrics()`, `manageUser()`, `updateSettings()`, `getAuditLogs()`
- **Connects to:** All admin tables, `super_users`

### `src/services/cleanup.service.ts`
- **Purpose:** Data cleanup operations
- **Functions:** `cleanupStaleSessions()`, `cleanupOldMessages()`
- **Connects to:** `active_chat_sessions`, `video_call_sessions`

---

## 6. Contexts

### `src/contexts/ThemeContext.tsx`
- **Purpose:** Theme management (light/dark/system)
- **What it does:** Stores theme preference in localStorage, applies CSS class to document root, provides `theme` and `setTheme` to all components
- **Used by:** `ThemeSelector`, all components via CSS variables

### `src/contexts/TranslationContext.tsx`
- **Purpose:** Real-time message translation context
- **What it does:** Provides translation functions for chat messages between different languages
- **Used by:** `ChatInterface`, `ChatMessageList`

---

## 7. Types & Constants

### `src/types/index.ts`
- **Purpose:** All shared TypeScript interfaces
- **Contains:** `User`, `UserProfile`, `Message`, `ChatSession`, `WalletBalance`, `Transaction`, `Match`, `Gift`, `VideoCallSession`, `Notification`, `AdminMetrics`, `UserSettings`, `DeviceInfo`

### `src/constants/index.ts`
- **Purpose:** All static application constants
- **Contains:** `ROUTES` (all route paths), `BREAKPOINTS`, `TIME`, `CACHE_DURATION`, `LIMITS` (max message length: 2000, max photos: 6, max parallel chats: 3), `CURRENCY` (INR default), `STORAGE_KEYS`, `PATTERNS` (email, phone, password regex), `GENDER_OPTIONS`, `ACCOUNT_STATUS`, `APPROVAL_STATUS`

---

## 8. Utilities & Libraries

### `src/lib/utils.ts`
- **Purpose:** General utility functions
- **Contains:** `cn()` — Tailwind class merging utility (clsx + tailwind-merge)

### `src/lib/matchScoreCalculator.ts`
- **Purpose:** Matching algorithm
- **What it does:** Calculates compatibility score (0-100) between two users based on:
  - Language overlap (highest weight)
  - Geographic proximity
  - Interest overlap
  - Age compatibility
  - Online status bonus

### `src/lib/content-moderation.ts`
- **Purpose:** Client-side content filtering
- **What it does:** Checks messages for prohibited content (profanity, personal info, external links) before sending

### `src/lib/performance.ts`
- **Purpose:** Performance monitoring
- **What it does:** Tracks component render times, API response times, reports to console in development

### `src/lib/polyfills.ts`
- **Purpose:** Browser compatibility polyfills
- **What it does:** Adds missing APIs for older browsers

### `src/lib/api/`
- `api-client.ts` — HTTP client wrapper with retry logic, timeout handling
- `cache-manager.ts` — In-memory cache with TTL-based expiration
- `network-monitor.ts` — Network connectivity monitoring
- `payment-service.ts` — Payment processing abstraction
- `payment-types.ts` — Payment-related TypeScript types
- `request-queue.ts` — FIFO request queue for rate limiting
- `types.ts` — API response type definitions
- `index.ts` — Barrel export

### `src/lib/fonts/`
- `font-loader.ts` — Dynamic font loading for multiple scripts (Devanagari, Arabic, etc.)
- `index.ts` — Barrel export

---

## 9. i18n (Internationalization)

### `src/i18n/config.ts`
- **Purpose:** i18next configuration
- **What it does:** Configures i18next with browser language detection, fallback language (English), namespace structure

### `src/i18n/index.ts`
- **Purpose:** i18n barrel export
- **What it does:** Exports configured i18n instance

### Locale Files (`src/i18n/locales/`)

| File | Language | Script |
|------|----------|--------|
| `en.json` | English | Latin |
| `hi.json` | Hindi | Devanagari |
| `ta.json` | Tamil | Tamil |
| `te.json` | Telugu | Telugu |
| `bn.json` | Bengali | Bengali |
| `mr.json` | Marathi | Devanagari |
| `gu.json` | Gujarati | Gujarati |
| `kn.json` | Kannada | Kannada |
| `ml.json` | Malayalam | Malayalam |
| `pa.json` | Punjabi | Gurmukhi |
| `or.json` | Odia | Odia |
| `ur.json` | Urdu | Arabic (RTL) |
| `ar.json` | Arabic | Arabic (RTL) |
| `fr.json` | French | Latin |
| `es.json` | Spanish | Latin |
| `zh.json` | Chinese | Simplified Chinese |

---

## 10. Data Files

### `src/data/countries.ts`
- **Purpose:** Country list with codes, names, phone codes
- **Used by:** Registration country selector

### `src/data/states.ts`
- **Purpose:** State/province lists per country
- **Used by:** Location setup screen

### `src/data/languages.ts`
- **Purpose:** All supported languages with codes
- **Used by:** Language preference selectors

### `src/data/men_languages.ts` / `women_languages.ts`
- **Purpose:** Gender-specific language lists
- **Used by:** Dashboard language-based user sections

### `src/data/supportedLanguages.ts`
- **Purpose:** Languages supported for real-time translation
- **Used by:** Translation features

---

## 11. Supabase Edge Functions

All edge functions are serverless Deno functions deployed to Supabase. They run on the server and have access to environment secrets.

| Function | Purpose | Trigger |
|----------|---------|---------|
| `video-call-server` | **SRS WebRTC signaling** — Handles publish/subscribe/unpublish actions for SRS media server. Creates/joins/ends video call rooms. | HTTP POST from client |
| `video-cleanup` | **Video session cleanup** — Deletes stale video call sessions older than 5 minutes. Ends orphaned active/ringing sessions. | Cron (every minute) |
| `chat-manager` | **Chat session management** — Creates chat sessions, handles per-minute billing, ends idle chats (3 min), ends paused chats (10 min). | HTTP POST / Cron |
| `content-moderation` | **Message moderation** — AI-powered content check for inappropriate messages. Flags violations. | HTTP POST (on message send) |
| `ai-women-approval` | **Auto-approve women** — AI checks women's profiles for eligibility (photo quality, completeness). Sets approval status. | HTTP POST (on registration) |
| `ai-women-manager` | **Women management** — Manages women's earning eligibility, golden badge assignment, performance scoring. | Cron (periodic) |
| `auto-approve-kyc` | **KYC auto-approval** — Automatically approves KYC applications that meet criteria. | Cron (periodic) |
| `monthly-earning-rotation` | **Earning rotation** — Monthly rotation of earning-eligible women to ensure fair distribution. | Cron (monthly) |
| `group-cleanup` | **Group state reset** — Daily midnight IST reset of all private group states (is_live, host, participants). | Cron (daily at 00:00 IST) |
| `data-cleanup` | **Data cleanup** — Removes old/stale data across multiple tables to keep database lean. | Cron (weekly) |
| `trigger-backup` | **Database backup** — Triggers a database backup and logs the operation. | HTTP POST (from admin) |
| `reset-password` | **Password reset** — Sends password reset email via Supabase Auth. | HTTP POST |
| `verify-photo` | **Photo verification** — Verifies uploaded photos meet requirements (face detection, quality). | HTTP POST |
| `seed-legal-documents` | **Legal docs seed** — Seeds initial legal documents (terms, privacy policy) into database. | HTTP POST (one-time) |
| `seed-super-users` | **Admin seed** — Seeds initial super user accounts for admin access. | HTTP POST (one-time) |

---

## 12. Flutter Mobile App

### Architecture

```
flutter/lib/
├── core/                    # Framework-level code
│   ├── config/              # App configuration
│   │   ├── app_config.dart  # Constants synced with React
│   │   └── supabase_config.dart  # Supabase connection
│   ├── services/            # API service layer
│   ├── theme/               # App theme (colors, typography)
│   ├── router/              # GoRouter navigation
│   ├── l10n/                # Localization
│   └── utils/               # Performance utilities
├── features/                # Feature modules
│   ├── auth/                # Login, register, password reset
│   ├── dashboard/           # Men's and women's dashboards
│   ├── chat/                # Chat interface
│   ├── matching/            # Match discovery
│   ├── profile/             # User profiles
│   ├── wallet/              # Wallet and transactions
│   ├── video_call/          # Video calling
│   ├── gifts/               # Gift sending
│   ├── settings/            # App settings
│   ├── shifts/              # Shift management
│   ├── transactions/        # Transaction history
│   ├── admin/               # Admin dashboard
│   └── community/           # Community features
├── shared/                  # Shared across features
│   ├── models/              # Data models
│   ├── providers/           # Riverpod providers
│   ├── screens/             # Common screens
│   └── widgets/             # Reusable widgets
└── main.dart                # App entry point
```

### Key Flutter Services

| Service | Purpose |
|---------|---------|
| `auth_service.dart` | Authentication (login, register, logout) |
| `profile_service.dart` | Profile CRUD operations |
| `chat_service.dart` | Chat messages and sessions |
| `wallet_service.dart` | Wallet balance and transactions |
| `matching_service.dart` | Match discovery and scoring |
| `notification_service.dart` | Push notifications |
| `storage_service.dart` | File upload/download |
| `relationship_service.dart` | Friends, blocks, reports |
| `dashboard_service.dart` | Dashboard data aggregation |
| `admin_service.dart` | Admin operations |
| `app_settings_service.dart` | Dynamic app settings |
| `cache_service.dart` | Local data caching |
| `optimized_supabase_service.dart` | Optimized Supabase queries |

### Key Flutter Models

| Model | Purpose |
|-------|---------|
| `user_model.dart` | User profile data |
| `chat_model.dart` | Chat messages and sessions |
| `match_model.dart` | Match data with scores |
| `wallet_model.dart` | Wallet and transactions |
| `gift_model.dart` | Gift catalog and transactions |

---

## 13. Scripts

### Unix Scripts (`scripts/unix/`)

| Script | Purpose |
|--------|---------|
| `startup.sh` | Start the application |
| `shutdown.sh` | Stop the application |
| `restart.sh` | Restart the application |
| `deploy.sh` | Deploy to production |
| `undeploy.sh` | Remove deployment |
| `backup.sh` | Database backup |
| `restore.sh` | Database restore |
| `webrtc-install.sh` | Full WebRTC infrastructure installation |
| `webrtc-start.sh` | Start TURN + SRS + Nginx |
| `webrtc-stop.sh` | Stop all WebRTC services |
| `webrtc-restart.sh` | Restart all WebRTC services |
| `webrtc-status.sh` | Status dashboard for all services |
| `webrtc-monitor.sh` | Live monitoring dashboard |

### Windows Scripts (`scripts/windows/`)

| Script | Purpose |
|--------|---------|
| `startup.bat` | Start the application |
| `shutdown.bat` | Stop the application |
| `restart.bat` | Restart the application |
| `deploy.bat` | Deploy to production |
| `backup.bat` | Database backup |
| `restore.bat` | Database restore |

---

## 14. Configuration Files

| File | Purpose |
|------|---------|
| `vite.config.ts` | Vite build configuration — plugins (PWA, React), dev server, aliases |
| `tailwind.config.ts` | Tailwind CSS configuration — custom colors, fonts, animations, breakpoints |
| `tsconfig.json` | TypeScript configuration — strict mode, path aliases, module resolution |
| `tsconfig.app.json` | App-specific TypeScript settings |
| `tsconfig.node.json` | Node.js (build tools) TypeScript settings |
| `postcss.config.js` | PostCSS plugins — Tailwind CSS, autoprefixer |
| `eslint.config.js` | ESLint rules — code quality, React hooks rules |
| `vitest.config.ts` | Vitest test runner configuration |
| `components.json` | shadcn/ui component configuration — style, paths, aliases |
| `capacitor.config.ts` | Capacitor mobile app configuration — app ID, server URL, plugins |
| `electron-builder.json` | Electron desktop app build settings |
| `package.json` | Node.js dependencies and scripts |
| `index.html` | HTML entry point with meta tags and PWA manifest |
| `public/manifest.json` | PWA manifest — app name, icons, theme colors |
| `public/robots.txt` | Search engine crawling rules |
| `supabase/config.toml` | Supabase project configuration |
| `src/index.css` | Global CSS — Tailwind imports, CSS custom properties (design tokens), dark mode variables |
| `.env` | Environment variables — Supabase URL and anon key (auto-populated) |
| `requirements.txt` | Server infrastructure requirements for WebRTC deployment |
