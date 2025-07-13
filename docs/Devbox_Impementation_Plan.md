# Nix Installation on Aurora Linux - Implementation Plan

## Objective

Install Determinate Nix on Aurora Linux (immutable OSTree system) with working multi-user daemon to allow use of devbox.

## Key Challenges Solved

1. **Immutable filesystem**: Can't create `/nix` in root, so store goes to `/var/lib/nix/store/`
2. **Hardcoded paths**: Nix binary expects `/nix/store/`, so create runtime symlink `/run/nix/store -> /var/lib/nix/store/store/`
3. **Persistent users**: Build-time users don't persist, so create at runtime via systemd
4. **glibc conflicts**: Execute binary via symlink path, not physical path

## Required Files Structure

### 1. Install Script: [`files/scripts/nix-install.sh`](../../files/scripts/nix-install.sh)

- Installs Determinate Nix to `/var/lib/nix/`
- Moves store and state to `/var/lib/nix/store` and `/var/lib/nix/var/`
- Patches wrapper at `/usr/bin/nix` with actual binary path
- Installs environment script at `/etc/profile.d/nix.sh`
- Validates presence and permissions of key directories, indents output for clarity
- Does **not** enable systemd services (handled in the recipe)

### 2. Daemon Wrapper Template: [`files/system/usr/share/nix-daemon-wrapper.template`](../../files/system/usr/share/nix-daemon-wrapper.template)

- Necessary to ensure proper library pathing for Nix and to set up the runtime environment for the daemon.
- The actual binary hash is patched in at runtime by the setup script.

### 3. Setup Script: [`files/system/usr/libexec/nix-setup.sh`](../../files/system/usr/libexec/nix-setup.sh)

- Creates `nixbld` group and users if not present
- Copies and patches daemon wrapper with correct binary hash to `/usr/bin/nix-daemon-wrapper`
- Patches `/usr/bin/nix` wrapper with actual binary path if present (legacy support)
- Creates marker files to prevent re-running steps

### 4. Wrapper Script: [`files/system/usr/bin/nix`](../../files/system/usr/bin/nix)

- Simple wrapper that uses the patched binary path
- Patched by the install script to point to the actual Nix binary in the store

### 5. Systemd Services: [`files/systemd/system/nix-setup.service`](../../files/systemd/system/nix-setup.service) and [`files/systemd/system/nix-daemon.service`](../../files/systemd/system/nix-daemon.service)

- `nix-setup.service` runs setup script on boot if not already done
- `nix-daemon.service` starts daemon using runtime-created wrapper
- Both are enabled in the image build recipe, not in the install script

### 6. Environment Script: [`files/system/etc/profile.d/nix.sh`](../../files/system/etc/profile.d/nix.sh)

- Sets up `PATH`, `LD_LIBRARY_PATH`, and Nix environment variables for users
- Dynamically finds the Nix binary and library paths

## How It Works Together

### Build Time (Immutable Layer)

1. **Nix Installation**: Store copied to `/var/lib/nix/store/`, state to `/var/lib/nix/var/`
2. **Wrapper Script**: `/usr/bin/nix` created and patched at install
3. **Environment**: `/etc/profile.d/nix.sh` sets `NIX_STORE_DIR="/run/nix/store"`
4. **Services**: Both `nix-daemon.service` and `nix-setup.service` are enabled in the image recipe
5. **Template**: Daemon wrapper template placed at `/usr/share/nix-daemon-wrapper.template`

### Runtime (First Boot)

1. **User Creation**: `nix-setup.service` runs `nix-setup.sh`, creates nixbld group + users
2. **Wrapper Creation**: Service copies and patches template to `/usr/bin/nix-daemon-wrapper`
3. **Path Resolution**: Service finds actual binary hash and updates wrapper
4. **Daemon Start**: `nix-daemon.service` starts using the runtime-created wrapper
5. **Symlink Creation**: Wrapper creates `/run/nix/store -> /var/lib/nix/store/store/`

### User Operation

1. **Environment**: User sources `/etc/profile.d/nix.sh` 
2. **Commands**: User runs `nix profile install nixpkgs#devbox`
3. **Communication**: User nix connects to daemon via socket at `/var/lib/nix/daemon-socket/socket`

## Critical Success Factors

- Daemon binary executed via symlink path (`/run/nix/store/...`) not physical path
- Both user and daemon agree on `NIX_STORE_DIR="/run/nix/store"`
- Runtime symlink bridges hardcoded paths to actual Aurora Linux locations
- All mutable components (users, daemon wrapper) created at runtime, not build time
