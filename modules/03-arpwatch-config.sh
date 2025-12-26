#!/bin/sh
# Module 3: ARPwatch Configuration

set -e

echo "Configuring ARPwatch..."

# Backup existing config if any
if [ -f "/etc/arpwatch.conf" ]; then
    cp /etc/arpwatch.conf /etc/arpwatch.conf.backup
    echo "  Backed up existing config"
fi

# Create ARPwatch configuration
cat > /etc/arpwatch.conf << 'EOF'
# ARP Sentinel Pro Configuration
# Generated on $(date)

OPTIONS="-N -f /var/log/arp-sentinel/arpwatch.log"
INTERFACES="br-lan"
ARGFILE="/var/lib/arpwatch/arp.dat"
EMAIL="root@localhost"
EOF

# Create interface-specific config
cat > /etc/arpwatch.d/br-lan.conf << 'EOF'
interface br-lan
{
    # Monitoring options
    flags = quiet;
    one_shot = no;
    
    # Notification
    mail = root;
    mail_interval = 3600;
    
    # Logging
    log_file = /var/log/arp-sentinel/br-lan.log;
    pid_file = /var/run/arpwatch.br-lan.pid;
}
EOF

# Initialize ARP database
mkdir -p /var/lib/arpwatch
touch /var/lib/arpwatch/arp.dat

echo ""
echo "ARPwatch configuration completed!"
