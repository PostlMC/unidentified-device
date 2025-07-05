#!/usr/bin/env bash

set -euo pipefail

echo "Installing Determinate Nix (base system)..."

# Download and run the Determinate Nix installer with --init none for container builds
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    bash -s -- install linux --no-confirm --init none

# Set up Nix environment
echo 'export PATH="/nix/var/nix/profiles/default/bin:$PATH"' >/etc/profile.d/nix.sh
echo 'export NIX_PROFILES="/nix/var/nix/profiles/default"' >>/etc/profile.d/nix.sh

# Create systemd service for the daemon (will be enabled on first boot)
cat >/etc/systemd/system/nix-daemon.service <<'SYSTEMD_EOF'
[Unit]
Description=Nix Daemon
Documentation=man:nix-daemon
RequiresMountsFor=/nix/store
RequiresMountsFor=/nix/var
RequiresMountsFor=/nix/var/nix/db
ConditionPathExists=/nix/store

[Service]
ExecStart=/nix/var/nix/profiles/default/bin/nix-daemon --daemon
KillMode=process
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

# Enable the nix daemon service for when systemd starts
systemctl enable nix-daemon.service

echo "Nix base installation complete (daemon will start on boot)"
