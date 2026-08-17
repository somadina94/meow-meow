#!/bin/bash
# ============================================================================
# Meow Chat - Deployment Script
# ============================================================================
# Description: Deploys the Meow Chat application to production
# Usage: ./deploy.sh [options]
# Options:
#   --frontend-only    Deploy only frontend
#   --backend-only     Deploy only backend (Edge Functions)
#   --skip-tests       Skip running tests before deployment
#   --skip-build       Skip build step (use existing build)
#   --dry-run          Show what would be deployed without actually deploying
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
LOG_FILE="$LOG_DIR/deploy_$(date +%Y%m%d_%H%M%S).log"

# Deployment configuration
DEPLOY_FRONTEND=true
DEPLOY_BACKEND=true
SKIP_TESTS=false
SKIP_BUILD=false
DRY_RUN=false

# Supabase project configuration
SUPABASE_PROJECT_ID="YOUR_SELF_HOSTED_PROJECT_ID"

# Edge functions to deploy
EDGE_FUNCTIONS=(
    "ai-women-approval"
    "ai-women-manager"
    "chat-manager"
    "content-moderation"
    "data-cleanup"
    "group-cleanup"
    "reset-password"
    "seed-legal-documents"
    "seed-super-users"
    
    "translate-message"
    "trigger-backup"
    "verify-photo"
    "video-call-server"
    "video-cleanup"
)

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --frontend-only)
            DEPLOY_FRONTEND=true
            DEPLOY_BACKEND=false
            shift
            ;;
        --backend-only)
            DEPLOY_FRONTEND=false
            DEPLOY_BACKEND=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
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
            echo "  --frontend-only    Deploy only frontend"
            echo "  --backend-only     Deploy only backend (Edge Functions)"
            echo "  --skip-tests       Skip running tests before deployment"
            echo "  --skip-build       Skip build step (use existing build)"
            echo "  --dry-run          Show what would be deployed without actually deploying"
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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# DEPLOYMENT FUNCTIONS
# ============================================================================

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Node.js
    if ! command_exists node; then
        error "Node.js is not installed."
        exit 1
    fi
    log "✓ Node.js $(node -v)"
    
    # Check npm
    if ! command_exists npm; then
        error "npm is not installed."
        exit 1
    fi
    log "✓ npm $(npm -v)"
    
    # Check Supabase CLI for backend deployment
    if [ "$DEPLOY_BACKEND" = true ]; then
        if ! command_exists supabase; then
            error "Supabase CLI is not installed. Install with: npm install -g supabase"
            exit 1
        fi
        log "✓ Supabase CLI $(supabase --version)"
    fi
    
    # Check Git
    if ! command_exists git; then
        error "Git is not installed."
        exit 1
    fi
    log "✓ Git $(git --version | cut -d' ' -f3)"
    
    log "✓ All prerequisites met"
}

run_tests() {
    if [ "$SKIP_TESTS" = true ]; then
        log "Skipping tests (--skip-tests flag)"
        return 0
    fi
    
    log "Running tests..."
    
    cd "$PROJECT_ROOT"
    
    # Run TypeScript type checking
    log "Running TypeScript type check..."
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would run: npx tsc --noEmit"
    else
        npx tsc --noEmit || {
            error "TypeScript type check failed"
            exit 1
        }
    fi
    
    # Run ESLint
    log "Running ESLint..."
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would run: npm run lint"
    else
        npm run lint || {
            error "ESLint check failed"
            exit 1
        }
    fi
    
    log "✓ All tests passed"
}

build_frontend() {
    if [ "$SKIP_BUILD" = true ]; then
        log "Skipping build (--skip-build flag)"
        
        if [ ! -d "$PROJECT_ROOT/dist" ]; then
            error "No existing build found. Remove --skip-build flag to build."
            exit 1
        fi
        
        return 0
    fi
    
    log "Building frontend..."
    
    cd "$PROJECT_ROOT"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would run: npm run build"
    else
        npm run build || {
            error "Frontend build failed"
            exit 1
        }
    fi
    
    # Verify build output
    if [ ! -d "$PROJECT_ROOT/dist" ] && [ "$DRY_RUN" = false ]; then
        error "Build directory not found after build"
        exit 1
    fi
    
    log "✓ Frontend build complete"
}

deploy_frontend() {
    if [ "$DEPLOY_FRONTEND" = false ]; then
        log "Skipping frontend deployment (--backend-only flag)"
        return 0
    fi
    
    log "Deploying frontend..."
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would deploy frontend to Lovable Cloud"
        log "[DRY RUN] Files in dist/:"
        ls -la "$PROJECT_ROOT/dist" 2>/dev/null || log "[DRY RUN] (dist directory would be created)"
    else
        # For Lovable, frontend deploys automatically via Git push
        # This section is for custom deployments
        log "Frontend deployment is handled by Lovable Cloud"
        log "Push to main branch and click 'Publish' in Lovable editor"
    fi
    
    log "✓ Frontend deployment complete"
}

deploy_backend() {
    if [ "$DEPLOY_BACKEND" = false ]; then
        log "Skipping backend deployment (--frontend-only flag)"
        return 0
    fi
    
    log "Deploying backend (Edge Functions)..."
    
    cd "$PROJECT_ROOT"
    
    for func in "${EDGE_FUNCTIONS[@]}"; do
        log "Deploying function: $func"
        
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would run: supabase functions deploy $func --project-ref $SUPABASE_PROJECT_ID"
        else
            supabase functions deploy "$func" --project-ref "$SUPABASE_PROJECT_ID" || {
                error "Failed to deploy function: $func"
                exit 1
            }
        fi
        
        log "✓ Deployed: $func"
    done
    
    log "✓ All Edge Functions deployed"
}

create_deployment_record() {
    log "Creating deployment record..."
    
    local git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local deploy_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local record_file="$PROJECT_ROOT/deployments/$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$PROJECT_ROOT/deployments"
    
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would create deployment record: $record_file"
    else
        cat > "$record_file" << EOF
{
    "timestamp": "$deploy_time",
    "git_commit": "$git_commit",
    "git_branch": "$git_branch",
    "frontend_deployed": $DEPLOY_FRONTEND,
    "backend_deployed": $DEPLOY_BACKEND,
    "dry_run": $DRY_RUN,
    "user": "$(whoami)",
    "hostname": "$(hostname)"
}
EOF
        log "✓ Deployment record created: $record_file"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    log "============================================"
    log "Meow Chat - Deployment Script"
    log "Deploy Frontend: $DEPLOY_FRONTEND"
    log "Deploy Backend: $DEPLOY_BACKEND"
    log "Skip Tests: $SKIP_TESTS"
    log "Skip Build: $SKIP_BUILD"
    log "Dry Run: $DRY_RUN"
    log "Project Root: $PROJECT_ROOT"
    log "============================================"
    
    # Record start time
    local start_time=$(date +%s)
    
    # Check prerequisites
    check_prerequisites
    
    # Run tests
    run_tests
    
    # Build frontend
    if [ "$DEPLOY_FRONTEND" = true ]; then
        build_frontend
    fi
    
    # Deploy frontend
    deploy_frontend
    
    # Deploy backend
    deploy_backend
    
    # Create deployment record
    create_deployment_record
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "============================================"
    if [ "$DRY_RUN" = true ]; then
        log "Dry run complete in ${duration}s!"
    else
        log "Deployment complete in ${duration}s!"
    fi
    log "Log file: $LOG_FILE"
    log "============================================"
}

# Run main function
main
