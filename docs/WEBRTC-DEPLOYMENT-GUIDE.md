# WebRTC Complete Deployment Guide — P2P & SFU
# Meow Meow Platform — End-to-End Infrastructure Documentation

> **Last Updated:** March 2026  
> **Target OS:** Ubuntu 22.04 / 24.04 LTS  
> **Audience:** DevOps engineers, system administrators, backend developers

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Server Requirements](#2-server-requirements)
3. [Recommended Hosting Providers](#3-recommended-hosting-providers)
4. [P2P WebRTC — TURN/STUN Server Setup](#4-p2p-webrtc--turnstun-server-setup)
5. [SFU WebRTC — SRS Server Setup](#5-sfu-webrtc--srs-server-setup)
6. [Nginx Reverse Proxy & SSL](#6-nginx-reverse-proxy--ssl)
7. [Systemd Service Configuration](#7-systemd-service-configuration)
8. [Firewall Configuration](#8-firewall-configuration)
9. [Server Management Scripts](#9-server-management-scripts)
10. [Monitoring & Logging](#10-monitoring--logging)
11. [Supabase Edge Function Configuration](#11-supabase-edge-function-configuration)
12. [Security Hardening](#12-security-hardening)
13. [Scaling & High Availability](#13-scaling--high-availability)
14. [Troubleshooting](#14-troubleshooting)
15. [Full Requirements](#15-full-requirements)

---

## 1. Architecture Overview

The Meow Meow platform uses **two distinct WebRTC strategies**:

### 1.1 P2P WebRTC (1-on-1 Video Calls)

```
┌──────────────┐                              ┌──────────────┐
│   User A     │ ←──── Direct WebRTC ────────►│   User B     │
│  (Caller)    │       (Audio + Video)        │  (Receiver)  │
└──────┬───────┘                              └──────┬───────┘
       │                                             │
       │  ICE Candidates                             │  ICE Candidates
       │  (NAT Traversal)                            │  (NAT Traversal)
       ▼                                             ▼
┌──────────────────────────────────────────────────────────┐
│                    STUN/TURN Server                      │
│               (coturn on Ubuntu)                         │
│                                                          │
│  • STUN: Discovers public IP (UDP 3478)                 │
│  • TURN: Relays media when direct fails (TCP/UDP 3478)  │
│  • TLS TURN: Encrypted relay (TCP 5349)                 │
└──────────────────────────────────────────────────────────┘
       │
       │  Signaling (SDP Offer/Answer + ICE)
       ▼
┌──────────────────────────────────────────────────────────┐
│              Supabase Realtime Channel                   │
│         (WebSocket-based signaling server)               │
│                                                          │
│  • Broadcasts SDP offers/answers between peers           │
│  • Exchanges ICE candidates                              │
│  • No media flows through Supabase                       │
└──────────────────────────────────────────────────────────┘
```

**When is P2P used?**
- All 1-on-1 private video calls between men and women
- Direct peer connection — lowest latency, no server media relay
- TURN fallback ensures connectivity behind strict NAT/firewalls

### 1.2 SFU WebRTC (Private Group Calls)

```
┌──────────────┐     Publish (WebRTC)     ┌──────────────┐
│   Host       │ ──────────────────────►  │  SRS Server  │
│  (Woman)     │                          │   (SFU)      │
└──────────────┘                          └──────┬───────┘
                                                 │
                              Subscribe (WebRTC) │
                    ┌────────────────────────────┼────────────────────────────┐
                    ▼                            ▼                           ▼
             ┌──────────────┐           ┌──────────────┐           ┌──────────────┐
             │  Viewer 1    │           │  Viewer 2    │           │  Viewer N    │
             │  (Man)       │           │  (Man)       │           │  (Man)       │
             └──────────────┘           └──────────────┘           └──────────────┘

Signaling: Supabase Edge Function → SRS HTTP API (port 1985)
Media:     SRS WebRTC (UDP port 8000)
```

**When is SFU used?**
- Private group calls (flower rooms: Rose, Lily, Jasmine, etc.)
- One host publishes, up to 100 viewers subscribe
- SRS relays media — host uploads once, server fans out to all viewers

### 1.3 Signaling Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        SIGNALING FLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  P2P (1-on-1):                                                 │
│  User A ──► Supabase Realtime Channel ──► User B               │
│       (SDP Offer)              (SDP Answer)                     │
│       (ICE Candidates)         (ICE Candidates)                │
│                                                                 │
│  SFU (Group):                                                  │
│  Host ──► Supabase Edge Function ──► SRS HTTP API ──► Viewers  │
│       (Publish SDP)          (SRS Answer SDP)                   │
│       Viewers ──► Edge Function ──► SRS ──► Subscribe           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Server Requirements

### 2.1 TURN Server (for P2P calls)

| Resource | Minimum | Recommended (500 concurrent calls) | High Scale (2000+ calls) |
|----------|---------|-------------------------------------|--------------------------|
| **CPU** | 2 vCPU | 4 vCPU | 8 vCPU |
| **RAM** | 2 GB | 4 GB | 8 GB |
| **Storage** | 20 GB SSD | 40 GB SSD | 80 GB SSD |
| **Network** | 100 Mbps | 1 Gbps | 10 Gbps |
| **Bandwidth** | 1 TB/month | 5 TB/month | 20 TB/month |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

> **Note:** TURN servers relay media only when direct P2P fails (~20-30% of calls).
> Each relayed call consumes ~1-2 Mbps bidirectional bandwidth.

### 2.2 SRS Server (for Group calls)

| Resource | Minimum | Recommended (50 groups × 50 viewers) | High Scale (100 groups × 100 viewers) |
|----------|---------|---------------------------------------|---------------------------------------|
| **CPU** | 2 vCPU | 4 vCPU | 8+ vCPU |
| **RAM** | 2 GB | 4 GB | 8+ GB |
| **Storage** | 20 GB SSD | 40 GB SSD | 80 GB SSD |
| **Network** | 100 Mbps | 1 Gbps | 10 Gbps |
| **Bandwidth** | 2 TB/month | 10 TB/month | 50 TB/month |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

> **Note:** Each group stream fan-out: 1 Mbps × N viewers.
> 10 groups × 100 viewers = ~1 Gbps peak bandwidth.

### 2.3 Port Requirements Summary

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 22 | TCP | SSH | Server management |
| 80 | TCP | Nginx | HTTP → HTTPS redirect |
| 443 | TCP | Nginx | HTTPS/WSS reverse proxy |
| 3478 | TCP+UDP | coturn | STUN/TURN primary |
| 5349 | TCP | coturn | TURN over TLS |
| 1935 | TCP | SRS | RTMP (optional) |
| 1985 | TCP | SRS | HTTP API |
| 8080 | TCP | SRS | HTTP server / WebRTC signaling |
| 8000 | UDP | SRS | WebRTC media transport |
| 49152-65535 | UDP | coturn | TURN relay port range |

---

## 3. Recommended Hosting Providers

### 3.1 Best Providers Comparison

| Provider | Plan | Monthly Cost | Best For | Locations |
|----------|------|-------------|----------|-----------|
| **DigitalOcean** | Premium AMD 4vCPU/8GB | $48/mo | Best value, simple | Bangalore, Singapore |
| **AWS EC2** | c5.xlarge | ~$120/mo | Enterprise, auto-scaling | Mumbai (ap-south-1) |
| **Google Cloud** | e2-standard-4 | ~$100/mo | Integration with GCP | Mumbai |
| **Hetzner** | CPX31 | €15/mo | Budget-friendly, EU | Helsinki, US |
| **Vultr** | High Freq 4vCPU/8GB | $48/mo | Low latency, global | Mumbai, Delhi |
| **Linode (Akamai)** | Dedicated 4GB | $36/mo | Reliable, good network | Mumbai |
| **OVHcloud** | B2-15 | ~€13/mo | Cheapest EU option | Global |

### 3.2 Recommended Setup (India-focused)

For an India-focused application, deploy servers close to users:

```
┌─────────────────────────────────────────────────────┐
│                PRODUCTION SETUP                      │
├─────────────────────────────────────────────────────┤
│                                                      │
│  Server 1: TURN Server                              │
│  ├── Provider: DigitalOcean / Vultr                 │
│  ├── Location: Mumbai / Bangalore                   │
│  ├── Specs: 4 vCPU, 8 GB RAM                       │
│  ├── Software: coturn                               │
│  └── Cost: ~$48/month                               │
│                                                      │
│  Server 2: SRS Media Server                         │
│  ├── Provider: DigitalOcean / Vultr                 │
│  ├── Location: Mumbai / Bangalore                   │
│  ├── Specs: 4 vCPU, 8 GB RAM                       │
│  ├── Software: SRS 5.x (Docker)                    │
│  └── Cost: ~$48/month                               │
│                                                      │
│  Total: ~$96/month for both servers                 │
│                                                      │
│  Alternative: Single Server (Small Scale)           │
│  ├── Run both coturn + SRS on one server            │
│  ├── Specs: 4 vCPU, 8 GB RAM minimum               │
│  └── Cost: ~$48/month                               │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 3.3 Budget Option (Single Server)

For small-to-medium scale (< 200 concurrent users):

| Provider | Plan | Cost | Specs |
|----------|------|------|-------|
| **Hetzner CPX31** | Cloud VPS | €15.90/mo | 4 vCPU, 8GB RAM, 160GB SSD |
| **Vultr High Freq** | Cloud Compute | $24/mo | 2 vCPU, 4GB RAM, 128GB NVMe |

---

## 4. P2P WebRTC — TURN/STUN Server Setup

### 4.1 Why You Need Your Own TURN Server

The current codebase uses public TURN servers (`openrelay.metered.ca`), which are:
- ❌ Rate-limited and unreliable for production
- ❌ Shared with all users globally (slow)
- ❌ May go offline without notice

Your own coturn server provides:
- ✅ Dedicated resources for your users
- ✅ Low latency (deployed in same region)
- ✅ Full control over credentials and security
- ✅ Reliable NAT traversal for all network conditions

### 4.2 Install coturn on Ubuntu

```bash
#!/bin/bash
# ============================================================
# Script: install-coturn.sh
# Purpose: Install and configure coturn TURN/STUN server
# OS: Ubuntu 22.04 / 24.04 LTS
# Run as: root or with sudo
# ============================================================

# Step 1: Update system packages to latest versions
# This ensures all security patches are applied
sudo apt update && sudo apt upgrade -y

# Step 2: Install coturn package
# coturn is the most widely used open-source TURN server
sudo apt install -y coturn

# Step 3: Enable coturn to start as a system service
# By default, coturn is disabled. We need to enable it.
# Edit /etc/default/coturn and set TURNSERVER_ENABLED=1
sudo sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

# Step 4: Generate a strong secret for TURN authentication
# This secret is used for HMAC-based credential generation
TURN_SECRET=$(openssl rand -hex 32)
echo "Generated TURN Secret: $TURN_SECRET"
echo "Save this secret! You'll need it for your application."

# Step 5: Detect the server's public IP address
# This is needed so clients know where to send media
SERVER_IP=$(curl -s ifconfig.me)
echo "Detected Server IP: $SERVER_IP"
```

### 4.3 Configure coturn

```bash
# Step 6: Create the coturn configuration file
# This replaces the default configuration with production settings
sudo tee /etc/turnserver.conf > /dev/null << 'TURNCONF'
# ============================================================
# coturn Configuration File
# /etc/turnserver.conf
# ============================================================

# -------------------- NETWORK SETTINGS --------------------

# Primary listening port for STUN/TURN
# STUN: Helps clients discover their public IP
# TURN: Relays media when direct P2P connection fails
listening-port=3478

# TLS listening port for TURN over TLS
# Used when clients are behind very strict firewalls
# that only allow port 443/5349 traffic
tls-listening-port=5349

# External IP address of this server
# Replace YOUR_SERVER_IP with your actual public IP
# This tells clients where to route media traffic
external-ip=YOUR_SERVER_IP

# Relay port range for media streams
# Each TURN allocation uses a port from this range
# 1000 ports = ~500 concurrent relayed calls
min-port=49152
max-port=65535

# -------------------- AUTHENTICATION --------------------

# Realm: Your domain name (used in authentication)
# Replace with your actual domain
realm=turn.yourdomain.com

# Use long-term credential mechanism
# More secure than short-term credentials
lt-cred-mech

# Static authentication secret
# Used to generate time-limited TURN credentials
# Replace YOUR_TURN_SECRET with the generated secret
use-auth-secret
static-auth-secret=YOUR_TURN_SECRET

# -------------------- SECURITY --------------------

# Fingerprinting: Adds message integrity checks
# Helps prevent TURN message tampering
fingerprint

# Disable multicast peers (security best practice)
# Prevents relay to multicast addresses
no-multicast-peers

# Deny peers from private/internal IP ranges
# Prevents using TURN to access internal networks
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255

# -------------------- PERFORMANCE --------------------

# Total memory quota for relay (in bytes)
# 128MB = good for ~500 concurrent relayed sessions
total-quota=128000000

# Per-session bandwidth limit (bytes/sec)
# 300000 = ~2.4 Mbps per session (enough for 720p video)
max-bps=300000

# Maximum number of simultaneous allocations
# Each call = 2 allocations (1 per participant)
# 2000 allocations = ~1000 concurrent calls
max-allocations=2000

# -------------------- LOGGING --------------------

# Log file location
log-file=/var/log/turnserver/turnserver.log

# Don't log to syslog (use file instead for easier parsing)
no-stdout-log

# Enable verbose logging for debugging (disable in production)
# Uncomment the next line for debug mode:
# verbose

# -------------------- TLS/SSL (Optional) --------------------
# Uncomment and configure if you have SSL certificates

# cert=/etc/letsencrypt/live/turn.yourdomain.com/fullchain.pem
# pkey=/etc/letsencrypt/live/turn.yourdomain.com/privkey.pem
# cipher-list="ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
# no-tlsv1
# no-tlsv1_1

TURNCONF
```

### 4.4 Apply Configuration

```bash
# Step 7: Replace placeholder values with actual server details
# Replace YOUR_SERVER_IP with detected public IP
sudo sed -i "s/YOUR_SERVER_IP/$SERVER_IP/g" /etc/turnserver.conf

# Replace YOUR_TURN_SECRET with generated secret
sudo sed -i "s/YOUR_TURN_SECRET/$TURN_SECRET/g" /etc/turnserver.conf

# Step 8: Create log directory
sudo mkdir -p /var/log/turnserver
sudo chown turnserver:turnserver /var/log/turnserver

# Step 9: Start coturn service
sudo systemctl restart coturn

# Step 10: Enable coturn to start on boot
sudo systemctl enable coturn

# Step 11: Verify coturn is running
sudo systemctl status coturn

# Step 12: Test STUN connectivity
# Install stun-client for testing
sudo apt install -y stun-client
stun $SERVER_IP
```

### 4.5 Update Application ICE Servers

After deploying your own TURN server, update the ICE configuration in the codebase:

**File: `src/hooks/useP2PCall.ts`** — Replace the ICE_SERVERS config:

```typescript
const ICE_SERVERS: RTCConfiguration = {
  iceServers: [
    // Google's free STUN servers (for NAT discovery only, no relay)
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    
    // Your own STUN server (faster, in your region)
    { urls: 'stun:turn.yourdomain.com:3478' },
    
    // Your own TURN server (for relay when P2P fails)
    // Credentials are generated using the shared secret
    {
      urls: [
        'turn:turn.yourdomain.com:3478',          // UDP relay
        'turn:turn.yourdomain.com:3478?transport=tcp', // TCP relay (fallback)
        'turns:turn.yourdomain.com:5349',          // TLS relay (strict firewalls)
      ],
      username: 'GENERATED_USERNAME',  // Time-based, generated server-side
      credential: 'GENERATED_CREDENTIAL', // HMAC of username + secret
    },
  ]
};
```

### 4.6 Generate Time-Limited TURN Credentials

For security, TURN credentials should be time-limited. Create a Supabase Edge Function:

```typescript
// supabase/functions/get-turn-credentials/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createHmac } from "node:crypto";

serve(async (req) => {
  // TURN secret from environment (same as coturn's static-auth-secret)
  const secret = Deno.env.get('TURN_SECRET') || '';
  
  // Generate credentials valid for 24 hours
  const ttl = 86400; // 24 hours in seconds
  const timestamp = Math.floor(Date.now() / 1000) + ttl;
  const username = `${timestamp}:meowmeow`;
  
  // HMAC-SHA1 of username using the shared secret
  const hmac = createHmac('sha1', secret);
  hmac.update(username);
  const credential = hmac.digest('base64');
  
  return new Response(JSON.stringify({
    urls: [
      'turn:turn.yourdomain.com:3478',
      'turn:turn.yourdomain.com:3478?transport=tcp',
    ],
    username,
    credential,
    ttl,
  }), { headers: { 'Content-Type': 'application/json' } });
});
```

---

## 5. SFU WebRTC — SRS Server Setup

### 5.1 Install Docker

```bash
#!/bin/bash
# ============================================================
# Script: install-docker.sh
# Purpose: Install Docker CE on Ubuntu for SRS deployment
# OS: Ubuntu 22.04 / 24.04 LTS
# Run as: root or with sudo
# ============================================================

# Step 1: Remove old Docker versions (if any)
# This ensures a clean installation
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null

# Step 2: Install prerequisites
# These packages allow apt to use HTTPS repositories
sudo apt update
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Step 3: Add Docker's official GPG key
# This verifies the integrity of Docker packages
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Step 4: Add Docker's apt repository
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 5: Install Docker CE (Community Edition)
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Step 6: Start Docker and enable on boot
sudo systemctl start docker
sudo systemctl enable docker

# Step 7: Add current user to docker group
# This allows running docker without sudo
sudo usermod -aG docker $USER

# Step 8: Install Docker Compose (standalone)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Step 9: Verify installation
docker --version
docker-compose --version

echo "Docker installed successfully!"
echo "Log out and back in for group changes to take effect."
```

### 5.2 Deploy SRS with Docker Compose

```bash
# Step 1: Create project directory
sudo mkdir -p /opt/srs
cd /opt/srs
```

### 5.3 SRS Configuration File

```bash
# Step 2: Create SRS configuration
sudo tee /opt/srs/conf/srs.conf > /dev/null << 'SRSCONF'
# ============================================================
# SRS (Simple Realtime Server) Configuration
# /opt/srs/conf/srs.conf
# ============================================================

# -------------------- CORE SETTINGS --------------------

# Port for RTMP streaming (not used in our setup, but enabled)
listen              1935;

# Maximum simultaneous connections
# Each viewer = 1 connection. 100 groups × 100 viewers = 10,000
max_connections     10000;

# Run in foreground (required for Docker)
daemon              off;

# Log to console (Docker captures stdout/stderr)
srs_log_tank        console;

# Log level: verbose, info, trace, warn, error
# Use 'warn' in production to reduce log noise
srs_log_level       warn;

# -------------------- HTTP API --------------------
# Provides management API for querying streams, clients, etc.

http_api {
    # Enable the HTTP API
    enabled         on;
    
    # Listen on port 1985 (internal)
    listen          1985;
    
    # Allow cross-origin requests (required for browser access)
    crossdomain     on;
}

# -------------------- HTTP SERVER --------------------
# Serves static files and WebRTC signaling

http_server {
    # Enable HTTP server
    enabled         on;
    
    # Listen on port 8080
    listen          8080;
    
    # Static file directory
    dir             ./objs/nginx/html;
}

# -------------------- WebRTC (RTC) SERVER --------------------
# Handles WebRTC connections for publish/subscribe

rtc_server {
    # Enable WebRTC server
    enabled         on;
    
    # UDP port for WebRTC media (audio/video data)
    listen          8000;
    
    # Candidate IP: use '*' to auto-detect
    # In production, set this to your server's public IP
    # candidate       YOUR_SERVER_IP;
    candidate       *;
}

# -------------------- VIRTUAL HOST CONFIGURATION --------------------
# Default virtual host handles all streams

vhost __defaultVhost__ {
    
    # WebRTC settings
    rtc {
        # Enable WebRTC for this vhost
        enabled     on;
        
        # Allow converting RTMP input to WebRTC output
        rtmp_to_rtc on;
        
        # Allow converting WebRTC input to RTMP output
        rtc_to_rtmp on;
    }
    
    # HTTP-FLV remux (for HTTP-FLV playback, optional)
    http_remux {
        enabled     on;
        mount       [vhost]/[app]/[stream].flv;
    }
    
    # --------- PRIVACY: NO RECORDING ----------
    # DVR (recording) is intentionally NOT configured
    # All streams are ephemeral — no video/audio is stored
    # This is a platform policy requirement
}
SRSCONF
```

### 5.4 Docker Compose File

```bash
# Step 3: Create Docker Compose configuration
sudo tee /opt/srs/docker-compose.yml > /dev/null << 'COMPOSE'
# ============================================================
# Docker Compose for SRS Media Server
# /opt/srs/docker-compose.yml
# ============================================================

version: '3.8'

services:
  srs:
    # SRS version 5 — latest stable with full WebRTC support
    image: ossrs/srs:5
    
    # Container name for easy management
    container_name: srs-server
    
    # Always restart unless explicitly stopped
    # Ensures server recovers from crashes automatically
    restart: unless-stopped
    
    # Port mappings (host:container)
    ports:
      # RTMP: Used for RTMP streaming (optional)
      - "1935:1935"
      
      # HTTP API: Management API for querying streams/clients
      - "1985:1985"
      
      # HTTP Server: WebRTC signaling + static file serving
      - "8080:8080"
      
      # WebRTC UDP: Carries actual audio/video data
      - "8000:8000/udp"
    
    # Mount custom configuration
    volumes:
      # Map our custom SRS config into the container
      - ./conf/srs.conf:/usr/local/srs/conf/srs.conf
      
      # Map logs directory for persistence
      - ./logs:/usr/local/srs/objs
    
    # Resource limits (prevent runaway memory/CPU usage)
    deploy:
      resources:
        limits:
          cpus: '4'        # Max 4 CPU cores
          memory: 4G       # Max 4GB RAM
        reservations:
          cpus: '1'        # Guaranteed 1 CPU core
          memory: 512M     # Guaranteed 512MB RAM
    
    # Health check: Verify SRS API is responding
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:1985/api/v1/versions"]
      interval: 30s        # Check every 30 seconds
      timeout: 10s         # Wait max 10 seconds for response
      retries: 3           # Mark unhealthy after 3 failures
      start_period: 10s    # Wait 10 seconds before first check
    
    # Logging configuration
    logging:
      driver: "json-file"
      options:
        max-size: "50m"    # Max 50MB per log file
        max-file: "5"      # Keep last 5 log files (250MB total)
COMPOSE
```

### 5.5 Start SRS

```bash
# Step 4: Create required directories
sudo mkdir -p /opt/srs/conf /opt/srs/logs

# Step 5: Start SRS using Docker Compose
cd /opt/srs
sudo docker-compose up -d

# Step 6: Verify SRS is running
# Check container status
sudo docker ps | grep srs-server

# Check SRS API is responding
curl -s http://localhost:1985/api/v1/versions | python3 -m json.tool

# Expected output:
# {
#     "code": 0,
#     "server": "...",
#     "data": {
#         "major": 5,
#         "minor": 0,
#         ...
#     }
# }

# Step 7: Check active streams (should be empty initially)
curl -s http://localhost:1985/api/v1/streams/ | python3 -m json.tool
```

---

## 6. Nginx Reverse Proxy & SSL

### 6.1 Install Nginx & Certbot

```bash
#!/bin/bash
# ============================================================
# Script: install-nginx-ssl.sh
# Purpose: Install Nginx reverse proxy with Let's Encrypt SSL
# OS: Ubuntu 22.04 / 24.04 LTS
# ============================================================

# Step 1: Install Nginx
sudo apt update
sudo apt install -y nginx

# Step 2: Install Certbot for free SSL certificates
sudo apt install -y certbot python3-certbot-nginx

# Step 3: Obtain SSL certificate
# Replace yourdomain.com with your actual domain
# Make sure DNS A record points to this server's IP first!
sudo certbot --nginx -d turn.yourdomain.com -d srs.yourdomain.com

# Step 4: Set up automatic certificate renewal
# Certbot adds a cron job automatically, but verify:
sudo certbot renew --dry-run
```

### 6.2 Nginx Configuration for SRS

```bash
sudo tee /etc/nginx/sites-available/srs > /dev/null << 'NGINX'
# ============================================================
# Nginx Reverse Proxy for SRS Media Server
# /etc/nginx/sites-available/srs
# ============================================================

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name srs.yourdomain.com;
    
    # Redirect all HTTP requests to HTTPS
    return 301 https://$host$request_uri;
}

# HTTPS server for SRS API
server {
    listen 443 ssl http2;
    server_name srs.yourdomain.com;
    
    # SSL certificates (managed by Certbot)
    ssl_certificate /etc/letsencrypt/live/srs.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/srs.yourdomain.com/privkey.pem;
    
    # Modern SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Proxy to SRS HTTP API (port 1985)
    location /api/ {
        proxy_pass http://127.0.0.1:1985/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Proxy to SRS WebRTC signaling (port 1985)
    location /rtc/ {
        proxy_pass http://127.0.0.1:1985/rtc/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebRTC signaling requires larger body sizes for SDP
        client_max_body_size 10m;
    }
    
    # Proxy to SRS HTTP server (port 8080)
    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX

# Enable the site
sudo ln -sf /etc/nginx/sites-available/srs /etc/nginx/sites-enabled/srs

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

---

## 7. Systemd Service Configuration

### 7.1 coturn Service (Auto-managed by apt)

coturn is already managed by systemd after installation:

```bash
# Check status
sudo systemctl status coturn

# Start/Stop/Restart
sudo systemctl start coturn
sudo systemctl stop coturn
sudo systemctl restart coturn

# View logs
sudo journalctl -u coturn -f
```

### 7.2 SRS Systemd Service

```bash
# Create systemd service for SRS Docker container
sudo tee /etc/systemd/system/srs.service > /dev/null << 'SERVICE'
# ============================================================
# Systemd Service: SRS Media Server
# /etc/systemd/system/srs.service
#
# This service manages the SRS Docker container.
# It ensures SRS starts on boot and restarts on failure.
# ============================================================

[Unit]
# Description shown in systemctl status
Description=SRS WebRTC Media Server (Docker)

# Start after Docker is ready
After=docker.service

# Requires Docker to be running
Requires=docker.service

[Service]
# Type: simple means systemd tracks the main process
Type=simple

# Always restart on failure (after 10 second delay)
Restart=always
RestartSec=10

# Working directory for docker-compose
WorkingDirectory=/opt/srs

# Before starting: stop and remove any existing container
# The '-' prefix means don't fail if container doesn't exist
ExecStartPre=-/usr/bin/docker-compose down

# Start SRS using docker-compose
ExecStart=/usr/bin/docker-compose up

# Stop SRS gracefully using docker-compose
ExecStop=/usr/bin/docker-compose down

# Give 30 seconds for graceful shutdown before force-killing
TimeoutStopSec=30

[Install]
# Start this service when the system reaches multi-user mode
WantedBy=multi-user.target
SERVICE

# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable SRS to start on boot
sudo systemctl enable srs

# Start SRS service
sudo systemctl start srs

# Check status
sudo systemctl status srs
```

---

## 8. Firewall Configuration

```bash
#!/bin/bash
# ============================================================
# Script: configure-firewall.sh
# Purpose: Configure UFW firewall for WebRTC servers
# OS: Ubuntu 22.04 / 24.04 LTS
# ============================================================

# Step 1: Enable UFW (if not already enabled)
sudo ufw --force enable

# Step 2: Allow SSH (CRITICAL — don't lock yourself out!)
sudo ufw allow 22/tcp comment 'SSH access'

# Step 3: Allow HTTP and HTTPS (for Nginx)
sudo ufw allow 80/tcp comment 'HTTP - redirect to HTTPS'
sudo ufw allow 443/tcp comment 'HTTPS - Nginx reverse proxy'

# Step 4: Allow coturn TURN/STUN ports
sudo ufw allow 3478/tcp comment 'TURN/STUN TCP'
sudo ufw allow 3478/udp comment 'TURN/STUN UDP'
sudo ufw allow 5349/tcp comment 'TURN over TLS'

# Step 5: Allow coturn relay port range
# This range is used for relaying media between peers
sudo ufw allow 49152:65535/udp comment 'TURN relay ports'

# Step 6: Allow SRS ports
sudo ufw allow 1935/tcp comment 'SRS RTMP'
sudo ufw allow 1985/tcp comment 'SRS HTTP API'
sudo ufw allow 8080/tcp comment 'SRS HTTP/WebRTC signaling'
sudo ufw allow 8000/udp comment 'SRS WebRTC media'

# Step 7: Set default policies
# Deny all incoming traffic except what we explicitly allowed
sudo ufw default deny incoming

# Allow all outgoing traffic
sudo ufw default allow outgoing

# Step 8: Verify firewall rules
sudo ufw status verbose

echo "Firewall configured successfully!"
```

---

## 9. Server Management Scripts

All management scripts are located in `scripts/unix/` directory.

### 9.1 Scripts Created

See the following files (created alongside this document):
- `scripts/unix/webrtc-start.sh` — Start all WebRTC services
- `scripts/unix/webrtc-stop.sh` — Stop all WebRTC services  
- `scripts/unix/webrtc-restart.sh` — Restart all WebRTC services
- `scripts/unix/webrtc-status.sh` — Check status of all services
- `scripts/unix/webrtc-monitor.sh` — Real-time monitoring dashboard
- `scripts/unix/webrtc-install.sh` — Full installation script

---

## 10. Monitoring & Logging

### 10.1 Log Locations

| Service | Log Location | Command |
|---------|-------------|---------|
| coturn | `/var/log/turnserver/turnserver.log` | `tail -f /var/log/turnserver/turnserver.log` |
| SRS | `/opt/srs/logs/` | `docker logs -f srs-server` |
| Nginx | `/var/log/nginx/` | `tail -f /var/log/nginx/error.log` |
| Systemd | journald | `journalctl -u srs -f` |

### 10.2 Health Check Endpoints

```bash
# coturn: Check if STUN is responding
stun YOUR_SERVER_IP 3478

# SRS: Check API health
curl -s http://localhost:1985/api/v1/versions

# SRS: List active streams
curl -s http://localhost:1985/api/v1/streams/

# SRS: List connected clients
curl -s http://localhost:1985/api/v1/clients/

# SRS: Server resource usage
curl -s http://localhost:1985/api/v1/summaries
```

### 10.3 Prometheus Metrics (Optional)

SRS exports metrics at `http://localhost:1985/api/v1/summaries` which can be scraped by Prometheus for Grafana dashboards.

---

## 11. Supabase Edge Function Configuration

### 11.1 Required Secrets

After deploying your servers, configure these secrets in Supabase:

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `SRS_API_URL` | `https://srs.yourdomain.com` | SRS HTTP API endpoint |
| `SRS_RTC_URL` | `https://srs.yourdomain.com/rtc/v1` | SRS WebRTC signaling |
| `TURN_SECRET` | Your coturn static-auth-secret | Generate TURN credentials |

### 11.2 How to Add Secrets

1. Go to Supabase Dashboard → Project Settings → Edge Functions
2. Add each secret key-value pair
3. Redeploy edge functions to pick up new secrets

---

## 12. Security Hardening

### 12.1 SSH Security

```bash
# Disable root login and password authentication
sudo tee -a /etc/ssh/sshd_config.d/hardened.conf > /dev/null << 'SSH'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
SSH

sudo systemctl restart sshd
```

### 12.2 Fail2Ban (Brute Force Protection)

```bash
sudo apt install -y fail2ban

sudo tee /etc/fail2ban/jail.local > /dev/null << 'F2B'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
F2B

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 12.3 Automatic Security Updates

```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## 13. Scaling & High Availability

### 13.1 Horizontal Scaling Strategy

```
                    ┌──── TURN Server 1 (Mumbai)
                    │
Load Balancer ──────┼──── TURN Server 2 (Bangalore)
(DNS Round Robin)   │
                    └──── TURN Server 3 (Delhi)

                    ┌──── SRS Server 1 (Groups 1-5)
                    │
Edge Function ──────┼──── SRS Server 2 (Groups 6-10)
(Route by group)    │
                    └──── SRS Server 3 (Overflow)
```

### 13.2 When to Scale

| Metric | Threshold | Action |
|--------|-----------|--------|
| CPU usage | > 80% sustained | Add another server |
| Concurrent relayed calls | > 500 per TURN | Add TURN server |
| SRS bandwidth | > 800 Mbps | Add SRS instance |
| Viewer count per group | > 100 | Consider CDN |

---

## 14. Troubleshooting

### 14.1 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Black video screen | Browser autoplay policy | Mute video first, unmute after user gesture |
| ICE connection failed | Firewall blocking UDP | Open ports 3478, 8000, 49152-65535/udp |
| TURN auth failed | Expired credentials | Regenerate time-limited credentials |
| SRS publish failed | Container not running | `docker restart srs-server` |
| High latency | Server too far from users | Deploy in Mumbai/Bangalore region |
| No audio | Echo cancellation conflict | Check `autoGainControl` and `noiseSuppression` settings |

### 14.2 Debug Commands

```bash
# Check if ports are open
sudo ss -tlnp | grep -E '3478|1985|8080|8000'

# Test TURN connectivity from another machine
turnutils_uclient -T -u test -w test YOUR_SERVER_IP

# Check SRS stream quality
curl -s http://localhost:1985/api/v1/streams/ | python3 -m json.tool

# Check Docker resource usage
docker stats srs-server

# Network traffic monitoring
sudo iftop -i eth0
```

---

## 15. Full Requirements

See `requirements.txt` in the project root for complete system requirements.

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                    QUICK REFERENCE                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  START ALL:    sudo bash scripts/unix/webrtc-start.sh       │
│  STOP ALL:     sudo bash scripts/unix/webrtc-stop.sh        │
│  RESTART ALL:  sudo bash scripts/unix/webrtc-restart.sh     │
│  STATUS:       sudo bash scripts/unix/webrtc-status.sh      │
│  MONITOR:      sudo bash scripts/unix/webrtc-monitor.sh     │
│                                                              │
│  TURN LOGS:    tail -f /var/log/turnserver/turnserver.log   │
│  SRS LOGS:     docker logs -f srs-server                    │
│  NGINX LOGS:   tail -f /var/log/nginx/error.log            │
│                                                              │
│  SRS API:      curl http://localhost:1985/api/v1/versions   │
│  SRS STREAMS:  curl http://localhost:1985/api/v1/streams/   │
│  SRS CLIENTS:  curl http://localhost:1985/api/v1/clients/   │
│                                                              │
│  Supabase Secrets:                                          │
│    SRS_API_URL = https://srs.yourdomain.com                 │
│    SRS_RTC_URL = https://srs.yourdomain.com/rtc/v1          │
│    TURN_SECRET = <your-coturn-secret>                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```
