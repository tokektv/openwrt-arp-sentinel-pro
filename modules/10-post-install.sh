#!/bin/sh
# Module 10: Post-installation Tasks

set -e

echo "Running post-installation tasks..."

# 1. Create initial baseline
echo "Creating initial baseline..."
mkdir -p /opt/arp-sentinel/data
arp -n | awk '/^[0-9]/ {print $1 " " $3}' > /opt/arp-sentinel/data/initial-baseline.txt
BASELINE_COUNT=$(wc -l < /opt/arp-sentinel/data/initial-baseline.txt)
echo "  Baseline created with $BASELINE_COUNT devices"

# 2. Set proper permissions
echo "Setting permissions..."
chown -R root:root /opt/arp-sentinel
chmod -R 755 /opt/arp-sentinel/bin
chmod 644 /etc/config/arp-sentinel

# 3. Create log rotation
echo "Configuring log rotation..."
cat > /etc/logrotate.d/arp-sentinel << 'EOF'
/var/log/arp-sentinel/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}
EOF

# 4. Create README file
echo "Creating documentation..."
cat > /opt/arp-sentinel/README.md << 'EOF'
# ARP Sentinel Pro

Advanced ARP monitoring and protection system for OpenWrt.

## Quick Start

1. Start the service:
   ```bash
   /etc/init.d/arp-sentinel start
