#!/bin/bash

# 🔧 Install dependencies
echo "🔧 Installing neofetch..."
if command -v apt &>/dev/null; then
    sudo apt update && sudo apt install -y neofetch
elif command -v yum &>/dev/null; then
    sudo yum install -y epel-release && sudo yum install -y neofetch
else
    echo "❌ Unsupported OS. Install neofetch manually."
    exit 1
fi

# 📁 Write dashboard script
DASHBOARD_SCRIPT="/etc/profile.d/welcome-dashboard.sh"
echo "⚙️  Writing dashboard to $DASHBOARD_SCRIPT"

sudo tee $DASHBOARD_SCRIPT > /dev/null << 'EOF'
#!/bin/bash

# 🎨 Colors
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RED="\e[31m"
NC="\e[0m"

clear

# 📦 Show system ASCII + info
if command -v neofetch &>/dev/null; then
    distro=$(lsb_release -is 2>/dev/null || cat /etc/*release | grep "^ID=" | cut -d= -f2)
    neofetch --ascii_distro "$distro" --color_blocks off
else
    echo -e "${YELLOW}⚠️  Neofetch not found${NC}"
fi

# 🔧 Load
echo -e "${BLUE}🌡  Load Average:$(cut -d " " -f1-3 /proc/loadavg)${NC}"

# 💾 Memory
echo -e "${YELLOW}💾  Memory Usage:${NC}"
free -h

# 🗄 Disk
echo -e "${YELLOW}🗄  Disk Usage (total):${NC}"
df -h --total | grep total

# 🌐 Network RX/TX
interface=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
[[ -z "$interface" ]] && interface=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' | head -n1 | tr -d ' ')

rx_bytes=$(cat /sys/class/net/${interface}/statistics/rx_bytes 2>/dev/null)
tx_bytes=$(cat /sys/class/net/${interface}/statistics/tx_bytes 2>/dev/null)

# Store to temp for delta calc
TMP_DIR="/tmp/.ssh-dash"
mkdir -p $TMP_DIR
RX_PREV_FILE="$TMP_DIR/rx_prev"
TX_PREV_FILE="$TMP_DIR/tx_prev"

# Read previous
rx_prev=0 && [[ -f "$RX_PREV_FILE" ]] && rx_prev=$(cat "$RX_PREV_FILE")
tx_prev=0 && [[ -f "$TX_PREV_FILE" ]] && tx_prev=$(cat "$TX_PREV_FILE")

# Save current
echo $rx_bytes > "$RX_PREV_FILE"
echo $tx_bytes > "$TX_PREV_FILE"

# Compute delta (assuming login happened ~1 sec apart, just to show "live-ish" rate)
rx_diff=$(( (rx_bytes - rx_prev) / 1024 / 1024 ))
tx_diff=$(( (tx_bytes - tx_prev) / 1024 / 1024 ))

echo -e "${YELLOW}📡  Network Usage:${NC}"
echo -e "Interface: ${interface}"
echo -e "Total RX: $((rx_bytes / 1024 / 1024)) MB"
echo -e "Total TX: $((tx_bytes / 1024 / 1024)) MB"
echo -e "Est. Login Speed: ↓ ${rx_diff} MB/s | ↑ ${tx_diff} MB/s"

# 👤 Users
echo -e "${BLUE}👤  Logged In Users:$(who | wc -l)   $(who | awk '{print $1, $5}' | sort | uniq)${NC}"
echo ""
EOF

# ✅ Permission
sudo chmod +x $DASHBOARD_SCRIPT

echo -e "\n🎉 SSH Dashboard Pro 已部署完成！每次登录 SSH 都会看到系统状态啦 😎"
