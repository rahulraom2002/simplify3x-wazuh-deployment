$installer = "C:\ProgramData\S3X_Security\S3X_Install.ps1"
$log = "C:\ProgramData\S3X_Security\launcher.log"

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
        Log "Is-Admin result: $result"
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
        Log "Testing credential for $u"

        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        if ($u -like "*\*") {
            $domain = $u.Split('\')[0]
            $user = $u.Split('\')[1]

            Log "Using domain context: $domain"

            $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
                [System.DirectoryServices.AccountManagement.ContextType]::Domain,
                $domain
            )
        }
        else {
            $user = $u

            Log "Using machine context"

            $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
                [System.DirectoryServices.AccountManagement.ContextType]::Machine
            )
        }

        $ok = $ctx.ValidateCredentials($user,$p)

        Log "Credential validation result: $ok"

        return $ok
    }
    catch {
        Log "Test-Pw exception: $_"
        return $false
    }
}

Log "==============================="
Log "Launcher started"
Log "Current user: $env:USERNAME"
Log "Computer: $env:COMPUTERNAME"

Write-Host ""
Write-Host "Simplify3x Security - Launcher"
Write-Host "--------------------------------"

if (Is-Admin) {
    Log "Current user already admin"

    Write-Host "[OK] Admin rights detected. Starting installer..."

    try {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
        Log "Installer launched directly"
        exit
    }
    catch {
        Log "Direct launch exception: $_"
        Write-Host "[FAIL] Direct launch failed"
        Read-Host "Press Enter"
        exit 1
    }
}

Log "Current user not admin"

Write-Host "[INFO] Standard user detected. Trying deployment credentials..."

$deployUser = "SIMPLIFY3X\wazuh"
$deployPass = "Simplify@5678"

if (Test-Pw $deployUser $deployPass) {
    Log "Deployment credential validated"

    try {
        $sec = ConvertTo-SecureString $deployPass -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($deployUser,$sec)

        Log "Launching installer with Start-Process -Credential"

        Start-Process powershell.exe `
            -Credential $cred `
            -WorkingDirectory "C:\Windows\System32" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installer`"" `
            -WindowStyle Maximized `
            -ErrorAction Stop

        Log "Start-Process succeeded"

        exit
    }
    catch {
        Log "Start-Process exception: $_"
        Write-Host "[FAIL] Launch failed"
        Read-Host "Press Enter"
        exit 1
    }
}

Log "Credential validation failed"

Write-Host "Authentication failed"
Read-Host "Press Enter"
exit 1
