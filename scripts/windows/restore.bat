@echo off
REM ============================================================================
REM Meow Chat - Restore Script (Windows)
REM ============================================================================
REM Description: Restores the application from a backup
REM Usage: restore.bat <backup_path> [options]
REM Options:
REM   /code      Restore only code/configuration
REM   /db        Restore only database
REM   /storage   Restore only storage files
REM   /dry-run   Show what would be restored without actually doing it
REM   /confirm   Skip confirmation prompt
REM ============================================================================

setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURATION
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "LOG_DIR=%PROJECT_ROOT%\logs"
set "RESTORE_CODE=true"
set "RESTORE_DB=true"
set "RESTORE_STORAGE=true"
set "DRY_RUN=false"
set "SKIP_CONFIRM=false"
set "BACKUP_PATH="

REM First argument is backup path
if not "%~1"=="" (
    if not "%~1:~0,1%"=="/" (
        set "BACKUP_PATH=%~1"
        shift
    )
)

REM Parse remaining arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="/code" set "RESTORE_DB=false" & set "RESTORE_STORAGE=false" & shift & goto :parse_args
if /i "%~1"=="/db" set "RESTORE_CODE=false" & set "RESTORE_STORAGE=false" & shift & goto :parse_args
if /i "%~1"=="/storage" set "RESTORE_CODE=false" & set "RESTORE_DB=false" & shift & goto :parse_args
if /i "%~1"=="/dry-run" set "DRY_RUN=true" & shift & goto :parse_args
if /i "%~1"=="/confirm" set "SKIP_CONFIRM=true" & shift & goto :parse_args
if /i "%~1"=="/y" set "SKIP_CONFIRM=true" & shift & goto :parse_args
shift
goto :parse_args
:args_done

REM Validate backup path
if "%BACKUP_PATH%"=="" (
    echo ERROR: Backup path is required
    echo Usage: %~nx0 ^<backup_path^> [options]
    exit /b 1
)

REM Create timestamp for log file
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%"
set "LOG_FILE=%LOG_DIR%\restore_%TIMESTAMP%.log"

REM ============================================================================
REM UTILITY FUNCTIONS
REM ============================================================================

:log
echo [%date% %time%] %~1
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:error
echo [%date% %time%] ERROR: %~1 1>&2
echo [%date% %time%] ERROR: %~1 >> "%LOG_FILE%"
goto :eof

REM ============================================================================
REM MAIN EXECUTION
REM ============================================================================

:main
REM Create log directory
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :log "============================================"
call :log "Meow Chat - Restore Script (Windows)"
call :log "Backup Path: %BACKUP_PATH%"
call :log "Restore Code: %RESTORE_CODE%"
call :log "Restore Database: %RESTORE_DB%"
call :log "Restore Storage: %RESTORE_STORAGE%"
call :log "Dry Run: %DRY_RUN%"
call :log "============================================"

REM Check if backup is a zip file
echo %BACKUP_PATH% | findstr /i ".zip" >nul
if not errorlevel 1 (
    call :log "Extracting backup archive..."
    set "TEMP_DIR=%TEMP%\meow_restore_%TIMESTAMP%"
    mkdir "!TEMP_DIR!"
    powershell -Command "Expand-Archive -Path '%BACKUP_PATH%' -DestinationPath '!TEMP_DIR!' -Force"
    for /d %%i in ("!TEMP_DIR!\*") do set "BACKUP_PATH=%%i"
    call :log "Extracted to: !BACKUP_PATH!"
)

REM Validate backup exists
if not exist "%BACKUP_PATH%" (
    call :error "Backup not found: %BACKUP_PATH%"
    exit /b 1
)

REM Confirm restore
if "%SKIP_CONFIRM%"=="false" (
    if "%DRY_RUN%"=="false" (
        echo.
        echo WARNING: You are about to restore from a backup!
        echo This will OVERWRITE current files.
        echo.
        set /p CONFIRM="Type YES to confirm: "
        if /i not "!CONFIRM!"=="YES" (
            call :log "Restore cancelled by user"
            exit /b 0
        )
    )
)

REM Restore code
if "%RESTORE_CODE%"=="true" (
    call :restore_code
)

REM Restore database info
if "%RESTORE_DB%"=="true" (
    call :restore_database
)

REM Restore storage info
if "%RESTORE_STORAGE%"=="true" (
    call :restore_storage
)

call :log "============================================"
call :log "Restore complete!"
call :log "Log file: %LOG_FILE%"
call :log "============================================"

endlocal
exit /b 0

:restore_code
set "CODE_BACKUP=%BACKUP_PATH%\code"
if not exist "%CODE_BACKUP%" (
    call :log "Code backup not found, skipping"
    goto :eof
)

call :log "Restoring code..."

if "%DRY_RUN%"=="true" (
    call :log "[DRY RUN] Would restore code from %CODE_BACKUP%"
) else (
    if exist "%CODE_BACKUP%\src" (
        if exist "%PROJECT_ROOT%\src" rmdir /s /q "%PROJECT_ROOT%\src"
        xcopy /E /I /Y "%CODE_BACKUP%\src" "%PROJECT_ROOT%\src" >nul
        call :log "  Restored: src"
    )
    if exist "%CODE_BACKUP%\public" (
        if exist "%PROJECT_ROOT%\public" rmdir /s /q "%PROJECT_ROOT%\public"
        xcopy /E /I /Y "%CODE_BACKUP%\public" "%PROJECT_ROOT%\public" >nul
        call :log "  Restored: public"
    )
    if exist "%CODE_BACKUP%\supabase" (
        if exist "%PROJECT_ROOT%\supabase" rmdir /s /q "%PROJECT_ROOT%\supabase"
        xcopy /E /I /Y "%CODE_BACKUP%\supabase" "%PROJECT_ROOT%\supabase" >nul
        call :log "  Restored: supabase"
    )
    
    call :log "Reinstalling dependencies..."
    cd /d "%PROJECT_ROOT%"
    npm install
)

call :log "Code restore complete"
goto :eof

:restore_database
call :log "Database restore requires manual steps"
call :log "Use Supabase Dashboard SQL Editor to restore schema and data"
goto :eof

:restore_storage
call :log "Storage restore requires manual steps"
call :log "Upload files through Supabase Dashboard Storage"
goto :eof
