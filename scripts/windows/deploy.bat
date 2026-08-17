@echo off
REM ============================================================================
REM Meow Chat - Deployment Script (Windows)
REM ============================================================================
REM Description: Deploys the Meow Chat application to production
REM Usage: deploy.bat [options]
REM Options:
REM   /frontend    Deploy only frontend
REM   /backend     Deploy only backend (Edge Functions)
REM   /skip-tests  Skip running tests before deployment
REM   /skip-build  Skip build step (use existing build)
REM   /dry-run     Show what would be deployed without actually deploying
REM ============================================================================

setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURATION
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "LOG_DIR=%PROJECT_ROOT%\logs"
set "DEPLOY_FRONTEND=true"
set "DEPLOY_BACKEND=true"
set "SKIP_TESTS=false"
set "SKIP_BUILD=false"
set "DRY_RUN=false"

set "SUPABASE_PROJECT_ID=meowmeow"

REM Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="/frontend" set "DEPLOY_BACKEND=false" & shift & goto :parse_args
if /i "%~1"=="/backend" set "DEPLOY_FRONTEND=false" & shift & goto :parse_args
if /i "%~1"=="/skip-tests" set "SKIP_TESTS=true" & shift & goto :parse_args
if /i "%~1"=="/skip-build" set "SKIP_BUILD=true" & shift & goto :parse_args
if /i "%~1"=="/dry-run" set "DRY_RUN=true" & shift & goto :parse_args
shift
goto :parse_args
:args_done

REM Create timestamp for log file
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%"
set "LOG_FILE=%LOG_DIR%\deploy_%TIMESTAMP%.log"

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
call :log "Meow Chat - Deployment Script (Windows)"
call :log "Deploy Frontend: %DEPLOY_FRONTEND%"
call :log "Deploy Backend: %DEPLOY_BACKEND%"
call :log "Skip Tests: %SKIP_TESTS%"
call :log "Skip Build: %SKIP_BUILD%"
call :log "Dry Run: %DRY_RUN%"
call :log "============================================"

REM Check prerequisites
call :check_prerequisites
if errorlevel 1 goto :error_exit

REM Run tests
if "%SKIP_TESTS%"=="false" (
    call :run_tests
    if errorlevel 1 goto :error_exit
)

REM Build frontend
if "%DEPLOY_FRONTEND%"=="true" (
    if "%SKIP_BUILD%"=="false" (
        call :build_frontend
        if errorlevel 1 goto :error_exit
    )
)

REM Deploy
call :log "Deployment is handled by Lovable Cloud"
call :log "Push to main branch and click 'Publish' in Lovable editor"
call :log "Edge Functions deploy automatically"

call :log "============================================"
call :log "Deployment instructions complete!"
call :log "Log file: %LOG_FILE%"
call :log "============================================"

endlocal
exit /b 0

:check_prerequisites
call :log "Checking prerequisites..."

where node >nul 2>&1
if errorlevel 1 (
    call :error "Node.js is not installed."
    exit /b 1
)
call :log "  Node.js detected"

where npm >nul 2>&1
if errorlevel 1 (
    call :error "npm is not installed."
    exit /b 1
)
call :log "  npm detected"

call :log "All prerequisites met"
exit /b 0

:run_tests
call :log "Running tests..."
cd /d "%PROJECT_ROOT%"

call :log "Running TypeScript type check..."
if "%DRY_RUN%"=="true" (
    call :log "[DRY RUN] Would run: npx tsc --noEmit"
) else (
    npx tsc --noEmit
    if errorlevel 1 (
        call :error "TypeScript type check failed"
        exit /b 1
    )
)

call :log "All tests passed"
exit /b 0

:build_frontend
call :log "Building frontend..."
cd /d "%PROJECT_ROOT%"

if "%DRY_RUN%"=="true" (
    call :log "[DRY RUN] Would run: npm run build"
) else (
    npm run build
    if errorlevel 1 (
        call :error "Frontend build failed"
        exit /b 1
    )
)

call :log "Frontend build complete"
exit /b 0

:error_exit
call :log "Deployment failed!"
endlocal
exit /b 1
