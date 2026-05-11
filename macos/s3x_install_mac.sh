#!/bin/bash

CC='\033[0;36m'
CG='\033[0;32m'
CR='\033[0;31m'
CY='\033[0;33m'
CW='\033[1;37m'
NC='\033[0m'

STAGING="/private/tmp/s3x_security"
PKG_FILE="$STAGING/wazuh-agent.pkg"
CONF_STAGING="$STAGING/ossec_macos.conf"
LOG="$STAGING/install.log"

WAZUH_VERSION="4.14.4-1"
WAZUH_MANAGER="10.0.74.29"
WAZUH_GROUP="endpoints-workstations-mac"

CONFIG_URL="https://raw.githubusercontent.com/rahulraom2002/simplify3x-wazuh-configs/main/macos/ossec.conf"

print_ok(){ echo -e "${CG}[ OK ] $1${NC}"; }
print_fail(){ echo -e "${CR}[FAIL] $1${NC}"; }
print_warn(){ echo -e "${CY}[WARN] $1${NC}"; }
print_step(){ echo -e "${CC}>> $1${NC}"; }

if [ "$(id -u)" -ne 0 ]; then
    print_fail "Run as root: sudo ./s3x_install_mac.sh"
    exit 1
fi

SCRIPT_PATH="$(realpath "$BASH_SOURCE" 2>/dev/null)"
[ -z "$SCRIPT_PATH" ] && SCRIPT_PATH="$0"

clear
echo -e "${CW}"
echo "===================================================="
echo "   SIMPLIFY3X SOC : macOS ENDPOINT DEPLOYMENT"
echo "===================================================="
echo -e "${NC}"

mkdir -p "$STAGING"

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
        print_fail "Unsupported macOS architecture: $ARCH_RAW"
        exit 2
        ;;
esac

print_ok "Detected architecture: $ARCH_RAW"

print_step "Checking dependencies..."

if ! command -v curl >/dev/null 2>&1; then
    print_fail "curl missing"
    exit 3
fi

if ! command -v installer >/dev/null 2>&1; then
    print_fail "installer binary missing"
    exit 4
fi

print_step "Stopping existing Wazuh agent..."
launchctl unload /Library/LaunchDaemons/com.wazuh.agent.plist 2>/dev/null
pkill -f wazuh-agent 2>/dev/null
pkill -f ossec-agent 2>/dev/null
sleep 2

print_ok "Environment cleared"

print_step "Downloading Wazuh agent package..."
curl -L --retry 3 --connect-timeout 20 \
     -A "Mozilla/5.0" \
     -o "$PKG_FILE" \
     "$PKG_URL"

if [ ! -f "$PKG_FILE" ] || [ "$(stat -f%z "$PKG_FILE")" -lt 1000000 ]; then
    print_fail "Package download failed"
    exit 5
fi

print_ok "Package downloaded"

print_step "Preparing Wazuh installer environment..."
echo "WAZUH_MANAGER='$WAZUH_MANAGER' && WAZUH_AGENT_GROUP='$WAZUH_GROUP'" > /tmp/wazuh_envs

print_step "Installing Wazuh agent..."
installer -pkg "$PKG_FILE" -target /

if [ $? -ne 0 ]; then
    print_fail "Installation failed"
    exit 6
fi

print_ok "Agent installed"

print_step "Downloading macOS ossec.conf..."
curl -L --retry 3 --connect-timeout 20 \
     -A "Mozilla/5.0" \
     -o "$CONF_STAGING" \
     "$CONFIG_URL"

if [ ! -f "$CONF_STAGING" ] || [ "$(stat -f%z "$CONF_STAGING")" -lt 1000 ]; then
    print_fail "Config download failed"
    exit 7
fi

if grep -q "ossec_config" "$CONF_STAGING"; then
    cp -f "$CONF_STAGING" /Library/Ossec/etc/ossec.conf
    print_ok "Custom config applied"
else
    print_fail "Downloaded config invalid"
    exit 8
fi

print_step "Starting Wazuh service..."
launchctl unload /Library/LaunchDaemons/com.wazuh.agent.plist 2>/dev/null
launchctl load /Library/LaunchDaemons/com.wazuh.agent.plist

sleep 8

if /Library/Ossec/bin/wazuh-control status 2>/dev/null | grep -q "is running"; then
    print_ok "Wazuh agent active"
else
    print_fail "Agent failed to start"
    /Library/Ossec/bin/wazuh-control status
    exit 9
fi

print_step "Cleaning temporary files..."

rm -f "$PKG_FILE"
rm -f "$CONF_STAGING"
rm -f "$LOG"
rm -f /tmp/wazuh_envs

(
    sleep 5
    rmdir "$STAGING" 2>/dev/null
    rm -f "$SCRIPT_PATH"
) >/dev/null 2>&1 &

disown

print_ok "Deployment complete"
print_ok "Agent enrolled to SOC"

exit 0
