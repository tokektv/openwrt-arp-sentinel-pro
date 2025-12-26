#!/bin/sh
# ARP Sentinel Pro - Main Installer
# CLEAN VERSION - No backticks, no substitution errors

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    clear
    echo ""
    echo "=================================================="
    echo "           ARP Sentinel Pro Installer"
    echo "=================================================="
    echo ""
}

print_step() {
    echo "[$(date '+%H:%M:%S')] $1"
}

print_success() {
    echo "✓ $1"
}

print_error() {
    echo "✗ $1"
}

check_environment() {
    print_step "Checking environment..."
    
    # Check if running on OpenWrt
    if [ ! -f "/etc/openwrt_release" ]; then
        print_error "This installer is for OpenWrt only!"
        exit 1
    fi
    
    # Check root
    if [ "$(id -u)" -ne 0 ]; then
        print_error "Please run as root!"
        exit 1
    fi
    
    print_success "Environment OK"
}

install_dependencies() {
    print_step "Installing dependencies..."
    
    opkg update
    opkg install arpwatch arp-scan ipset curl ca-bundle
    
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed"
    else
        print_error "Failed to install some packages"
        exit 1
    fi
}

create_directories() {
    print_step "Creating directories..."
    
    mkdir -p /opt/arp-sentinel
    mkdir -p /opt/arp-sentinel/bin
    mkdir -p /opt/arp-sentinel/data
    mkdir -p /var/log/arp-sentinel
    
    print_success "Directories created"
}

setup_arpwatch() {
    print_step "Setting up ARPwatch..."
    
    # Create config
    cat > /etc/arpwatch.conf << ARPWATCH_CONF
# ARPwatch configuration for ARP Sentinel
OPTIONS="-N"
INTERFACES="br-lan"
ARGFILE="/var/lib/arpwatch/arp.dat"
ARPWATCH_CONF
    
    print_success "ARPwatch configured"
}

create_main_script() {
    print_step "Creating main script..."
    
    cat > /usr/bin/arp-sentinel << MAIN_SCRIPT
#!/bin/sh
# ARP Sentinel Control Script

show_help() {
    echo "ARP Sentinel Commands:"
    echo "  start    - Start monitoring"
    echo "  stop     - Stop monitoring"
    echo "  status   - Show status"
    echo "  scan     - Scan network"
    echo "  logs     - Show logs"
    echo "  help     - Show this help"
}

case "\$1" in
    start)
        echo "Starting ARP Sentinel..."
        arpwatch -i br-lan -f /var/log/arp-sentinel/arpwatch.log &
        echo "Started"
        ;;
    stop)
        echo "Stopping ARP Sentinel..."
        pkill arpwatch
        echo "Stopped"
        ;;
    status)
        echo "ARP Sentinel Status:"
        if ps | grep -q "[a]rpwatch"; then
            echo "  ARPwatch: RUNNING"
        else
            echo "  ARPwatch: STOPPED"
        fi
        echo ""
        echo "Network devices: \$(arp -n | grep -v incomplete | wc -l)"
        ;;
    scan)
        echo "Scanning network..."
        arp-scan --interface=br-lan --localnet
        ;;
    logs)
        echo "Showing logs..."
        tail -f /var/log/arp-sentinel/arpwatch.log
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: \$1"
        show_help
        exit 1
        ;;
esac
MAIN_SCRIPT
    
    chmod +x /usr/bin/arp-sentinel
    print_success "Main script created"
}

setup_monitoring_script() {
    print_step "Creating monitoring script..."
    
    cat > /usr/bin/arp-monitor << MONITOR_SCRIPT
#!/bin/sh
# Real-time ARP Monitor

echo "ARP Real-time Monitor"
echo "Interface: br-lan"
echo "Press Ctrl+C to stop"
echo ""

tcpdump -i br-lan -n -e arp 2>/dev/null | while read line; do
    timestamp=\$(date '+%H:%M:%S')
    
    if echo "\$line" | grep -q "arp who-has"; then
        echo "[\$timestamp] REQUEST: \$line"
    elif echo "\$line" | grep -q "arp reply"; then
        echo "[\$timestamp] REPLY: \$line"
    fi
done
MONITOR_SCRIPT
    
    chmod +x /usr/bin/arp-monitor
    print_success "Monitor script created"
}

setup_service() {
    print_step "Setting up service..."
    
    cat > /etc/init.d/arp-sentinel << SERVICE_SCRIPT
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
    /usr/bin/arp-sentinel start
}

stop() {
    /usr/bin/arp-sentinel stop
}

restart() {
    stop
    sleep 2
    start
}
SERVICE_SCRIPT
    
    chmod +x /etc/init.d/arp-sentinel
    /etc/init.d/arp-sentinel enable
    
    print_success "Service configured"
}

show_summary() {
    echo ""
    echo "=================================================="
    echo "          INSTALLATION COMPLETED"
    echo "=================================================="
    echo ""
    echo "What was installed:"
    echo "  1. arpwatch & arp-scan packages"
    echo "  2. Main command: arp-sentinel"
    echo "  3. Monitor command: arp-monitor"
    echo "  4. Service: /etc/init.d/arp-sentinel"
    echo "  5. Log directory: /var/log/arp-sentinel"
    echo ""
    echo "Quick start:"
    echo "  arp-sentinel start    # Start monitoring"
    echo "  arp-sentinel status   # Check status"
    echo "  arp-monitor           # Real-time monitor"
    echo "  arp-sentinel scan     # Scan network"
    echo ""
    echo "Web interface (LuCI) will be available in next version"
    echo ""
    echo "Logs: tail -f /var/log/arp-sentinel/arpwatch.log"
    echo ""
}

main() {
    print_header
    check_environment
    install_dependencies
    create_directories
    setup_arpwatch
    create_main_script
    setup_monitoring_script
    setup_service
    
    # Start the service
    /usr/bin/arp-sentinel start
    
    show_summary
}

# Run main function
main
