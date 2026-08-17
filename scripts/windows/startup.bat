@echo off
REM ============================================================================
REM Meow Chat - Application Startup Script (Windows)
REM ============================================================================
REM Description: Starts the Meow Chat application and all required services
REM Usage: startup.bat [environment]
REM Environments: development, staging, production
REM ============================================================================

setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURATION
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%..\.."
set "LOG_DIR=%PROJECT_ROOT%\logs"
set "ENVIRONMENT=%~1"

if "%ENVIRONMENT%"=="" set "ENVIRONMENT=development"

REM Create timestamp for log file
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%"
set "LOG_FILE=%LOG_DIR%\startup_%TIMESTAMP%.log"

REM Port configuration
set "DEV_PORT=5173"
set "PREVIEW_PORT=4173"
set "PROD_PORT=80"

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
call :log "Meow Chat - Startup Script (Windows)"
call :log "Environment: %ENVIRONMENT%"
call :log "Project Root: %PROJECT_ROOT%"
call :log "============================================"

REM Check prerequisites
call :check_prerequisites
if errorlevel 1 goto :error_exit

REM Start based on environment
if /i "%ENVIRONMENT%"=="development" goto :start_development
if /i "%ENVIRONMENT%"=="dev" goto :start_development
if /i "%ENVIRONMENT%"=="staging" goto :start_preview
if /i "%ENVIRONMENT%"=="preview" goto :start_preview
if /i "%ENVIRONMENT%"=="production" goto :start_production
if /i "%ENVIRONMENT%"=="prod" goto :start_production

call :error "Unknown environment: %ENVIRONMENT%"
echo Usage: %~nx0 [development^|staging^|production]
goto :error_exit

:check_prerequisites
call :log "Checking prerequisites..."

REM Check Node.js
where node >nul 2>&1
if errorlevel 1 (
    call :error "Node.js is not installed. Please install Node.js v18 or higher."
    exit /b 1
)
for /f "tokens=*" %%i in ('node -v') do set NODE_VERSION=%%i
call :log "  Node.js %NODE_VERSION% detected"

REM Check npm
where npm >nul 2>&1
if errorlevel 1 (
    call :error "npm is not installed."
    exit /b 1
)
for /f "tokens=*" %%i in ('npm -v') do set NPM_VERSION=%%i
call :log "  npm %NPM_VERSION% detected"

REM Check dependencies
if not exist "%PROJECT_ROOT%\node_modules" (
    call :log "Installing dependencies..."
    cd /d "%PROJECT_ROOT%"
    npm install
)
call :log "  Dependencies installed"

REM Check environment file
if not exist "%PROJECT_ROOT%\.env" (
    if exist "%PROJECT_ROOT%\.env.example" (
        call :log "Creating .env from .env.example..."
        copy "%PROJECT_ROOT%\.env.example" "%PROJECT_ROOT%\.env" >nul
        call :log "  Please configure your .env file with proper values"
    ) else (
        call :error ".env file not found."
        exit /b 1
    )
)
call :log "  Environment file exists"

call :log "All prerequisites met"
exit /b 0

:start_development
call :log "Starting development server..."
cd /d "%PROJECT_ROOT%"
start "Meow Chat Dev Server" cmd /c "npm run dev > "%LOG_DIR%\dev_server.log" 2>&1"
call :log "Development server starting on http://localhost:%DEV_PORT%"
timeout /t 5 /nobreak >nul
call :log "Startup complete!"
goto :success_exit

:start_preview
call :log "Starting preview server..."
call :log "Building application..."
cd /d "%PROJECT_ROOT%"
npm run build
start "Meow Chat Preview Server" cmd /c "npm run preview > "%LOG_DIR%\preview_server.log" 2>&1"
call :log "Preview server starting on http://localhost:%PREVIEW_PORT%"
timeout /t 3 /nobreak >nul
call :log "Startup complete!"
goto :success_exit

:start_production
call :log "Starting production server..."
call :log "Building application for production..."
cd /d "%PROJECT_ROOT%"
npm run build

REM Check if serve is installed
where serve >nul 2>&1
if errorlevel 1 (
    call :log "Installing serve globally..."
    npm install -g serve
)

start "Meow Chat Production Server" cmd /c "serve -s dist -l %PROD_PORT% > "%LOG_DIR%\prod_server.log" 2>&1"
call :log "Production server starting on http://localhost:%PROD_PORT%"
timeout /t 3 /nobreak >nul
call :log "Startup complete!"
goto :success_exit

:success_exit
call :log "============================================"
call :log "Application started successfully!"
call :log "Log file: %LOG_FILE%"
call :log "============================================"
endlocal
exit /b 0

:error_exit
call :log "Startup failed!"
endlocal
exit /b 1
