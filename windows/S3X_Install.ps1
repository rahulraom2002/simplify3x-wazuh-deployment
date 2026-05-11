# ============================================================
#  Simplify3x Cyber Defence Team
#  Endpoint Shield - Deployment Engine
# ============================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"
Clear-Host

$Host.UI.RawUI.WindowTitle = "Simplify3x Cyber Defence Team  |  Endpoint Shield"

$CC = [ConsoleColor]::Cyan
$CG = [ConsoleColor]::Green
$CR = [ConsoleColor]::Red
$CY = [ConsoleColor]::Yellow
$CW = [ConsoleColor]::White
$CM = [ConsoleColor]::Magenta
$CD = [ConsoleColor]::DarkCyan
$DG = [ConsoleColor]::DarkGray

function Write-Banner {
    Write-Host ""
    Write-Host "  +============================================================+" -ForegroundColor $CC
    Write-Host "  |                                                            |" -ForegroundColor $CC
    Write-Host "  |      SIMPLIFY3X  CYBER  DEFENCE  TEAM                     |" -ForegroundColor $CW
    Write-Host "  |      Endpoint Shield  .  Deployment Console               |" -ForegroundColor $CD
    Write-Host "  |                                                            |" -ForegroundColor $CC
    Write-Host "  +============================================================+" -ForegroundColor $CC
    Write-Host ""
    Write-Host "  TARGET  : $env:COMPUTERNAME" -ForegroundColor $CY
    Write-Host "  TIME    : $(Get-Date -Format 'yyyy-MM-dd  HH:mm:ss')" -ForegroundColor $CY
    Write-Host "  ------------------------------------------------------------" -ForegroundColor $DG
    Write-Host ""
}

function Write-Section($title) {
    Write-Host ""
    Write-Host "  [ $title ]" -ForegroundColor $CM
    Write-Host "  ------------------------------------------------------------" -ForegroundColor $DG
}

function Write-Step($msg) {
    Write-Host "  >>  $msg" -ForegroundColor $CC
    Start-Sleep -Milliseconds 500
}

function Write-OK($msg) {
    Write-Host "  [ OK ]  $msg" -ForegroundColor $CG
    Start-Sleep -Milliseconds 300
}

function Write-Warn2($msg) {
    Write-Host "  [WARN]  $msg" -ForegroundColor $CY
}

function Write-Fail($msg) {
    Write-Host "  [FAIL]  $msg" -ForegroundColor $CR
}

Write-Banner

# ============================================================
# CONFIG
# ============================================================
$StagingPath = "C:\ProgramData\S3X_Security"

if (!(Test-Path $StagingPath)) {
    New-Item -Path $StagingPath -ItemType Directory -Force | Out-Null
}

$MSI_URL    = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.4-1.msi"
$CONFIG_URL = "https://raw.githubusercontent.com/rahulraom2002/simplify3x-wazuh-deployment/main/windows/ossec.conf"
$MSI_PATH   = "$StagingPath\wazuh_installer.msi"
$LogPath    = "$StagingPath\wazuh_msi_log.txt"
$AgentPath  = "C:\Program Files (x86)\ossec-agent"

# ============================================================
# MOVEFILEEX
# ============================================================
$MoveFileCode = @"
using System;
using System.Runtime.InteropServices;
public class KernelIO {
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern bool MoveFileEx(string src, string dst, uint flags);
    public const uint DELAY_UNTIL_REBOOT = 0x4;
    public const uint REPLACE_EXISTING   = 0x1;
}
"@

Add-Type -TypeDefinition $MoveFileCode -Language CSharp -ErrorAction SilentlyContinue

# ============================================================
# PHASE 1
# ============================================================
Write-Section "PHASE 1  -  SYSTEM PREPARATION"
Write-Step "Terminating conflicting security processes..."

Stop-Service -Name "WazuhSvc" -Force -ErrorAction SilentlyContinue
Get-Process | Where-Object { $_.Name -match "wazuh|ossec" } | Stop-Process -Force -ErrorAction SilentlyContinue

Write-OK "Environment cleared"

# ============================================================
# PHASE 2
# ============================================================
Write-Section "PHASE 2  -  ACQUIRING SECURITY BINARIES"
Write-Step "Contacting Wazuh distribution network..."

Invoke-WebRequest -Uri $MSI_URL -OutFile $MSI_PATH -UserAgent "Mozilla/5.0" -UseBasicParsing

if (!(Test-Path $MSI_PATH)) {
    Write-Fail "MSI download failed"
    pause
    exit 1
}

Write-OK "Agent binary received  ($([math]::Round((Get-Item $MSI_PATH).Length/1MB,1)) MB)"

# ============================================================
# PHASE 3
# ============================================================
Write-Section "PHASE 3  -  DEPLOYING ENDPOINT SHIELD"
Write-Step "Initiating silent installation..."

$installArgs = "/i `"$MSI_PATH`" /qn /L*V `"$LogPath`" WAZUH_MANAGER='10.0.74.29' WAZUH_AGENT_GROUP='endpoints-workstations-windows' ALLUSERS=1"

$process = Start-Process msiexec.exe -ArgumentList $installArgs -Wait -PassThru

if ($process.ExitCode -ne 0) {
    Write-Fail "Shield core installation failed (exit $($process.ExitCode))"
    Write-Host ""
    Write-Host "MSI Log: $LogPath" -ForegroundColor Yellow
    pause
    exit 1
}

Write-OK "Shield core installed"

# ============================================================
# PHASE 4
# ============================================================
Write-Section "PHASE 4  -  APPLYING SECURITY POLICIES"

if (Test-Path $AgentPath) {

    Write-Step "Downloading Hybrid-Guard policy bundle..."

    $StagingConfig = "$StagingPath\ossec_new.conf"
    $DestConfig    = "$AgentPath\ossec.conf"

    Invoke-WebRequest -Uri $CONFIG_URL -OutFile $StagingConfig -UserAgent "Mozilla/5.0" -UseBasicParsing

    if (!(Test-Path $StagingConfig)) {
        Write-Fail "Config download failed"
        pause
        exit 1
    }

    try {
        Copy-Item -Path $StagingConfig -Destination $DestConfig -Force -ErrorAction Stop
        Write-OK "Security policies applied - live"
    }
    catch {
        Write-Warn2 "Config file locked - scheduling kernel-level swap at reboot"
        [KernelIO]::MoveFileEx(
            $StagingConfig,
            $DestConfig,
            ([KernelIO]::DELAY_UNTIL_REBOOT -bor [KernelIO]::REPLACE_EXISTING)
        ) | Out-Null
    }

} else {
    Write-Warn2 "Agent path not found - policy deployment skipped"
}

# ============================================================
# PHASE 5
# ============================================================
Write-Section "PHASE 5  -  SANITISING DEPLOYMENT TRACES"

$cleanCmd = "timeout /t 8 /nobreak >nul & rd /s /q `"$StagingPath`""
Start-Process cmd.exe -ArgumentList "/c $cleanCmd" -WindowStyle Hidden

$filesToPurge = @(
    "$StagingPath\wazuh_installer.msi",
    "$StagingPath\wazuh_msi_log.txt",
    "$StagingPath\ossec_new.conf",
    "$StagingPath\S3X_Install.ps1"
)

foreach ($f in $filesToPurge) {
    [KernelIO]::MoveFileEx($f, $null, [KernelIO]::DELAY_UNTIL_REBOOT) | Out-Null
}

[KernelIO]::MoveFileEx($StagingPath, $null, [KernelIO]::DELAY_UNTIL_REBOOT) | Out-Null

Write-OK "Staging area scheduled for purge"

# ============================================================
# PHASE 6
# ============================================================
Write-Section "PHASE 6  -  FINALISING"

Write-Host ""
Write-Host "  +============================================================+" -ForegroundColor $CR
Write-Host "  |                                                            |" -ForegroundColor $CR
Write-Host "  |   SYSTEM RESTART INITIATED  -  T-60 SECONDS               |" -ForegroundColor $CW
Write-Host "  |   Endpoint Shield will be active after reboot.            |" -ForegroundColor $CY
Write-Host "  |                                                            |" -ForegroundColor $CR
Write-Host "  +============================================================+" -ForegroundColor $CR
Write-Host ""
Write-Host "  Simplify3x Cyber Defence Team  -  Deployment complete." -ForegroundColor $CD
Write-Host ""

shutdown.exe /r /f /t 60 /c "Simplify3x Cyber Defence: Finalizing Endpoint Shield."

Start-Sleep -Seconds 10
exit
