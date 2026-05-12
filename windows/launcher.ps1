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

function Is-Admin {
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        $result = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        Log "Is-Admin = $result"
        return $result
    }
    catch {
        Log "Is-Admin exception: $_"
        return $false
    }
}

function Test-Pw {
    param($u,$p)

    try {
        Log "Testing local credential for $u"

        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
            [System.DirectoryServices.AccountManagement.ContextType]::Machine
        )

        $user = $u.Split('\')[-1]
        $ok = $ctx.ValidateCredentials($user,$p)

        Log "Credential result = $ok"

        return $ok
    }
    catch {
        Log "Test-Pw exception: $_"
        return $false
    }
}

Log "=================================="
Log "Launcher started"
Log "User=$env:USERNAME"
Log "Host=$env:COMPUTERNAME"

Write-Host ""
Write-Host "Simplify3x Security - Launcher"
Write-Host "--------------------------------"

if (Is-Admin) {
    Log "Current user already admin"

    Write-Host "[OK] Local admin detected. Starting installer..."

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
    exit
}

Log "Current user not admin"

Write-Host "[INFO] Standard user detected. Trying deployment credentials..."

if (Test-Pw $primaryUser $primaryPass) {
    Log "Primary credential valid"
    $sec = ConvertTo-SecureString $primaryPass -AsPlainText -Force
}
elseif (Test-Pw $primaryUser $secondaryPass) {
    Log "Secondary credential valid"
    $sec = ConvertTo-SecureString $secondaryPass -AsPlainText -Force
}
else {
    Log "No credential worked"
    Write-Host "Authentication failed"
    Read-Host "Press Enter"
    exit 1
}

try {
    $cred = New-Object System.Management.Automation.PSCredential($primaryUser,$sec)

    Log "Launching elevated installer"

    Start-Process powershell.exe `
        -Credential $cred `
        -WorkingDirectory "C:\Windows\System32" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installer`"" `
        -WindowStyle Maximized `
        -ErrorAction Stop

    Log "Start-Process OK"
}
catch {
    Log "Start-Process exception: $_"
    Write-Host "Launch failed"
    Read-Host "Press Enter"
    exit 1
}
