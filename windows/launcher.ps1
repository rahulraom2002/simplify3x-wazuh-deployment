Add-Type -AssemblyName System.DirectoryServices.AccountManagement

function Test-Pw($u, $p) {
    try {
        $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('Machine')
        return $ctx.ValidateCredentials($u, $p)
    } catch {
        return $false
    }
}

$sec = $null

if (Test-Pw 'administrator' 'Simplify@7685') {
    Write-Host 'Primary password accepted' -ForegroundColor Green
    $sec = ConvertTo-SecureString 'Simplify@7685' -AsPlainText -Force
} elseif (Test-Pw 'administrator' '34001360') {
    Write-Host 'Fallback password accepted' -ForegroundColor Yellow
    $sec = ConvertTo-SecureString '34001360' -AsPlainText -Force
} else {
    Write-Host 'Both passwords failed. Contact SOC team.' -ForegroundColor Red
    Add-Content -Path $env:S3X_LOG -Value '[LAUNCHER] FAIL: both passwords rejected'
    Read-Host 'Press Enter'
    exit 1
}

$target  = $env:S3X_TARGET
$logpath = $env:S3X_LOG

$cred  = New-Object System.Management.Automation.PSCredential('.\administrator', $sec)
$pargs = '-NoProfile -ExecutionPolicy Bypass -File "' + $target + '"'

Write-Host 'Elevating session - please wait...' -ForegroundColor Cyan
Add-Content -Path $logpath -Value '[LAUNCHER] Calling Start-Process'

try {
    Start-Process powershell.exe `
        -ArgumentList $pargs `
        -Credential $cred `
        -WorkingDirectory 'C:\Windows\System32' `
        -WindowStyle Maximized `
        -ErrorAction Stop
    Add-Content -Path $logpath -Value '[LAUNCHER] Start-Process OK'
} catch {
    $msg = '[LAUNCHER] FAIL: ' + $_.ToString()
    Add-Content -Path $logpath -Value $msg
    Write-Host $msg -ForegroundColor Red
    Read-Host 'Press Enter'
}
