#!/usr/bin/env bash

# Tell this script to exit if there are any errors.
# You should have this in every custom script, to ensure that your completed
# builds actually ran successfully without any errors!
set -oue pipefail

# Set up 1Password repository and GPG key
echo "Setting up 1Password repository..."

# Install the repository GPG key
curl https://downloads.1password.com/linux/keys/1password.asc | tee /etc/pki/rpm-gpg/RPM-GPG-KEY-1password

# Add the repository
cat >/etc/yum.repos.d/1password.repo <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-1password
EOF

echo "1Password repository setup complete"
