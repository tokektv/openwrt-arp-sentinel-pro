#!/bin/sh
# Module 2: Create Directories & Structure

set -e

echo "Creating directory structure..."

# Main directories
DIRS="
/opt/arp-sentinel
/opt/arp-sentinel/bin
/opt/arp-sentinel/etc
/opt/arp-sentinel/lib
/opt/arp-sentinel/data
/opt/arp-sentinel/logs
/var/log/arp-sentinel
/tmp/arp-sentinel-cache
"

for dir in $DIRS; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "  Created: $dir"
    else
        echo "  Exists: $dir"
    fi
done

# Set permissions
chmod 755 /opt/arp-sentinel
chmod 755 /var/log/arp-sentinel

# Create symlink for easy access
ln -sf /opt/arp-sentinel/bin/* /usr/local/bin/ 2>/dev/null || true

echo ""
echo "Directory structure created!"
