#!/bin/bash
# ============================================================
# Script: webrtc-restart.sh
# Purpose: Restart all WebRTC services (zero-downtime goal)
# OS: Ubuntu 22.04 / 24.04 LTS
# Usage: sudo bash scripts/unix/webrtc-restart.sh
#
# This script performs a rolling restart:
#   1. Stops all services gracefully
#   2. Waits for clean shutdown
#   3. Starts all services in correct order
#
# NOTE: There will be a brief interruption (~10 seconds)
#       during which video calls will be disconnected.
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

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $1"
}

# -------------------- MAIN SCRIPT --------------------

echo "============================================================"
echo "  Meow Meow — WebRTC Services Restart"
echo "============================================================"
echo ""

# Get the directory where this script is located
# This allows calling stop.sh and start.sh from the same directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Phase 1: Stop all services ----
log_info "Phase 1: Stopping all services..."
echo ""

# Call the stop script
bash "$SCRIPT_DIR/webrtc-stop.sh"

echo ""

# ---- Phase 2: Wait for clean shutdown ----
log_info "Phase 2: Waiting for clean shutdown..."

# Wait 5 seconds to ensure all processes have fully terminated
# and all ports are released
sleep 5

# Verify all ports are free
PORTS_IN_USE=0
for port in 3478 1985 8080 8000; do
    if sudo ss -tlnp | grep -q ":$port "; then
        log_warn "Port $port is still in use!"
        PORTS_IN_USE=$((PORTS_IN_USE + 1))
    fi
done

if [ $PORTS_IN_USE -gt 0 ]; then
    log_warn "Some ports are still in use. Waiting 5 more seconds..."
    sleep 5
fi

echo ""

# ---- Phase 3: Start all services ----
log_info "Phase 3: Starting all services..."
echo ""

# Call the start script
bash "$SCRIPT_DIR/webrtc-start.sh"

echo ""
log_success "Restart complete!"
echo "============================================================"
