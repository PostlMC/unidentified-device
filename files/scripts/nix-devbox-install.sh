#!/usr/bin/env bash

set -euo pipefail

echo "Installing Determinate Nix for Aurora Linux (immutable system)..."

# Install basic dependencies that might be needed
dnf install -y which findutils

# Create a systemd service to set up Nix build users on first boot
# (users/groups don't persist from container build to OSTree runtime)
cat >/etc/systemd/system/nix-setup-users.service <<'EOF'
[Unit]
Description=Create Nix build users
Before=nix-daemon.service
ConditionPathExists=!/var/lib/nix/.users-created

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
if ! getent group nixbld >/dev/null 2>&1; then \
    groupadd -g 30000 nixbld; \
fi; \
for i in $(seq 1 10); do \
    if ! getent passwd nixbld$i >/dev/null 2>&1; then \
        useradd -c "Nix build user $i" -d /var/empty -g nixbld \
            -G nixbld -M -N -r -s $(which nologin) \
            -u $((30000 + i)) nixbld$i; \
    fi; \
done; \
touch /var/lib/nix/.users-created'

[Install]
WantedBy=multi-user.target
EOF

# Enable the user creation service
systemctl enable nix-setup-users.service

# Create staging directory for ALL Nix data (everything goes in /var/lib/nix)
mkdir -p /var/lib/nix

# Install Nix to a temporary location first
export NIX_INSTALLER_TARBALL_PATH="/tmp/nix-installer"
mkdir -p "$NIX_INSTALLER_TARBALL_PATH"

# Download and run the Determinate Nix installer with special flags for our setup
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix |
    NIX_INSTALLER_NO_MODIFY_PROFILE=1 \
        bash -s -- install linux --no-confirm --init none --no-start-daemon

# Move the Nix installation to /var/lib/nix (writable location)
# Move store directly to avoid double nesting
mv /nix/store /var/lib/nix/store
# Move var contents to /var/lib/nix (preserving the var/nix structure)
mv /nix/var/nix /var/lib/nix/var
mkdir -p /var/lib/nix/var
# Note: Can't remove /nix directories on immutable filesystem - they'll be read-only at runtime

# Find the nix binary path dynamically (it will be in a store path)
NIX_BINARY=$(find /var/lib/nix/store -name "nix" -type f -executable 2>/dev/null | head -1)
if [ -z "$NIX_BINARY" ]; then
    echo "ERROR: Could not find nix binary in store"
    exit 1
fi

# Ensure /usr/local/bin exists
mkdir -p /usr/local/bin

# Create wrapper script for nix command (handles shared library issues)
cat >/usr/local/bin/nix <<'EOF'
#!/bin/bash
exec /lib64/ld-linux-x86-64.so.2 NIX_BINARY_PLACEHOLDER "$@"
EOF

# Replace placeholder with actual path
sed -i "s|NIX_BINARY_PLACEHOLDER|$NIX_BINARY|g" /usr/local/bin/nix
chmod +x /usr/local/bin/nix

# Create wrapper script for nix-daemon (handles shared library issues + environment)
cat >/usr/bin/nix-daemon-wrapper <<'EOF'
#!/bin/bash
export LD_LIBRARY_PATH="$(find /var/lib/nix/store -name "lib" -type d 2>/dev/null | grep -v -E "(glibc|gcc|binutils)" | tr '\n' ':' | sed 's/:$//')"
export NIX_STORE_DIR="/var/lib/nix/store"
export NIX_STATE_DIR="/var/lib/nix"
export NIX_LOG_DIR="/var/lib/nix/log"
export NIX_CONF_DIR="/var/lib/nix/conf"
export NIX_DAEMON_SOCKET_PATH="/var/lib/nix/daemon-socket/socket"
mkdir -p /var/lib/nix/daemon-socket
exec /lib64/ld-linux-x86-64.so.2 NIX_BINARY_PLACEHOLDER --extra-experimental-features nix-command --extra-experimental-features flakes daemon "$@"
EOF

# Replace placeholder with actual path
sed -i "s|NIX_BINARY_PLACEHOLDER|$NIX_BINARY|g" /usr/local/bin/nix-daemon-wrapper
chmod +x /usr/bin/nix-daemon-wrapper

# Set up Nix environment for all users (points to writable store location)
cat >/etc/profile.d/nix.sh <<'EOF'
# Nix environment setup for Aurora (immutable system)

# Find the nix binary dynamically
NIX_BINARY=$(find /var/lib/nix/store -name "nix" -type f -executable 2>/dev/null | head -1)
if [ -n "$NIX_BINARY" ]; then
    NIX_BIN_DIR=$(dirname "$NIX_BINARY")
    export PATH="/usr/local/bin:$NIX_BIN_DIR:$PATH"
    
    # Find ALL library directories but exclude problematic system libraries
    ALL_LIB_DIRS=$(find /var/lib/nix/store -name "lib" -type d 2>/dev/null | grep -v -E "(glibc|gcc|binutils)" | tr '\n' ':')
    if [ -n "$ALL_LIB_DIRS" ]; then
        export LD_LIBRARY_PATH="${ALL_LIB_DIRS%:}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
fi

# Tell Nix where its data actually lives (all in /var/lib/nix)
export NIX_STORE_DIR="/var/lib/nix/store"
export NIX_STATE_DIR="/var/lib/nix"
export NIX_PROFILES="/var/lib/nix/var/nix/profiles/default"
export NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
export __ETC_PROFILE_NIX_SOURCED=1
EOF

# Create systemd service for the daemon (uses wrapper script)
cat >/etc/systemd/system/nix-daemon.service <<'EOF'
[Unit]
Description=Nix Daemon
Documentation=man:nix-daemon
RequiresMountsFor=/var/lib/nix/store
RequiresMountsFor=/var/lib/nix
ConditionPathExists=/var/lib/nix/store

[Service]
ExecStart=/usr/bin/nix-daemon-wrapper
KillMode=process
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# Enable the nix daemon service for when systemd starts
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

if [ ! -f "/usr/local/bin/nix" ]; then
    echo "ERROR: Nix wrapper script not created"
    exit 1
fi

if [ ! -f "/usr/bin/nix-daemon-wrapper" ]; then
    echo "ERROR: Nix daemon wrapper script not created"
    exit 1
fi

echo ""
echo "Nix installation complete!"
echo "After reboot, you can install devbox with:"
echo "  nix profile install nixpkgs#devbox"
echo ""
echo "Note: The binary cache warning about store prefix is expected and harmless."
