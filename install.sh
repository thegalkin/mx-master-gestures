#!/bin/bash

# MX Master 3S Gesture Support - Automated Installer
# https://github.com/thegalkin/mx-master-gestures

set -e  # Exit on error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "================================================"
echo "  MX Master 3S Gesture Support Installer"
echo "  https://github.com/thegalkin/mx-master-gestures"
echo "================================================"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Error: Don't run this script as root!${NC}"
   echo "Run it as your regular user. It will ask for sudo when needed."
   exit 1
fi

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    echo -e "${GREEN}✓${NC} Detected distribution: $PRETTY_NAME"
else
    echo -e "${RED}Error: Cannot detect distribution${NC}"
    exit 1
fi

# Step 1: Install dependencies
echo -e "\n${BLUE}[1/7]${NC} Installing dependencies..."

case $DISTRO in
    fedora|rhel|centos)
        echo "Installing packages via rpm-ostree..."
        if command -v rpm-ostree &> /dev/null; then
            sudo rpm-ostree install playerctl xdotool
            echo -e "${YELLOW}Note: System reboot required after rpm-ostree install${NC}"
            NEEDS_REBOOT=true
        else
            sudo dnf install -y python3-evdev playerctl xdotool
        fi
        ;;
    ubuntu|debian)
        sudo apt update
        sudo apt install -y python3-evdev playerctl xdotool
        ;;
    arch|manjaro)
        sudo pacman -S --noconfirm python-evdev playerctl xdotool
        ;;
    *)
        echo -e "${YELLOW}Warning: Unsupported distribution. Please install manually:${NC}"
        echo "  - python3-evdev or evdev (pip)"
        echo "  - playerctl"
        echo "  - xdotool"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        ;;
esac

# Install Python evdev if not available via system package
if ! python3 -c "import evdev" &> /dev/null; then
    echo "Installing evdev via pip..."
    pip install --user evdev
fi

echo -e "${GREEN}✓${NC} Dependencies installed"

# Step 2: Configure permissions
echo -e "\n${BLUE}[2/7]${NC} Configuring permissions..."

# Create input group
sudo groupadd -f input
echo -e "${GREEN}✓${NC} Input group created"

# Add user to input group
if ! groups | grep -q input; then
    sudo usermod -a -G input $USER
    echo -e "${GREEN}✓${NC} User added to input group"
    NEEDS_RELOGIN=true
else
    echo -e "${GREEN}✓${NC} User already in input group"
fi

# Create udev rule
echo 'KERNEL=="event*", SUBSYSTEM=="input", MODE="0660", GROUP="input"' | sudo tee /etc/udev/rules.d/99-mx-gestures.rules > /dev/null
echo -e "${GREEN}✓${NC} Udev rule created"

# Reload udev
sudo udevadm control --reload-rules
sudo udevadm trigger
echo -e "${GREEN}✓${NC} Udev reloaded"

# Step 3: Download script
echo -e "\n${BLUE}[3/7]${NC} Installing gesture handler script..."

mkdir -p ~/.local/bin
curl -fsSL -o ~/.local/bin/mx-gestures.py https://raw.githubusercontent.com/thegalkin/mx-master-gestures/main/mx-gestures.py
chmod +x ~/.local/bin/mx-gestures.py
echo -e "${GREEN}✓${NC} Script installed to ~/.local/bin/mx-gestures.py"

# Step 4: Find mouse device
echo -e "\n${BLUE}[4/7]${NC} Detecting mouse device..."

MOUSE_DEVICE=""
for event in /dev/input/event*; do
    if [ -r "$event" ]; then
        DEVICE_NAME=$(cat "/sys/class/input/$(basename $event)/device/name" 2>/dev/null || echo "")
        if [[ $DEVICE_NAME =~ "Logitech" ]] && [[ $DEVICE_NAME =~ "Mouse" ]]; then
            MOUSE_DEVICE=$event
            echo -e "${GREEN}✓${NC} Found Logitech mouse: $event ($DEVICE_NAME)"
            break
        fi
    fi
done

if [ -z "$MOUSE_DEVICE" ]; then
    echo -e "${YELLOW}Warning: Could not auto-detect mouse device${NC}"
    echo "Please edit ~/.local/bin/mx-gestures.py and set DEVICE_PATH manually"
    echo "To find your device, run:"
    echo "  sudo libinput debug-events"
else
    # Update device path in script
    sed -i "s|DEVICE_PATH = '/dev/input/event10'|DEVICE_PATH = '$MOUSE_DEVICE'|" ~/.local/bin/mx-gestures.py
    echo -e "${GREEN}✓${NC} Script configured to use $MOUSE_DEVICE"
fi

# Step 5: Create systemd service
echo -e "\n${BLUE}[5/7]${NC} Setting up systemd service..."

mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/mx-gestures.service <<EOF
[Unit]
Description=MX Master 3S Gesture Handler
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 %h/.local/bin/mx-gestures.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

echo -e "${GREEN}✓${NC} Systemd service created"

# Step 6: Enable service (but don't start yet if reboot needed)
echo -e "\n${BLUE}[6/7]${NC} Enabling service..."

systemctl --user daemon-reload
systemctl --user enable mx-gestures.service
echo -e "${GREEN}✓${NC} Service enabled"

if [ -z "$NEEDS_REBOOT" ] && [ -z "$NEEDS_RELOGIN" ]; then
    systemctl --user start mx-gestures.service
    echo -e "${GREEN}✓${NC} Service started"
fi

# Step 7: Final instructions
echo -e "\n${BLUE}[7/7]${NC} Installation complete!"

if [ ! -z "$NEEDS_REBOOT" ]; then
    echo -e "\n${YELLOW}⚠️  REBOOT REQUIRED${NC}"
    echo "Run: systemctl reboot"
elif [ ! -z "$NEEDS_RELOGIN" ]; then
    echo -e "\n${YELLOW}⚠️  RE-LOGIN REQUIRED${NC}"
    echo "Log out and log back in for permissions to take effect."
    echo "Then start the service: systemctl --user start mx-gestures.service"
else
    echo -e "\n${GREEN}All done! Gestures should now work.${NC}"
fi

echo -e "\n${BLUE}Gesture mappings:${NC}"
echo "  ↑ Swipe Up    -> Super+W (Show windows)"
echo "  ↓ Swipe Down  -> Escape"
echo "  ← Swipe Left  -> Previous track"
echo "  → Swipe Right -> Next track"
echo "  • Tap         -> Play/Pause"

echo -e "\n${BLUE}Useful commands:${NC}"
echo "  Check status:  systemctl --user status mx-gestures.service"
echo "  View logs:     journalctl --user -u mx-gestures.service -f"
echo "  Restart:       systemctl --user restart mx-gestures.service"
echo "  Stop:          systemctl --user stop mx-gestures.service"
echo "  Customize:     nano ~/.local/bin/mx-gestures.py"

echo -e "\n${GREEN}For more info, visit:${NC}"
echo "  https://github.com/thegalkin/mx-master-gestures"
echo ""
