#!/bin/bash
# ============================================================================
# Meow Chat - Application Restart Script
# ============================================================================
# Description: Restarts the Meow Chat application (shutdown + startup)
# Usage: ./restart.sh [environment] [options]
# Environments: development, staging, production
# Options:
#   --force    Force restart without graceful shutdown
#   --clean    Clean build before restart
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
LOG_FILE="$LOG_DIR/restart_$(date +%Y%m%d_%H%M%S).log"

# Default values
ENVIRONMENT="development"
FORCE_RESTART=false
CLEAN_BUILD=false

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        development|dev|staging|preview|production|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        --force|-f)
            FORCE_RESTART=true
            shift
            ;;
        --clean|-c)
            CLEAN_BUILD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [environment] [options]"
            echo ""
            echo "Environments:"
            echo "  development, dev    Start development server"
            echo "  staging, preview    Start preview server"
            echo "  production, prod    Start production server"
            echo ""
            echo "Options:"
            echo "  --force, -f         Force restart without graceful shutdown"
            echo "  --clean, -c         Clean build before restart"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
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

# ============================================================================
# RESTART FUNCTIONS
# ============================================================================

clean_build() {
    log "Cleaning build artifacts..."
    
    # Remove dist directory
    if [ -d "$PROJECT_ROOT/dist" ]; then
        rm -rf "$PROJECT_ROOT/dist"
        log "✓ Removed dist directory"
    fi
    
    # Remove Vite cache
    if [ -d "$PROJECT_ROOT/node_modules/.vite" ]; then
        rm -rf "$PROJECT_ROOT/node_modules/.vite"
        log "✓ Removed Vite cache"
    fi
    
    # Remove TypeScript build info
    rm -f "$PROJECT_ROOT/tsconfig.tsbuildinfo" 2>/dev/null || true
    
    log "✓ Clean complete"
}

run_shutdown() {
    log "Running shutdown script..."
    
    local shutdown_args=""
    if [ "$FORCE_RESTART" = true ]; then
        shutdown_args="--force"
    fi
    
    bash "$SCRIPT_DIR/shutdown.sh" $shutdown_args
    
    log "✓ Shutdown complete"
}

run_startup() {
    log "Running startup script..."
    
    bash "$SCRIPT_DIR/startup.sh" "$ENVIRONMENT"
    
    log "✓ Startup complete"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    log "============================================"
    log "Meow Chat - Restart Script"
    log "Environment: $ENVIRONMENT"
    log "Force Restart: $FORCE_RESTART"
    log "Clean Build: $CLEAN_BUILD"
    log "Project Root: $PROJECT_ROOT"
    log "============================================"
    
    # Record start time
    local start_time=$(date +%s)
    
    # Run shutdown
    run_shutdown
    
    # Clean build if requested
    if [ "$CLEAN_BUILD" = true ]; then
        clean_build
    fi
    
    # Wait a moment before starting
    log "Waiting before startup..."
    sleep 2
    
    # Run startup
    run_startup
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "============================================"
    log "Restart complete in ${duration}s!"
    log "Log file: $LOG_FILE"
    log "============================================"
}

# Run main function
main
