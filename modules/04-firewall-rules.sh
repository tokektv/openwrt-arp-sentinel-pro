#!/bin/sh
# Module 4: Firewall Rules for ARP Protection

set -e

echo "Setting up firewall rules..."

# Create firewall script
cat > /etc/firewall.arp-sentinel << 'EOF'
#!/bin/sh
# ARP Sentinel Firewall Rules
# This file is included from /etc/firewall.user

. /lib/functions.sh

# Create IPSet for known devices
ipset -N arp_known hash:ip,mac timeout 86400 2>/dev/null || true
ipset -N arp_whitelist hash:ip,mac 2>/dev/null || true
ipset -N arp_blacklist hash:ip timeout 3600 2>/dev/null || true

# ARP Protection chain
iptables -N ARP_PROTECT 2>/dev/null || true
iptables -F ARP_PROTECT 2>/dev/null || true

# Add to INPUT and FORWARD chains
iptables -C INPUT -j ARP_PROTECT 2>/dev/null || iptables -A INPUT -j ARP_PROTECT
iptables -C FORWARD -j ARP_PROTECT 2>/dev/null || iptables -A FORWARD -j ARP_PROTECT

# Allow ARP requests
iptables -A ARP_PROTECT -p arp --arp-op Request -j ACCEPT

# Allow ARP replies from known devices
iptables -A ARP_PROTECT -p arp --arp-op Reply -m set --match-set arp_known src,src -j ACCEPT

# Allow whitelisted devices
iptables -A ARP_PROTECT -p arp -m set --match-set arp_whitelist src,src -j ACCEPT

# Block blacklisted devices
iptables -A ARP_PROTECT -p arp -m set --match-set arp_blacklist src -j DROP

# Log suspicious ARP packets (limit to 1/min)
iptables -A ARP_PROTECT -p arp -m limit --limit 1/min -j LOG --log-prefix "ARP_SUSPICIOUS: "

# Default drop for other ARP packets
iptables -A ARP_PROTECT -p arp -j DROP

echo "ARP Sentinel firewall rules applied"
EOF

# Make executable
chmod +x /etc/firewall.arp-sentinel

# Include in firewall.user if not already
if ! grep -q "firewall.arp-sentinel" /etc/firewall.user; then
    echo "" >> /etc/firewall.user
    echo "# ARP Sentinel Rules" >> /etc/firewall.user
    echo ". /etc/firewall.arp-sentinel" >> /etc/firewall.user
fi

echo ""
echo "Firewall rules configured!"
echo "Rules will be applied on next firewall restart"
