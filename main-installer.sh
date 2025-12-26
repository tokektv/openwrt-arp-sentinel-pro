
---

## **2. 📄 main-installer.sh**

```bash
#!/bin/sh
# ARP Sentinel Pro - Main Installer
# Calls modules in sequence

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════╗"
    echo "║           ARP Sentinel Pro Installer           ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
}

print_step() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
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

run_module() {
    local module="$1"
    local module_file="modules/${module}"
    
    if [ -f "$module_file" ]; then
        print_step "Running module: ${module%.sh}"
        chmod +x "$module_file"
        if "$module_file"; then
            print_success "Module ${module%.sh} completed"
        else
            print_error "Module ${module%.sh} failed"
            return 1
        fi
    else
        print_error "Module not found: $module"
        return 1
    fi
}

main() {
    print_header
    check_environment
    
    # Create backup
    print_step "Creating system backup..."
    mkdir -p /tmp/arp-sentinel-backup
    cp /etc/config/network /tmp/arp-sentinel-backup/ 2>/dev/null || true
    cp /etc/config/wireless /tmp/arp-sentinel-backup/ 2>/dev/null || true
    print_success "Backup created in /tmp/arp-sentinel-backup"
    
    # Run modules in sequence
    local modules=(
        "01-dependencies.sh"
        "02-directories.sh"
        "03-arpwatch-config.sh"
        "04-firewall-rules.sh"
        "05-luci-interface.sh"
        "06-services.sh"
        "07-cron-jobs.sh"
        "08-monitoring-scripts.sh"
        "09-telegram-bot.sh"
        "10-post-install.sh"
    )
    
    for module in "${modules[@]}"; do
        if ! run_module "$module"; then
            print_error "Installation stopped at ${module%.sh}"
            echo "Check logs in /var/log/arp-sentinel-install.log"
            exit 1
        fi
    done
    
    # Final message
    echo ""
    echo "╔════════════════════════════════════════════════╗"
    echo "║          INSTALLATION COMPLETED SUCCESSFULLY   ║"
    echo "╚════════════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo "1. Configure Telegram bot (optional):"
    echo "   Edit /etc/config/arp-sentinel"
    echo ""
    echo "2. Start the service:"
    echo "   /etc/init.d/arp-sentinel start"
    echo ""
    echo "3. Access web interface:"
    echo "   http://your-router-ip/cgi-bin/luci/admin/network/arp-sentinel"
    echo ""
    echo "4. Check status:"
    echo "   arp-sentinel status"
    echo ""
    echo "For help: arp-sentinel --help"
}

# Run main function
main "$@"
