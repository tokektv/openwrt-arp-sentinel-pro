#!/bin/sh
# Module 5: LuCI Web Interface

set -e

echo "Installing LuCI web interface..."

# Check if LuCI is installed
if [ ! -d "/usr/lib/lua/luci" ]; then
    echo "  ⚠️  LuCI not found, skipping web interface"
    exit 0
fi

# Create LuCI app directory structure
LUCI_DIR="/usr/lib/lua/luci"
APP_DIR="$LUCI_DIR/controller/arp-sentinel"
MODEL_DIR="$LUCI_DIR/model/cbi/arp-sentinel"
VIEW_DIR="$LUCI_DIR/view/arp-sentinel"

mkdir -p "$APP_DIR" "$MODEL_DIR" "$VIEW_DIR"

# Create controller
cat > "$APP_DIR/arp-sentinel.lua" << 'EOF'
module("luci.controller.arp-sentinel", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/arp-sentinel") then
        return
    end
    
    entry({"admin", "network", "arp-sentinel"}, firstchild(), _("ARP Sentinel"), 60).dependent = false
    
    entry({"admin", "network", "arp-sentinel", "status"}, template("arp-sentinel/status"), _("Status"), 10)
    entry({"admin", "network", "arp-sentinel", "devices"}, template("arp-sentinel/devices"), _("Devices"), 20)
    entry({"admin", "network", "arp-sentinel", "alerts"}, template("arp-sentinel/alerts"), _("Alerts"), 30)
    entry({"admin", "network", "arp-sentinel", "settings"}, cbi("arp-sentinel/settings"), _("Settings"), 40)
    
    entry({"admin", "network", "arp-sentinel", "get_status"}, call("action_status")).leaf = true
    entry({"admin", "network", "arp-sentinel", "scan_now"}, call("action_scan")).leaf = true
end

function action_status()
    local sys = require "luci.sys"
    local http = require "luci.http"
    
    local data = {
        arpwatch = sys.exec("pidof arpwatch 2>/dev/null") ~= "" and 1 or 0,
        devices = sys.exec("arp -n | wc -l") or "0",
        memory = sys.exec("free -m | awk 'NR==2{printf \"%s/%sMB\", $3, $2}'") or "N/A",
        uptime = sys.exec("uptime | cut -d',' -f1 | cut -d' ' -f4-") or "N/A"
    }
    
    http.prepare_content("application/json")
    http.write_json(data)
end

function action_scan()
    local sys = require "luci.sys"
    local http = require "luci.http"
    
    local result = sys.exec("arp-scan --interface=br-lan --localnet 2>&1 | head -30")
    http.prepare_content("text/plain")
    http.write(result or "Scan failed")
end
EOF

# Create CBI model
cat > "$MODEL_DIR/settings.lua" << 'EOF'
m = Map("arp-sentinel", translate("ARP Sentinel Settings"))

s = m:section(TypedSection, "global", translate("Global Settings"))
s.anonymous = true

o = s:option(Flag, "enabled", translate("Enable ARP Sentinel"))
o.default = "1"

o = s:option(ListValue, "alert_method", translate("Alert Method"))
o:value("none", "No Alerts")
o:value("log", "Log Only")
o:value("telegram", "Telegram")
o:value("email", "Email")
o.default = "log"

o = s:option(Value, "interface", translate("Monitor Interface"))
o.default = "br-lan"
o:value("br-lan", "LAN (br-lan)")
o:value("eth0", "WAN (eth0)")

o = s:option(Flag, "auto_baseline", translate("Auto Baseline Learning"))
o.default = "1"

o = s:option(Value, "scan_interval", translate("Scan Interval (minutes)"))
o.default = "60"
o.datatype = "range(5,1440)"

return m
EOF

# Create simple view template
mkdir -p "$VIEW_DIR"
cat > "$VIEW_DIR/status.htm" << 'EOF'
<%+header%>

<h2><a href="<%=controller%>/admin/network/arp-sentinel"><%:ARP Sentinel%></a> › <%:Status%></h2>

<div class="cbi-map">
    <div class="cbi-section">
        <div class="cbi-section-node">
            <div class="table" id="status-table">
                <div class="tr table-titles">
                    <div class="th"><%:Service%></div>
                    <div class="th"><%:Status%></div>
                    <div class="th"><%:Action%></div>
                </div>
                <div class="tr">
                    <div class="td">ARPwatch</div>
                    <div class="td" id="arpwatch-status">Checking...</div>
                    <div class="td">
                        <button class="btn cbi-button" onclick="startService('arpwatch')"><%:Start%></button>
                        <button class="btn cbi-button" onclick="stopService('arpwatch')"><%:Stop%></button>
                    </div>
                </div>
            </div>
            
            <br>
            <button class="btn cbi-button cbi-button-action" onclick="scanNetwork()"><%:Scan Network%></button>
            <div id="scan-result" class="cbi-value-description"></div>
        </div>
    </div>
</div>

<script>
function updateStatus() {
    fetch('<%=luci.dispatcher.build_url("admin/network/arp-sentinel/get_status")%>')
        .then(r => r.json())
        .then(data => {
            document.getElementById('arpwatch-status').textContent = 
                data.arpwatch ? 'Running' : 'Stopped';
        });
}

function scanNetwork() {
    document.getElementById('scan-result').textContent = 'Scanning...';
    fetch('<%=luci.dispatcher.build_url("admin/network/arp-sentinel/scan_now")%>')
        .then(r => r.text())
        .then(data => {
            document.getElementById('scan-result').innerHTML = 
                '<pre>' + data + '</pre>';
        });
}

// Update status every 10 seconds
setInterval(updateStatus, 10000);
updateStatus();
</script>

<%+footer%>
EOF

# Create UCI configuration
cat > /etc/config/arp-sentinel << 'EOF'
config global 'arp_sentinel'
    option enabled '1'
    option interface 'br-lan'
    option alert_method 'log'
    option auto_baseline '1'
    option scan_interval '60'

config telegram 'alert'
    option enabled '0'
    option bot_token ''
    option chat_id ''
EOF

echo ""
echo "LuCI interface installed!"
echo "Access at: LuCI → Network → ARP Sentinel"
