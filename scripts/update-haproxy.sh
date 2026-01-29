#!/bin/bash
# update-haproxy.sh - Check for and install HAProxy updates from GitHub releases
# Usage: ./update-haproxy.sh [--force]

set -e

REPO="YOUR_USERNAME/haproxy-quic-rpm"
INSTALL_DIR="/tmp/haproxy-update"
FORCE=${1:-""}

echo "HAProxy QUIC Updater (AWS-LC Edition)"
echo "======================================"

# Get current installed version
if command -v haproxy &> /dev/null; then
    CURRENT=$(haproxy -v 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "none")
    echo "Current version: ${CURRENT}"
else
    CURRENT="none"
    echo "HAProxy not currently installed"
fi

# Get latest release from GitHub
echo "Checking for updates..."
LATEST_RELEASE=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest")
LATEST_TAG=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')
LATEST_HAPROXY=$(echo "$LATEST_TAG" | grep -oP 'haproxy-\K[0-9]+\.[0-9]+\.[0-9]+')
LATEST_AWSLC=$(echo "$LATEST_TAG" | grep -oP 'awslc\K[0-9]+\.[0-9]+\.[0-9]+')

echo "Latest available: HAProxy ${LATEST_HAPROXY} + AWS-LC ${LATEST_AWSLC}"

# Compare versions
if [ "$CURRENT" = "$LATEST_HAPROXY" ] && [ "$FORCE" != "--force" ]; then
    echo "Already running latest version. Use --force to reinstall."
    exit 0
fi

echo ""
echo "Update available: ${CURRENT} -> ${LATEST_HAPROXY}"

# Find RPM download URL
RPM_URL=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | endswith(".rpm")) | .browser_download_url' | head -1)

if [ -z "$RPM_URL" ]; then
    echo "ERROR: Could not find RPM in release"
    exit 1
fi

RPM_NAME=$(basename "$RPM_URL")
echo "Downloading: ${RPM_NAME}"

# Download and install
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

curl -LO "$RPM_URL"

echo ""
echo "Installing..."
sudo dnf localinstall -y "$RPM_NAME"

# Verify
echo ""
echo "Verifying installation..."
haproxy -vv | grep -E "(version|QUIC|AWS-LC|OpenSSL)" || true

# Cleanup
rm -rf "$INSTALL_DIR"

echo ""
echo "Update complete!"
echo ""
echo "To restart HAProxy:"
echo "  sudo systemctl restart haproxy"
