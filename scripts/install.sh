
---

## **🛠️ 2. Script Instalasi Otomatis Lengkap**

### **`scripts/install.sh`**

```bash
#!/bin/sh
# OpenWrt ARP Sentinel Pro - Installation Script
# GitHub: https://github.com/tokektv/openwrt-arp-sentinel-pro

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/arp-sentinel"
LOG_DIR="/var/log/arp-sentinel"
CONFIG_DIR="/etc/config"
BACKUP_DIR="/tmp/arp-sentinel-backup"
REPO_URL="https://github.com/tokektv/openwrt-arp-sentinel-pro"

print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[-]${NC} $1"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root!"
        exit 1
    fi
}

check_openwrt() {
    if [ ! -f "/etc/openwrt_release" ]; then
        print_error "This script is for OpenWrt only!"
        exit 1
    fi
}

check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check for essential packages
    for pkg in opkg curl wget; do
        if ! command -v $pkg >/dev/null 2>&1; then
            print_error "$pkg is not installed!"
            exit 1
        fi
    done
    
    # Check memory
    MEM_FREE=$(free | awk '/^Mem:/ {print $4}')
    if [ "$MEM_FREE" -lt 50000 ]; then
        print_warning "Low memory available (${MEM_FREE}KB). Some features may be disabled."
    fi
    
    # Check storage
    STORAGE_AVAIL=$(df /overlay | awk 'NR==2 {print $4}')
    if [ "$STORAGE_AVAIL" -lt 5000 ]; then
        print_warning "Low storage available (${STORAGE_AVAIL}KB)."
    fi
}

update_package_list() {
    print_status "Updating package list..."
    opkg update >/dev/null 2>&1 || {
        print_warning "Failed to update package list, continuing anyway..."
    }
}

install_packages() {
    print_status "Installing required packages..."
    
    # Core packages
    CORE_PKGS="arpwatch arp-scan ipset curl ca-bundle logrotate"
    
    # Optional packages (installed if space available)
    OPTIONAL_PKGS="vnstat vnstati tcpdump nmap netdiscore msmtp"
    
    for pkg in $CORE_PKGS; do
        if opkg list-installed | grep -q "^$pkg "; then
            print_status "$pkg is already installed"
        else
            print_status "Installing $pkg..."
            opkg install $pkg --force-overwrite >/dev/null 2>&1 || {
                print_warning "Failed to install $pkg, continuing..."
            }
        fi
    done
    
    # Try to install optional packages
    for pkg in $OPTIONAL_PKGS; do
        if ! opkg list-installed | grep -q "^$pkg "; then
            opkg install $pkg >/dev/null 2>&1 && \
                print_status "Installed optional package: $pkg" || \
                print_warning "Skipping optional package: $pkg"
        fi
    done
}

create_directories() {
    print_status "Creating directories..."
    
    mkdir -p $INSTALL_DIR/{bin,etc,logs,data,baseline}
    mkdir -p $LOG_DIR
    mkdir -p $BACKUP_DIR
    
    # Create symlinks for convenience
    ln -sf $INSTALL_DIR/bin/* /usr/bin/ 2>/dev/null || true
}

backup_existing() {
    print_status "Backing up existing configurations..."
    
    # Backup ARPwatch config if exists
    if [ -f "/etc/arpwatch.conf" ]; then
        cp /etc/arpwatch.conf $BACKUP_DIR/
    fi
    
    # Backup cron jobs
    crontab -l > $BACKUP_DIR/crontab.backup 2>/dev/null || true
    
    # Backup firewall rules
    iptables-save > $BACKUP_DIR/iptables.backup 2>/dev/null || true
}

install_scripts() {
    print_status "Installing scripts..."
    
    # Copy all scripts from repository
    cp -r scripts/* $INSTALL_DIR/bin/
    
    # Make scripts executable
    chmod +x $INSTALL_DIR/bin/*
    
    # Create symlinks in /usr/bin
    for script in $INSTALL_DIR/bin/*; do
        script_name=$(basename $script)
        ln -sf $script /usr/bin/$script_name 2>/dev/null || true
    done
    
    # Install main sentinel script
    cat > /usr/bin/arp-sentinel << 'EOF'
#!/bin/sh
# ARP Sentinel Main Controller

case "$1" in
    start)
        /opt/arp-sentinel/bin/start-sentinel.sh
        ;;
    stop)
        /opt/arp-sentinel/bin/stop-sentinel.sh
        ;;
    restart)
        /opt/arp-sentinel/bin/stop-sentinel.sh
        sleep 2
        /opt/arp-sentinel/bin/start-sentinel.sh
        ;;
    status)
        /opt/arp-sentinel/bin/status-sentinel.sh
        ;;
    scan)
        /opt/arp-sentinel/bin/network-scan.sh
        ;;
    alerts)
        tail -f /var/log/arp-sentinel/alerts.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|scan|alerts}"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/bin/arp-sentinel
}

install_configs() {
    print_status "Installing configurations..."
    
    # ARPwatch configuration
    cat > /etc/arpwatch.conf << 'EOF'
# ARPwatch configuration for ARP Sentinel Pro
OPTIONS="-N -f /var/log/arp-sentinel/arpwatch.log"
INTERFACES="br-lan"
ARGFILE="/var/arpwatch/arpwatch.dat"
EOF
    
    # UCI configuration
    cat > $CONFIG_DIR/arp-sentinel << 'EOF'
config global 'arp_sentinel'
    option enabled '1'
    option alert_method 'both'
    option email_alerts '0'
    option telegram_alerts '1'
    option log_level 'info'
    option auto_baseline '1'
    option baseline_update '24'

config interface 'lan'
    option name 'lan'
    option interface 'br-lan'
    option monitor '1'
    option protect '1'
    option whitelist_only '0'

config interface 'wan'
    option name 'wan'
    option interface 'eth0'
    option monitor '1'
    option protect '0'

config telegram 'alert'
    option bot_token ''
    option chat_id ''
    option enable_preview '0'

config email 'alert'
    option smtp_server ''
    option smtp_port '587'
    option username ''
    option password ''
    option recipient ''
EOF
    
    # Firewall rules
    cat > /etc/firewall.arp-sentinel << 'EOF'
#!/bin/sh
# ARP Sentinel Firewall Rules

. /lib/functions.sh
. /lib/functions/network.sh

# Create IPSet for known devices
ipset create arp_known hash:ip,mac timeout 86400 -exist
ipset create arp_whitelist hash:ip,mac -exist
ipset create arp_suspicious hash:ip timeout 3600 -exist

# ARP Protection chain
fw4 add chain filter ARP_PROTECT
fw4 add rule filter INPUT jump ARP_PROTECT
fw4 add rule filter FORWARD jump ARP_PROTECT

# Allow ARP requests
fw4 add rule filter ARP_PROTECT pkttype arp-request accept

# Check ARP replies against known devices
fw4 add rule filter ARP_PROTECT pkttype arp-reply \
    ipset match arp_known src,src accept

# Log suspicious ARP
fw4 add rule filter ARP_PROTECT pkttype arp-reply \
    limit 1/minute log prefix "ARP_Spoof: " level warning drop

# Allow whitelisted devices
fw4 add rule filter ARP_PROTECT ipset match arp_whitelist src,src accept
EOF
}

install_luci_app() {
    print_status "Installing LuCI web interface..."
    
    LUCIDIR="/usr/lib/lua/luci"
    
    if [ -d "$LUCIDIR" ]; then
        mkdir -p $LUCIDIR/controller $LUCIDIR/model/cbi $LUCIDIR/view/arp-sentinel
        
        # Controller
        cat > $LUCIDIR/controller/arp-sentinel.lua << 'EOF'
module("luci.controller.arp-sentinel", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/arp-sentinel") then
        return
    end
    
    entry({"admin", "network", "arp-sentinel"}, firstchild(), _("ARP Sentinel"), 60).dependent = false
    
    entry({"admin", "network", "arp-sentinel", "dashboard"}, template("arp-sentinel/dashboard"), _("Dashboard"), 10)
    entry({"admin", "network", "arp-sentinel", "devices"}, arcombine(template("arp-sentinel/devices"), cbi("arp-sentinel/devices")), _("Devices"), 20)
    entry({"admin", "network", "arp-sentinel", "alerts"}, template("arp-sentinel/alerts"), _("Alerts"), 30)
    entry({"admin", "network", "arp-sentinel", "settings"}, cbi("arp-sentinel/settings"), _("Settings"), 40)
    entry({"admin", "network", "arp-sentinel", "tools"}, template("arp-sentinel/tools"), _("Tools"), 50)
    entry({"admin", "network", "arp-sentinel", "logs"}, template("arp-sentinel/logs"), _("Logs"), 60)
    
    entry({"admin", "network", "arp-sentinel", "status"}, call("action_status")).leaf = true
    entry({"admin", "network", "arp-sentinel", "scan"}, call("action_scan")).leaf = true
    entry({"admin", "network", "arp-sentinel", "get_logs"}, call("get_logs")).leaf = true
end

function action_status()
    local sys = require "luci.sys"
    local http = require "luci.http"
    
    local data = {
        arpwatch = sys.exec("pidof arpwatch 2>/dev/null") ~= "" and 1 or 0,
        memory = sys.exec("free | awk '/^Mem:/ {printf \"%.1f\", $3/$2*100}'"),
        alerts = sys.exec("tail -5 /var/log/arp-sentinel/alerts.log | wc -l"),
        devices = sys.exec("arp -n | wc -l")
    }
    
    http.prepare_content("application/json")
    http.write_json(data)
end

function action_scan()
    local sys = require "luci.sys"
    local http = require "luci.http"
    
    local result = sys.exec("arp-scan --interface=br-lan --localnet 2>&1 | head -50")
    http.write(result)
end

function get_logs()
    local sys = require "luci.sys"
    local http = require "luci.http"
    
    local lines = tonumber(http.formvalue("lines") or 50)
    local log = sys.exec("tail -n " .. lines .. " /var/log/arp-sentinel/alerts.log 2>/dev/null")
    
    http.prepare_content("text/plain")
    http.write(log or "No logs available")
end
EOF
        
        # CBI Model
        cat > $LUCIDIR/model/cbi/arp-sentinel/settings.lua << 'EOF'
m = Map("arp-sentinel", translate("ARP Sentinel Settings"))

s = m:section(TypedSection, "global", translate("Global Settings"))
s.anonymous = true

s:option(Flag, "enabled", translate("Enable ARP Sentinel"))
s:option(ListValue, "alert_method", translate("Alert Method"))
    :value("none", "No Alerts")
    :value("log", "Log Only")
    :value("telegram", "Telegram")
    :value("email", "Email")
    :value("both", "Both")

s:option(Flag, "auto_baseline", translate("Auto Baseline Learning"))
s:option(Value, "baseline_update", translate("Baseline Update (hours)"))
    :depends("auto_baseline", "1")

-- Telegram settings
tg = m:section(TypedSection, "telegram", translate("Telegram Settings"))
tg.anonymous = true
tg:option(Value, "bot_token", translate("Bot Token"))
tg:option(Value, "chat_id", translate("Chat ID"))
tg:option(Flag, "enable_preview", translate("Enable Link Preview"))

return m
EOF
        
        # Templates (simplified)
        mkdir -p $LUCIDIR/view/arp-sentinel
        echo "<h1>ARP Sentinel Dashboard</h1>" > $LUCIDIR/view/arp-sentinel/dashboard.htm
        
        print_success "LuCI app installed"
    else
        print_warning "LuCI not found, skipping web interface installation"
    fi
}

setup_services() {
    print_status "Setting up services..."
    
    # Main service
    cat > /etc/init.d/arp-sentinel << 'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /opt/arp-sentinel/bin/main-daemon.sh
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn 300 5 0
    procd_set_param pidfile /var/run/arp-sentinel.pid
    procd_close_instance
}

stop_service() {
    /opt/arp-sentinel/bin/stop-sentinel.sh
}
EOF
    
    chmod +x /etc/init.d/arp-sentinel
    
    # Enable services
    /etc/init.d/arp-sentinel enable
    /etc/init.d/firewall enable
    
    # Add to rc.local for startup
    if ! grep -q "arp-sentinel" /etc/rc.local; then
        sed -i '/exit 0/i\/etc/init.d/arp-sentinel start' /etc/rc.local
    fi
}

setup_cron() {
    print_status "Setting up cron jobs..."
    
    CRON_FILE="/etc/crontabs/root"
    
    # Backup existing cron
    cp $CRON_FILE $BACKUP_DIR/crontab.original 2>/dev/null || true
    
    # Add our cron jobs
    {
        echo "# ARP Sentinel Pro Cron Jobs"
        echo "0 */6 * * * /opt/arp-sentinel/bin/update-baseline.sh >/dev/null 2>&1"
        echo "*/5 * * * * /opt/arp-sentinel/bin/health-check.sh >/dev/null 2>&1"
        echo "0 2 * * * /opt/arp-sentinel/bin/cleanup-logs.sh >/dev/null 2>&1"
        echo "*/15 * * * * /opt/arp-sentinel/bin/check-anomalies.sh >/dev/null 2>&1"
    } >> $CRON_FILE
    
    # Restart cron
    /etc/init.d/cron restart 2>/dev/null || true
}

setup_logging() {
    print_status "Setting up logging..."
    
    # Logrotate config
    cat > /etc/logrotate.d/arp-sentinel << 'EOF'
/var/log/arp-sentinel/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
    sharedscripts
    postrotate
        /etc/init.d/arp-sentinel restart >/dev/null 2>&1 || true
    endscript
}
EOF
    
    # Rsyslog config if available
    if [ -d "/etc/rsyslog.d" ]; then
        cat > /etc/rsyslog.d/arp-sentinel.conf << 'EOF'
:programname, isequal, "arp-sentinel" /var/log/arp-sentinel/syslog.log
:programname, isequal, "arpwatch" /var/log/arp-sentinel/arpwatch.log
& stop
EOF
    fi
}

post_installation() {
    print_status "Running post-installation tasks..."
    
    # Create initial baseline
    print_status "Creating initial network baseline..."
    /opt/arp-sentinel/bin/create-baseline.sh >/dev/null 2>&1 || true
    
    # Start services
    print_status "Starting services..."
    /etc/init.d/arp-sentinel start
    /etc/init.d/firewall restart
    
    # Wait a bit for services to start
    sleep 3
    
    # Test functionality
    if pgrep -f "arpwatch" >/dev/null; then
        print_success "ARPwatch is running"
    else
        print_warning "ARPwatch failed to start, check logs"
    fi
    
    # Set permissions
    chmod 755 $INSTALL_DIR
    chown -R root:root $INSTALL_DIR
    chmod -R 755 $INSTALL_DIR/bin
}

show_summary() {
    print_success "Installation completed!"
    echo ""
    echo "┌─────────────────────────────────────────────┐"
    echo "│           ARP SENTINEL PRO INSTALLED        │"
    echo "├─────────────────────────────────────────────┤"
    echo "│  Installation Directory: $INSTALL_DIR       │"
    echo "│  Log Directory:         $LOG_DIR           │"
    echo "│  Configuration:         $CONFIG_DIR        │"
    echo "│  Backup Directory:      $BACKUP_DIR        │"
    echo "├─────────────────────────────────────────────┤"
    echo "│  Available Commands:                        │"
    echo "│    • arp-sentinel start|stop|restart        │"
    echo "│    • arp-sentinel status                    │"
    echo "│    • arp-sentinel scan                      │"
    echo "│    • arp-sentinel alerts                    │"
    echo "│    • arp-monitor (real-time monitoring)     │"
    echo "├─────────────────────────────────────────────┤"
    echo "│  Web Interface:                             │"
    echo "│    LuCI → Network → ARP Sentinel            │"
    echo "│  Or access via: http://<router-ip>/cgi-bin/ │"
    echo "│               luci/admin/network/arp-sentinel│"
    echo "└─────────────────────────────────────────────┘"
    echo ""
    print_warning "Don't forget to:"
    echo "  1. Configure Telegram/Email alerts in LuCI"
    echo "  2. Review baseline settings"
    echo "  3. Check firewall rules"
    echo ""
    echo "Backup files are saved in: $BACKUP_DIR"
    echo ""
    print_status "Starting ARP Sentinel in 5 seconds..."
    
    # Final test
    sleep 5
    if /usr/bin/arp-sentinel status | grep -q "running"; then
        print_success "ARP Sentinel is now active and protecting your network!"
    else
        print_warning "Some services may not have started. Check logs at $LOG_DIR"
    fi
}

cleanup() {
    print_status "Cleaning up temporary files..."
    rm -rf /tmp/arp-sentinel-*
}

main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║    OpenWrt ARP Sentinel Pro Installer    ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    
    # Run installation steps
    check_root
    check_openwrt
    check_dependencies
    update_package_list
    install_packages
    create_directories
    backup_existing
    install_scripts
    install_configs
    install_luci_app
    setup_services
    setup_cron
    setup_logging
    post_installation
    cleanup
    show_summary
}

# Handle script arguments
case "$1" in
    --help|-h)
        echo "Usage: $0 [OPTION]"
        echo "Install ARP Sentinel Pro on OpenWrt"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help"
        echo "  --minimal      Install minimal version"
        echo "  --uninstall    Uninstall ARP Sentinel"
        echo "  --update       Update from repository"
        exit 0
        ;;
    --minimal)
        export MINIMAL_INSTALL=1
        ;;
    --uninstall)
        exec /opt/arp-sentinel/bin/uninstall.sh
        ;;
    --update)
        print_status "Update feature coming soon!"
        exit 0
        ;;
esac

# Run main installation
main "$@"
