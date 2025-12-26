#!/bin/sh
# Module 8: Monitoring Scripts

set -e

echo "Installing monitoring scripts..."

# Create monitoring directory
mkdir -p /opt/arp-sentinel/monitoring

# 1. Real-time monitor
cat > /usr/bin/arp-monitor << 'EOF'
#!/bin/sh
# Real-time ARP Monitor

INTERFACE=${1:-br-lan}
LOG_FILE="/var/log/arp-sentinel/monitor.log"

echo "🔍 ARP Real-time Monitor"
echo "Interface: $INTERFACE"
echo "Press Ctrl+C to stop"
echo ""

# Clear screen and show header
clear
echo "╔════════════════════════════════════════════╗"
echo "║            ARP Real-time Monitor           ║"
echo "╠════════════════════════════════════════════╣"
echo "║ Interface: $INTERFACE"
echo "║ Time: $(date)"
echo "╚════════════════════════════════════════════╝"
echo ""

# Monitor ARP traffic
tcpdump -i "$INTERFACE" -n -e arp 2>/dev/null | \
while read -r line; do
    TIMESTAMP=$(date '+%H:%M:%S')
    
    # Parse ARP packet
    if echo "$line" | grep -q "arp who-has"; then
        REQUESTER=$(echo "$line" | sed -n 's/.* \(.*\) > .*: arp who-has \(.*\) tell \(.*\).*/\1/p')
        TARGET=$(echo "$line" | sed -n 's/.* \(.*\) > .*: arp who-has \(.*\) tell \(.*\).*/\2/p')
        ASKER=$(echo "$line" | sed -n 's/.* \(.*\) > .*: arp who-has \(.*\) tell \(.*\).*/\3/p')
        
        echo "[$TIMESTAMP] 📡 REQUEST: $ASKER asks '$TARGET is at?'"
        
    elif echo "$line" | grep -q "arp reply"; then
        SENDER=$(echo "$line" | sed -n 's/.* \(.*\) > .*: arp reply \(.*\) is-at \(.*\).*/\1/p')
        IP=$(echo "$line" | sed -n 's/.* \(.*\) > .*: arp reply \(.*\) is-at \(.*\).*/\2/p')
        MAC=$(echo "$line" | sed -n 's/.* \(.*\) > .*: arp reply \(.*\) is-at \(.*\).*/\3/p')
        
        echo "[$TIMESTAMP] ✅ REPLY: $IP is at $MAC"
        
        # Check if MAC changed
        OLD_MAC=$(arp -n | awk -v ip="$IP" '$1==ip {print $3}')
        if [ -n "$OLD_MAC" ] && [ "$OLD_MAC" != "$MAC" ]; then
            echo "[$TIMESTAMP] ⚠️  WARNING: $IP changed MAC: $OLD_MAC → $MAC"
        fi
    fi
done
EOF

# 2. Network scanner
cat > /usr/bin/arp-scan-detailed << 'EOF'
#!/bin/sh
# Detailed Network Scanner

INTERFACE=${1:-br-lan}

echo "Scanning network on $INTERFACE..."
echo ""

# Get network information
IP_ADDR=$(ip -4 addr show dev "$INTERFACE" | grep inet | awk '{print $2}' | cut -d/ -f1)
NETWORK=$(ip route | grep "dev $INTERFACE" | grep kernel | awk '{print $1}')

echo "Interface: $INTERFACE"
echo "IP Address: $IP_ADDR"
echo "Network: $NETWORK"
echo ""

# Perform scan
arp-scan --interface="$INTERFACE" --localnet --retry=3 --timeout=1000 | \
while read -r line; do
    if echo "$line" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
        IP=$(echo "$line" | awk '{print $1}')
        MAC=$(echo "$line" | awk '{print $2}')
        VENDOR=$(echo "$line" | cut -d$'\t' -f3)
        
        # Check if known
        if arp -n | grep -q "^$IP "; then
            STATUS="✅ Known"
        else
            STATUS="🆕 New"
        fi
        
        printf "%-15s %-17s %-30s %s\n" "$IP" "$MAC" "$VENDOR" "$STATUS"
    fi
done

echo ""
echo "Scan completed at $(date)"
EOF

# 3. Device history tracker
cat > /opt/arp-sentinel/bin/track-devices.sh << 'EOF'
#!/bin/sh
# Track device history

HISTORY_FILE="/opt/arp-sentinel/data/device-history.csv"

# Create header if file doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    echo "timestamp,ip,mac,vendor,event" > "$HISTORY_FILE"
fi

# Get current ARP table
arp -n | grep -v "incomplete" | while read -r line; do
    IP=$(echo "$line" | awk '{print $1}')
    MAC=$(echo "$line" | awk '{print $3}')
    
    if [ -n "$IP" ] && [ -n "$MAC" ]; then
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        VENDOR=$(arp-scan --localnet 2>/dev/null | grep "$IP" | cut -d$'\t' -f3 || echo "Unknown")
        
        # Check if this is new
        if ! grep -q "$IP,$MAC" "$HISTORY_FILE"; then
            echo "$TIMESTAMP,$IP,$MAC,$VENDOR,NEW" >> "$HISTORY_FILE"
        fi
    fi
done

echo "Device history updated: $(wc -l < "$HISTORY_FILE") records"
EOF

# 4. Statistics generator
cat > /opt/arp-sentinel/bin/generate-stats.sh << 'EOF'
#!/bin/sh
# Generate statistics

STATS_FILE="/opt/arp-sentinel/data/stats.json"
LOG_FILE="/var/log/arp-sentinel/arpwatch.log"

# Count events from log
TOTAL_EVENTS=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
NEW_DEVICES=$(grep -c "new station" "$LOG_FILE" 2>/dev/null || echo "0")
CHANGED_MAC=$(grep -c "changed ethernet address" "$LOG_FILE" 2>/dev/null || echo "0")
FLAGGED=$(grep -c "FLAGGED" "$LOG_FILE" 2>/dev/null || echo "0")

# Get current device count
DEVICE_COUNT=$(arp -n | grep -v "incomplete" | wc -l)

# Create stats JSON
cat > "$STATS_FILE" << STATS_EOF
{
    "timestamp": "$(date -Iseconds)",
    "statistics": {
        "total_events": $TOTAL_EVENTS,
        "new_devices": $NEW_DEVICES,
        "changed_mac": $CHANGED_MAC,
        "flagged_events": $FLAGGED,
        "current_devices": $DEVICE_COUNT
    },
    "system": {
        "uptime": "$(uptime -p)",
        "memory_used": "$(free -m | awk '/^Mem:/ {print $3}')MB",
        "disk_used": "$(df -h /overlay | awk 'NR==2 {print $5}')"
    }
}
STATS_EOF

echo "Statistics generated: $STATS_FILE"
EOF

# Make scripts executable
chmod +x /usr/bin/arp-monitor
chmod +x /usr/bin/arp-scan-detailed
chmod +x /opt/arp-sentinel/bin/*.sh

echo ""
echo "Monitoring scripts installed!"
echo "Try: arp-monitor br-lan"
echo "Try: arp-scan-detailed br-lan"
