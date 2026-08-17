# Implementation Plan

Large, cross-cutting request. Breaking into 5 workstreams.

## 1. Supabase anon key validity
- Decode current `VITE_SUPABASE_PUBLISHABLE_KEY` in `.env` — check `exp` claim.
- Current key `exp: 2080564141` (Nov 2035). **Not expired, no action needed.** Will confirm and report.

## 2. Women dashboard — remove Bulk Chat
- Locate `BulkChat` / "Bulk Chat" tab/button in `WomenDashboardScreen.tsx` and related components.
- Remove the tab, route entry, and the underlying component file(s). Keep no dead imports.

## 3. 1-to-1 chat attachments/camera/files/voice not visible after send
- Audit `DraggableMiniChatWindow.tsx`, `ChatScreen.tsx`, `VoiceRecorder.tsx`, and the upload path to `/meowmeow/app/attachment` (or `chat-attachments` bucket).
- Fix: ensure after upload, message row is inserted with `attachment_url`/`type` and realtime INSERT is broadcasting to both sender and receiver. Verify sender's own optimistic message renders the attachment (not just text).
- Ensure `chat_messages` SELECT policy allows both participants; verify realtime publication includes the table.

## 4. Group chat behavior
- **Default men view empty**: Query group rooms with `EXISTS women host active` filter on men side. Hide rooms with 0 women hosts.
- **Room appears on men side when a woman initiates**: already partly done via `group_active_hosts`; ensure realtime subscription on men dashboard filters/refreshes.
- **Right-side online members panel**: Add a sidebar in `GroupChatRoom.tsx` listing all currently-online participants (host + men), driven by presence channel. Same for both genders.
- **Join/leave system messages**: Insert system-type `group_chat_messages` on presence join/leave, visible to host and all participants.
- **Host typing multi-script**: Reuse `translateForViewer` pipeline (already added last turn) — verify host preview + post-send translation runs based on each viewer's profile language. Fix the post-send path if `english_translation`/per-viewer translation isn't being computed.

## 5. Admin Online / Chats / TL tabs
- **Online tab**: Two columns — all online men (left), all online women (right). Admin can click any to open 1-to-1 chat, audio call, video call. All routed through a `is_admin` bypass in `bill_session_minute` so no debit/credit occurs.
- **Chats tab**: Admin's active chat threads list.
- **TL tab**: Community-style room. Only women assigned the `TL` service role see this tab and can chat with admin free of charge.
  - Add `TL` value to `user_service_roles.role` enum (or reuse existing table).
  - `/admin/usermanagement`: add "Assign TL" toggle button per woman user.
  - Women with TL role see a "TL" tab in `WomenDashboardScreen`.
  - Admin sees TL tab listing all TL women + a group-style chat.
- **Billing bypass**: In `bill_session_minute` and `bill_group_chat_minute` RPCs, early-return `success` with 0 debit/credit when either participant has admin role.

## Technical details

### DB migrations
```sql
-- TL role
INSERT INTO ... user_service_roles ... (or add enum value 'tl');
GRANT ... appropriate policies

-- Billing bypass
CREATE OR REPLACE FUNCTION bill_session_minute(...) ...
  IF has_role(_man, 'admin') OR has_role(_woman, 'admin') THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'admin');
  END IF;
```

### Files to touch (estimate)
- `.env` — verify only
- `src/pages/WomenDashboardScreen.tsx` — remove bulk chat tab, add TL tab (conditional)
- `src/components/BulkChat*.tsx` — delete
- `src/components/DraggableMiniChatWindow.tsx` — attachment render fix
- `src/components/chat/VoiceRecorder.tsx` — persist voice url in message
- `src/components/group-chat/GroupChatRoom.tsx` — online sidebar, join/leave system msgs, per-viewer translation on send
- `src/pages/MatchDiscoveryScreen.tsx` / men dashboard — filter group rooms to only those with active women hosts
- `src/pages/AdminDashboard.tsx` — Online / Chats / TL tabs
- `src/pages/AdminUserLookup.tsx` — TL assign button
- New: `supabase/migrations/*` — TL role, billing bypass for admin, RLS, GRANTs

### Verification
- Playwright: log in as woman → send attachment → confirm visible on both sides.
- SQL: `SELECT bill_session_minute(admin_id, woman_id, ...)` returns `skipped: admin`.
- Manual: admin dashboard shows Online/Chats/TL tabs; TL tab only visible to TL-tagged women.

## Scope check

This is ~8-12 hours of work. Confirm priority order before I start, or approve to execute end-to-end.
