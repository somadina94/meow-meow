@echo off
REM ============================================================================
REM Meow Chat - Application Restart Script (Windows)
REM ============================================================================
REM Description: Restarts the Meow Chat application (shutdown + startup)
REM Usage: restart.bat [environment] [/force] [/clean]
REM Environments: development, staging, production
REM Options:
REM   /force    Force restart without graceful shutdown
REM   /clean    Clean build before restart
REM ============================================================================

setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURATION
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "LOG_DIR=%PROJECT_ROOT%\logs"
set "ENVIRONMENT=development"
set "FORCE_RESTART=false"
set "CLEAN_BUILD=false"

REM Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="development" set "ENVIRONMENT=development" & shift & goto :parse_args
if /i "%~1"=="dev" set "ENVIRONMENT=development" & shift & goto :parse_args
if /i "%~1"=="staging" set "ENVIRONMENT=staging" & shift & goto :parse_args
if /i "%~1"=="preview" set "ENVIRONMENT=staging" & shift & goto :parse_args
if /i "%~1"=="production" set "ENVIRONMENT=production" & shift & goto :parse_args
if /i "%~1"=="prod" set "ENVIRONMENT=production" & shift & goto :parse_args
if /i "%~1"=="/force" set "FORCE_RESTART=true" & shift & goto :parse_args
if /i "%~1"=="-f" set "FORCE_RESTART=true" & shift & goto :parse_args
if /i "%~1"=="/clean" set "CLEAN_BUILD=true" & shift & goto :parse_args
if /i "%~1"=="-c" set "CLEAN_BUILD=true" & shift & goto :parse_args
shift
goto :parse_args
:args_done

REM Create timestamp for log file
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%"
set "LOG_FILE=%LOG_DIR%\restart_%TIMESTAMP%.log"

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
REM Create log directory
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :log "============================================"
call :log "Meow Chat - Restart Script (Windows)"
call :log "Environment: %ENVIRONMENT%"
call :log "Force Restart: %FORCE_RESTART%"
call :log "Clean Build: %CLEAN_BUILD%"
call :log "============================================"

REM Run shutdown
call :log "Running shutdown..."
if "%FORCE_RESTART%"=="true" (
    call "%SCRIPT_DIR%shutdown.bat" /force
) else (
    call "%SCRIPT_DIR%shutdown.bat"
)

REM Clean build if requested
if "%CLEAN_BUILD%"=="true" (
    call :log "Cleaning build artifacts..."
    if exist "%PROJECT_ROOT%\dist" rmdir /s /q "%PROJECT_ROOT%\dist"
    if exist "%PROJECT_ROOT%\node_modules\.vite" rmdir /s /q "%PROJECT_ROOT%\node_modules\.vite"
    call :log "Clean complete"
)

REM Wait before starting
call :log "Waiting before startup..."
timeout /t 2 /nobreak >nul

REM Run startup
call :log "Running startup..."
call "%SCRIPT_DIR%startup.bat" %ENVIRONMENT%

call :log "============================================"
call :log "Restart complete!"
call :log "Log file: %LOG_FILE%"
call :log "============================================"

endlocal
exit /b 0
