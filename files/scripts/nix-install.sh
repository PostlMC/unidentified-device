#!/usr/bin/env bash

set -euo pipefail

echo "Installing Determinate Nix for Aurora Linux (immutable system)..."

# Install basic dependencies that might be needed
dnf install -y which findutils

# Create target directories for ALL Nix data (everything goes in /var/lib/nix when we're done)
mkdir -p /var/lib/nix/var

# Install Nix to a temporary location first
export NIX_INSTALLER_TARBALL_PATH="/tmp/nix-installer"
mkdir -p "$NIX_INSTALLER_TARBALL_PATH"

# Download and run the Determinate Nix installer with special flags for our setup
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    NIX_INSTALLER_NO_MODIFY_PROFILE=1 \
        bash -s -- install linux --no-confirm --init none --no-start-daemon

# Move the Nix installation to /var/lib/nix (writable location)
# Move store directly to avoid double nesting
cp -r /nix/store /var/lib/nix/store
cp -r /nix/var/nix/* /var/lib/nix/var/

# Find the nix binary path dynamically (it will be in a store path) and verify it's actually executable
NIX_BINARY=$(find /var/lib/nix/store -name "nix" -type f -executable 2>/dev/null | head -1)
if [ -z "$NIX_BINARY" ]; then
    echo "ERROR: Could not find nix binary in store"
    exit 1
fi
if [ ! -x "$NIX_BINARY" ]; then
    echo "ERROR: Found nix binary but it's not executable: $NIX_BINARY"
    exit 1
fi

# Ensure /usr/bin exists
# mkdir -p /usr/bin 2>/dev/null || true

# Copy static nix wrapper script and replace placeholder with actual path
# cp /files/system/usr/local/bin/nix /usr/bin/nix
sed -i "s|NIX_BINARY_PLACEHOLDER|$NIX_BINARY|g" /usr/bin/nix
chmod +x /usr/bin/nix

# Copy static nix environment setup script
# mkdir -p /etc/profile.d
# cp /files/system/etc/profile.d/nix.sh /etc/profile.d/nix.sh
chmod +x /etc/profile.d/nix.sh

# Copy static nix-daemon systemd service file
# mkdir -p /etc/systemd/system
# cp /files/system/etc/systemd/system/nix-daemon.service /etc/systemd/system/nix-daemon.service

# Enable the new services
systemctl enable nix-setup-users.service
systemctl enable nix-daemon.service

echo "Nix base installation complete (Aurora-compatible)"

# Verify installation structure
if [ ! -d "/var/lib/nix/store" ]; then
    echo "ERROR: Nix store not found at expected location /var/lib/nix/store"
    exit 1
fi

if [ ! -d "/var/lib/nix/var/profiles" ]; then
    echo "ERROR: Nix profiles not found in /var/lib/nix/var/profiles"
    exit 1
fi

if [ ! -f "/usr/bin/nix" ]; then
    echo "ERROR: Nix wrapper script not created"
    exit 1
fi

echo ""
echo "Nix installation complete!"
