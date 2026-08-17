#!/bin/bash
# ============================================================================
# Meow Chat - Application Shutdown Script
# ============================================================================
# Description: Gracefully shuts down the Meow Chat application
# Usage: ./shutdown.sh [--force]
# Options:
#   --force    Force kill all processes without graceful shutdown
# ============================================================================

set -e  # Exit immediately if a command exits with a non-zero status

# ============================================================================
# CONFIGURATION
# ============================================================================

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Log file location
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/shutdown_$(date +%Y%m%d_%H%M%S).log"

# PID file for process management
PID_FILE="$PROJECT_ROOT/.pid"

# Ports used by the application
PORTS=(5173 4173 80 8080 3000)

# Force kill flag
FORCE_KILL=false

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_KILL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force]"
            exit 1
            ;;
    esac
done

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Log message with timestamp
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Log error message
error() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo "$message" >&2
    echo "$message" >> "$LOG_FILE"
}

# Check if port is in use
port_in_use() {
    lsof -i ":$1" >/dev/null 2>&1
}

# Get PID using port
get_pid_on_port() {
    lsof -ti ":$1" 2>/dev/null || echo ""
}

# Gracefully stop process
graceful_stop() {
    local pid=$1
    local timeout=${2:-10}
    
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        return 0
    fi
    
    log "Sending SIGTERM to PID $pid..."
    kill -TERM "$pid" 2>/dev/null || true
    
    # Wait for graceful shutdown
    local count=0
    while kill -0 "$pid" 2>/dev/null && [ $count -lt $timeout ]; do
        sleep 1
        count=$((count + 1))
        log "Waiting for process $pid to stop... ($count/$timeout)"
    done
    
    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        log "Process $pid did not stop gracefully, force killing..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    if ! kill -0 "$pid" 2>/dev/null; then
        log "✓ Process $pid stopped"
        return 0
    else
        error "Failed to stop process $pid"
        return 1
    fi
}

# Force kill all processes on a port
force_kill_port() {
    local port=$1
    local pids=$(get_pid_on_port "$port")
    
    if [ -n "$pids" ]; then
        log "Force killing processes on port $port: $pids"
        echo "$pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
}

# ============================================================================
# SHUTDOWN FUNCTIONS
# ============================================================================

stop_from_pid_file() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        log "Found PID file with PID: $pid"
        
        if [ "$FORCE_KILL" = true ]; then
            log "Force killing process $pid..."
            kill -9 "$pid" 2>/dev/null || true
        else
            graceful_stop "$pid" 15
        fi
        
        rm -f "$PID_FILE"
        log "✓ PID file removed"
    else
        log "No PID file found at $PID_FILE"
    fi
}

stop_all_ports() {
    log "Checking for processes on application ports..."
    
    for port in "${PORTS[@]}"; do
        if port_in_use "$port"; then
            local pids=$(get_pid_on_port "$port")
            log "Found processes on port $port: $pids"
            
            if [ "$FORCE_KILL" = true ]; then
                force_kill_port "$port"
            else
                for pid in $pids; do
                    graceful_stop "$pid" 10
                done
            fi
        else
            log "Port $port is not in use"
        fi
    done
}

cleanup_temp_files() {
    log "Cleaning up temporary files..."
    
    # Remove Vite cache
    if [ -d "$PROJECT_ROOT/node_modules/.vite" ]; then
        rm -rf "$PROJECT_ROOT/node_modules/.vite"
        log "✓ Removed Vite cache"
    fi
    
    # Remove any lock files
    rm -f "$PROJECT_ROOT/.lock" 2>/dev/null || true
    
    log "✓ Cleanup complete"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    log "============================================"
    log "Meow Chat - Shutdown Script"
    log "Force Kill: $FORCE_KILL"
    log "Project Root: $PROJECT_ROOT"
    log "============================================"
    
    # Stop process from PID file
    stop_from_pid_file
    
    # Stop all processes on application ports
    stop_all_ports
    
    # Cleanup temporary files
    cleanup_temp_files
    
    log "============================================"
    log "Shutdown complete!"
    log "Log file: $LOG_FILE"
    log "============================================"
}

# Run main function
main
