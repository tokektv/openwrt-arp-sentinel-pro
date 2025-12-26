# 🛡️ OpenWrt ARP Sentinel Pro

Advanced ARP Monitoring and Protection System for OpenWrt Routers

[![OpenWrt Version](https://img.shields.io/badge/OpenWrt-23.05+-green.svg)](https://openwrt.org)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/yourusername/openwrt-arp-sentinel-pro.svg)](https://github.com/yourusername/openwrt-arp-sentinel-pro/stargazers)

## ✨ Features

- 🔍 **Real-time ARP Monitoring** - Detect ARP spoofing, poisoning, and anomalies
- 📊 **Web Dashboard** - LuCI integrated interface
- 🔔 **Multi-channel Alerts** - Telegram, Email, Syslog notifications
- 🛡️ **Active Protection** - Firewall integration with IPSet
- 📈 **Statistics & Logging** - Historical data and reports
- 🤖 **Auto-baseline Management** - Learns network patterns
- 🚀 **High Performance** - Optimized for Filogic routers (256MB+ RAM)

## 📋 Requirements

- OpenWrt 21.02 or higher
- Minimum 128MB RAM, 32MB free storage
- Recommended: 256MB RAM, 128MB ROM (for full features)

## 🚀 Quick Installation

### One-line Install:
```bash
wget -O- https://raw.githubusercontent.com/yourusername/openwrt-arp-sentinel-pro/main/scripts/install.sh | sh
