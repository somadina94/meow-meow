# Video Calling System Documentation

## Overview

This application uses **P2P WebRTC** for 1-on-1 video calling between users. Connections are established directly between peers using WebRTC, with signaling handled through Supabase Realtime (the `video_call_sessions` table).

**Key Features:**
- 1-on-1 video calls between same-language Indian users
- Direct peer-to-peer WebRTC (no media server)
- Self-hosted coturn TURN server for NAT traversal
- No content storage (ephemeral streams only)
- Per-minute billing with automatic balance checks

---

## Architecture

```
┌─────────────────┐     WebRTC (P2P)     ┌─────────────────┐
│   User A        │◄───────────────────►│   User B        │
│   (Caller)      │                     │   (Receiver)    │
└────────┬────────┘                     └────────┬────────┘
         │                                       │
         │  Signaling (SDP/ICE)                  │
         ▼                                       ▼
┌──────────────────────────────────────────────────────────┐
│              Supabase Realtime                           │
│         (video_call_sessions table)                      │
└──────────────────────────────────────────────────────────┘
```

**Components:**
1. **Supabase Realtime** — Signaling channel for SDP offers/answers and ICE candidates
2. **coturn TURN Server** — Self-hosted relay for users behind symmetric NAT
3. **React Hooks** (`useP2PCall`) — Client-side WebRTC management
4. **Cleanup Function** (`video-cleanup`) — Auto-deletes session data after 5 minutes

---

## Privacy & Storage Policy

**IMPORTANT: No video/audio content is stored or recorded.**

- All streams are ephemeral (real-time peer-to-peer only)
- No media server involved — data flows directly between peers
- Session metadata is automatically deleted after 5 minutes
- Cron job runs every minute to clean up old records

---

## ICE / TURN Configuration

WebRTC requires ICE servers for NAT traversal. Configuration is in `src/lib/iceServers.ts`.

### Self-hosted coturn (recommended for production)

Set these environment variables:

```env
VITE_TURN_URL=turn:your-coturn-server.com:3478
VITE_TURN_USERNAME=youruser
VITE_TURN_CREDENTIAL=yourpassword
```

The app automatically adds TCP and TLS variants for restrictive networks.

### STUN Servers

Free STUN servers (Google, Cloudflare) are always included for basic connectivity.

---

## System Rules

- **India-only**: Both participants must have `country='IN'`
- **Same language**: Both must share a primary language
- **Minimum balance**: Men need ≥₹16 (2 minutes at ₹8/min) to start a call
- **Billing**: Per-minute at 60-second intervals; auto-terminates on insufficient balance
- **Priority**: Active calls take priority over chats

---

## Database Schema

### Table: `video_call_sessions`

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `call_id` | TEXT | Unique call identifier |
| `man_user_id` | UUID | Caller user ID |
| `woman_user_id` | UUID | Receiver user ID |
| `status` | TEXT | ringing, connecting, active, ended |
| `rate_per_minute` | NUMERIC | Cost per minute |
| `total_minutes` | NUMERIC | Call duration |
| `total_earned` | NUMERIC | Total earnings |
| `started_at` | TIMESTAMP | Call start time |
| `ended_at` | TIMESTAMP | Call end time |
| `end_reason` | TEXT | Why call ended |
| `created_at` | TIMESTAMP | Record creation time |

**Note:** Records are automatically deleted after 5 minutes.

---

## React Components

### `useP2PCall` Hook

Manages the full WebRTC lifecycle: creating offers, handling answers, exchanging ICE candidates, and managing media streams.

### Key Components

| Component | Purpose |
|-----------|---------|
| `P2PVideoCallModal` | Main video call UI |
| `VideoCallButton` | Initiate video calls |
| `DirectVideoCallButton` | Direct call to specific user |
| `IncomingVideoCallWindow` | Incoming call notification |
| `DraggableVideoCallWindow` | Minimized call window |

---

## Cleanup

### Edge Function: `video-cleanup`

**Endpoint:** `POST /functions/v1/video-cleanup`

Automatically called by cron job every minute. Deletes:
- Video call sessions older than 5 minutes
- Ends stale active/ringing sessions

---

## Troubleshooting

### WebRTC Connection Failed

1. Check browser console for ICE errors
2. Verify coturn TURN server is running and accessible
3. Check firewall allows TURN ports (3478/TCP+UDP, 443/TCP)
4. Ensure HTTPS in production (WebRTC requires secure context)

### No Video/Audio

1. Check browser permissions for camera/microphone
2. Verify local stream is created (check console logs)
3. Test camera in browser settings

### Cleanup Not Working

1. Check cron job is scheduled:
   ```sql
   SELECT * FROM cron.job;
   ```
2. Check edge function logs in Supabase dashboard

---

## Security

1. **No Recording:** No media server, no DVR — pure P2P
2. **Auto-Cleanup:** Session data deleted after 5 minutes
3. **Signaling Security:** Supabase RLS on video_call_sessions
4. **HTTPS:** Required for WebRTC in production
