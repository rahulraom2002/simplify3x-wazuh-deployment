#!/bin/bash

###############################################################################
# Simplify3X Cyber Defence Team
# macOS Wazuh Endpoint Deployment Script
# Version: 2.2.0
###############################################################################

CC='\033[0;36m'
CG='\033[0;32m'
CR='\033[0;31m'
CY='\033[0;33m'
CW='\033[1;37m'
NC='\033[0m'

SCRIPT_VERSION="2.2.0"
WAZUH_VERSION="4.14.5-1"

WAZUH_MANAGER="10.0.74.29"
WAZUH_GROUP="endpoints-workstations-mac"
AUTH_PASSWORD="MuVOAb1xabilNFFtJRBf9v+q50SE+oU73jwuv6xjQRc="

STAGING="/private/tmp/s3x_security"
PKG_FILE="$STAGING/wazuh-agent.pkg"
LOG="/private/var/log/s3x_wazuh_install.log"

mkdir -p "$STAGING"

exec > >(tee -a "$LOG") 2>&1

print_ok(){ echo -e "${CG}[ OK ] $1${NC}"; }
print_fail(){ echo -e "${CR}[FAIL] $1${NC}"; }
print_warn(){ echo -e "${CY}[WARN] $1${NC}"; }
print_step(){ echo -e "${CC}>> $1${NC}"; }

if [ "$(id -u)" -ne 0 ]; then
    print_fail "Run as root: sudo ./wazuh_macos.sh"
    exit 1
fi

SCRIPT_PATH="$0"

clear

echo -e "${CW}"
echo "========================================================"
echo "        SIMPLIFY3X CYBER DEFENCE TEAM"
echo "           macOS Endpoint Deployment"
echo ""
echo " Version : $SCRIPT_VERSION"
echo " Wazuh   : $WAZUH_VERSION"
echo "========================================================"
echo -e "${NC}"

print_step "Detecting architecture..."

ARCH_RAW=$(uname -m)

case "$ARCH_RAW" in
    x86_64)
        PKG_URL="https://packages.wazuh.com/4.x/macos/wazuh-agent-${WAZUH_VERSION}.intel64.pkg"
        ;;
    arm64)
        PKG_URL="https://packages.wazuh.com/4.x/macos/wazuh-agent-${WAZUH_VERSION}.arm64.pkg"
        ;;
    *)
        print_fail "Unsupported architecture: $ARCH_RAW"
        exit 2
        ;;
esac

print_ok "Architecture: $ARCH_RAW"

command -v curl >/dev/null 2>&1 || { print_fail "curl missing"; exit 3; }
command -v installer >/dev/null 2>&1 || { print_fail "installer missing"; exit 4; }

print_step "Removing previous Wazuh installation cleanly..."

launchctl unload /Library/LaunchDaemons/com.wazuh.agent.plist 2>/dev/null || true
pkill -f wazuh-agent 2>/dev/null || true
pkill -f ossec-agent 2>/dev/null || true

rm -rf /Library/Ossec
rm -f /Library/LaunchDaemons/com.wazuh.agent.plist
rm -f /tmp/wazuh_envs

print_ok "Old installation cleaned from disk"

print_step "Downloading Wazuh package..."

curl -L --retry 3 --connect-timeout 20 \
     -A "Mozilla/5.0" \
     -o "$PKG_FILE" \
     "$PKG_URL"

if [ ! -f "$PKG_FILE" ]; then
    print_fail "Package download failed"
    exit 5
fi

print_ok "Download completed"

print_step "Pre-configuring deployment environment variables..."

# Overriding registration parameters via target package environment configuration
cat > /tmp/wazuh_envs << EOF
WAZUH_MANAGER="${WAZUH_MANAGER}"
WAZUH_AGENT_GROUP="${WAZUH_GROUP}"
WAZUH_REGISTRATION_PASSWORD="${AUTH_PASSWORD}"
EOF

print_ok "Environment deployment parameters seeded cleanly"

print_step "Installing Wazuh Agent via system package execution loops..."

installer -pkg "$PKG_FILE" -target /

if [ $? -ne 0 ]; then
    print_fail "Installation execution failed"
    exit 6
fi

print_ok "Package framework installation succeeded"

print_step "Applying verified Simplify3X configuration profile..."

cat > /Library/Ossec/etc/ossec.conf << 'EOF'
<ossec_config>
  <client>
    <server>
      <address>10.0.74.29</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>

    <server>
      <address>103.117.237.116</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>

    <config-profile>darwin, darwin25, macos</config-profile>

    <notify_time>20</notify_time>
    <time-reconnect>20</time-reconnect>

    <force_reconnect_interval>1h</force_reconnect_interval>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>

    <enrollment>
      <enabled>yes</enabled>
      <groups>endpoints-workstations-mac</groups>
      <manager_address>10.0.74.29</manager_address>
      <manager_address>103.117.237.116</manager_address>
      <port>1515</port>
      </enrollment>
  </client>

  <client_buffer>
    <disabled>no</disabled>
    <queue_size>5000</queue_size>
    <events_per_second>500</events_per_second>
  </client_buffer>

  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>

    <frequency>43200</frequency>

    <rootkit_files>etc/shared/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>etc/shared/rootkit_trojans.txt</rootkit_trojans>

    <skip_nfs>yes</skip_nfs>
  </rootcheck>

  <wodle name="osquery">
    <disabled>yes</disabled>
    <run_daemon>yes</run_daemon>
    <log_path>/var/log/osquery/osqueryd.results.log</log_path>
    <config_path>/etc/osquery/osquery.conf</config_path>
    <add_labels>yes</add_labels>
  </wodle>

  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>1h</interval>
    <scan-on-start>yes</scan-on-start>
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

  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>12h</interval>
    <skip_nfs>yes</skip_nfs>
  </sca>

  <syscheck>
    <disabled>no</disabled>
    <frequency>43200</frequency>
    <scan_on_start>yes</scan_on_start>

    <directories>/etc,/usr/bin,/usr/sbin</directories>
    <directories>/bin,/sbin</directories>

    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>

    <ignore type="sregex">.log$|.swp$</ignore>

    <skip_nfs>yes</skip_nfs>
    <skip_dev>yes</skip_dev>
    <skip_proc>yes</skip_proc>
    <skip_sys>yes</skip_sys>

    <process_priority>10</process_priority>
    <max_eps>50</max_eps>

    <synchronization>
      <enabled>yes</enabled>
      <interval>5m</interval>
      <max_eps>10</max_eps>
    </synchronization>
  </syscheck>

  <localfile>
    <log_format>full_command</log_format>
    <command>netstat -an | awk '{if ((/^(tcp|udp)/) && ($4 != "*.*") && ($5 == "*.*")) {print $1" "$4" "$5}}' | sort -u</command>
    <alias>netstat listening ports</alias>
    <frequency>360</frequency>
  </localfile>

  <localfile>
    <location>macos</location>
    <log_format>macos</log_format>
    <query type="trace,log,activity" level="info">(process == "sudo") or (process == "sessionlogoutd") or (process == "sshd")</query>
  </localfile>

  <active-response>
    <disabled>no</disabled>
    <ca_store>etc/wpk_root.pem</ca_store>
    <ca_verification>yes</ca_verification>
  </active-response>

  <logging>
    <log_format>plain</log_format>
  </logging>
</ossec_config>
EOF

print_ok "Configuration schema applied cleanly"

print_step "Starting Wazuh service modules..."

# Force structural profile reload on the macOS service engine management layer
launchctl unload /Library/LaunchDaemons/com.wazuh.agent.plist 2>/dev/null || true
launchctl load /Library/LaunchDaemons/com.wazuh.agent.plist

sleep 10

if /Library/Ossec/bin/wazuh-control status 2>/dev/null | grep -q "is running"; then
    print_ok "Agent service running natively in an active state"
else
    print_fail "Service failed operational verification testing loops"
    /Library/Ossec/bin/wazuh-control status
    exit 7
fi

print_step "Checking orchestration infrastructure enrollment status..."

sleep 5

if grep -qi "Connected to the server" /Library/Ossec/logs/ossec.log 2>/dev/null; then
    print_ok "Agent authenticated and registered successfully."
elif grep -qi "Requesting a key" /Library/Ossec/logs/ossec.log 2>/dev/null; then
    print_ok "Enrollment handshake requests pending transaction context verification."
else
    print_warn "Agent running. Registration handshakes cycling asynchronously."
fi

print_step "Cleaning structural staging contexts..."

rm -f "$PKG_FILE"
rm -f /tmp/wazuh_envs

(
sleep 5
rmdir "$STAGING" 2>/dev/null
rm -f "$SCRIPT_PATH"
) >/dev/null 2>&1 &

disown

echo
echo -e "${CG}"
echo "========================================================"
echo "        WAZUH AGENT DEPLOYMENT COMPLETED"
echo "========================================================"
echo " Manager : $WAZUH_MANAGER"
echo " Group   : $WAZUH_GROUP"
echo " Log     : $LOG"
echo "========================================================"
echo -e "${NC}"

exit 0
