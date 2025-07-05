#!/usr/bin/env bash

set -euo pipefail

echo "Installing Determinate Nix (base system)..."

# Download and run the Determinate Nix installer
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    bash -s -- install linux --no-confirm --init systemd

# Enable nix daemon
systemctl enable nix-daemon.service

# Set up Nix environment
echo 'export PATH="/nix/var/nix/profiles/default/bin:$PATH"' >/etc/profile.d/nix.sh
echo 'export NIX_PROFILES="/nix/var/nix/profiles/default"' >>/etc/profile.d/nix.sh

echo "Nix base installation complete (devbox can be installed separately)"
