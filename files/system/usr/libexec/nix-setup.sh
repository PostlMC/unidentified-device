#!/bin/bash
set -euo pipefail

# User creation
if [ ! -f /var/lib/nix/.users-created ]; then
    # Only create group if it doesn't exist
    if ! getent group nixbld >/dev/null 2>&1; then
        groupadd -g 30000 nixbld
    fi
    for i in $(seq 1 10); do
        USERNAME="nixbld$i"
        # Only create user if it doesn't exist
        if ! id -u "$USERNAME" >/dev/null 2>&1; then
            useradd -c "Nix build user $i" -d /var/empty -g nixbld -G nixbld -M -N -r -s $(which nologin) -u $((30000 + i)) "$USERNAME"
        fi
    done
    touch /var/lib/nix/.users-created
fi
