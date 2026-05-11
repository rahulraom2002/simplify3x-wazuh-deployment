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
    Write-Host "  TIME    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor $CY
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
}

function Write-OK($msg) {
    Write-Host "  [ OK ]  $msg" -ForegroundColor $CG
}

function Write-Warn2($msg) {
    Write-Host "  [WARN]  $msg" -ForegroundColor $CY
}

function Write-Fail($msg) {
    Write-Host "  [FAIL]  $msg" -ForegroundColor $CR
}

Write-Banner

# CONFIG
$StagingPath = "C:\ProgramData\S3X_Security"
$MSI_URL = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.4-1.msi"
$CONFIG_URL = "https://raw.githubusercontent.com/rahulraom2002/simplify3x-wazuh-deployment/main/windows/ossec.conf"
$MSI_PATH = "$StagingPath\wazuh_installer.msi"
$LogPath = "$StagingPath\wazuh_msi_log.txt"
$AgentPath = "C:\Program Files (x86)\ossec-agent"

if (!(Test-Path $StagingPath)) {
    New-Item -Path $StagingPath -ItemType Directory -Force | Out-Null
}

# ============================================================
# PHASE 1
# ============================================================
Write-Section "PHASE 1  -  SYSTEM PREPARATION"
Write-Step "Terminating conflicting security processes..."

Stop-Service WazuhSvc -Force -ErrorAction SilentlyContinue
Stop-Service OssecSvc -Force -ErrorAction SilentlyContinue

sc.exe stop WazuhSvc | Out-Null
sc.exe stop OssecSvc | Out-Null

taskkill /F /IM wazuh-agent.exe /T 2>$null
taskkill /F /IM wazuh-agent-auth.exe /T 2>$null
taskkill /F /IM wazuh-agentd.exe /T 2>$null
taskkill /F /IM ossec-agent.exe /T 2>$null
taskkill /F /IM ossec-agent-auth.exe /T 2>$null

Start-Sleep -Seconds 5

# FAST registry detection
$wazuhUninstall = Get-ChildItem `
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" `
-ErrorAction SilentlyContinue |
Get-ItemProperty |
Where-Object { $_.DisplayName -like "*Wazuh*" }

if ($wazuhUninstall) {
    Write-Warn2 "Existing Wazuh detected. Removing previous installation..."

    foreach ($app in $wazuhUninstall) {
        if ($app.UninstallString) {
            $guid = ($app.UninstallString -replace '.*\{','{')

            Start-Process msiexec.exe `
                -ArgumentList "/x $guid /qn /norestart" `
                -Wait
        }
    }

    Start-Sleep -Seconds 10
}

Write-OK "Environment cleared"

# ============================================================
# PHASE 2
# ============================================================
Write-Section "PHASE 2  -  ACQUIRING SECURITY BINARIES"
Write-Step "Contacting Wazuh distribution network..."

Invoke-WebRequest -Uri $MSI_URL -OutFile $MSI_PATH -UserAgent "Mozilla/5.0"

if (!(Test-Path $MSI_PATH)) {
    Write-Fail "MSI download failed"
    pause
    exit 1
}

$size = [math]::Round((Get-Item $MSI_PATH).Length / 1MB, 1)
Write-OK "Agent binary received ($size MB)"

# ============================================================
# PHASE 3
# ============================================================
Write-Section "PHASE 3  -  DEPLOYING ENDPOINT SHIELD"
Write-Step "Initiating silent installation..."

$installArgs = "/i `"$MSI_PATH`" /qn /norestart /L*V `"$LogPath`" WAZUH_MANAGER='10.0.74.29' WAZUH_AGENT_GROUP='endpoints-workstations-windows' ALLUSERS=1"

$process = Start-Process msiexec.exe `
    -ArgumentList $installArgs `
    -Wait `
    -PassThru

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

$StagingConfig = "$StagingPath\ossec_new.conf"
$DestConfig = "$AgentPath\ossec.conf"

Write-Step "Downloading Hybrid-Guard policy bundle..."

Invoke-WebRequest -Uri $CONFIG_URL -OutFile $StagingConfig -UserAgent "Mozilla/5.0"

if (!(Test-Path $StagingConfig)) {
    Write-Fail "Config download failed"
    pause
    exit 1
}

if (!(Select-String -Path $StagingConfig -Pattern "<ossec_config>" -Quiet)) {
    Write-Fail "Downloaded config invalid"
    pause
    exit 1
}

Copy-Item $StagingConfig $DestConfig -Force

Write-OK "Security policies applied"

# ============================================================
# PHASE 5
# ============================================================
Write-Section "PHASE 5  -  STARTING AGENT"

Write-Step "Starting Wazuh service..."

Start-Service WazuhSvc -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

$svc = Get-Service WazuhSvc -ErrorAction SilentlyContinue

if ($svc -and $svc.Status -eq "Running") {
    Write-OK "Wazuh agent active"
}
else {
    Write-Warn2 "Service start check incomplete"
}

# ============================================================
# PHASE 6
# ============================================================
Write-Section "PHASE 6  -  CLEANUP"

Remove-Item $MSI_PATH -Force -ErrorAction SilentlyContinue
Remove-Item $StagingConfig -Force -ErrorAction SilentlyContinue

Write-OK "Cleanup complete"

Write-Host ""
Write-Host "  +============================================================+" -ForegroundColor $CG
Write-Host "  |                                                            |" -ForegroundColor $CG
Write-Host "  |   ENDPOINT SHIELD DEPLOYMENT SUCCESSFUL                    |" -ForegroundColor $CW
Write-Host "  |   TEST MODE : AUTO REBOOT DISABLED                         |" -ForegroundColor $CY
Write-Host "  |                                                            |" -ForegroundColor $CG
Write-Host "  +============================================================+" -ForegroundColor $CG
Write-Host ""

pause
exit
