#!/bin/bash

set -euo pipefail

# Create the missing group that 1Password expects (this is the core fix)
groupadd -g 1001 onepassword-bridge || true

# Create native messaging manifest directory
mkdir -p /usr/lib64/mozilla/native-messaging-hosts

# Create the 1Password native messaging manifest
cat >/usr/lib64/mozilla/native-messaging-hosts/com.1password.1password.json <<'EOF'
{
  "name": "com.1password.1password",
  "description": "1Password extension helper",
  "path": "/usr/lib/opt/1Password/1Password-BrowserSupport",
  "type": "stdio",
  "allowed_extensions": [
    "{d634138d-c276-4fc8-924b-40a0ea21d284}",
    "{25fc87fa-4d31-4fee-b5c1-c32a7844c063}",
    "{0a75d802-9aed-41e7-8daa-24c067386e82}"
  ]
}
EOF

chmod 644 /usr/lib64/mozilla/native-messaging-hosts/com.1password.1password.json

echo "1Password native messaging setup completed"
