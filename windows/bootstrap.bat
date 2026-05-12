@echo off
setlocal

title Simplify3x Security
cls

set "GLOBAL_PATH=C:\ProgramData\S3X_Security"
set "INSTALLER_URL=https://raw.githubusercontent.com/rahulraom2002/simplify3x-wazuh-deployment/main/windows/S3X_Install.ps1"
set "LAUNCHER_URL=https://raw.githubusercontent.com/rahulraom2002/simplify3x-wazuh-deployment/main/windows/launcher.ps1"

set "INSTALLER=%GLOBAL_PATH%\S3X_Install.ps1"
set "LAUNCHER=%GLOBAL_PATH%\launcher.ps1"

echo.
echo Simplify3x Security - Endpoint Compliance
echo ------------------------------------------
echo Host: %COMPUTERNAME%
echo User: %USERNAME%
echo.

echo [1/4] Preparing staging...
if not exist "%GLOBAL_PATH%" mkdir "%GLOBAL_PATH%"

echo [2/4] Downloading installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri '%INSTALLER_URL%' -OutFile '%INSTALLER%'"

if not exist "%INSTALLER%" (
    echo INSTALLER DOWNLOAD FAILED
    pause
    exit /b 1
)

echo [3/4] Downloading launcher...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"Invoke-WebRequest -Uri '%LAUNCHER_URL%' -OutFile '%LAUNCHER%'"

if not exist "%LAUNCHER%" (
    echo LAUNCHER DOWNLOAD FAILED
    pause
    exit /b 2
)

echo [4/4] Launching deployment...
powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%"

timeout /t 3 >nul
exit
