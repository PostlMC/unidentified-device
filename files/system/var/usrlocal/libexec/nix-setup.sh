#!/bin/bash
set -euo pipefail

# User creation
if [ ! -f /var/lib/nix/.users-created ]; then
    groupadd -g 30000 nixbld
    for i in $(seq 1 10); do
        useradd -c "Nix build user $i" -d /var/empty -g nixbld -G nixbld -M -N -r -s $(which nologin) -u $((30000 + i)) nixbld$i
    done
    touch /var/lib/nix/.users-created
fi

# Wrapper creation
if [ ! -f /var/lib/nix/.wrapper-created ]; then
    mkdir -p /usr/local/bin
    cp /usr/local/share/nix-daemon-wrapper.template /usr/local/bin/nix-daemon-wrapper
    chmod +x /usr/local/bin/nix-daemon-wrapper
    touch /var/lib/nix/.wrapper-created
fi

# Template patching
if [ ! -f /var/lib/nix/.template-patched ]; then
    BINARY_PATH=$(find /var/lib/nix/store -name "nix" -type f -executable 2>/dev/null | head -1)
    BINARY_HASH=$(basename $(dirname $(dirname $BINARY_PATH)))
    sed -i "s/BINARY_HASH/$BINARY_HASH/g" /usr/local/bin/nix-daemon-wrapper
    touch /var/lib/nix/.template-patched
fi

# Patch and ensure /usr/local/bin/nix wrapper
if [ -f /usr/local/bin/nix ]; then
    sed -i "s|NIX_BINARY_PLACEHOLDER|$BINARY_PATH|g" /usr/local/bin/nix
    chmod +x /usr/local/bin/nix
fi
