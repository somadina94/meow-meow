@echo off
REM ============================================================================
REM Meow Chat - Backup Script (Windows)
REM ============================================================================
REM Description: Creates backups of the application, database, and storage
REM Usage: backup.bat [options]
REM Options:
REM   /full          Full backup (code, database, storage)
REM   /code          Backup only code/configuration
REM   /db            Backup only database
REM   /storage       Backup only storage files
REM   /compress      Compress backup with zip
REM ============================================================================

setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURATION
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "LOG_DIR=%PROJECT_ROOT%\logs"
set "BACKUP_DIR=%PROJECT_ROOT%\backups"
set "BACKUP_CODE=true"
set "BACKUP_DB=true"
set "BACKUP_STORAGE=true"
set "COMPRESS=false"

REM Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="/full" set "BACKUP_CODE=true" & set "BACKUP_DB=true" & set "BACKUP_STORAGE=true" & shift & goto :parse_args
if /i "%~1"=="/code" set "BACKUP_CODE=true" & set "BACKUP_DB=false" & set "BACKUP_STORAGE=false" & shift & goto :parse_args
if /i "%~1"=="/db" set "BACKUP_CODE=false" & set "BACKUP_DB=true" & set "BACKUP_STORAGE=false" & shift & goto :parse_args
if /i "%~1"=="/storage" set "BACKUP_CODE=false" & set "BACKUP_DB=false" & set "BACKUP_STORAGE=true" & shift & goto :parse_args
if /i "%~1"=="/compress" set "COMPRESS=true" & shift & goto :parse_args
shift
goto :parse_args
:args_done

REM Create timestamp
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%"
set "LOG_FILE=%LOG_DIR%\backup_%TIMESTAMP%.log"
set "BACKUP_PATH=%BACKUP_DIR%\%TIMESTAMP%"

REM ============================================================================
REM UTILITY FUNCTIONS
REM ============================================================================

:log
echo [%date% %time%] %~1
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

REM ============================================================================
REM MAIN EXECUTION
REM ============================================================================

:main
REM Create directories
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"

call :log "============================================"
call :log "Meow Chat - Backup Script (Windows)"
call :log "Backup Code: %BACKUP_CODE%"
call :log "Backup Database: %BACKUP_DB%"
call :log "Backup Storage: %BACKUP_STORAGE%"
call :log "Compress: %COMPRESS%"
call :log "Output: %BACKUP_PATH%"
call :log "============================================"

REM Backup code
if "%BACKUP_CODE%"=="true" (
    call :backup_code
)

REM Backup database info
if "%BACKUP_DB%"=="true" (
    call :backup_database
)

REM Backup storage info
if "%BACKUP_STORAGE%"=="true" (
    call :backup_storage
)

REM Compress if requested
if "%COMPRESS%"=="true" (
    call :compress_backup
)

call :log "============================================"
call :log "Backup complete!"
call :log "Backup location: %BACKUP_PATH%"
call :log "Log file: %LOG_FILE%"
call :log "============================================"

endlocal
exit /b 0

:backup_code
call :log "Backing up code..."
set "CODE_BACKUP=%BACKUP_PATH%\code"
mkdir "%CODE_BACKUP%"

REM Copy source directories
if exist "%PROJECT_ROOT%\src" xcopy /E /I /Y "%PROJECT_ROOT%\src" "%CODE_BACKUP%\src" >nul
if exist "%PROJECT_ROOT%\public" xcopy /E /I /Y "%PROJECT_ROOT%\public" "%CODE_BACKUP%\public" >nul
if exist "%PROJECT_ROOT%\supabase" xcopy /E /I /Y "%PROJECT_ROOT%\supabase" "%CODE_BACKUP%\supabase" >nul

REM Copy config files
if exist "%PROJECT_ROOT%\package.json" copy "%PROJECT_ROOT%\package.json" "%CODE_BACKUP%\" >nul
if exist "%PROJECT_ROOT%\tsconfig.json" copy "%PROJECT_ROOT%\tsconfig.json" "%CODE_BACKUP%\" >nul
if exist "%PROJECT_ROOT%\vite.config.ts" copy "%PROJECT_ROOT%\vite.config.ts" "%CODE_BACKUP%\" >nul
if exist "%PROJECT_ROOT%\tailwind.config.ts" copy "%PROJECT_ROOT%\tailwind.config.ts" "%CODE_BACKUP%\" >nul

call :log "Code backup complete"
goto :eof

:backup_database
call :log "Backing up database info..."
set "DB_BACKUP=%BACKUP_PATH%\database"
mkdir "%DB_BACKUP%"

echo {"backup_type": "database", "timestamp": "%TIMESTAMP%", "note": "Use Supabase Dashboard for full database export"} > "%DB_BACKUP%\MANIFEST.json"

call :log "Database backup info created"
call :log "For full database backup, use Supabase Dashboard"
goto :eof

:backup_storage
call :log "Backing up storage info..."
set "STORAGE_BACKUP=%BACKUP_PATH%\storage"
mkdir "%STORAGE_BACKUP%"

echo {"backup_type": "storage", "timestamp": "%TIMESTAMP%", "note": "Download storage files from Supabase Dashboard"} > "%STORAGE_BACKUP%\MANIFEST.json"

call :log "Storage backup info created"
goto :eof

:compress_backup
call :log "Compressing backup..."
cd /d "%BACKUP_DIR%"

REM Use PowerShell to create zip
powershell -Command "Compress-Archive -Path '%TIMESTAMP%' -DestinationPath 'meow_chat_backup_%TIMESTAMP%.zip' -Force"

REM Remove uncompressed folder
rmdir /s /q "%TIMESTAMP%"

call :log "Backup compressed: meow_chat_backup_%TIMESTAMP%.zip"
goto :eof
