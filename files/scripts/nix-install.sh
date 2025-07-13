#!/usr/bin/env bash

set -euo pipefail

echo "Validating files module actions..."
for D in /etc/profile.d /usr/bin /usr/libexec /usr/share; do
    echo "Validating $D..."
    ls -la $D | sed 's/^/    /'
done

echo "Installing Determinate Nix for Aurora Linux (immutable system)..."

# Create target directories for ALL Nix data
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

# Update static nix wrapper script with actual binary path
sed -i "s|NIX_BINARY_PLACEHOLDER|$NIX_BINARY|g" /usr/bin/nix

chmod +x /usr/bin/nix
chmod +x /usr/libexec/nix-setup.sh
chmod +x /etc/profile.d/nix.sh

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

echo "Nix installation complete!"
