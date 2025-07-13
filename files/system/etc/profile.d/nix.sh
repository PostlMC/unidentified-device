# if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
#     . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
# fi

# Find the nix binary dynamically
NIX_BINARY=$(find /var/lib/nix/store -name "nix" -type f -executable 2>/dev/null | head -1)
if [ -n "$NIX_BINARY" ]; then
    NIX_BIN_DIR=$(dirname "$NIX_BINARY")
    export PATH="/usr/bin:$NIX_BIN_DIR:$PATH"

    # Find ALL library directories but exclude problematic system libraries
    ALL_LIB_DIRS=$(find /var/lib/nix/store -name "lib" -type d 2>/dev/null | grep -v -E "(glibc|gcc|binutils)" | tr '\n' ':' 2>/dev/null || echo "")
    if [ -n "$ALL_LIB_DIRS" ]; then
        export LD_LIBRARY_PATH="${ALL_LIB_DIRS%:}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
fi

# Tell Nix where its data actually lives (all in /var/lib/nix)
export NIX_STORE_DIR="/run/nix/store"
export NIX_STATE_DIR="/var/lib/nix"
export NIX_PROFILES="/var/lib/nix/var/profiles/default"
export NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
export __ETC_PROFILE_NIX_SOURCED=1
