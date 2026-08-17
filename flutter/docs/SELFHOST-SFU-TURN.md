# Self-hosting open-source media stack

You said the SFU + TURN run on your own VPS. This is the minimal,
fully open-source layout. No proprietary services anywhere.

```
┌─────────────────────────────────────────────────────────┐
│  Your VPS  (Ubuntu 22.04 LTS, 4 vCPU / 8 GB RAM min)    │
│                                                          │
│  ┌───────────────┐    ┌───────────────────────────┐    │
│  │ coturn        │    │ livekit-server (Go)       │    │
│  │ TURN/STUN     │◄───┤ Apache 2.0  SFU           │    │
│  │ ports 3478,   │    │ ports 7880 (WS), 7881-7882│    │
│  │ 5349, 49160-  │    │ (TCP/UDP RTP)             │    │
│  │ 49200/UDP     │    └───────────────────────────┘    │
│  └───────────────┘                                       │
│                                                          │
│  Caddy / nginx → TLS termination                         │
└─────────────────────────────────────────────────────────┘
            ▲                    ▲
            │                    │
       1:1 P2P fallback     Group calls
       (flutter_webrtc)     (livekit_client)
```

## 1. Install via docker compose

`/opt/media/docker-compose.yml`:

```yaml
services:
  coturn:
    image: coturn/coturn:4.6
    network_mode: host
    restart: unless-stopped
    volumes:
      - ./turnserver.conf:/etc/turnserver.conf:ro
    command: ["-c", "/etc/turnserver.conf"]

  livekit:
    image: livekit/livekit-server:v1.7
    network_mode: host
    restart: unless-stopped
    command: --config /etc/livekit.yaml
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml:ro
```

## 2. coturn config (`turnserver.conf`)

```
listening-port=3478
tls-listening-port=5349
min-port=49160
max-port=49200
fingerprint
lt-cred-mech
realm=turn.yourdomain.com
user=meowmeow:STRONG_PASSWORD_HERE
no-multicast-peers
no-cli
cert=/etc/letsencrypt/live/turn.yourdomain.com/fullchain.pem
pkey=/etc/letsencrypt/live/turn.yourdomain.com/privkey.pem
```

## 3. LiveKit config (`livekit.yaml`)

```yaml
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
keys:
  YOUR_API_KEY: YOUR_API_SECRET   # 32+ char secret
turn:
  enabled: true
  domain: turn.yourdomain.com
  tls_port: 5349
  udp_port: 3478
```

Generate keys:
```bash
docker run --rm livekit/livekit-server generate-keys
```

## 4. Lovable secrets to add

After your server is running, add these as Lovable runtime secrets so the
`livekit-token` edge function can mint JWTs:

| Secret | Value |
|---|---|
| `LIVEKIT_API_KEY` | The key from step 3 |
| `LIVEKIT_API_SECRET` | The secret from step 3 |
| `LIVEKIT_WS_URL` | `wss://livekit.yourdomain.com` |

## 5. Flutter build-time env

Pass coturn creds into the app for 1:1 calls:

```bash
flutter run \
  --dart-define=TURN_URL=turn:turn.yourdomain.com:3478 \
  --dart-define=TURN_USERNAME=meowmeow \
  --dart-define=TURN_CREDENTIAL=STRONG_PASSWORD_HERE
```

## 6. Firewall (ufw)

```bash
ufw allow 3478/udp
ufw allow 3478/tcp
ufw allow 5349/tcp        # TURN/TLS
ufw allow 49160:49200/udp # coturn relay
ufw allow 7880/tcp        # LiveKit signaling (front by Caddy w/ TLS)
ufw allow 50000:60000/udp # LiveKit RTP
```

## 7. Why this stack

| Need | Software | License | Why |
|---|---|---|---|
| 1:1 audio/video | `flutter_webrtc` | BSD | Pure Google libwebrtc, no SFU needed |
| Group rooms | `livekit-server` + `livekit_client` | Apache 2.0 | Single Go binary, mature, simulcast/SVC |
| NAT traversal | `coturn` | BSD | The reference TURN server |
| Signaling | Supabase realtime | OSS Postgres+Elixir | Already in stack |

Zero SaaS lock-in. Zero per-minute SFU fees. You own the recording too
(LiveKit egress can dump rooms to S3 or local disk).
