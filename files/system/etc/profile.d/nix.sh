# Find the nix binary dynamically
NIX_BINARY=$(find /var/lib/nix/store -name "nix" -type f -executable 2>/dev/null | head -1)
if [ -n "$NIX_BINARY" ]; then
    NIX_BIN_DIR=$(dirname "$NIX_BINARY")
    export PATH="/usr/bin:$NIX_BIN_DIR:$PATH"

    # Build library path with Nix libraries first (same as daemon wrapper)
    NIX_LIB_DIRS=$(find /var/lib/nix/store -name "lib" -type d 2>/dev/null | grep -E "(nix-)" | tr '\n' ':' 2>/dev/null || echo "")
    OTHER_LIB_DIRS=$(find /var/lib/nix/store -name "lib" -type d 2>/dev/null | grep -v -E "(glibc|gcc|binutils|gcc-wrapper|glibc-|libc6)" | tr '\n' ':' 2>/dev/null || echo "")

    COMBINED_LIBS="${NIX_LIB_DIRS}${OTHER_LIB_DIRS}"
    if [ -n "$COMBINED_LIBS" ]; then
        export LD_LIBRARY_PATH="${COMBINED_LIBS%:}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
fi

# Tell Nix where its data actually lives (all in /var/lib/nix)
export NIX_STORE_DIR="/run/nix/store"
export NIX_STATE_DIR="/var/lib/nix"
export NIX_PROFILES="/var/lib/nix/var/profiles/default"
export NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
export __ETC_PROFILE_NIX_SOURCED=1
