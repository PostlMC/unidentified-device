#!/usr/bin/env bash

set -euo pipefail

echo "Installing Determinate Nix for Aurora Linux (immutable system)..."

# Install basic dependencies that might be needed
dnf install -y which findutils

# On OSTree systems, /nix would be immutable, so we install to /usr/lib/nix
# and use /var/lib/nix for writable data, then create symlinks at runtime

# Create staging directory for writable data
mkdir -p /var/lib/nix

# Install Nix to a temporary location first
export NIX_INSTALLER_TARBALL_PATH="/tmp/nix-installer"
mkdir -p "$NIX_INSTALLER_TARBALL_PATH"

# Download and run the Determinate Nix installer with special flags for our setup
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    NIX_INSTALLER_NO_MODIFY_PROFILE=1 \
        bash -s -- install linux --no-confirm --init none --no-start-daemon

# Move the Nix installation from /nix to /usr/lib/nix (immutable location)
mv /nix /usr/lib/nix

# Move writable data to /var/lib/nix (persistent location)
mv /usr/lib/nix/var/nix/* /var/lib/nix/
rm -rf /usr/lib/nix/var

# Set up proper symlinks via tmpfiles.d (created at boot time)
cat >/usr/lib/tmpfiles.d/nix.conf <<'EOF'
# Create /nix symlink to /usr/lib/nix
L  /nix  -  -  -  -  /usr/lib/nix

# Create /nix/var directory structure
d  /nix/var  0755  root  root  -
L  /nix/var/nix  -  -  -  -  /var/lib/nix
EOF

# Set up Nix environment for all users (don't rely on profiles that may not exist yet)
cat >/etc/profile.d/nix.sh <<'EOF'
# Nix environment setup
export PATH="/nix/var/nix/profiles/default/bin:$PATH"
export NIX_PROFILES="/nix/var/nix/profiles/default"
export NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
export __ETC_PROFILE_NIX_SOURCED=1
EOF

# Create systemd service for the daemon
cat >/etc/systemd/system/nix-daemon.service <<'EOF'
[Unit]
Description=Nix Daemon
Documentation=man:nix-daemon
RequiresMountsFor=/nix/store
RequiresMountsFor=/var/lib/nix
ConditionPathExists=/nix/store

[Service]
ExecStart=/nix/var/nix/profiles/default/bin/nix-daemon --daemon
KillMode=process
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# Enable the nix daemon service for when systemd starts
systemctl enable nix-daemon.service

echo "Nix base installation complete (Aurora-compatible)"

# Verify installation structure
if [ ! -d "/usr/lib/nix/store" ]; then
    echo "ERROR: Nix store not found at expected location /usr/lib/nix/store"
    exit 1
fi

if [ ! -d "/var/lib/nix/profiles" ]; then
    echo "ERROR: Nix profiles not found in /var/lib/nix/profiles"
    exit 1
fi

if [ ! -f "/usr/lib/tmpfiles.d/nix.conf" ]; then
    echo "ERROR: tmpfiles.d configuration not created"
    exit 1
fi

echo "Nix installation verified successfully"

# Install devbox using the Nix we just installed
echo "Installing devbox via Nix..."

# We need to work with the actual binary locations during build time
# The symlinks won't exist until boot, so use direct paths to /var/lib/nix

# First, create a temporary symlink structure for the build
mkdir -p /tmp/nix-build/var
ln -s /var/lib/nix /tmp/nix-build/var/nix

# Install devbox using direct path to nix binary
NIXPKGS_ALLOW_UNFREE=1 /var/lib/nix/profiles/default/bin/nix \
    --extra-experimental-features "nix-command flakes" \
    profile install nixpkgs#devbox \
    --profile /var/lib/nix/profiles/default

# Verify devbox installation
if [ ! -f "/var/lib/nix/profiles/default/bin/devbox" ]; then
    echo "ERROR: devbox not found after installation"
    exit 1
fi

echo "Nix and devbox installation complete (will be functional after reboot)"
