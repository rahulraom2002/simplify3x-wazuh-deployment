$installer = "C:\ProgramData\S3X_Security\S3X_Install.ps1"

function Is-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Pw {
    param($u,$p)

    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        if ($u -like "*\*") {
            $domain = $u.Split('\')[0]
            $user = $u.Split('\')[1]
            $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Domain', $domain)
        }
        else {
            $user = $u
            $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine')
        }

        return $ctx.ValidateCredentials($user, $p)
    }
    catch {
        return $false
    }
}

Write-Host ""
Write-Host "Simplify3x Security - Launcher"
Write-Host "--------------------------------"

if (Is-Admin) {
    Write-Host "[OK] Local admin detected. Starting installer..."
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installer
    exit
}

Write-Host "[INFO] Standard user detected. Trying deployment credentials..."

$deployUser = "SIMPLIFY3X\wazuh"
$deployPass = "Simplify@5678"

if (Test-Pw $deployUser $deployPass) {
    Write-Host "[OK] Deployment credential validated."

    $sec = ConvertTo-SecureString $deployPass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($deployUser, $sec)

    Start-Process powershell.exe `
        -Credential $cred `
        -WorkingDirectory "C:\Windows\System32" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installer`"" `
        -WindowStyle Maximized

    exit
}

Write-Host "[FAIL] No usable administrative access found."
Read-Host "Press Enter to exit"
exit 1
