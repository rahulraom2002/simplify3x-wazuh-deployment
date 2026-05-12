$installer = "C:\ProgramData\S3X_Security\S3X_Install.ps1"
$log = "C:\ProgramData\S3X_Security\launcher.log"

$primaryUser = ".\administrator"
$primaryPass = "Simplify@7685"
$secondaryPass = "34001360"

function Log {
    param($msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $log -Value "[$ts] $msg"
}

function Get-TokenState {
    try {
        $groups = whoami /groups | Out-String

        $isAdminGroup = $groups -match "S-1-5-32-544"
        $isDenyOnly = $groups -match "Group used for deny only"
        $isHigh = $groups -match "High Mandatory Level"

        if ($isAdminGroup -and $isHigh) {
            return "ElevatedAdmin"
        }

        if ($isAdminGroup -and $isDenyOnly) {
            return "LocalAdminNeedsElevation"
        }

        return "StandardUser"
    }
    catch {
        Log "Token detection exception: $_"
        return "StandardUser"
    }
}

function Test-Pw {
    param($u,$p)

    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
            [System.DirectoryServices.AccountManagement.ContextType]::Machine
        )

        $user = $u.Split('\')[-1]
        $ok = $ctx.ValidateCredentials($user,$p)

        Log "Credential test for $u = $ok"
        return $ok
    }
    catch {
        Log "Credential test exception: $_"
        return $false
    }
}

Log "======================================"
Log "Launcher started"
Log "User=$env:USERNAME"
Log "Host=$env:COMPUTERNAME"

Write-Host ""
Write-Host "Simplify3x Security - Launcher"
Write-Host "--------------------------------"

$state = Get-TokenState()
Log "Detected token state = $state"

# CASE 1 — already elevated
if ($state -eq "ElevatedAdmin") {
    Log "CASE 1: Elevated admin"

    Write-Host "[OK] Elevated administrative access detected."
    Write-Host "[INFO] Starting deployment..."

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
    exit
}

# CASE 2 — local admin but needs UAC elevation
if ($state -eq "LocalAdminNeedsElevation") {
    Log "CASE 2: Local admin requiring elevation"

    Write-Host "[INFO] Local admin detected. Requesting elevation..."

    try {
        Start-Process powershell.exe `
            -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installer`""

        Log "UAC elevation launched"
        exit
    }
    catch {
        Log "UAC elevation failed: $_"
    }
}

# CASE 3 — standard user
Log "CASE 3: Standard user fallback"

Write-Host "[INFO] Standard user detected. Using deployment credentials..."

if (Test-Pw $primaryUser $primaryPass) {
    Log "Primary credential valid"
    $sec = ConvertTo-SecureString $primaryPass -AsPlainText -Force
}
elseif (Test-Pw $primaryUser $secondaryPass) {
    Log "Secondary credential valid"
    $sec = ConvertTo-SecureString $secondaryPass -AsPlainText -Force
}
else {
    Log "No deployment credential worked"

    Write-Host ""
    Write-Host "[FAIL] Administrative access unavailable."
    Write-Host "[FAIL] Deployment credentials rejected."
    Read-Host "Press Enter"

    exit 1
}

try {
    $cred = New-Object System.Management.Automation.PSCredential($primaryUser,$sec)

    Start-Process powershell.exe `
        -Credential $cred `
        -WorkingDirectory "C:\Windows\System32" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installer`"" `
        -WindowStyle Maximized `
        -ErrorAction Stop

    Log "Credential launch successful"
}
catch {
    Log "Credential launch failed: $_"

    Write-Host ""
    Write-Host "[FAIL] Launch failed."
    Read-Host "Press Enter"
    exit 1
}
