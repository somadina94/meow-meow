@echo off
REM ============================================================================
REM Meow Chat - Application Shutdown Script (Windows)
REM ============================================================================
REM Description: Gracefully shuts down the Meow Chat application
REM Usage: shutdown.bat [/force]
REM Options:
REM   /force    Force kill all processes without graceful shutdown
REM ============================================================================

setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURATION
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "LOG_DIR=%PROJECT_ROOT%\logs"
set "FORCE_KILL=false"

REM Parse arguments
if /i "%~1"=="/force" set "FORCE_KILL=true"
if /i "%~1"=="-f" set "FORCE_KILL=true"

REM Create timestamp for log file
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%"
set "LOG_FILE=%LOG_DIR%\shutdown_%TIMESTAMP%.log"

REM Ports used by the application
set "PORTS=5173 4173 80 8080 3000"

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
call :log "Meow Chat - Shutdown Script (Windows)"
call :log "Force Kill: %FORCE_KILL%"
call :log "Project Root: %PROJECT_ROOT%"
call :log "============================================"

REM Kill Node.js processes on application ports
call :log "Stopping processes on application ports..."

for %%p in (%PORTS%) do (
    call :kill_port %%p
)

REM Kill any remaining Node.js processes related to the project
call :log "Checking for remaining Node.js processes..."
tasklist /FI "IMAGENAME eq node.exe" /FO CSV 2>nul | find "node.exe" >nul
if not errorlevel 1 (
    if "%FORCE_KILL%"=="true" (
        call :log "Force killing all Node.js processes..."
        taskkill /F /IM node.exe 2>nul
    ) else (
        call :log "Node.js processes still running. Use /force to kill all."
    )
)

REM Cleanup temporary files
call :log "Cleaning up temporary files..."
if exist "%PROJECT_ROOT%\node_modules\.vite" (
    rmdir /s /q "%PROJECT_ROOT%\node_modules\.vite" 2>nul
    call :log "  Removed Vite cache"
)

call :log "============================================"
call :log "Shutdown complete!"
call :log "Log file: %LOG_FILE%"
call :log "============================================"

endlocal
exit /b 0

:kill_port
set "port=%~1"
call :log "Checking port %port%..."

for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%port%" ^| findstr "LISTENING" 2^>nul') do (
    set "pid=%%a"
    if not "!pid!"=="" (
        call :log "  Killing process !pid! on port %port%..."
        if "%FORCE_KILL%"=="true" (
            taskkill /F /PID !pid! 2>nul
        ) else (
            taskkill /PID !pid! 2>nul
        )
    )
)
goto :eof
