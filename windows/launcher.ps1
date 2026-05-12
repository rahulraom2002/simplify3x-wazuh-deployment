$primaryUser = ".\administrator"
$primaryPass = "Simplify@7685"
$secondaryPass = "34001360"

function Test-Pw {
    param($u,$p)

    try {
        Add-Type -AssemblyName System.DirectoryServices.AccountManagement
        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine')
        return $ctx.ValidateCredentials($u.Split('\')[-1], $p)
    }
    catch {
        return $false
    }
}

if (Test-Pw $primaryUser $primaryPass) {
    $sec = ConvertTo-SecureString $primaryPass -AsPlainText -Force
}
elseif (Test-Pw $primaryUser $secondaryPass) {
    $sec = ConvertTo-SecureString $secondaryPass -AsPlainText -Force
}
else {
    Write-Host "Authentication failed"
    pause
    exit 1
}

$cred = New-Object System.Management.Automation.PSCredential($primaryUser,$sec)

Start-Process powershell.exe `
    -Credential $cred `
    -WorkingDirectory "C:\Windows\System32" `
    -ArgumentList '-ExecutionPolicy Bypass -File "C:\ProgramData\S3X_Security\S3X_Install.ps1"' `
    -WindowStyle Maximized
