#!/bin/sh
# Module 6: System Services

set -e

echo "Setting up system services..."

# Create main service
cat > /etc/init.d/arp-sentinel << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /opt/arp-sentinel/bin/daemon.sh
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn 300 5 0
    procd_close_instance
}

stop_service() {
    /opt/arp-sentinel/bin/stop.sh
}
EOF

chmod +x /etc/init.d/arp-sentinel

# Create daemon script
cat > /opt/arp-sentinel/bin/daemon.sh << 'EOF'
#!/bin/sh
# ARP Sentinel Daemon

INTERFACE=$(uci get arp-sentinel.@global[0].interface 2>/dev/null || echo "br-lan")
LOG_DIR="/var/log/arp-sentinel"

# Start ARPwatch
echo "Starting ARPwatch on interface $INTERFACE"
arpwatch -i "$INTERFACE" -f "$LOG_DIR/arpwatch.log" &

# Start log monitor
/opt/arp-sentinel/bin/log-monitor.sh &

# Start periodic scanner
/opt/arp-sentinel/bin/periodic-scanner.sh &

echo "ARP Sentinel started"
echo "Interface: $INTERFACE"
echo "Logs: $LOG_DIR"

# Keep script running
while true; do
    sleep 60
    # Check if ARPwatch is still running
    if ! pgrep arpwatch >/dev/null; then
        echo "ARPwatch stopped, restarting..."
        arpwatch -i "$INTERFACE" -f "$LOG_DIR/arpwatch.log" &
    fi
done
EOF

chmod +x /opt/arp-sentinel/bin/daemon.sh

# Create stop script
cat > /opt/arp-sentinel/bin/stop.sh << 'EOF'
#!/bin/sh
# Stop ARP Sentinel

echo "Stopping ARP Sentinel..."
pkill arpwatch
pkill -f "log-monitor.sh"
pkill -f "periodic-scanner.sh"
echo "Stopped"
EOF

chmod +x /opt/arp-sentinel/bin/stop.sh

# Create status script
cat > /usr/bin/arp-sentinel-status << 'EOF'
#!/bin/sh
# ARP Sentinel Status

echo "=== ARP Sentinel Status ==="
echo "Time: $(date)"
echo ""

# Check services
if pgrep arpwatch >/dev/null; then
    echo "ARPwatch:    RUNNING ($(pgrep arpwatch))"
else
    echo "ARPwatch:    STOPPED"
fi

if pgrep -f "log-monitor.sh" >/dev/null; then
    echo "Log Monitor: RUNNING"
else
    echo "Log Monitor: STOPPED"
fi

echo ""
echo "=== Network Info ==="
INTERFACE=$(uci get arp-sentinel.@global[0].interface 2>/dev/null || echo "br-lan")
echo "Interface: $INTERFACE"
echo "Devices: $(arp -n | wc -l)"
echo ""

echo "=== Recent Logs ==="
tail -5 /var/log/arp-sentinel/arpwatch.log 2>/dev/null || echo "No logs"
EOF

chmod +x /usr/bin/arp-sentinel-status

# Create control script
cat > /usr/bin/arp-sentinel << 'EOF'
#!/bin/sh
# ARP Sentinel Control Script

case "$1" in
    start)
        /etc/init.d/arp-sentinel start
        ;;
    stop)
        /etc/init.d/arp-sentinel stop
        ;;
    restart)
        /etc/init.d/arp-sentinel restart
        ;;
    status)
        /usr/bin/arp-sentinel-status
        ;;
    scan)
        INTERFACE=$(uci get arp-sentinel.@global[0].interface 2>/dev/null || echo "br-lan")
        echo "Scanning $INTERFACE..."
        arp-scan --interface="$INTERFACE" --localnet
        ;;
    logs)
        tail -f /var/log/arp-sentinel/arpwatch.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|scan|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start ARP Sentinel"
        echo "  stop     - Stop ARP Sentinel"
        echo "  restart  - Restart ARP Sentinel"
        echo "  status   - Show status"
        echo "  scan     - Scan network"
        echo "  logs     - Show live logs"
        exit 1
        ;;
esac
EOF

chmod +x /usr/bin/arp-sentinel

# Enable service
/etc/init.d/arp-sentinel enable

echo ""
echo "Services configured!"
echo "Control with: arp-sentinel {start|stop|status|scan|logs}"
