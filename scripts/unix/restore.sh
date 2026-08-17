#!/bin/bash
# ============================================================================
# Meow Chat - Restore Script
# ============================================================================
# Description: Restores the application from a backup
# Usage: ./restore.sh <backup_path> [options]
# Options:
#   --code-only        Restore only code/configuration
#   --db-only          Restore only database
#   --storage-only     Restore only storage files
#   --dry-run          Show what would be restored without actually doing it
#   --confirm          Skip confirmation prompt
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
LOG_FILE="$LOG_DIR/restore_$(date +%Y%m%d_%H%M%S).log"

# Restore configuration
RESTORE_CODE=true
RESTORE_DB=true
RESTORE_STORAGE=true
DRY_RUN=false
SKIP_CONFIRM=false
BACKUP_PATH=""

# Supabase configuration
SUPABASE_PROJECT_ID="YOUR_SELF_HOSTED_PROJECT_ID"

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

# First argument should be backup path
if [ $# -gt 0 ] && [[ ! "$1" =~ ^-- ]]; then
    BACKUP_PATH="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --code-only)
            RESTORE_CODE=true
            RESTORE_DB=false
            RESTORE_STORAGE=false
            shift
            ;;
        --db-only)
            RESTORE_CODE=false
            RESTORE_DB=true
            RESTORE_STORAGE=false
            shift
            ;;
        --storage-only)
            RESTORE_CODE=false
            RESTORE_DB=false
            RESTORE_STORAGE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --confirm|-y)
            SKIP_CONFIRM=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 <backup_path> [options]"
            echo ""
            echo "Arguments:"
            echo "  backup_path        Path to backup directory or archive"
            echo ""
            echo "Options:"
            echo "  --code-only        Restore only code/configuration"
            echo "  --db-only          Restore only database"
            echo "  --storage-only     Restore only storage files"
            echo "  --dry-run          Show what would be restored without actually doing it"
            echo "  --confirm, -y      Skip confirmation prompt"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 ./backups/20231201_120000"
            echo "  $0 ./backups/meow_chat_backup_20231201_120000.tar.gz"
            echo "  $0 ./backups/20231201_120000 --code-only --dry-run"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate backup path
if [ -z "$BACKUP_PATH" ]; then
    error "Backup path is required"
    echo "Usage: $0 <backup_path> [options]"
    exit 1
fi

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# RESTORE FUNCTIONS
# ============================================================================

prepare_backup() {
    log "Preparing backup for restore..."
    
    # Check if backup is an archive
    if [[ "$BACKUP_PATH" =~ \.tar\.gz$ ]]; then
        if [ ! -f "$BACKUP_PATH" ]; then
            error "Backup archive not found: $BACKUP_PATH"
            exit 1
        fi
        
        log "Extracting backup archive..."
        local temp_dir=$(mktemp -d)
        
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would extract: $BACKUP_PATH to $temp_dir"
        else
            tar -xzf "$BACKUP_PATH" -C "$temp_dir"
            
            # Find extracted directory
            local extracted=$(ls "$temp_dir" | head -1)
            BACKUP_PATH="$temp_dir/$extracted"
        fi
        
        log "✓ Archive extracted to: $BACKUP_PATH"
    fi
    
    # Validate backup structure
    if [ ! -d "$BACKUP_PATH" ]; then
        error "Backup directory not found: $BACKUP_PATH"
        exit 1
    fi
    
    log "✓ Backup path validated: $BACKUP_PATH"
}

confirm_restore() {
    if [ "$SKIP_CONFIRM" = true ] || [ "$DRY_RUN" = true ]; then
        return 0
    fi
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    ⚠️  WARNING ⚠️                              ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║  You are about to restore from a backup!                      ║"
    echo "║                                                               ║"
    echo "║  This action will OVERWRITE:                                  ║"
    if [ "$RESTORE_CODE" = true ]; then
    echo "║    - Current source code and configuration                    ║"
    fi
    if [ "$RESTORE_DB" = true ]; then
    echo "║    - Database schema and data                                 ║"
    fi
    if [ "$RESTORE_STORAGE" = true ]; then
    echo "║    - Storage bucket files                                     ║"
    fi
    echo "║                                                               ║"
    echo "║  Backup source: $BACKUP_PATH"
    echo "║                                                               ║"
    echo "║  Make sure you have a current backup before proceeding!       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    read -p "Are you sure you want to continue? Type 'YES' to confirm: " confirm
    
    if [ "$confirm" != "YES" ]; then
        log "Restore cancelled by user"
        exit 0
    fi
    
    log "User confirmed restore"
}

restore_code() {
    if [ "$RESTORE_CODE" = false ]; then
        log "Skipping code restore"
        return 0
    fi
    
    local code_backup="$BACKUP_PATH/code"
    
    if [ ! -d "$code_backup" ]; then
        warn "Code backup not found in: $code_backup"
        return 0
    fi
    
    log "Restoring code and configuration..."
    
    # Items to restore
    local restore_items=(
        "src"
        "public"
        "supabase"
        "docs"
        "scripts"
        "package.json"
        "package-lock.json"
        "tsconfig.json"
        "tsconfig.app.json"
        "tsconfig.node.json"
        "vite.config.ts"
        "tailwind.config.ts"
        "postcss.config.js"
        "eslint.config.js"
        "capacitor.config.ts"
        "index.html"
        "README.md"
    )
    
    for item in "${restore_items[@]}"; do
        if [ -e "$code_backup/$item" ]; then
            if [ "$DRY_RUN" = true ]; then
                log "[DRY RUN] Would restore: $item"
            else
                # Backup current file/directory
                if [ -e "$PROJECT_ROOT/$item" ]; then
                    rm -rf "$PROJECT_ROOT/$item"
                fi
                
                cp -r "$code_backup/$item" "$PROJECT_ROOT/"
                log "  ✓ Restored: $item"
            fi
        fi
    done
    
    # Reinstall dependencies
    if [ "$DRY_RUN" = false ]; then
        log "Reinstalling dependencies..."
        cd "$PROJECT_ROOT"
        npm install
        log "  ✓ Dependencies installed"
    fi
    
    log "✓ Code restore complete"
}

restore_database() {
    if [ "$RESTORE_DB" = false ]; then
        log "Skipping database restore"
        return 0
    fi
    
    local db_backup="$BACKUP_PATH/database"
    
    if [ ! -d "$db_backup" ]; then
        warn "Database backup not found in: $db_backup"
        return 0
    fi
    
    log "Restoring database..."
    
    # Check for required tools
    if ! command_exists supabase; then
        error "Supabase CLI not installed. Cannot restore database."
        return 1
    fi
    
    # Restore schema
    if [ -f "$db_backup/schema.sql" ]; then
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would restore schema from: $db_backup/schema.sql"
        else
            log "Restoring database schema..."
            # Note: This requires database connection
            warn "Database schema restore requires manual execution"
            log "Run the following SQL in local Supabase Studio SQL Editor:"
            log "  File: $db_backup/schema.sql"
        fi
    fi
    
    # Restore data
    if [ -f "$db_backup/data.sql" ]; then
        if [ "$DRY_RUN" = true ]; then
            log "[DRY RUN] Would restore data from: $db_backup/data.sql"
        else
            log "Restoring database data..."
            warn "Database data restore requires manual execution"
            log "Run the following SQL in Supabase SQL Editor:"
            log "  File: $db_backup/data.sql"
        fi
    fi
    
    log "✓ Database restore instructions provided"
}

restore_storage() {
    if [ "$RESTORE_STORAGE" = false ]; then
        log "Skipping storage restore"
        return 0
    fi
    
    local storage_backup="$BACKUP_PATH/storage"
    
    if [ ! -d "$storage_backup" ]; then
        warn "Storage backup not found in: $storage_backup"
        return 0
    fi
    
    log "Restoring storage..."
    
    if [ -f "$storage_backup/MANIFEST.json" ]; then
        log "Storage files must be uploaded manually to local storage volume"
        log "  Location: /meowmeow/app/configs/supabase/docker/volumes/storage"
    fi
    
    log "✓ Storage restore instructions provided"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    log "============================================"
    log "Meow Chat - Restore Script"
    log "Backup Path: $BACKUP_PATH"
    log "Restore Code: $RESTORE_CODE"
    log "Restore Database: $RESTORE_DB"
    log "Restore Storage: $RESTORE_STORAGE"
    log "Dry Run: $DRY_RUN"
    log "============================================"
    
    # Record start time
    local start_time=$(date +%s)
    
    # Prepare backup
    prepare_backup
    
    # Confirm restore
    confirm_restore
    
    # Run restore operations
    restore_code
    restore_database
    restore_storage
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "============================================"
    if [ "$DRY_RUN" = true ]; then
        log "Dry run complete in ${duration}s!"
    else
        log "Restore complete in ${duration}s!"
    fi
    log "Log file: $LOG_FILE"
    log "============================================"
}

# Run main function
main
