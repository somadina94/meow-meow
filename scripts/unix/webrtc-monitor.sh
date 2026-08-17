#!/bin/bash
# ============================================================
# Script: webrtc-monitor.sh
# Purpose: Real-time monitoring dashboard for WebRTC services
# OS: Ubuntu 22.04 / 24.04 LTS
# Usage: sudo bash scripts/unix/webrtc-monitor.sh
#
# This script displays a live-updating dashboard showing:
#   - Service health (coturn, SRS, Nginx)
#   - Active streams and viewer counts
#   - CPU, memory, and bandwidth usage
#   - Real-time log tail
#
# Press Ctrl+C to exit the monitor.
# ============================================================

# -------------------- COLOR CODES --------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# -------------------- CONFIGURATION --------------------

# How often to refresh the dashboard (in seconds)
REFRESH_INTERVAL=5

# -------------------- CLEANUP ON EXIT --------------------

# When the user presses Ctrl+C, clean up and exit gracefully
cleanup() {
    # Show cursor again (we hide it during monitoring)
    tput cnorm
    echo ""
    echo -e "${BLUE}Monitor stopped.${NC}"
    exit 0
}

# Register the cleanup function to run on SIGINT (Ctrl+C)
trap cleanup SIGINT SIGTERM

# Hide cursor for cleaner display
tput civis

# -------------------- MAIN MONITORING LOOP --------------------

while true; do
    # Clear screen for fresh display
    clear
    
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║        Meow Meow — WebRTC Live Monitor                     ║${NC}"
    echo -e "${CYAN}${BOLD}║        $(date '+%Y-%m-%d %H:%M:%S %Z')                              ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # ---- Services Health ----
    echo -e "${BOLD}🔧 Services${NC}"
    
    # coturn status
    if sudo systemctl is-active --quiet coturn 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} coturn (TURN/STUN) — ${GREEN}running${NC}"
    else
        echo -e "  ${RED}●${NC} coturn (TURN/STUN) — ${RED}stopped${NC}"
    fi
    
    # SRS status
    if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q srs-server; then
        echo -e "  ${GREEN}●${NC} SRS (SFU Server) — ${GREEN}running${NC}"
    else
        echo -e "  ${RED}●${NC} SRS (SFU Server) — ${RED}stopped${NC}"
    fi
    
    # Nginx status
    if sudo systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} Nginx (Proxy) — ${GREEN}running${NC}"
    else
        echo -e "  ${RED}●${NC} Nginx (Proxy) — ${RED}stopped${NC}"
    fi
    
    echo ""
    
    # ---- SRS Live Stats ----
    echo -e "${BOLD}📡 Live Streams${NC}"
    
    if curl -sf http://localhost:1985/api/v1/versions > /dev/null 2>&1; then
        # Fetch stream and client data from SRS API
        STREAMS_JSON=$(curl -sf http://localhost:1985/api/v1/streams/ 2>/dev/null)
        CLIENTS_JSON=$(curl -sf http://localhost:1985/api/v1/clients/ 2>/dev/null)
        
        STREAM_COUNT=$(echo "$STREAMS_JSON" | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d.get('streams',[])))" 2>/dev/null || echo "0")
        CLIENT_COUNT=$(echo "$CLIENTS_JSON" | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d.get('clients',[])))" 2>/dev/null || echo "0")
        
        echo "  Active Streams:    $STREAM_COUNT"
        echo "  Connected Clients: $CLIENT_COUNT"
        
        # Show individual streams if any are active
        if [ "$STREAM_COUNT" != "0" ]; then
            echo ""
            echo -e "  ${DIM}Stream Details:${NC}"
            echo "$STREAMS_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for s in data.get('streams', []):
        name = s.get('name', 'unknown')
        clients = s.get('clients', 0)
        kbps_recv = s.get('kbps', {}).get('recv_30s', 0)
        kbps_send = s.get('kbps', {}).get('send_30s', 0)
        print(f'    📺 {name} — {clients} viewers — ↑{kbps_recv}kbps ↓{kbps_send}kbps')
except:
    print('    Unable to parse stream data')
" 2>/dev/null
        fi
    else
        echo -e "  ${RED}SRS API not reachable${NC}"
    fi
    
    echo ""
    
    # ---- Resource Usage ----
    echo -e "${BOLD}💻 Resources${NC}"
    
    # CPU utilization (average across all cores)
    CPU_PERCENT=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | cut -d. -f1 2>/dev/null || echo "0")
    echo "  CPU Usage:    ${CPU_PERCENT}%"
    
    # Memory utilization
    MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}' 2>/dev/null || echo "0")
    MEM_INFO=$(free -h | awk '/^Mem:/ {printf "%s / %s (%s free)", $3, $2, $4}')
    echo "  Memory:       $MEM_INFO (${MEM_PERCENT}%)"
    
    # System load
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo "  System Load:  $LOAD"
    
    # ---- Circuit Breaker: Auto-trip if CPU or Memory > 95% ----
    SUPABASE_URL="${SUPABASE_URL:-}"
    SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
    
    if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
        if [ "$CPU_PERCENT" -gt 95 ] || [ "$MEM_PERCENT" -gt 95 ]; then
            echo -e "  ${RED}${BOLD}⚠ CRITICAL: Resource utilization > 95% — Tripping circuit breaker!${NC}"
            curl -sf -X POST "${SUPABASE_URL}/functions/v1/video-call-circuit-breaker" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
                -d "{\"action\":\"report_high_utilization\",\"cpu_percent\":${CPU_PERCENT},\"memory_percent\":${MEM_PERCENT},\"source\":\"webrtc-monitor\"}" \
                > /dev/null 2>&1
            echo -e "  ${RED}Video calls disabled for 2 hours${NC}"
        else
            echo -e "  ${GREEN}✓ Resources within safe limits${NC}"
        fi
    else
        echo -e "  ${DIM}Set SUPABASE_URL and SUPABASE_ANON_KEY to enable circuit breaker${NC}"
    fi
    
    # Docker container stats
    if sudo docker ps --format '{{.Names}}' 2>/dev/null | grep -q srs-server; then
        DOCKER_STATS=$(sudo docker stats srs-server --no-stream --format "CPU: {{.CPUPerc}} | Mem: {{.MemUsage}} | Net: {{.NetIO}}" 2>/dev/null)
        echo "  SRS Container: $DOCKER_STATS"
    fi
    
    # Network connections count
    CONN_COUNT=$(sudo ss -s | grep "TCP:" | awk '{print $2}')
    echo "  TCP Connections: $CONN_COUNT"
    
    echo ""
    
    # ---- Recent Activity ----
    echo -e "${BOLD}📋 Recent SRS Logs (last 5 lines)${NC}"
    sudo docker logs srs-server 2>&1 | tail -5 | sed 's/^/  /'
    
    echo ""
    echo -e "${DIM}Refreshing every ${REFRESH_INTERVAL}s — Press Ctrl+C to exit${NC}"
    
    # Wait before next refresh
    sleep $REFRESH_INTERVAL
done
