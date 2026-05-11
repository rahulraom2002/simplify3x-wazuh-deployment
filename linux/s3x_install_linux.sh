#!/bin/bash

CC='\033[0;36m'
CG='\033[0;32m'
CR='\033[0;31m'
CY='\033[0;33m'
CW='\033[1;37m'
NC='\033[0m'

STAGING="/tmp/s3x_security"
LOG="$STAGING/install.log"
CONF_STAGING="$STAGING/ossec_linux.conf"

WAZUH_VERSION="4.14.4-1"
WAZUH_MANAGER="10.0.74.29"
WAZUH_GROUP="endpoints-workstations-linux"

CONFIG_URL="https://simplify3xsoftware-my.sharepoint.com/:u:/g/personal/soc_simplify3x_com/IQA30I4pNmB9ToC9-U09NqyaAY068-_rokXCQ39QLkY8ypU?download=1"

print_ok(){ echo -e "${CG}[ OK ] $1${NC}"; }
print_fail(){ echo -e "${CR}[FAIL] $1${NC}"; }
print_warn(){ echo -e "${CY}[WARN] $1${NC}"; }
print_step(){ echo -e "${CC}>> $1${NC}"; }

if [ "$(id -u)" -ne 0 ]; then
    print_fail "Run as root: sudo ./s3x_install_linux.sh"
    exit 1
fi

SCRIPT_PATH="$(realpath "$BASH_SOURCE")"

clear
echo -e "${CW}"
echo "===================================================="
echo "   SIMPLIFY3X SOC : LINUX ENDPOINT DEPLOYMENT"
echo "===================================================="
echo -e "${NC}"

mkdir -p "$STAGING"

print_step "Detecting platform..."

ARCH_RAW=$(uname -m)

case "$ARCH_RAW" in
    x86_64|amd64)
        ARCH_DEB="amd64"
        ARCH_RPM="x86_64"
        ;;
    aarch64|arm64)
        ARCH_DEB="arm64"
        ARCH_RPM="aarch64"
        ;;
    *)
        print_fail "Unsupported architecture: $ARCH_RAW"
        exit 2
        ;;
esac

if command -v apt-get >/dev/null 2>&1; then
    PKG_TYPE="deb"
    PKG_FILE="$STAGING/wazuh-agent.deb"
    DOWNLOAD_URL="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VERSION}_${ARCH_DEB}.deb"
    apt-get update
    apt-get install -y wget ca-certificates
elif command -v yum >/dev/null 2>&1; then
    PKG_TYPE="rpm"
    PKG_FILE="$STAGING/wazuh-agent.rpm"
    DOWNLOAD_URL="https://packages.wazuh.com/4.x/yum/wazuh-agent-${WAZUH_VERSION}.${ARCH_RPM}.rpm"
    yum install -y wget ca-certificates
elif command -v dnf >/dev/null 2>&1; then
    PKG_TYPE="rpm"
    PKG_FILE="$STAGING/wazuh-agent.rpm"
    DOWNLOAD_URL="https://packages.wazuh.com/4.x/yum/wazuh-agent-${WAZUH_VERSION}.${ARCH_RPM}.rpm"
    dnf install -y wget ca-certificates
else
    print_fail "Unsupported Linux distribution"
    exit 3
fi

print_ok "Detected package type: $PKG_TYPE"
print_ok "Detected architecture: $ARCH_RAW"

mkdir -p "$STAGING"

print_step "Stopping existing agent..."
systemctl stop wazuh-agent 2>/dev/null
pkill -f wazuh-agent 2>/dev/null
pkill -f ossec-agent 2>/dev/null

print_step "Downloading Wazuh agent..."
wget -O "$PKG_FILE" "$DOWNLOAD_URL"

if [ ! -f "$PKG_FILE" ] || [ ! -s "$PKG_FILE" ]; then
    print_fail "Package download failed"
    exit 4
fi

print_ok "Package downloaded"

print_step "Installing Wazuh agent..."

if [ "$PKG_TYPE" = "deb" ]; then
    WAZUH_MANAGER="$WAZUH_MANAGER" \
    WAZUH_AGENT_GROUP="$WAZUH_GROUP" \
    dpkg -i "$PKG_FILE"
else
    WAZUH_MANAGER="$WAZUH_MANAGER" \
    WAZUH_AGENT_GROUP="$WAZUH_GROUP" \
    rpm -ivh --replacepkgs "$PKG_FILE"
fi

if [ $? -ne 0 ]; then
    print_fail "Installation failed"
    exit 5
fi

print_ok "Agent installed"

print_step "Downloading Linux ossec.conf..."
wget -O "$CONF_STAGING" "$CONFIG_URL"

if [ ! -f "$CONF_STAGING" ] || [ ! -s "$CONF_STAGING" ]; then
    print_fail "Config download failed"
    exit 6
fi

if grep -q "ossec_config" "$CONF_STAGING"; then
    cp -f "$CONF_STAGING" /var/ossec/etc/ossec.conf
    print_ok "Custom config applied"
else
    print_fail "Downloaded config invalid"
    exit 7
fi

print_step "Starting Wazuh service..."
systemctl daemon-reload
systemctl enable wazuh-agent
systemctl restart wazuh-agent

sleep 8

STATUS=$(systemctl is-active wazuh-agent)

if [ "$STATUS" = "active" ]; then
    print_ok "Wazuh agent active"
else
    print_fail "Service failed to start"
    systemctl status wazuh-agent --no-pager
    exit 8
fi

print_step "Cleaning up..."

rm -f "$PKG_FILE"
rm -f "$CONF_STAGING"
rm -f "$LOG"

(
    sleep 5
    rmdir "$STAGING" 2>/dev/null
    rm -f "$SCRIPT_PATH"
) >/dev/null 2>&1 &

disown

print_ok "Deployment complete"
exit 0
