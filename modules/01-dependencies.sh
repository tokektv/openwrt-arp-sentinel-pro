#!/bin/sh
# Module 1: Install Dependencies

set -e

echo "Installing required packages..."

# Update package list
opkg update

# Essential packages
ESSENTIAL_PACKAGES="
arpwatch
arp-scan
ipset
curl
ca-bundle
logrotate
"

# Optional packages (install if space available)
OPTIONAL_PACKAGES="
vnstat
vnstati
tcpdump
nmap
netdiscover
jq
"

# Install essential packages
for pkg in $ESSENTIAL_PACKAGES; do
    if opkg list-installed | grep -q "^$pkg "; then
        echo "  ✓ $pkg already installed"
    else
        echo "  Installing $pkg..."
        if opkg install "$pkg"; then
            echo "  ✓ $pkg installed"
        else
            echo "  ⚠️  Failed to install $pkg, continuing..."
        fi
    fi
done

# Try to install optional packages
for pkg in $OPTIONAL_PACKAGES; do
    if ! opkg list-installed | grep -q "^$pkg "; then
        if opkg install "$pkg" 2>/dev/null; then
            echo "  ✓ Optional: $pkg installed"
        else
            echo "  ⚠️  Skipping optional: $pkg"
        fi
    fi
done

echo ""
echo "Package installation completed!"
echo "Installed: $(opkg list-installed | grep -c '^') packages"
