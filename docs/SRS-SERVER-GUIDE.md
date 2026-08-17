# SRS (Simple Realtime Server) Deployment Guide

Complete guide for deploying, starting, running, and stopping SRS servers for video calling functionality.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Local Development](#local-development)
4. [Cloud Deployment](#cloud-deployment)
5. [Server Management](#server-management)
6. [Configuration](#configuration)
7. [Monitoring](#monitoring)
8. [Troubleshooting](#troubleshooting)
9. [Security](#security)

---

## Overview

SRS (Simple Realtime Server) is a high-performance real-time video server supporting RTMP, WebRTC, HLS, HTTP-FLV, and SRT protocols.

### Architecture

```
┌─────────────┐     WebRTC      ┌─────────────┐
│   Browser   │ ◄─────────────► │ SRS Server  │
│  (Publisher)│                 │             │
└─────────────┘                 └──────┬──────┘
                                       │
                                       │ WebRTC
                                       ▼
                                ┌─────────────┐
                                │   Browser   │
                                │  (Viewer)   │
                                └─────────────┘
```

### Ports Used

| Port | Protocol | Purpose |
|------|----------|---------|
| 1935 | TCP | RTMP streaming |
| 1985 | TCP | HTTP API |
| 8080 | TCP | HTTP server / WebRTC signaling |
| 8000 | UDP | WebRTC media |

---

## Prerequisites

### Required Software

1. **Docker** (Recommended)
   - Windows: [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Linux: `sudo apt install docker.io`
   - macOS: [Docker Desktop](https://www.docker.com/products/docker-desktop/)

2. **Alternative: Build from Source**
   - Git
   - GCC/G++ compiler
   - Make

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 1 core | 2+ cores |
| RAM | 512 MB | 2+ GB |
| Storage | 1 GB | 10+ GB |
| Network | 10 Mbps | 100+ Mbps |

---

## Local Development

### Starting SRS with Docker

```bash
# Pull the latest SRS image
docker pull ossrs/srs:5

# Start SRS server
docker run -d \
  --name srs \
  -p 1935:1935 \
  -p 1985:1985 \
  -p 8080:8080 \
  -p 8000:8000/udp \
  ossrs/srs:5

# Verify it's running
docker ps | grep srs
```

### If Port 8080 is Already in Use

```bash
# Use an alternative port (e.g., 8088)
docker run -d \
  --name srs \
  -p 1935:1935 \
  -p 1985:1985 \
  -p 8088:8080 \
  -p 8000:8000/udp \
  ossrs/srs:5
```

### Verify Installation

```bash
# Check API is responding
curl http://localhost:1985/api/v1/versions

# Expected response:
# {"code":0,"server":"...","data":{"major":5,"minor":0,...}}
```

### Stopping SRS

```bash
# Stop the container
docker stop srs

# Remove the container
docker rm srs
```

### Restarting SRS

```bash
# Restart existing container
docker restart srs

# Or stop, remove, and start fresh
docker stop srs && docker rm srs
docker run -d --name srs -p 1935:1935 -p 1985:1985 -p 8080:8080 -p 8000:8000/udp ossrs/srs:5
```

---

## Cloud Deployment

### Option 1: DigitalOcean Droplet

#### Step 1: Create a Droplet

1. Go to [DigitalOcean](https://www.digitalocean.com/)
2. Create a new Droplet:
   - Image: Ubuntu 22.04 LTS
   - Size: Basic ($6/month minimum)
   - Region: Choose closest to your users

#### Step 2: Install Docker

```bash
# SSH into your droplet
ssh root@YOUR_DROPLET_IP

# Update system
apt update && apt upgrade -y

# Install Docker
apt install -y docker.io

# Start Docker service
systemctl start docker
systemctl enable docker
```

#### Step 3: Deploy SRS

```bash
# Run SRS
docker run -d \
  --name srs \
  --restart unless-stopped \
  -p 1935:1935 \
  -p 1985:1985 \
  -p 8080:8080 \
  -p 8000:8000/udp \
  ossrs/srs:5
```

#### Step 4: Configure Firewall

```bash
# Allow SRS ports
ufw allow 1935/tcp
ufw allow 1985/tcp
ufw allow 8080/tcp
ufw allow 8000/udp
ufw enable
```

### Option 2: AWS EC2

#### Step 1: Launch EC2 Instance

1. Go to AWS Console → EC2
2. Launch Instance:
   - AMI: Ubuntu 22.04 LTS
   - Instance Type: t2.micro (free tier) or t2.small
   - Security Group: Allow ports 1935, 1985, 8080 (TCP) and 8000 (UDP)

#### Step 2: Connect and Deploy

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@YOUR_EC2_IP

# Install Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Deploy SRS
sudo docker run -d \
  --name srs \
  --restart unless-stopped \
  -p 1935:1935 \
  -p 1985:1985 \
  -p 8080:8080 \
  -p 8000:8000/udp \
  ossrs/srs:5
```

### Option 3: Google Cloud Platform

```bash
# Create a VM instance
gcloud compute instances create srs-server \
  --machine-type=e2-small \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --tags=srs-server

# Create firewall rules
gcloud compute firewall-rules create srs-ports \
  --allow tcp:1935,tcp:1985,tcp:8080,udp:8000 \
  --target-tags=srs-server

# SSH and deploy
gcloud compute ssh srs-server
# Then follow the Docker installation and SRS deployment steps
```

### Option 4: Using ngrok (For Testing Only)

If you need to quickly expose a local SRS server:

```bash
# Start SRS locally
docker run -d --name srs -p 1935:1935 -p 1985:1985 -p 8088:8080 -p 8000:8000/udp ossrs/srs:5

# Install ngrok (https://ngrok.com/)
# Then expose the HTTP API
ngrok http 8088

# Note the ngrok URL (e.g., https://abc123.ngrok.io)
# Use this URL in your application
```

---

## Server Management

### Docker Commands Reference

```bash
# Start SRS
docker start srs

# Stop SRS
docker stop srs

# Restart SRS
docker restart srs

# View logs
docker logs srs

# View real-time logs
docker logs -f srs

# View last 100 lines
docker logs --tail 100 srs

# Remove container
docker rm srs

# Remove container (force)
docker rm -f srs

# Check container status
docker ps -a | grep srs

# Execute command inside container
docker exec -it srs bash

# Check resource usage
docker stats srs
```

### Systemd Service (Production)

Create a systemd service for automatic startup:

```bash
# Create service file
sudo nano /etc/systemd/system/srs.service
```

Add the following content:

```ini
[Unit]
Description=SRS Media Server
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStartPre=-/usr/bin/docker stop srs
ExecStartPre=-/usr/bin/docker rm srs
ExecStart=/usr/bin/docker run --rm --name srs \
  -p 1935:1935 \
  -p 1985:1985 \
  -p 8080:8080 \
  -p 8000:8000/udp \
  ossrs/srs:5
ExecStop=/usr/bin/docker stop srs

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable on boot
sudo systemctl enable srs

# Start service
sudo systemctl start srs

# Check status
sudo systemctl status srs

# View logs
sudo journalctl -u srs -f
```

### Docker Compose (Recommended)

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  srs:
    image: ossrs/srs:5
    container_name: srs
    restart: unless-stopped
    ports:
      - "1935:1935"   # RTMP
      - "1985:1985"   # HTTP API
      - "8080:8080"   # HTTP/WebRTC
      - "8000:8000/udp"  # WebRTC UDP
    volumes:
      - ./conf/srs.conf:/usr/local/srs/conf/srs.conf
      - ./logs:/usr/local/srs/objs
    environment:
      - SRS_LOG_LEVEL=info
```

Commands:

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# View logs
docker-compose logs -f

# Rebuild and start
docker-compose up -d --build
```

---

## Configuration

### Custom SRS Configuration

Create `conf/srs.conf`:

```nginx
listen              1935;
max_connections     1000;
daemon              off;
srs_log_tank        console;
srs_log_level       info;

http_api {
    enabled         on;
    listen          1985;
    crossdomain     on;
}

http_server {
    enabled         on;
    listen          8080;
    dir             ./objs/nginx/html;
}

rtc_server {
    enabled         on;
    listen          8000;
    candidate       *;
}

vhost __defaultVhost__ {
    rtc {
        enabled     on;
        rtmp_to_rtc on;
        rtc_to_rtmp on;
    }
    
    http_remux {
        enabled     on;
        mount       [vhost]/[app]/[stream].flv;
    }
}
```

### Environment-Specific Configurations

#### Development

```nginx
srs_log_level       trace;
max_connections     100;
```

#### Production

```nginx
srs_log_level       warn;
max_connections     10000;

# Enable performance optimizations
tcp_nodelay         on;
min_latency         on;
```

---

## Monitoring

### Health Check Endpoints

```bash
# Server version
curl http://YOUR_SERVER:1985/api/v1/versions

# Server summary
curl http://YOUR_SERVER:1985/api/v1/summaries

# Active streams
curl http://YOUR_SERVER:1985/api/v1/streams

# Connected clients
curl http://YOUR_SERVER:1985/api/v1/clients

# Server statistics
curl http://YOUR_SERVER:1985/api/v1/vhosts
```

### Monitoring Script

Create `monitor-srs.sh`:

```bash
#!/bin/bash

SRS_API="http://localhost:1985/api/v1"

echo "=== SRS Server Status ==="
echo ""

# Check if server is running
if curl -s "$SRS_API/versions" > /dev/null; then
    echo "✅ Server: RUNNING"
else
    echo "❌ Server: DOWN"
    exit 1
fi

# Get active streams
STREAMS=$(curl -s "$SRS_API/streams" | jq '.streams | length')
echo "📺 Active Streams: $STREAMS"

# Get connected clients
CLIENTS=$(curl -s "$SRS_API/clients" | jq '.clients | length')
echo "👥 Connected Clients: $CLIENTS"

# Get memory usage
MEMORY=$(curl -s "$SRS_API/summaries" | jq '.data.system.mem_percent')
echo "💾 Memory Usage: ${MEMORY}%"

echo ""
echo "=== Recent Activity ==="
docker logs --tail 10 srs
```

### Prometheus Metrics (Advanced)

SRS exposes Prometheus metrics at `/metrics`:

```bash
curl http://YOUR_SERVER:1985/metrics
```

---

## Troubleshooting

### Common Issues

#### 1. Port Already in Use

```bash
# Find what's using the port
sudo lsof -i :8080
# or
sudo netstat -tulpn | grep 8080

# Kill the process
sudo kill -9 <PID>

# Or use a different port
docker run -d --name srs -p 8088:8080 ...
```

#### 2. Container Won't Start

```bash
# Check logs
docker logs srs

# Check if container exists
docker ps -a | grep srs

# Remove and recreate
docker rm -f srs
docker run -d --name srs ...
```

#### 3. WebRTC Connection Failed

- Ensure UDP port 8000 is open
- Check firewall rules
- Verify candidate IP is correct for your network

```bash
# Test UDP port
nc -vzu YOUR_SERVER 8000
```

#### 4. High CPU/Memory Usage

```bash
# Check resource usage
docker stats srs

# Restart container
docker restart srs

# Limit resources
docker run -d --name srs \
  --cpus=2 \
  --memory=2g \
  ...
```

#### 5. Docker Daemon Not Running

```bash
# Windows: Start Docker Desktop application

# Linux:
sudo systemctl start docker
sudo systemctl enable docker

# Check status
sudo systemctl status docker
```

### Log Analysis

```bash
# View all logs
docker logs srs

# Search for errors
docker logs srs 2>&1 | grep -i error

# Search for specific stream
docker logs srs 2>&1 | grep "stream_name"
```

---

## Security

### Best Practices

1. **Use HTTPS/WSS** - Put SRS behind a reverse proxy (nginx) with SSL

2. **Restrict API Access** - Don't expose port 1985 publicly

3. **Use Authentication** - Implement token-based authentication

4. **Firewall Rules** - Only open necessary ports

5. **Regular Updates** - Keep SRS image updated

### Nginx Reverse Proxy with SSL

```nginx
server {
    listen 443 ssl http2;
    server_name stream.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/stream.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/stream.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /rtc/ {
        proxy_pass http://127.0.0.1:1985/rtc/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

---

## Quick Reference

### Essential Commands

| Action | Command |
|--------|---------|
| Start | `docker run -d --name srs -p 1935:1935 -p 1985:1985 -p 8080:8080 -p 8000:8000/udp ossrs/srs:5` |
| Stop | `docker stop srs` |
| Start (existing) | `docker start srs` |
| Restart | `docker restart srs` |
| Logs | `docker logs -f srs` |
| Remove | `docker rm -f srs` |
| Status | `docker ps \| grep srs` |
| Health | `curl http://localhost:1985/api/v1/versions` |

### API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/api/v1/versions` | Server version |
| `/api/v1/summaries` | Server statistics |
| `/api/v1/streams` | Active streams |
| `/api/v1/clients` | Connected clients |
| `/rtc/v1/whip/` | WebRTC publish |
| `/rtc/v1/whep/` | WebRTC play |

---

## Integration with Application

After deploying SRS, update the edge function configuration:

```typescript
// In supabase/functions/video-call-server/index.ts
const SRS_CONFIG = {
  apiUrl: 'http://YOUR_SRS_SERVER_IP:1985',
  rtcUrl: 'http://YOUR_SRS_SERVER_IP:8080',
  noRecording: true
};
```

---

## Support

- **SRS Documentation**: https://ossrs.io/lts/en-us/docs/v5/doc/introduction
- **SRS GitHub**: https://github.com/ossrs/srs
- **Docker Hub**: https://hub.docker.com/r/ossrs/srs
