#!/bin/bash
# ============================================================================
# Meow Chat - Application Startup Script
# ============================================================================
# Description: Starts the Meow Chat application and all required services
# Usage: ./startup.sh [environment]
# Environments: development, staging, production
# ============================================================================

set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default environment
ENVIRONMENT="${1:-development}"

# Log file location
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/startup_$(date +%Y%m%d_%H%M%S).log"

# PID file for process management
PID_FILE="$PROJECT_ROOT/.pid"

# Port configuration
DEV_PORT=5173
PREVIEW_PORT=4173
PROD_PORT=80

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if port is in use
port_in_use() {
    lsof -i ":$1" >/dev/null 2>&1
}

# Kill process on port
kill_port() {
    local port=$1
    if port_in_use "$port"; then
        log "Killing process on port $port..."
        lsof -ti ":$port" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Node.js
    if ! command_exists node; then
        error "Node.js is not installed. Please install Node.js v18 or higher."
        exit 1
    fi
    
    local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$node_version" -lt 18 ]; then
        error "Node.js v18 or higher is required. Current version: $(node -v)"
        exit 1
    fi
    log "✓ Node.js $(node -v) detected"
    
    # Check npm
    if ! command_exists npm; then
        error "npm is not installed."
        exit 1
    fi
    log "✓ npm $(npm -v) detected"
    
    # Check if dependencies are installed
    if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
        log "Installing dependencies..."
        cd "$PROJECT_ROOT"
        npm install
    fi
    log "✓ Dependencies installed"
    
    # Check environment file
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        if [ -f "$PROJECT_ROOT/.env.example" ]; then
            log "Creating .env from .env.example..."
            cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
            log "⚠ Please configure your .env file with proper values"
        else
            error ".env file not found. Please create one with required environment variables."
            exit 1
        fi
    fi
    log "✓ Environment file exists"
}

# ============================================================================
# STARTUP FUNCTIONS
# ============================================================================

start_development() {
    log "Starting development server..."
    
    # Kill existing process on dev port
    kill_port $DEV_PORT
    
    cd "$PROJECT_ROOT"
    
    # Start Vite dev server in background
    nohup npm run dev > "$LOG_DIR/dev_server.log" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait for server to start
    log "Waiting for server to start..."
    sleep 5
    
    if port_in_use $DEV_PORT; then
        log "✓ Development server started on http://localhost:$DEV_PORT"
        log "✓ PID: $pid"
    else
        error "Failed to start development server"
        exit 1
    fi
}

start_preview() {
    log "Starting preview server..."
    
    # Build the application first
    log "Building application..."
    cd "$PROJECT_ROOT"
    npm run build
    
    # Kill existing process on preview port
    kill_port $PREVIEW_PORT
    
    # Start preview server in background
    nohup npm run preview > "$LOG_DIR/preview_server.log" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait for server to start
    sleep 3
    
    if port_in_use $PREVIEW_PORT; then
        log "✓ Preview server started on http://localhost:$PREVIEW_PORT"
        log "✓ PID: $pid"
    else
        error "Failed to start preview server"
        exit 1
    fi
}

start_production() {
    log "Starting production server..."
    
    # Build the application
    log "Building application for production..."
    cd "$PROJECT_ROOT"
    npm run build
    
    # Check if serve is installed
    if ! command_exists serve; then
        log "Installing serve globally..."
        npm install -g serve
    fi
    
    # Kill existing process on production port
    kill_port $PROD_PORT
    
    # Start production server
    nohup serve -s dist -l $PROD_PORT > "$LOG_DIR/prod_server.log" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    
    # Wait for server to start
    sleep 3
    
    if port_in_use $PROD_PORT; then
        log "✓ Production server started on http://localhost:$PROD_PORT"
        log "✓ PID: $pid"
    else
        error "Failed to start production server"
        exit 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    log "============================================"
    log "Meow Chat - Startup Script"
    log "Environment: $ENVIRONMENT"
    log "Project Root: $PROJECT_ROOT"
    log "============================================"
    
    # Run prerequisite checks
    check_prerequisites
    
    # Start based on environment
    case "$ENVIRONMENT" in
        development|dev)
            start_development
            ;;
        staging|preview)
            start_preview
            ;;
        production|prod)
            start_production
            ;;
        *)
            error "Unknown environment: $ENVIRONMENT"
            echo "Usage: $0 [development|staging|production]"
            exit 1
            ;;
    esac
    
    log "============================================"
    log "Startup complete!"
    log "Log file: $LOG_FILE"
    log "============================================"
}

# Run main function
main
