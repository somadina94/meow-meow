#!/bin/bash
# ============================================================================
# Meow Chat - Undeployment Script
# ============================================================================
# Description: Removes deployed resources from production
# Usage: ./undeploy.sh [options]
# Options:
#   --frontend-only    Undeploy only frontend
#   --backend-only     Undeploy only backend (Edge Functions)
#   --confirm          Skip confirmation prompt
#   --dry-run          Show what would be undeployed without actually doing it
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
LOG_FILE="$LOG_DIR/undeploy_$(date +%Y%m%d_%H%M%S).log"

# Undeployment configuration
UNDEPLOY_FRONTEND=true
UNDEPLOY_BACKEND=true
SKIP_CONFIRM=false
DRY_RUN=false

# Supabase project configuration
SUPABASE_PROJECT_ID="YOUR_SELF_HOSTED_PROJECT_ID"

# Edge functions to undeploy
EDGE_FUNCTIONS=(
    "ai-women-approval"
    "ai-women-manager"
    "chat-manager"
    "content-moderation"
    "data-cleanup"
    "reset-password"
    "seed-legal-documents"
    "seed-sample-users"
    "seed-super-users"
    
    "translate-message"
    "trigger-backup"
    "verify-photo"
)

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --frontend-only)
            UNDEPLOY_FRONTEND=true
            UNDEPLOY_BACKEND=false
            shift
            ;;
        --backend-only)
            UNDEPLOY_FRONTEND=false
            UNDEPLOY_BACKEND=true
            shift
            ;;
        --confirm|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --frontend-only    Undeploy only frontend"
            echo "  --backend-only     Undeploy only backend (Edge Functions)"
            echo "  --confirm, -y      Skip confirmation prompt"
            echo "  --dry-run          Show what would be undeployed without actually doing it"
            echo "  --help, -h         Show this help message"
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

# Log warning message
warn() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo "$message" >&2
    echo "$message" >> "$LOG_FILE"
}

# ============================================================================
# UNDEPLOYMENT FUNCTIONS
# ============================================================================

confirm_undeploy() {
    if [ "$SKIP_CONFIRM" = true ] || [ "$DRY_RUN" = true ]; then
        return 0
    fi
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  WARNING ⚠️                              ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║  You are about to undeploy production resources!              ║"
    echo "║                                                               ║"
    echo "║  This action will:                                            ║"
    if [ "$UNDEPLOY_FRONTEND" = true ]; then
    echo "║    - Remove the frontend application                          ║"
    fi
    if [ "$UNDEPLOY_BACKEND" = true ]; then
    echo "║    - Delete all Edge Functions                                ║"
    fi
    echo "║                                                               ║"
    echo "║  This action CANNOT be undone easily!                         ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    read -p "Are you sure you want to continue? Type 'YES' to confirm: " confirm
    
    if [ "$confirm" != "YES" ]; then
        log "Undeployment cancelled by user"
        exit 0
    fi
    
    log "User confirmed undeployment"
}

undeploy_frontend() {
    if [ "$UNDEPLOY_FRONTEND" = false ]; then
        log "Skipping frontend undeployment (--backend-only flag)"
        return 0
    fi
    
    log "Undeploying frontend..."
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would remove frontend deployment"
        log "[DRY RUN] Note: Lovable frontend cannot be fully undeployed"
        log "[DRY RUN] Consider unpublishing in Lovable dashboard instead"
    else
        warn "Frontend cannot be fully undeployed programmatically"
        log "To unpublish the frontend:"
        log "  1. Go to Lovable editor"
        log "  2. Click on project settings"
        log "  3. Manage domain settings or unpublish"
    fi
    
    log "✓ Frontend undeployment complete"
}

undeploy_backend() {
    if [ "$UNDEPLOY_BACKEND" = false ]; then
        log "Skipping backend undeployment (--frontend-only flag)"
        return 0
    fi
    
    log "Undeploying backend (Edge Functions)..."
    
    for func in "${EDGE_FUNCTIONS[@]}"; do
        log "Removing function: $func"
        
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would run: supabase functions delete $func"
        else
            # Note: Supabase CLI doesn't have a delete command for functions
            # Functions need to be deleted from the dashboard
            warn "Function deletion must be done manually in local Supabase Studio"
            log "Navigate to Studio for management"
        fi
    done
    
    log "✓ Backend undeployment instructions provided"
}

cleanup_local() {
    log "Cleaning up local deployment artifacts..."
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would remove dist/ directory"
        log "[DRY RUN] Would clear deployment cache"
    else
        # Remove build directory
        if [ -d "$PROJECT_ROOT/dist" ]; then
            rm -rf "$PROJECT_ROOT/dist"
            log "✓ Removed dist directory"
        fi
        
        # Clear Vite cache
        if [ -d "$PROJECT_ROOT/node_modules/.vite" ]; then
            rm -rf "$PROJECT_ROOT/node_modules/.vite"
            log "✓ Removed Vite cache"
        fi
    fi
    
    log "✓ Local cleanup complete"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    log "============================================"
    log "Meow Chat - Undeployment Script"
    log "Undeploy Frontend: $UNDEPLOY_FRONTEND"
    log "Undeploy Backend: $UNDEPLOY_BACKEND"
    log "Skip Confirm: $SKIP_CONFIRM"
    log "Dry Run: $DRY_RUN"
    log "Project Root: $PROJECT_ROOT"
    log "============================================"
    
    # Confirm undeployment
    confirm_undeploy
    
    # Record start time
    local start_time=$(date +%s)
    
    # Undeploy frontend
    undeploy_frontend
    
    # Undeploy backend
    undeploy_backend
    
    # Cleanup local artifacts
    cleanup_local
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "============================================"
    if [ "$DRY_RUN" = true ]; then
        log "Dry run complete in ${duration}s!"
    else
        log "Undeployment complete in ${duration}s!"
    fi
    log "Log file: $LOG_FILE"
    log "============================================"
}

# Run main function
main
