# 🖱️ MX Master 3S Gesture Support for Linux

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.6+](https://img.shields.io/badge/python-3.6+-blue.svg)](https://www.python.org/downloads/)
[![Linux](https://img.shields.io/badge/platform-linux-lightgrey.svg)](https://www.kernel.org/)

Add macOS-like gesture support to your Logitech MX Master 3S on Linux! 🎨

</div>

---

## ✨ Features

Control your system using the **side button** + mouse movements:

| Gesture | Action | Description |
|---------|--------|-------------|
| 👆 **Swipe Up** | `Super + W` | Show all windows/activities |
| 👇 **Swipe Down** | `Escape` | Close overview/escape |
| 👈 **Swipe Left** | Previous track | `playerctl previous` |
| 👉 **Swipe Right** | Next track | `playerctl next` |
| 👊 **Tap** (no movement) | Play/Pause | `playerctl play-pause` |

## 🎯 How It Works

1. **Press and hold** the side button (BTN_FORWARD)
2. **Move the mouse** in any direction
3. **Release** the button to execute the gesture

The script detects the movement direction and executes the corresponding command!

---

## 📦 Installation

### Prerequisites

- Linux system (tested on Fedora/Bazzite)
- Logitech MX Master 3S
- Python 3.6+

### Quick Install (Automated)

```bash
curl -fsSL https://raw.githubusercontent.com/thegalkin/mx-master-gestures/main/install.sh | bash
```

### Manual Installation

#### 1. Install Dependencies

**Fedora/RHEL/Bazzite:**
```bash
sudo rpm-ostree install playerctl
# Reboot if using immutable system
systemctl reboot
```

**Debian/Ubuntu:**
```bash
sudo apt install python3-evdev playerctl xdotool
```

**Arch:**
```bash
sudo pacman -S python-evdev playerctl xdotool
```

#### 2. Install Python Package

```bash
pip install --user evdev
```

#### 3. Configure Permissions

```bash
# Create input group and add yourself
sudo groupadd -f input
sudo usermod -a -G input $USER

# Create udev rule
sudo tee /etc/udev/rules.d/99-mx-gestures.rules > /dev/null <<EOF
KERNEL=="event*", SUBSYSTEM=="input", MODE="0660", GROUP="input"
EOF

# Reload udev
sudo udevadm control --reload-rules
sudo udevadm trigger
```

**⚠️ You must reboot after this step!**

```bash
systemctl reboot
```

#### 4. Install the Script

```bash
# Create directory
mkdir -p ~/.local/bin

# Download the script
curl -o ~/.local/bin/mx-gestures.py https://raw.githubusercontent.com/thegalkin/mx-master-gestures/main/mx-gestures.py
chmod +x ~/.local/bin/mx-gestures.py
```

#### 5. Find Your Mouse Device

```bash
ls -la /dev/input/by-id/ | grep -i logitech
```

Look for something like `usb-Logitech_USB_Receiver-if01-event-mouse -> ../event10`

Then test which event device works:

```bash
sudo libinput debug-events --device /dev/input/event10
```

Press the side button - you should see `BTN_FORWARD (277)` events.

**Edit the script** and update line 7:
```python
device = InputDevice('/dev/input/event10')  # Change event10 to your device
```

#### 6. Setup Systemd Service (Auto-start)

```bash
# Create service file
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

# Enable and start the service
systemctl --user daemon-reload
systemctl --user enable mx-gestures.service
systemctl --user start mx-gestures.service
```

#### 7. Check Status

```bash
# Check if service is running
systemctl --user status mx-gestures.service

# View logs
journalctl --user -u mx-gestures.service -f
```

---

## 🎨 Customization

Edit `~/.local/bin/mx-gestures.py` and modify the `execute_gesture()` function:

```python
def execute_gesture(direction):
    commands = {
        'up': ['xdotool', 'key', 'super+w'],      # Change this
        'down': ['xdotool', 'key', 'Escape'],      # Change this
        'left': ['playerctl', 'previous'],         # Change this
        'right': ['playerctl', 'next'],            # Change this
        'tap': ['playerctl', 'play-pause']         # Change this
    }
```

After changes, restart the service:
```bash
systemctl --user restart mx-gestures.service
```

---

## 🔧 Troubleshooting

### Permission Denied Error

```bash
# Check if you're in the input group
groups

# If 'input' is missing, add yourself:
sudo usermod -a -G input $USER
systemctl reboot
```

### Gestures Not Working

1. Check if service is running:
   ```bash
   systemctl --user status mx-gestures.service
   ```

2. Test device manually:
   ```bash
   python3 ~/.local/bin/mx-gestures.py
   ```

3. Check logs:
   ```bash
   journalctl --user -u mx-gestures.service -n 50
   ```

### Wrong Event Device

If gestures don't respond, find the correct device:

```bash
sudo libinput debug-events --device /dev/input/event10
# Press side button and move mouse
# Look for BTN_FORWARD (277) events
```

Update the device path in the script.

---

## 🚀 Performance

- **CPU Usage:** ~0.1% in idle
- **Memory:** ~17 MB
- **Battery Impact:** Negligible

The script uses efficient event-driven architecture with `select()` - it only wakes up when the mouse sends events!

---

## 🤝 Contributing

Contributions are welcome! Feel free to:

- Report bugs
- Suggest new features
- Submit pull requests

---

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [evdev](https://python-evdev.readthedocs.io/) - Python bindings for the Linux input subsystem
- [playerctl](https://github.com/altdesktop/playerctl) - MPRIS media player controller

---

<div align="center">

**Made with ❤️ for Linux users who love their MX Master 3S**

[Report Bug](https://github.com/thegalkin/mx-master-gestures/issues) · [Request Feature](https://github.com/thegalkin/mx-master-gestures/issues)

</div>