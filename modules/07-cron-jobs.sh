#!/bin/sh
# Module 7: Cron Jobs

set -e

echo "Setting up cron jobs..."

# Create cron directory
mkdir -p /etc/cron.d

# Create ARP Sentinel cron file
cat > /etc/cron.d/arp-sentinel << 'EOF'
# ARP Sentinel Cron Jobs
# Generated on $(date)

# Update baseline every 6 hours
0 */6 * * * /opt/arp-sentinel/bin/update-baseline.sh >/dev/null 2>&1

# Health check every 15 minutes
*/15 * * * * /opt/arp-sentinel/bin/health-check.sh >/dev/null 2>&1

# Clean old logs daily at 3 AM
0 3 * * * /opt/arp-sentinel/bin/clean-logs.sh >/dev/null 2>&1

# Daily report at midnight
0 0 * * * /opt/arp-sentinel/bin/daily-report.sh >/dev/null 2>&1

# Check for anomalies every 5 minutes
*/5 * * * * /opt/arp-sentinel/bin/check-anomalies.sh >/dev/null 2>&1
EOF

# Create cron scripts
mkdir -p /opt/arp-sentinel/bin

# update-baseline.sh
cat > /opt/arp-sentinel/bin/update-baseline.sh << 'EOF'
#!/bin/sh
# Update ARP baseline

BASELINE_FILE="/opt/arp-sentinel/data/baseline.json"
INTERFACE=$(uci get arp-sentinel.@global[0].interface 2>/dev/null || echo "br-lan")

echo "$(date): Updating baseline for $INTERFACE" >> /var/log/arp-sentinel/cron.log

# Get current ARP table
arp -n | awk '/^[0-9]/ {print $1 " " $3}' > "/tmp/current-arp.txt"

# Update baseline
if [ -f "$BASELINE_FILE" ]; then
    # Merge with existing
    cat "/tmp/current-arp.txt" >> "$BASELINE_FILE"
    sort -u "$BASELINE_FILE" -o "$BASELINE_FILE"
else
    cp "/tmp/current-arp.txt" "$BASELINE_FILE"
fi

echo "Baseline updated with $(wc -l < "$BASELINE_FILE") devices" >> /var/log/arp-sentinel/cron.log
EOF

# health-check.sh
cat > /opt/arp-sentinel/bin/health-check.sh << 'EOF'
#!/bin/sh
# Health check script

LOG_FILE="/var/log/arp-sentinel/health.log"

echo "$(date): Health check started" >> "$LOG_FILE"

# Check ARPwatch
if ! pgrep arpwatch >/dev/null; then
    echo "ARPwatch not running, restarting..." >> "$LOG_FILE"
    /etc/init.d/arp-sentinel restart
fi

# Check disk space
DISK_USAGE=$(df /overlay | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "Warning: Disk usage $DISK_USAGE%" >> "$LOG_FILE"
fi

# Check memory
MEM_FREE=$(free | awk '/^Mem:/ {print $4}')
if [ "$MEM_FREE" -lt 10000 ]; then
    echo "Warning: Low memory $MEM_FREE KB" >> "$LOG_FILE"
fi

echo "$(date): Health check completed" >> "$LOG_FILE"
EOF

# clean-logs.sh
cat > /opt/arp-sentinel/bin/clean-logs.sh << 'EOF'
#!/bin/sh
# Clean old logs

LOG_DIR="/var/log/arp-sentinel"
DAYS_TO_KEEP=7

echo "$(date): Cleaning logs older than $DAYS_TO_KEEP days" >> "$LOG_DIR/cleanup.log"

# Remove old log files
find "$LOG_DIR" -name "*.log" -mtime +$DAYS_TO_KEEP -delete

# Compress logs older than 1 day
find "$LOG_DIR" -name "*.log" -mtime +1 -exec gzip {} \;

# Keep directory size under control
du -sh "$LOG_DIR" >> "$LOG_DIR/cleanup.log"
EOF

# Make scripts executable
chmod +x /opt/arp-sentinel/bin/*.sh

# Restart cron if available
if [ -f "/etc/init.d/cron" ]; then
    /etc/init.d/cron restart
fi

echo ""
echo "Cron jobs installed!"
echo "Check logs in /var/log/arp-sentinel/cron.log"
