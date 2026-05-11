@echo off
setlocal EnableDelayedExpansion

:: Log goes to Desktop - writable by any user
set "LOG=%USERPROFILE%\Desktop\s3x_debug.log"
set "GLOBAL_PATH=C:\ProgramData\S3X_Security"
set "TARGET=%GLOBAL_PATH%\S3X_Install.ps1"

goto :MAIN

:L
    echo [%DATE% %TIME%] %~1
    echo [%DATE% %TIME%] %~1 >> "%LOG%" 2>&1
    goto :EOF

:MAIN

call :L "=== RunMe.bat START ==="
call :L "HOST=%COMPUTERNAME%  USER=%USERNAME%"

title Simplify3x Cyber Defence Team  -  Endpoint Shield
cls

echo.
echo   +============================================================+
echo   ^|                                                            ^|
echo   ^|      SIMPLIFY3X  CYBER  DEFENCE  TEAM                     ^|
echo   ^|      Endpoint Shield  .  Compliance Gateway               ^|
echo   ^|                                                            ^|
echo   +============================================================+
echo.
echo   TARGET  : %COMPUTERNAME%
echo   USER    : %USERNAME%
echo.

call :L "STEP 1 - Banner OK"

set "D_USER=.\administrator"
set "D_PASS1=Simplify@7685"
set "D_PASS2=34001360"
call :L "STEP 2 - Credentials set"

set "PS_URL=https://raw.githubusercontent.com/rahulraom2002/simplify3x-wazuh-deployment/main/windows/S3X_Install.ps1"
call :L "STEP 3 - URL set"

echo   [1/3]  Initialising secure staging area...
if not exist "%GLOBAL_PATH%" mkdir "%GLOBAL_PATH%" >nul 2>&1
call :L "STEP 4 - Staging dir ready"

echo   [2/3]  Acquiring deployment modules...
call :L "STEP 5 - Downloading PS1..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%TARGET%' -UserAgent 'Mozilla/5.0' -UseBasicParsing" >> "%LOG%" 2>&1
call :L "STEP 5 - Download done (errorlevel=%ERRORLEVEL%)"

if not exist "%TARGET%" (
    call :L "STEP 5 - FAIL: PS1 not found after download"
    echo.
    echo   [FAIL]  Download failed. See: %LOG%
    echo.
    pause
    exit /b 2
)
call :L "STEP 5 - PS1 exists OK"
echo   [ OK ]  Deployment modules ready.

echo   [3/3]  Authenticating security session...
echo.
call :L "STEP 6 - Starting auth+elevation PowerShell block"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$user='%D_USER%'; ^
$pass1='%D_PASS1%'; ^
$pass2='%D_PASS2%'; ^
$target='%TARGET%'; ^
$log='%LOG%'; ^
Add-Type -AssemblyName System.DirectoryServices.AccountManagement; ^
function Test-Pw($u,$p){ ^
    try { ^
        $ctx=New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine'); ^
        return $ctx.ValidateCredentials($u.Split('\\')[-1],$p); ^
    } catch { Add-Content $log "[PS] Test-Pw exception: $_"; return $false } ^
}; ^
Add-Content $log '[PS] Testing primary...'; ^
if(Test-Pw $user $pass1){ ^
    Add-Content $log '[PS] Primary OK'; ^
    Write-Host '  [ OK ]  Identity verified - primary channel.' -ForegroundColor Green; ^
    $sec=ConvertTo-SecureString $pass1 -AsPlainText -Force ^
} elseif(Test-Pw $user $pass2){ ^
    Add-Content $log '[PS] Fallback OK'; ^
    Write-Host '  [ OK ]  Identity verified - secondary channel.' -ForegroundColor Yellow; ^
    $sec=ConvertTo-SecureString $pass2 -AsPlainText -Force ^
} else { ^
    Add-Content $log '[PS] FAIL: both passwords rejected'; ^
    Write-Host '  [FAIL]  Authentication failed. Contact SOC team.' -ForegroundColor Red; ^
    Read-Host 'Press Enter'; ^
    exit ^
}; ^
Add-Content $log '[PS] Building credential object...'; ^
$cred=New-Object System.Management.Automation.PSCredential($user,$sec); ^
$pargs='-NoProfile -ExecutionPolicy Bypass -File """'+$target+'"""'; ^
Add-Content $log '[PS] Calling Start-Process...'; ^
try { ^
    Start-Process powershell.exe -ArgumentList $pargs -Credential $cred -WorkingDirectory 'C:\Windows\System32' -WindowStyle Maximized -ErrorAction Stop; ^
    Add-Content $log '[PS] Start-Process returned OK' ^
} catch { ^
    Add-Content $log "[PS] FAIL Start-Process: $_"; ^
    Write-Host "  [FAIL] $_" -ForegroundColor Red; ^
    Read-Host 'Press Enter' ^
}" >> "%LOG%" 2>&1

call :L "STEP 6 - PS block done (errorlevel=%ERRORLEVEL%)"

echo.
echo   Deployment console launched. This window will close.
echo   Simplify3x Cyber Defence Team
echo.

call :L "STEP 7 - Reached end, scheduling self-delete"

set "SELF=%~f0"
start "" /b cmd /c "timeout /t 6 /nobreak >nul & del /f /q !SELF!"

call :L "STEP 7 - Done. Exiting."
timeout /t 5 /nobreak >nul
exit
