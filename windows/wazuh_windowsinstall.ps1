# ============================================================
#  Simplify3x Cyber Defence Team
#  Runs as: ADMIN
#  Target:  Domain-joined Windows endpoints
# ============================================================
#  HOW IT WORKS
#  ------------
#  - Downloads MSI directly from Wazuh CDN
#  - Writes ossec.conf from the inline config embedded below
#  - Starts the service and verifies it is running
#  - All logs written to C:\Windows\Temp\S3X_WazuhDeploy.log
#
# ============================================================

#Requires -RunAsAdministrator
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# -- CONFIGURATION --------------------------------------------
$MANAGER_IP_INTERNAL  = "10.0.74.29"
$MANAGER_IP_EXTERNAL  = "103.117.237.116"
$MANAGER_PORT_EVENTS  = 1514
$MANAGER_PORT_ENROLL  = 1515
$AGENT_GROUP          = "endpoints-workstations-windows"
$ENROLLMENT_PASSWORD  = "MuVOAb1xabilNFFtJRBf9v+q50SE+oU73jwuv6xjQRc="

$MSI_URL              = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.5-1.msi"
$STAGING_PATH         = "C:\Windows\Temp\S3X_Wazuh"
$MSI_PATH             = "$STAGING_PATH\wazuh-agent.msi"
$MSI_LOG              = "$STAGING_PATH\msi_install.log"
$DEPLOY_LOG           = "C:\Windows\Temp\S3X_WazuhDeploy.log"
$AGENT_PATH           = "C:\Program Files (x86)\ossec-agent"
$CONF_PATH            = "$AGENT_PATH\ossec.conf"
# -------------------------------------------------------------

# -- LOGGING --------------------------------------------------
function Write-Log {
    param([string]$Level, [string]$Message)
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $DEPLOY_LOG -Value $line -ErrorAction SilentlyContinue
    Write-Output $line
}
function Log-Info  { param($m) Write-Log "INFO " $m }
function Log-OK    { param($m) Write-Log " OK  " $m }
function Log-Warn  { param($m) Write-Log "WARN " $m }
function Log-Error { param($m) Write-Log "ERROR" $m }
# -------------------------------------------------------------

Log-Info "======================================================"
Log-Info "Simplify3x Cyber Defence - Wazuh GPO Deployment Start"
Log-Info "Host : $env:COMPUTERNAME"
Log-Info "User : $env:USERNAME  (expected: SYSTEM)"
Log-Info "======================================================"

# -- STEP 1: UNINSTALL EXISTING AGENT IF PRESENT -------------
# If a previous install exists, stop the service, uninstall via WMI,
# and delete the leftover folder before doing a clean fresh install.
$svc = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
if ($svc) {
    Log-Warn "Existing WazuhSvc found (Status: $($svc.Status)). Performing clean uninstall..."

    # Stop the service first
    try {
        Stop-Service -Name "WazuhSvc" -Force -ErrorAction Stop
        Log-OK "WazuhSvc stopped."
    } catch {
        Log-Warn "Could not stop WazuhSvc (may already be stopped): $_"
    }

    # Uninstall via WMI (same as Add/Remove Programs)
    try {
        $wmiPkg = Get-WmiObject -Class Win32_Product -Filter "Name LIKE '%Wazuh%'" -ErrorAction Stop
        if ($wmiPkg) {
            $result = $wmiPkg.Uninstall()
            if ($result.ReturnValue -eq 0) {
                Log-OK "Wazuh agent uninstalled successfully."
            } else {
                Log-Warn "WMI uninstall returned code $($result.ReturnValue) -- continuing anyway."
            }
        } else {
            Log-Warn "No Wazuh entry found in Win32_Product -- skipping WMI uninstall."
        }
    } catch {
        Log-Warn "WMI uninstall failed: $_ -- continuing anyway."
    }

    # Delete leftover agent folder
    try {
        if (Test-Path $AGENT_PATH) {
            Remove-Item -Path $AGENT_PATH -Recurse -Force -ErrorAction Stop
            Log-OK "Removed leftover folder: $AGENT_PATH"
        }
    } catch {
        Log-Warn "Could not fully remove $($AGENT_PATH): $_"
    }

    # Brief pause to allow Windows to release file handles after uninstall
    Start-Sleep -Seconds 5
    Log-Info "Clean uninstall complete. Proceeding with fresh installation."
} else {
    Log-Info "No existing WazuhSvc found. Proceeding with fresh installation."
}

# -- STEP 2: STAGING DIRECTORY --------------------------------
try {
    if (!(Test-Path $STAGING_PATH)) {
        New-Item -Path $STAGING_PATH -ItemType Directory -Force | Out-Null
    }
    Log-OK "Staging directory ready: $STAGING_PATH"
} catch {
    Log-Error "Failed to create staging directory: $_"
    exit 1
}

# -- STEP 3: DOWNLOAD MSI -------------------------------------
Log-Info "Downloading Wazuh agent MSI from Wazuh CDN..."
try {
    Invoke-WebRequest `
        -Uri $MSI_URL `
        -OutFile $MSI_PATH `
        -UseBasicParsing `
        -UserAgent "Mozilla/5.0" `
        -ErrorAction Stop

    $sizeMB = [math]::Round((Get-Item $MSI_PATH).Length / 1MB, 1)
    Log-OK "MSI downloaded successfully ($sizeMB MB)"
} catch {
    Log-Error "MSI download failed: $_"
    exit 2
}

# -- STEP 4: SILENT MSI INSTALL -------------------------------
# msiexec properties handle manager IP, group, and enrollment password.
# ossec.conf will be overwritten in Step 5 with the full hardened config.
Log-Info "Running silent MSI installation..."

$msiArgs = @(
    "/i", "`"$MSI_PATH`"",
    "/qn",
    "/l*v", "`"$MSI_LOG`"",
    "WAZUH_MANAGER=`"$MANAGER_IP_INTERNAL`"",
    "WAZUH_REGISTRATION_SERVER=`"$MANAGER_IP_INTERNAL`"",
    "WAZUH_REGISTRATION_PORT=`"$MANAGER_PORT_ENROLL`"",
    "WAZUH_REGISTRATION_PASSWORD=`"$ENROLLMENT_PASSWORD`"",
    "WAZUH_AGENT_GROUP=`"$AGENT_GROUP`"",
    "WAZUH_PROTOCOL=`"TCP`"",
    "ALLUSERS=1"
)

try {
    $proc = Start-Process -FilePath "msiexec.exe" `
                          -ArgumentList $msiArgs `
                          -Wait `
                          -PassThru `
                          -NoNewWindow `
                          -ErrorAction Stop

    if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) {
        Log-OK "MSI install completed (ExitCode: $($proc.ExitCode))"
        # ExitCode 3010 = success, reboot required -- we continue anyway
    } else {
        Log-Error "MSI installer returned exit code $($proc.ExitCode). Check: $MSI_LOG"
        exit 3
    }
} catch {
    Log-Error "msiexec launch failed: $_"
    exit 3
}

# -- STEP 5: WRITE HARDENED ossec.conf ------------------------
# Inline config -- no second file needed on SYSVOL.
# Overrides the MSI default with your full hardened configuration.
Log-Info "Writing hardened ossec.conf..."

$ossecConf = @"
<!--
  Wazuh Agent Configuration - Simplify3x Cyber Defence Team
  Managed deployment - do not edit manually on endpoint.
-->

<ossec_config>

  <client>
    <!-- Primary Connection (Internal / VPN) -->
    <server>
      <address>$MANAGER_IP_INTERNAL</address>
      <port>$MANAGER_PORT_EVENTS</port>
      <protocol>tcp</protocol>
    </server>

    <!-- Secondary Connection (External) -->
    <server>
      <address>$MANAGER_IP_EXTERNAL</address>
      <port>$MANAGER_PORT_EVENTS</port>
      <protocol>tcp</protocol>
    </server>

    <force_reconnect_interval>1h</force_reconnect_interval>
    <time-reconnect>20</time-reconnect>
    <notify_time>20</notify_time>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
    <config-profile>windows, windows10</config-profile>

    <enrollment>
      <enabled>yes</enabled>
      <groups>$AGENT_GROUP</groups>
      <manager_address>$MANAGER_IP_INTERNAL</manager_address>
      <manager_address>$MANAGER_IP_EXTERNAL</manager_address>
      <port>$MANAGER_PORT_ENROLL</port>
    </enrollment>
  </client>

  <client_buffer>
    <disabled>no</disabled>
    <queue_size>5000</queue_size>
    <events_per_second>500</events_per_second>
  </client_buffer>

  <!-- Log analysis -->
  <localfile>
    <location>Application</location>
    <log_format>eventchannel</log_format>
  </localfile>

  <localfile>
    <location>Security</location>
    <log_format>eventchannel</log_format>
    <query>Event/System[EventID != 5145 and EventID != 5156 and EventID != 5447 and
      EventID != 4656 and EventID != 4658 and EventID != 4663 and EventID != 4660 and
      EventID != 4670 and EventID != 4690 and EventID != 4703 and EventID != 4907 and
      EventID != 5152 and EventID != 5157]</query>
  </localfile>

  <localfile>
    <location>System</location>
    <log_format>eventchannel</log_format>
  </localfile>

  <localfile>
    <location>active-response\active-responses.log</location>
    <log_format>syslog</log_format>
  </localfile>

  <!-- Policy monitoring -->
  <rootcheck>
    <disabled>no</disabled>
    <windows_apps>./shared/win_applications_rcl.txt</windows_apps>
    <windows_malware>./shared/win_malware_rcl.txt</windows_malware>
  </rootcheck>

  <!-- Security Configuration Assessment -->
  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>12h</interval>
    <skip_nfs>yes</skip_nfs>
  </sca>

  <!-- File Integrity Monitoring -->
  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>

    <directories recursion_level="0" restrict="regedit.exe`$|system.ini`$|win.ini`$">%WINDIR%</directories>
    <directories recursion_level="0" restrict="at.exe`$|attrib.exe`$|cacls.exe`$|cmd.exe`$|eventcreate.exe`$|ftp.exe`$|lsass.exe`$|net.exe`$|net1.exe`$|netsh.exe`$|reg.exe`$|regedt32.exe|regsvr32.exe|runas.exe|sc.exe|schtasks.exe|sethc.exe|subst.exe`$">%WINDIR%\SysNative</directories>
    <directories recursion_level="0">%WINDIR%\SysNative\drivers\etc</directories>
    <directories recursion_level="0" restrict="WMIC.exe`$">%WINDIR%\SysNative\wbem</directories>
    <directories recursion_level="0" restrict="powershell.exe`$">%WINDIR%\SysNative\WindowsPowerShell\v1.0</directories>
    <directories recursion_level="0" restrict="winrm.vbs`$">%WINDIR%\SysNative</directories>

    <directories recursion_level="0" restrict="at.exe`$|attrib.exe`$|cacls.exe`$|cmd.exe`$|eventcreate.exe`$|ftp.exe`$|lsass.exe`$|net.exe`$|net1.exe`$|netsh.exe`$|reg.exe`$|regedit.exe`$|regedt32.exe`$|regsvr32.exe`$|runas.exe`$|sc.exe`$|schtasks.exe`$|sethc.exe`$|subst.exe`$">%WINDIR%\System32</directories>
    <directories recursion_level="0">%WINDIR%\System32\drivers\etc</directories>
    <directories recursion_level="0" restrict="WMIC.exe`$">%WINDIR%\System32\wbem</directories>
    <directories recursion_level="0" restrict="powershell.exe`$">%WINDIR%\System32\WindowsPowerShell\v1.0</directories>
    <directories recursion_level="0" restrict="winrm.vbs`$">%WINDIR%\System32</directories>

    <directories realtime="yes">%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup</directories>

    <ignore>%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs\Startup\desktop.ini</ignore>
    <ignore type="sregex">.log`$|.htm`$|.jpg`$|.png`$|.chm`$|.pnf`$|.evtx`$</ignore>

    <!-- Registry monitoring -->
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Classes\batfile</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Classes\cmdfile</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Classes\comfile</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Classes\exefile</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Classes\piffile</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Classes\AllFilesystemObjects</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Classes\Directory</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Classes\Folder</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Classes\Protocols</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Policies</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Security</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Internet Explorer</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\KnownDLLs</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\SecurePipeServers\winreg</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnce</windows_registry>
    <windows_registry>HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnceEx</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\URL</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Windows</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Winlogon</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Active Setup\Installed Components</windows_registry>

    <!-- Registry ignore -->
    <registry_ignore>HKEY_LOCAL_MACHINE\Security\Policy\Secrets</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\Security\SAM\Domains\Account\Users</registry_ignore>
    <registry_ignore type="sregex">\Enum`$</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\MpsSvc\Parameters\AppCs</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\MpsSvc\Parameters\PortKeywords\DHCP</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\MpsSvc\Parameters\PortKeywords\IPTLSIn</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\MpsSvc\Parameters\PortKeywords\IPTLSOut</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\MpsSvc\Parameters\PortKeywords\RPC-EPMap</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\MpsSvc\Parameters\PortKeywords\Teredo</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\PolicyAgent\Parameters\Cache</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\RunOnceEx</registry_ignore>
    <registry_ignore>HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\ADOVMPPackage\Final</registry_ignore>

    <windows_audit_interval>60</windows_audit_interval>
    <process_priority>10</process_priority>
    <max_eps>50</max_eps>

    <synchronization>
      <enabled>yes</enabled>
      <interval>5m</interval>
      <max_eps>10</max_eps>
    </synchronization>
  </syscheck>

  <!-- System Inventory -->
  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>1h</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="yes">yes</ports>
    <processes>yes</processes>
    <users>yes</users>
    <groups>yes</groups>
    <services>yes</services>
    <browser_extensions>yes</browser_extensions>
    <synchronization>
      <max_eps>10</max_eps>
    </synchronization>
  </wodle>

  <!-- CIS-CAT disabled until licensed -->
  <wodle name="cis-cat">
    <disabled>yes</disabled>
    <timeout>1800</timeout>
    <interval>1d</interval>
    <scan-on-start>yes</scan-on-start>
    <java_path>\\server\jre\bin\java.exe</java_path>
    <ciscat_path>C:\cis-cat</ciscat_path>
  </wodle>

  <!-- Osquery disabled until deployed -->
  <wodle name="osquery">
    <disabled>yes</disabled>
    <run_daemon>yes</run_daemon>
    <bin_path>C:\Program Files\osquery\osqueryd</bin_path>
    <log_path>C:\Program Files\osquery\log\osqueryd.results.log</log_path>
    <config_path>C:\Program Files\osquery\osquery.conf</config_path>
    <add_labels>yes</add_labels>
  </wodle>

  <!-- Active Response -->
  <active-response>
    <disabled>no</disabled>
    <ca_store>wpk_root.pem</ca_store>
    <ca_verification>yes</ca_verification>
  </active-response>

  <logging>
    <log_format>plain</log_format>
  </logging>

</ossec_config>
"@

try {
    # Wait up to 30s for agent path to appear (MSI may still be finalising)
    $waited = 0
    while (!(Test-Path $AGENT_PATH) -and $waited -lt 30) {
        Start-Sleep -Seconds 2
        $waited += 2
    }

    if (!(Test-Path $AGENT_PATH)) {
        Log-Error "Agent path not found after waiting: $AGENT_PATH"
        exit 4
    }

    $ossecConf | Out-File -FilePath $CONF_PATH -Encoding UTF8 -Force
    Log-OK "ossec.conf written to $CONF_PATH"
} catch {
    Log-Error "Failed to write ossec.conf: $_"
    exit 4
}

# -- STEP 5b: WRITE ENROLLMENT PASSWORD FILE --------------------
# Wazuh 4.x does NOT support <password> inside <enrollment> in ossec.conf.
# The registration password must be supplied via authd.pass instead.
$AUTHD_PASS_PATH = "$AGENT_PATH\authd.pass"
try {
    [System.IO.File]::WriteAllText($AUTHD_PASS_PATH, $ENROLLMENT_PASSWORD.Trim(), [System.Text.Encoding]::ASCII)
    Log-OK "authd.pass written to $AUTHD_PASS_PATH"
} catch {
    Log-Error "Failed to write authd.pass: $_"
    exit 4
}

# -- STEP 6: START AND VERIFY SERVICE -------------------------
Log-Info "Starting WazuhSvc..."
try {
    Start-Service -Name "WazuhSvc" -ErrorAction Stop
    Start-Sleep -Seconds 5

    $svc = Get-Service -Name "WazuhSvc" -ErrorAction Stop
    if ($svc.Status -eq "Running") {
        Log-OK "WazuhSvc is Running."
    } else {
        Log-Warn "WazuhSvc status after start: $($svc.Status)"
    }
} catch {
    Log-Error "Failed to start WazuhSvc: $_"
    # Not exiting -- agent may self-start or enrollment may complete async
}

# -- STEP 7: CLEANUP STAGING ----------------------------------
Log-Info "Cleaning up staging directory..."
try {
    Remove-Item -Path $STAGING_PATH -Recurse -Force -ErrorAction SilentlyContinue
    Log-OK "Staging directory removed."
} catch {
    Log-Warn "Could not fully remove staging directory: $_"
}

# -- DONE -----------------------------------------------------
Log-Info "======================================================"
Log-OK  "Wazuh GPO deployment complete on $env:COMPUTERNAME"
Log-Info "Log file: $DEPLOY_LOG"
Log-Info "======================================================"
exit 0
