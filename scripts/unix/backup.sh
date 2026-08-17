#!/bin/bash
# ============================================================================
# Meow Chat - Backup Script
# ============================================================================
# Description: Creates backups of the application, database, and storage
# Usage: ./backup.sh [options]
# Options:
#   --full             Full backup (code, database, storage)
#   --code-only        Backup only code/configuration
#   --db-only          Backup only database
#   --storage-only     Backup only storage files
#   --output-dir DIR   Custom output directory for backups
#   --compress         Compress backup with gzip
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
LOG_FILE="$LOG_DIR/backup_$(date +%Y%m%d_%H%M%S).log"

# Backup configuration
BACKUP_CODE=true
BACKUP_DB=true
BACKUP_STORAGE=true
COMPRESS=false
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Supabase configuration
SUPABASE_PROJECT_ID="YOUR_SELF_HOSTED_PROJECT_ID"

# Storage buckets to backup
STORAGE_BUCKETS=(
    "profile-photos"
    "voice-messages"
    "legal-documents"
)

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            BACKUP_CODE=true
            BACKUP_DB=true
            BACKUP_STORAGE=true
            shift
            ;;
        --code-only)
            BACKUP_CODE=true
            BACKUP_DB=false
            BACKUP_STORAGE=false
            shift
            ;;
        --db-only)
            BACKUP_CODE=false
            BACKUP_DB=true
            BACKUP_STORAGE=false
            shift
            ;;
        --storage-only)
            BACKUP_CODE=false
            BACKUP_DB=false
            BACKUP_STORAGE=true
            shift
            ;;
        --output-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --compress|-z)
            COMPRESS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --full             Full backup (code, database, storage)"
            echo "  --code-only        Backup only code/configuration"
            echo "  --db-only          Backup only database"
            echo "  --storage-only     Backup only storage files"
            echo "  --output-dir DIR   Custom output directory for backups"
            echo "  --compress, -z     Compress backup with gzip"
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

# Get human readable file size
human_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        echo "$(echo "scale=2; $size / 1073741824" | bc) GB"
    elif [ $size -ge 1048576 ]; then
        echo "$(echo "scale=2; $size / 1048576" | bc) MB"
    elif [ $size -ge 1024 ]; then
        echo "$(echo "scale=2; $size / 1024" | bc) KB"
    else
        echo "$size bytes"
    fi
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

backup_code() {
    if [ "$BACKUP_CODE" = false ]; then
        log "Skipping code backup"
        return 0
    fi
    
    log "Backing up code and configuration..."
    
    local code_backup_dir="$BACKUP_DIR/$TIMESTAMP/code"
    mkdir -p "$code_backup_dir"
    
    # Files and directories to backup
    local backup_items=(
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
        ".env.example"
    )
    
    for item in "${backup_items[@]}"; do
        if [ -e "$PROJECT_ROOT/$item" ]; then
            cp -r "$PROJECT_ROOT/$item" "$code_backup_dir/"
            log "  ✓ Backed up: $item"
        fi
    done
    
    # Create backup manifest
    cat > "$code_backup_dir/MANIFEST.json" << EOF
{
    "backup_type": "code",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "git_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")",
    "git_branch": "$(git branch --show-current 2>/dev/null || echo "unknown")",
    "node_version": "$(node -v)",
    "npm_version": "$(npm -v)"
}
EOF
    
    log "✓ Code backup complete: $code_backup_dir"
}

backup_database() {
    if [ "$BACKUP_DB" = false ]; then
        log "Skipping database backup"
        return 0
    fi
    
    log "Backing up database..."
    
    local db_backup_dir="$BACKUP_DIR/$TIMESTAMP/database"
    mkdir -p "$db_backup_dir"
    
    # Check for Supabase CLI
    if ! command_exists supabase; then
        error "Supabase CLI not installed. Cannot backup database directly."
        log "Alternative: Use local Supabase Studio for database export"
        return 1
    fi
    
    # Export database schema
    log "Exporting database schema..."
    supabase db dump --project-ref "$SUPABASE_PROJECT_ID" \
        --schema public \
        -f "$db_backup_dir/schema.sql" 2>/dev/null || {
        error "Failed to export schema. Make sure you're logged in: supabase login"
        return 1
    }
    
    # Export data (if pg_dump is available)
    if command_exists pg_dump; then
        log "Exporting database data..."
        # Note: Requires SUPABASE_DB_URL environment variable
        if [ -n "${SUPABASE_DB_URL:-}" ]; then
            pg_dump "$SUPABASE_DB_URL" \
                --data-only \
                --no-owner \
                --no-acl \
                -f "$db_backup_dir/data.sql" 2>/dev/null || {
                error "Failed to export data"
            }
        else
            log "SUPABASE_DB_URL not set, skipping data export"
        fi
    fi
    
    # Create backup manifest
    cat > "$db_backup_dir/MANIFEST.json" << EOF
{
    "backup_type": "database",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "supabase_project_id": "$SUPABASE_PROJECT_ID",
    "includes_schema": true,
    "includes_data": $([ -f "$db_backup_dir/data.sql" ] && echo "true" || echo "false")
}
EOF
    
    log "✓ Database backup complete: $db_backup_dir"
}

backup_storage() {
    if [ "$BACKUP_STORAGE" = false ]; then
        log "Skipping storage backup"
        return 0
    fi
    
    log "Backing up storage buckets..."
    
    local storage_backup_dir="$BACKUP_DIR/$TIMESTAMP/storage"
    mkdir -p "$storage_backup_dir"
    
    # Note: Supabase CLI doesn't support direct storage download
    # This creates a manifest for manual download
    
    cat > "$storage_backup_dir/MANIFEST.json" << EOF
{
    "backup_type": "storage",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "supabase_project_id": "$SUPABASE_PROJECT_ID",
    "buckets": [
$(printf '        "%s",\n' "${STORAGE_BUCKETS[@]}" | sed '$ s/,$//')
    ],
    "note": "Storage files must be downloaded manually from local storage",
    "dashboard_url": "n/a"
}
EOF
    
    log "Storage backup manifest created"
    log "⚠ Note: Download storage files manually from local storage"
    log "  Location: /meowmeow/app/configs/supabase/docker/volumes/storage"
    
    log "✓ Storage backup manifest complete: $storage_backup_dir"
}

compress_backup() {
    if [ "$COMPRESS" = false ]; then
        return 0
    fi
    
    log "Compressing backup..."
    
    local backup_path="$BACKUP_DIR/$TIMESTAMP"
    local archive_name="meow_chat_backup_$TIMESTAMP.tar.gz"
    
    cd "$BACKUP_DIR"
    tar -czf "$archive_name" "$TIMESTAMP"
    
    local archive_size=$(stat -f%z "$archive_name" 2>/dev/null || stat -c%s "$archive_name" 2>/dev/null)
    
    # Remove uncompressed backup
    rm -rf "$TIMESTAMP"
    
    log "✓ Backup compressed: $archive_name ($(human_size $archive_size))"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Create directories
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR/$TIMESTAMP"
    
    log "============================================"
    log "Meow Chat - Backup Script"
    log "Backup Code: $BACKUP_CODE"
    log "Backup Database: $BACKUP_DB"
    log "Backup Storage: $BACKUP_STORAGE"
    log "Compress: $COMPRESS"
    log "Output Directory: $BACKUP_DIR"
    log "Timestamp: $TIMESTAMP"
    log "============================================"
    
    # Record start time
    local start_time=$(date +%s)
    
    # Run backups
    backup_code
    backup_database
    backup_storage
    
    # Compress if requested
    compress_backup
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Calculate backup size
    local backup_size=0
    if [ "$COMPRESS" = true ]; then
        local archive="$BACKUP_DIR/meow_chat_backup_$TIMESTAMP.tar.gz"
        if [ -f "$archive" ]; then
            backup_size=$(stat -f%z "$archive" 2>/dev/null || stat -c%s "$archive" 2>/dev/null)
        fi
    else
        if [ -d "$BACKUP_DIR/$TIMESTAMP" ]; then
            backup_size=$(du -sb "$BACKUP_DIR/$TIMESTAMP" 2>/dev/null | cut -f1 || echo 0)
        fi
    fi
    
    log "============================================"
    log "Backup complete in ${duration}s!"
    log "Backup size: $(human_size $backup_size)"
    log "Log file: $LOG_FILE"
    log "============================================"
}

# Run main function
main
