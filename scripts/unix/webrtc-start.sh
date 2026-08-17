#!/bin/bash
# ============================================================
# Script: webrtc-start.sh
# Purpose: Start all WebRTC services (coturn + SRS + Nginx)
# OS: Ubuntu 22.04 / 24.04 LTS
# Usage: sudo bash scripts/unix/webrtc-start.sh
#
# This script starts the following services in order:
#   1. coturn  — TURN/STUN server for P2P NAT traversal
#   2. SRS    — SFU media server for group video calls
#   3. Nginx  — Reverse proxy with SSL termination
#
# Prerequisites:
#   - coturn installed via apt
#   - SRS deployed via Docker at /opt/srs
#   - Nginx configured with SSL certificates
# ============================================================

# -------------------- COLOR CODES --------------------
# These make terminal output easier to read
RED='\033[0;31m'       # Error messages
GREEN='\033[0;32m'     # Success messages
YELLOW='\033[1;33m'    # Warning messages
BLUE='\033[0;34m'      # Info messages
NC='\033[0m'           # No Color (reset)

# -------------------- HELPER FUNCTIONS --------------------

# Print a formatted log message with timestamp
log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"
}

# Print a success message
log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [OK]${NC} $1"
}

# Print an error message
log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1"
}

# Print a warning message
log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $1"
}

# Check if a command exists on the system
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed. Please install it first."
        return 1
    fi
    return 0
}

# -------------------- MAIN SCRIPT --------------------

echo "============================================================"
echo "  Meow Meow — WebRTC Services Startup"
echo "  Starting: coturn (TURN) + SRS (SFU) + Nginx (Proxy)"
echo "============================================================"
echo ""

# ---- Step 1: Start coturn (TURN/STUN Server) ----
# coturn handles NAT traversal for P2P video calls.
# When two users can't connect directly (behind firewalls),
# coturn relays the media traffic between them.

log_info "Starting coturn TURN/STUN server..."

# Check if coturn is installed
if check_command turnserver; then
    # Start coturn using systemd
    sudo systemctl start coturn
    
    # Wait 2 seconds for the service to initialize
    sleep 2
    
    # Verify coturn is running by checking systemd status
    if sudo systemctl is-active --quiet coturn; then
        log_success "coturn started successfully"
        
        # Show which ports coturn is listening on
        log_info "coturn listening on ports:"
        sudo ss -tlnp | grep turnserver | awk '{print "  " $4}' 2>/dev/null
    else
        log_error "coturn failed to start!"
        log_error "Check logs: sudo journalctl -u coturn -n 20"
    fi
else
    log_warn "coturn not installed — P2P video calls will use public TURN servers (less reliable)"
fi

echo ""

# ---- Step 2: Start SRS Media Server (Docker) ----
# SRS handles group video calls using SFU (Selective Forwarding Unit).
# The host publishes their stream to SRS, and SRS forwards it to all viewers.
# This is more efficient than having the host send to each viewer directly.

log_info "Starting SRS media server (Docker)..."

# Check if Docker is installed and running
if check_command docker; then
    # Verify Docker daemon is running
    if ! sudo systemctl is-active --quiet docker; then
        log_info "Docker is not running. Starting Docker first..."
        sudo systemctl start docker
        sleep 3
    fi
    
    # Check if docker-compose file exists
    if [ -f "/opt/srs/docker-compose.yml" ]; then
        # Navigate to SRS directory
        cd /opt/srs
        
        # Start SRS using docker-compose
        # -d flag runs containers in the background (detached mode)
        sudo docker-compose up -d
        
        # Wait for SRS to initialize (it needs a few seconds to start the API)
        log_info "Waiting for SRS to initialize..."
        sleep 5
        
        # Verify SRS is responding by checking its API endpoint
        # The /api/v1/versions endpoint returns server version info
        if curl -sf http://localhost:1985/api/v1/versions > /dev/null 2>&1; then
            log_success "SRS media server started successfully"
            
            # Display SRS version information
            SRS_VERSION=$(curl -sf http://localhost:1985/api/v1/versions | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'v{d[\"data\"][\"major\"]}.{d[\"data\"][\"minor\"]}')" 2>/dev/null)
            log_info "SRS Version: ${SRS_VERSION:-unknown}"
            
            # Display port information
            log_info "SRS endpoints:"
            echo "  HTTP API:    http://localhost:1985"
            echo "  WebRTC:      http://localhost:8080"
            echo "  WebRTC UDP:  port 8000"
            echo "  RTMP:        rtmp://localhost:1935"
        else
            log_error "SRS is running but API is not responding!"
            log_error "Check logs: docker logs srs-server"
        fi
    else
        # Fallback: Run SRS directly with Docker (without compose)
        log_warn "docker-compose.yml not found at /opt/srs/"
        log_info "Starting SRS with direct Docker command..."
        
        # Stop and remove existing container if it exists
        sudo docker stop srs-server 2>/dev/null
        sudo docker rm srs-server 2>/dev/null
        
        # Run SRS container
        # --restart unless-stopped: Auto-restart on crash or reboot
        # Port mappings: host_port:container_port
        sudo docker run -d \
            --name srs-server \
            --restart unless-stopped \
            -p 1935:1935 \
            -p 1985:1985 \
            -p 8080:8080 \
            -p 8000:8000/udp \
            ossrs/srs:5
        
        sleep 5
        
        if curl -sf http://localhost:1985/api/v1/versions > /dev/null 2>&1; then
            log_success "SRS started successfully (standalone mode)"
        else
            log_error "SRS failed to start!"
        fi
    fi
else
    log_error "Docker is not installed! SRS (group calls) will not work."
    log_error "Install Docker: sudo apt install -y docker.io"
fi

echo ""

# ---- Step 3: Start Nginx Reverse Proxy ----
# Nginx serves as a reverse proxy that:
# - Terminates SSL/TLS (handles HTTPS)
# - Routes API requests to SRS
# - Provides security headers
# - Handles HTTP→HTTPS redirects

log_info "Starting Nginx reverse proxy..."

if check_command nginx; then
    # Test Nginx configuration before starting
    # This prevents starting with broken config
    if sudo nginx -t 2>/dev/null; then
        # Start Nginx
        sudo systemctl start nginx
        
        sleep 1
        
        if sudo systemctl is-active --quiet nginx; then
            log_success "Nginx started successfully"
        else
            log_error "Nginx failed to start!"
            log_error "Check logs: sudo tail -20 /var/log/nginx/error.log"
        fi
    else
        log_error "Nginx configuration test failed!"
        log_error "Fix config: sudo nginx -t"
    fi
else
    log_warn "Nginx not installed — SRS will be accessible directly (no SSL)"
fi

echo ""

# ---- Step 4: Display Summary ----
echo "============================================================"
echo "  Startup Summary"
echo "============================================================"

# Check each service and display status
for service in coturn docker nginx; do
    if sudo systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $service is running"
    else
        echo -e "  ${RED}✗${NC} $service is not running"
    fi
done

# Check SRS container specifically
if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q srs-server; then
    echo -e "  ${GREEN}✓${NC} srs-server container is running"
else
    echo -e "  ${RED}✗${NC} srs-server container is not running"
fi

echo ""
echo "  To check status:  sudo bash scripts/unix/webrtc-status.sh"
echo "  To view SRS logs:  docker logs -f srs-server"
echo "  To view TURN logs: tail -f /var/log/turnserver/turnserver.log"
echo "============================================================"
