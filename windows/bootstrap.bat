@echo off
setlocal EnableDelayedExpansion

set "GLOBAL_PATH=C:\ProgramData\S3X_Security"
set "TARGET=%GLOBAL_PATH%\S3X_Install.ps1"
set "LAUNCHER=%GLOBAL_PATH%\launcher.ps1"
set "LOG=%USERPROFILE%\Desktop\s3x_debug.log"

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
    call :L "STEP 5 - FAIL: PS1 not found"
    echo   [FAIL]  Download failed. Log: %LOG%
    pause
    exit /b 2
)
call :L "STEP 5 - PS1 OK"
echo   [ OK ]  Deployment modules ready.

echo   [3/3]  Authenticating security session...
echo.
call :L "STEP 6 - Writing launcher.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Content -Path '%LAUNCHER%' -Value '' -Encoding UTF8" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' 'Add-Type -AssemblyName System.DirectoryServices.AccountManagement'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' 'function Test-Pw($u,$p) {'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    try {'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(''Machine'')'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '        return $ctx.ValidateCredentials($u.Split(''\\'')[-1], $p)'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    } catch { return $false }'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '}'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '$sec = $null'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' 'if (Test-Pw ''.\administrator'' ''Simplify@7685'') {'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    $sec = ConvertTo-SecureString ''Simplify@7685'' -AsPlainText -Force'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Write-Host ''  [ OK ]  Primary verified'' -ForegroundColor Green'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '} elseif (Test-Pw ''.\administrator'' ''34001360'') {'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    $sec = ConvertTo-SecureString ''34001360'' -AsPlainText -Force'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Write-Host ''  [ OK ]  Fallback verified'' -ForegroundColor Yellow'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '} else {'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Write-Host ''  [FAIL]  Both passwords rejected'' -ForegroundColor Red'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Read-Host ''Press Enter'''" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    exit 1'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '}'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '$cred = New-Object System.Management.Automation.PSCredential(''.\administrator'', $sec)'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '$pargs = ''-NoProfile -ExecutionPolicy Bypass -File '''''' + ''%TARGET%'' + '''''''" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' 'Write-Host ''  [  >>  ]  Elevating - please wait...'' -ForegroundColor Cyan'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' 'try {'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Start-Process powershell.exe -ArgumentList $pargs -Credential $cred -WorkingDirectory ''C:\Windows\System32'' -WindowStyle Maximized -ErrorAction Stop'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Add-Content -Path ''%LOG%'' -Value ''[LAUNCHER] Start-Process OK'''" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '} catch {'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    $msg = ''[LAUNCHER] FAIL: '' + $_.ToString()'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Add-Content -Path ''%LOG%'' -Value $msg'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Write-Host $msg -ForegroundColor Red'" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '    Read-Host ''Press Enter'''" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Content '%LAUNCHER%' '}'" >> "%LOG%" 2>&1

call :L "STEP 6 - Launcher written"

if not exist "%LAUNCHER%" (
    call :L "STEP 6 - FAIL: launcher not created"
    echo   [FAIL]  Launcher not created. See: %LOG%
    pause
    exit /b 3
)
call :L "STEP 6 - launcher.ps1 OK, running now"
echo   Please wait - authenticating...

powershell -NoProfile -ExecutionPolicy Bypass -File "%LAUNCHER%"

call :L "STEP 6 - Launcher done (errorlevel=%ERRORLEVEL%)"

echo.
echo   Deployment console launched. This window will close.
echo   Simplify3x Cyber Defence Team
echo.
:: ── Cleanup ──────────────────────────────────────────────────
:: Capture all paths into variables BEFORE exit.
:: Detached cmd fires 6s later (parent already gone, all locks released):
::   1. del BAT file itself
::   2. del launcher.ps1
::   3. rd  entire S3X_Security folder + all contents
::   4. del debug log on Desktop  (last - still readable if earlier step fails)
:: Paths quoted with \" inside the cmd /c string to handle spaces in usernames.

set "SELF=%~f0"
set "LCH=%LAUNCHER%"
set "GPATH=%GLOBAL_PATH%"
set "LOGF=%LOG%"

start "" /b cmd /c "timeout /t 6 /nobreak >nul & del /f /q \"!SELF!\" & del /f /q \"!LCH!\" & rd /s /q \"!GPATH!\" & del /f /q \"!LOGF!\""

timeout /t 5 /nobreak >nul
exit
