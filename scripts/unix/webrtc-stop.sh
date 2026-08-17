#!/bin/bash
# ============================================================
# Script: webrtc-stop.sh
# Purpose: Gracefully stop all WebRTC services
# OS: Ubuntu 22.04 / 24.04 LTS
# Usage: sudo bash scripts/unix/webrtc-stop.sh
#
# This script stops services in reverse order:
#   1. Nginx  — Stop accepting new connections
#   2. SRS    — Stop media server (disconnects all streams)
#   3. coturn — Stop TURN relay (disconnects relayed calls)
#
# WARNING: Stopping these services will:
#   - Disconnect all active video calls
#   - End all live group streams
#   - Break new call attempts
# ============================================================

# -------------------- COLOR CODES --------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# -------------------- HELPER FUNCTIONS --------------------

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $1"
}

# -------------------- MAIN SCRIPT --------------------

echo "============================================================"
echo "  Meow Meow — WebRTC Services Shutdown"
echo "  Stopping: Nginx + SRS + coturn"
echo "============================================================"
echo ""

# ---- Pre-check: Show active connections ----
# Before stopping, show how many users will be affected

log_info "Checking active connections before shutdown..."

# Check SRS active streams
if curl -sf http://localhost:1985/api/v1/streams/ > /dev/null 2>&1; then
    STREAM_COUNT=$(curl -sf http://localhost:1985/api/v1/streams/ | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d.get('streams',[])))" 2>/dev/null || echo "0")
    CLIENT_COUNT=$(curl -sf http://localhost:1985/api/v1/clients/ | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d.get('clients',[])))" 2>/dev/null || echo "0")
    
    if [ "$STREAM_COUNT" != "0" ] || [ "$CLIENT_COUNT" != "0" ]; then
        log_warn "Active SRS connections: ${STREAM_COUNT} streams, ${CLIENT_COUNT} clients"
        log_warn "These connections will be terminated!"
    fi
fi

echo ""

# ---- Step 1: Stop Nginx ----
# Stop the reverse proxy first so no new requests reach the backend

log_info "Stopping Nginx reverse proxy..."

if sudo systemctl is-active --quiet nginx 2>/dev/null; then
    # Graceful stop: finishes serving current requests, then stops
    sudo systemctl stop nginx
    sleep 1
    
    if ! sudo systemctl is-active --quiet nginx; then
        log_success "Nginx stopped"
    else
        log_error "Nginx didn't stop gracefully, force stopping..."
        sudo systemctl kill nginx
        log_success "Nginx force stopped"
    fi
else
    log_info "Nginx was not running"
fi

echo ""

# ---- Step 2: Stop SRS Media Server ----
# Stop the SFU server — this disconnects all group video calls

log_info "Stopping SRS media server..."

# Check if docker-compose is available
if [ -f "/opt/srs/docker-compose.yml" ]; then
    cd /opt/srs
    
    # docker-compose down: stops containers and removes them
    # This ensures a clean state for next startup
    sudo docker-compose down
    
    sleep 2
    
    if ! sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q srs-server; then
        log_success "SRS stopped and container removed"
    else
        log_error "SRS container still running, force removing..."
        sudo docker rm -f srs-server
        log_success "SRS force stopped"
    fi
else
    # Fallback: stop container directly
    if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q srs-server; then
        sudo docker stop srs-server
        sudo docker rm srs-server 2>/dev/null
        log_success "SRS stopped (standalone container)"
    else
        log_info "SRS was not running"
    fi
fi

echo ""

# ---- Step 3: Stop coturn ----
# Stop the TURN server — this disconnects all relayed P2P calls
# Note: Direct P2P calls (not relayed) will continue working

log_info "Stopping coturn TURN/STUN server..."

if sudo systemctl is-active --quiet coturn 2>/dev/null; then
    sudo systemctl stop coturn
    sleep 1
    
    if ! sudo systemctl is-active --quiet coturn; then
        log_success "coturn stopped"
    else
        log_error "coturn didn't stop, force killing..."
        sudo systemctl kill coturn
        log_success "coturn force stopped"
    fi
else
    log_info "coturn was not running"
fi

echo ""

# ---- Step 4: Display Summary ----
echo "============================================================"
echo "  Shutdown Summary"
echo "============================================================"

for service in nginx coturn; do
    if sudo systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "  ${RED}✗${NC} $service is still running (unexpected)"
    else
        echo -e "  ${GREEN}✓${NC} $service is stopped"
    fi
done

if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q srs-server; then
    echo -e "  ${RED}✗${NC} srs-server container is still running (unexpected)"
else
    echo -e "  ${GREEN}✓${NC} srs-server container is stopped"
fi

echo ""
echo "  All WebRTC services have been stopped."
echo "  To restart: sudo bash scripts/unix/webrtc-start.sh"
echo "============================================================"
