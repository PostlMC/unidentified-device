#!/usr/bin/env bash

set -euo pipefail

echo "Installing Determinate Nix (base system)..."

# Install basic dependencies that might be needed
dnf install -y which findutils

# Download and run the Determinate Nix installer with container-appropriate flags
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    bash -s -- install linux --no-confirm --init none --no-start-daemon

# Set up Nix environment for all users
echo 'export PATH="/nix/var/nix/profiles/default/bin:$PATH"' >/etc/profile.d/nix.sh
echo 'export NIX_PROFILES="/nix/var/nix/profiles/default"' >>/etc/profile.d/nix.sh

# The installer should have created the systemd service, just enable it
if [ -f /lib/systemd/system/nix-daemon.service ] || [ -f /usr/lib/systemd/system/nix-daemon.service ]; then
    systemctl enable nix-daemon.service
    echo "Nix daemon service enabled"
else
    echo "Warning: nix-daemon.service not found, may need manual setup"
fi

echo "Nix base installation complete"

# Verify installation worked
if [ ! -d "/nix/store" ]; then
    echo "ERROR: Nix installation failed - /nix/store not found"
    exit 1
fi

if [ ! -f "/nix/var/nix/profiles/default/bin/nix" ]; then
    echo "ERROR: Nix binary not found at expected location"
    exit 1
fi

echo "Nix installation verified successfully"
