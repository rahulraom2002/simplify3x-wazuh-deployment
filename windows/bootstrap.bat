@echo off
setlocal EnableDelayedExpansion

C:

set "GLOBAL_PATH=C:\ProgramData\S3X_Security"
set "TARGET=%GLOBAL_PATH%\S3X_Install.ps1"
set "LAUNCHER=%GLOBAL_PATH%\launcher.ps1"
set "LOG=%GLOBAL_PATH%\s3x_debug.log"

if not exist "%GLOBAL_PATH%" mkdir "%GLOBAL_PATH%" >nul 2>&1

goto :MAIN

:L
    echo [%DATE% %TIME%] %~1
    echo [%DATE% %TIME%] %~1 >> "%LOG%" 2>&1
    goto :EOF

:MAIN
call :L "=== RunMe.bat START ==="
call :L "HOST=%COMPUTERNAME%  USER=%USERNAME%"

title Simplify3x Security
cls
echo.
echo Simplify3x Security - Endpoint Compliance
echo ------------------------------------------
echo Host: %COMPUTERNAME%
echo User: %USERNAME%
echo.

call :L "STEP 1 - Banner OK"

set "PS1_URL=https://raw.githubusercontent.com/rahulraom2002/simplify3x-wazuh-deployment/main/windows/S3X_Install.ps1"
set "LCH_URL=https://raw.githubusercontent.com/rahulraom2002/simplify3x-wazuh-deployment/main/windows/launcher.ps1"
call :L "STEP 2 - URLs set"

echo [1/3] Preparing staging area...
call :L "STEP 3 - Staging dir ready"

echo [2/3] Downloading deployment files...
call :L "STEP 4 - Downloading S3X_Install.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PS1_URL%' -OutFile '%TARGET%' -UserAgent 'Mozilla/5.0' -UseBasicParsing" >> "%LOG%" 2>&1
call :L "STEP 4 - Done (errorlevel=%ERRORLEVEL%)"

if not exist "%TARGET%" (
    call :L "STEP 4 - FAIL: S3X_Install.ps1 not found"
    echo [FAIL] Download failed. Log: %LOG%
    pause
    exit /b 2
)
call :L "STEP 4 - S3X_Install.ps1 OK"

call :L "STEP 5 - Downloading launcher.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%LCH_URL%' -OutFile '%LAUNCHER%' -UserAgent 'Mozilla/5.0' -UseBasicParsing" >> "%LOG%" 2>&1
call :L "STEP 5 - Done (errorlevel=%ERRORLEVEL%)"

if not exist "%LAUNCHER%" (
    call :L "STEP 5 - FAIL: launcher.ps1 not found"
    echo [FAIL] Launcher download failed. Log: %LOG%
    pause
    exit /b 3
)
call :L "STEP 5 - launcher.ps1 OK"
echo [OK] Files ready.

echo [3/3] Authenticating and launching...
echo.
call :L "STEP 6 - Running launcher.ps1"

:: Pass paths to launcher via environment variables - no quoting issues
set "S3X_TARGET=%TARGET%"
set "S3X_LOG=%LOG%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%"

call :L "STEP 6 - Launcher done (errorlevel=%ERRORLEVEL%)"

echo.
echo Deployment launched. This window will close.
echo.
call :L "STEP 7 - Cleanup"

set "SELF=%~f0"
set "LCH=%LAUNCHER%"
set "GPATH=%GLOBAL_PATH%"
set "LOGF=%LOG%"

start "" /b cmd /c "timeout /t 6 /nobreak >nul & del /f /q "!SELF!" & rd /s /q "!GPATH!""

timeout /t 5 /nobreak >nul
exit
