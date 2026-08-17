#!/bin/bash
# ============================================================
# Script: webrtc-status.sh
# Purpose: Display status of all WebRTC services
# OS: Ubuntu 22.04 / 24.04 LTS
# Usage: sudo bash scripts/unix/webrtc-status.sh
#
# Shows:
#   - Service running state (coturn, SRS, Nginx)
#   - Port availability
#   - Active streams and connections
#   - Resource usage (CPU, RAM)
#   - Recent errors in logs
# ============================================================

# -------------------- COLOR CODES --------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# -------------------- HELPER FUNCTIONS --------------------

# Print a section header
section() {
    echo ""
    echo -e "${CYAN}${BOLD}── $1 ──${NC}"
}

# Print status line with checkmark or X
status_line() {
    local name=$1
    local is_running=$2
    local details=$3
    
    if [ "$is_running" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} ${BOLD}$name${NC} — running ${details}"
    else
        echo -e "  ${RED}✗${NC} ${BOLD}$name${NC} — stopped"
    fi
}

# -------------------- MAIN SCRIPT --------------------

echo "============================================================"
echo "  Meow Meow — WebRTC Services Status"
echo "  Checked at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "============================================================"

# ---- Section 1: Service Status ----
section "SERVICE STATUS"

# Check coturn
# coturn provides TURN/STUN for P2P NAT traversal
if sudo systemctl is-active --quiet coturn 2>/dev/null; then
    COTURN_PID=$(sudo systemctl show coturn --property=MainPID --value)
    status_line "coturn (TURN/STUN)" "true" "(PID: $COTURN_PID)"
else
    status_line "coturn (TURN/STUN)" "false"
fi

# Check Docker
if sudo systemctl is-active --quiet docker 2>/dev/null; then
    status_line "Docker Engine" "true"
else
    status_line "Docker Engine" "false"
fi

# Check SRS container
# SRS is the SFU media server for group video calls
if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q srs-server; then
    SRS_UPTIME=$(sudo docker ps --format '{{.Status}}' --filter name=srs-server)
    status_line "SRS Media Server" "true" "($SRS_UPTIME)"
else
    status_line "SRS Media Server" "false"
fi

# Check Nginx
# Nginx provides SSL termination and reverse proxy
if sudo systemctl is-active --quiet nginx 2>/dev/null; then
    status_line "Nginx Proxy" "true"
else
    status_line "Nginx Proxy" "false"
fi

# ---- Section 2: Port Status ----
section "PORT STATUS"

# Define ports and their purposes
declare -A PORTS=(
    [3478]="coturn STUN/TURN"
    [5349]="coturn TURN-TLS"
    [1935]="SRS RTMP"
    [1985]="SRS HTTP API"
    [8080]="SRS WebRTC"
    [8000]="SRS WebRTC UDP"
    [80]="Nginx HTTP"
    [443]="Nginx HTTPS"
)

for port in 3478 5349 1985 8080 80 443; do
    if sudo ss -tlnp | grep -q ":$port " 2>/dev/null; then
        PROCESS=$(sudo ss -tlnp | grep ":$port " | awk '{print $6}' | head -1)
        echo -e "  ${GREEN}●${NC} Port $port (${PORTS[$port]}) — listening ${PROCESS}"
    else
        echo -e "  ${RED}○${NC} Port $port (${PORTS[$port]}) — not listening"
    fi
done

# Check UDP port for SRS WebRTC media
if sudo ss -ulnp | grep -q ":8000 " 2>/dev/null; then
    echo -e "  ${GREEN}●${NC} Port 8000/udp (SRS WebRTC Media) — listening"
else
    echo -e "  ${RED}○${NC} Port 8000/udp (SRS WebRTC Media) — not listening"
fi

# ---- Section 3: SRS Statistics ----
section "SRS LIVE STATISTICS"

if curl -sf http://localhost:1985/api/v1/versions > /dev/null 2>&1; then
    # Get SRS version
    SRS_VER=$(curl -sf http://localhost:1985/api/v1/versions | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'v{d[\"data\"][\"major\"]}.{d[\"data\"][\"minor\"]}')" 2>/dev/null || echo "unknown")
    echo "  SRS Version: $SRS_VER"
    
    # Count active streams (each group host = 1 stream)
    STREAMS=$(curl -sf http://localhost:1985/api/v1/streams/ 2>/dev/null)
    STREAM_COUNT=$(echo "$STREAMS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d.get('streams',[])))" 2>/dev/null || echo "0")
    echo "  Active Streams: $STREAM_COUNT"
    
    # Count connected clients (hosts + viewers)
    CLIENTS=$(curl -sf http://localhost:1985/api/v1/clients/ 2>/dev/null)
    CLIENT_COUNT=$(echo "$CLIENTS" | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d.get('clients',[])))" 2>/dev/null || echo "0")
    echo "  Connected Clients: $CLIENT_COUNT"
    
    # Server uptime and resource usage
    SUMMARY=$(curl -sf http://localhost:1985/api/v1/summaries 2>/dev/null)
    if [ -n "$SUMMARY" ]; then
        CPU_PERCENT=$(echo "$SUMMARY" | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'{d[\"data\"][\"self\"][\"cpu_percent\"]:.1f}%')" 2>/dev/null || echo "N/A")
        MEM_MB=$(echo "$SUMMARY" | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'{d[\"data\"][\"self\"][\"mem_kilo\"]/1024:.0f}MB')" 2>/dev/null || echo "N/A")
        echo "  SRS CPU Usage: $CPU_PERCENT"
        echo "  SRS Memory: $MEM_MB"
    fi
else
    echo "  SRS API not reachable"
fi

# ---- Section 4: Docker Container Resources ----
section "CONTAINER RESOURCES"

if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q srs-server; then
    # Show Docker resource usage (CPU%, MEM, NET I/O)
    sudo docker stats srs-server --no-stream --format \
        "  CPU: {{.CPUPerc}}  |  Memory: {{.MemUsage}}  |  Net I/O: {{.NetIO}}" 2>/dev/null
else
    echo "  SRS container not running"
fi

# ---- Section 5: System Resources ----
section "SYSTEM RESOURCES"

# Show overall system CPU and memory usage
echo "  CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "  Memory: $(free -h | awk '/^Mem:/ {printf "%s used / %s total (%s free)", $3, $2, $4}')"
echo "  Disk: $(df -h / | awk 'NR==2 {printf "%s used / %s total (%s free, %s used)", $3, $2, $4, $5}')"

# Network bandwidth (if iftop or vnstat is available)
if command -v vnstat &> /dev/null; then
    echo "  Network (today): $(vnstat -d 1 | tail -3 | head -1 | awk '{print $2, $3, "rx /", $5, $6, "tx"}')"
fi

# ---- Section 6: Recent Errors ----
section "RECENT ERRORS (Last 5)"

# Check coturn logs for errors
echo -e "  ${BOLD}coturn:${NC}"
if [ -f /var/log/turnserver/turnserver.log ]; then
    COTURN_ERRORS=$(grep -i "error" /var/log/turnserver/turnserver.log 2>/dev/null | tail -3)
    if [ -n "$COTURN_ERRORS" ]; then
        echo "$COTURN_ERRORS" | sed 's/^/    /'
    else
        echo "    No recent errors"
    fi
else
    echo "    Log file not found"
fi

# Check SRS container logs for errors
echo -e "  ${BOLD}SRS:${NC}"
SRS_ERRORS=$(sudo docker logs srs-server 2>&1 | grep -i "error" | tail -3 2>/dev/null)
if [ -n "$SRS_ERRORS" ]; then
    echo "$SRS_ERRORS" | sed 's/^/    /'
else
    echo "    No recent errors"
fi

# Check Nginx logs for errors
echo -e "  ${BOLD}Nginx:${NC}"
if [ -f /var/log/nginx/error.log ]; then
    NGINX_ERRORS=$(tail -3 /var/log/nginx/error.log 2>/dev/null)
    if [ -n "$NGINX_ERRORS" ]; then
        echo "$NGINX_ERRORS" | sed 's/^/    /'
    else
        echo "    No recent errors"
    fi
else
    echo "    Log file not found"
fi

echo ""
echo "============================================================"
echo "  Status check complete."
echo "============================================================"
