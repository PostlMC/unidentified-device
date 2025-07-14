#!/usr/bin/env bash

set -euo pipefail

echo "Installing Determinate Nix for Aurora Linux (immutable system)..."

# Create target directories for ALL Nix data
mkdir -p /var/lib/nix/{var,store}

# Install Nix to a temporary location first
export NIX_INSTALLER_TARBALL_PATH="/tmp/nix-installer"
mkdir -p "$NIX_INSTALLER_TARBALL_PATH"

# Download and run the Determinate Nix installer
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    NIX_INSTALLER_NO_MODIFY_PROFILE=1 \
        bash -s -- install linux --no-confirm --init none --no-start-daemon

# Move the Nix installation to /var/lib/nix (writable location)
cp -r /nix/store/* /var/lib/nix/store/
cp -r /nix/var/nix/* /var/lib/nix/var/

chmod +x /usr/bin/nix
chmod +x /usr/bin/nix-daemon-wrapper
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

# Verify script placement
if [ ! -f "/usr/bin/nix" ]; then
    echo "ERROR: Nix wrapper script not created"
    exit 1
fi
if [ ! -f "/usr/bin/nix-daemon-wrapper" ]; then
    echo "ERROR: Nix daemon wrapper script not created"
    exit 1
fi
if [ ! -f "/usr/libexec/nix-setup.sh" ]; then
    echo "ERROR: Nix setup script not created"
    exit 1
fi
if [ ! -f "/etc/profile.d/nix.sh" ]; then
    echo "ERROR: Nix profile script not created"
    exit 1
fi

echo "Nix installation complete!"
