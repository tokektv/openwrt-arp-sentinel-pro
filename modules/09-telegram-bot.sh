#!/bin/sh
# Module 9: Telegram Bot (Optional)

set -e

echo "Setting up Telegram bot (optional)..."

# Create Telegram bot directory
mkdir -p /opt/arp-sentinel/telegram

# Create bot script
cat > /opt/arp-sentinel/telegram/bot.sh << 'EOF'
#!/bin/sh
# Telegram Bot for ARP Sentinel

CONFIG_FILE="/etc/config/arp-sentinel"
LOG_FILE="/var/log/arp-sentinel/telegram.log"

# Read config
if [ -f "$CONFIG_FILE" ]; then
    BOT_TOKEN=$(uci get arp-sentinel.@telegram[0].bot_token 2>/dev/null || echo "")
    CHAT_ID=$(uci get arp-sentinel.@telegram[0].chat_id 2>/dev/null || echo "")
    ENABLED=$(uci get arp-sentinel.@telegram[0].enabled 2>/dev/null || echo "0")
else
    BOT_TOKEN=""
    CHAT_ID=""
    ENABLED="0"
fi

# Check if enabled
if [ "$ENABLED" != "1" ] || [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Telegram bot not configured or disabled" >> "$LOG_FILE"
    exit 0
fi

send_message() {
    local message="$1"
    
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$message" \
        -d parse_mode="HTML" >> "$LOG_FILE" 2>&1
    
    echo "$(date): Sent message" >> "$LOG_FILE"
}

send_alert() {
    local severity="$1"
    local ip="$2"
    local mac="$3"
    local message="$4"
    
    local alert_message="🛡️ <b>ARP Sentinel Alert</b>
    
Severity: $severity
IP: $ip
MAC: $mac
Event: $message
Time: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_message "$alert_message"
}

# Monitor ARPwatch log for alerts
tail -F /var/log/arp-sentinel/arpwatch.log 2>/dev/null | \
while read -r line; do
    # Check for different types of events
    if echo "$line" | grep -q "FLAGGED"; then
        # Parse FLAGGED event
        IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        MAC=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)
        send_alert "HIGH" "$IP" "$MAC" "Suspicious activity detected"
        
    elif echo "$line" | grep -q "changed ethernet address"; then
        # Parse MAC change
        IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        MAC=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | tail -1)
        send_alert "MEDIUM" "$IP" "$MAC" "MAC address changed"
        
    elif echo "$line" | grep -q "new station"; then
        # Parse new device
        IP=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        MAC=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)
        send_alert "LOW" "$IP" "$MAC" "New device detected"
    fi
done
EOF

# Create configuration helper
cat > /opt/arp-sentinel/telegram/configure.sh << 'EOF'
#!/bin/sh
# Configure Telegram bot

echo "=== Telegram Bot Configuration ==="
echo ""
echo "To use Telegram alerts:"
echo "1. Create a bot with @BotFather on Telegram"
echo "2. Get your bot token"
echo "3. Get your chat ID (send message to @userinfobot)"
echo ""
echo "Then run:"
echo "uci set arp-sentinel.@telegram[0].enabled='1'"
echo "uci set arp-sentinel.@telegram[0].bot_token='YOUR_BOT_TOKEN'"
echo "uci set arp-sentinel.@telegram[0].chat_id='YOUR_CHAT_ID'"
echo "uci commit arp-sentinel"
echo ""
echo "Start bot: /opt/arp-sentinel/telegram/bot.sh &"
EOF

# Create test script
cat > /opt/arp-sentinel/telegram/test.sh << 'EOF'
#!/bin/sh
# Test Telegram bot

CONFIG_FILE="/etc/config/arp-sentinel"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ARP Sentinel not configured"
    exit 1
fi

BOT_TOKEN=$(uci get arp-sentinel.@telegram[0].bot_token 2>/dev/null || echo "")
CHAT_ID=$(uci get arp-sentinel.@telegram[0].chat_id 2>/dev/null || echo "")

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Telegram bot not configured"
    echo "Run: /opt/arp-sentinel/telegram/configure.sh"
    exit 1
fi

echo "Testing Telegram bot..."
echo "Bot Token: ${BOT_TOKEN:0:10}..."
echo "Chat ID: $CHAT_ID"
echo ""

# Send test message
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="✅ ARP Sentinel Test Message
Time: $(date)
System: $(uname -a)
Status: Bot is working!" \
    -d parse_mode="HTML"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Test message sent successfully!"
else
    echo ""
    echo "❌ Failed to send test message"
    echo "Check your bot token and chat ID"
fi
EOF

# Make scripts executable
chmod +x /opt/arp-sentinel/telegram/*.sh

echo ""
echo "Telegram bot scripts installed!"
echo "Configure with: /opt/arp-sentinel/telegram/configure.sh"
echo "Test with: /opt/arp-sentinel/telegram/test.sh"
