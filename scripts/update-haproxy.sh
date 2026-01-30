#!/bin/bash
# update-haproxy.sh - Check for and install HAProxy updates
# Usage: ./update-haproxy.sh [--force] [--manual|--repo]

set -e

REPO="derFrisson/haproxy-quic-awslc-rpm"
INSTALL_DIR="/tmp/haproxy-update"
REPO_FILE="/etc/yum.repos.d/haproxy-quic.repo"
REPO_URL="https://derFrisson.github.io/haproxy-quic-awslc-rpm/packages/haproxy-quic.repo"

# Parse arguments
FORCE=""
METHOD=""
for arg in "$@"; do
    case $arg in
        --force)
            FORCE="--force"
            ;;
        --manual)
            METHOD="manual"
            ;;
        --repo)
            METHOD="repo"
            ;;
    esac
done

echo "HAProxy QUIC Updater (AWS-LC Edition)"
echo "======================================"

# Check if DNF repository is already configured
REPO_CONFIGURED=false
if [ -f "$REPO_FILE" ]; then
    REPO_CONFIGURED=true
    echo "DNF repository: Configured"
fi

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
echo ""

# Determine installation method
if [ "$REPO_CONFIGURED" = true ] && [ -z "$METHOD" ]; then
    # Repository already configured, use it by default
    echo "Using DNF repository for updates..."
    METHOD="repo"
elif [ -z "$METHOD" ]; then
    # Ask user to choose installation method
    echo "Choose installation method:"
    echo "  1) DNF Repository (recommended - automatic updates via 'dnf update')"
    echo "  2) Manual Download (one-time install from GitHub releases)"
    echo ""
    read -p "Enter choice [1-2]: " choice

    case $choice in
        1)
            METHOD="repo"
            ;;
        2)
            METHOD="manual"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi

# Execute chosen method
case $METHOD in
    repo)
        # Install/configure DNF repository
        if [ "$REPO_CONFIGURED" = false ]; then
            echo ""
            echo "Installing DNF repository..."
            sudo curl -o "$REPO_FILE" "$REPO_URL"
            echo "✓ Repository configured at $REPO_FILE"
            echo ""
        fi

        echo "Installing/updating HAProxy via DNF repository..."
        if [ "$CURRENT" = "none" ]; then
            sudo dnf install -y haproxy-quic
        else
            sudo dnf update -y haproxy-quic || sudo dnf install -y haproxy-quic
        fi

        echo ""
        echo "✓ Future updates will be available via: sudo dnf update haproxy-quic"
        ;;

    manual)
        # Manual download and install
        echo ""
        echo "Downloading RPM from GitHub releases..."

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

        # Cleanup
        rm -rf "$INSTALL_DIR"

        echo ""
        echo "✓ Manual installation complete"
        echo "  Note: Run this script again to check for future updates"
        ;;
esac

# Verify
echo ""
echo "Verifying installation..."
haproxy -vv | grep -E "(version|QUIC|AWS-LC|OpenSSL)" || true

echo ""
echo "Update complete!"
echo ""
echo "To restart HAProxy:"
echo "  sudo systemctl restart haproxy"
