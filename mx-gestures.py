#!/usr/bin/env python3
"""
MX Master 3S Gesture Handler for Linux
Controls system using side button + mouse movements

Author: Nik Galkin
License: MIT
Repository: https://github.com/thegalkin/mx-master-gestures
"""

import evdev
import subprocess
import sys
from evdev import InputDevice, ecodes
from select import select

# Configuration
DEVICE_PATH = '/dev/input/event10'  # Change this to your mouse event device
THRESHOLD = 100  # Minimum movement distance to trigger gesture (in pixels)

# Initialize device
try:
    device = InputDevice(DEVICE_PATH)
    print(f"Listening to: {device.name}")
    print(f"Device path: {DEVICE_PATH}")
    print("Ready! Press side button and move mouse to trigger gestures.")
except FileNotFoundError:
    print(f"Error: Device {DEVICE_PATH} not found!")
    print("\nTo find your device, run:")
    print("  ls -la /dev/input/by-id/ | grep -i logitech")
    print("  sudo libinput debug-events --device /dev/input/eventXX")
    sys.exit(1)
except PermissionError:
    print(f"Error: Permission denied for {DEVICE_PATH}")
    print("\nRun these commands to fix:")
    print("  sudo groupadd -f input")
    print("  sudo usermod -a -G input $USER")
    print("  systemctl reboot")
    sys.exit(1)

# State tracking
button_pressed = False
start_x, start_y = 0, 0
current_x, current_y = 0, 0

def execute_gesture(direction):
    """
    Execute command based on gesture direction
    
    Available directions:
    - 'up': Swipe up while holding button
    - 'down': Swipe down while holding button
    - 'left': Swipe left while holding button
    - 'right': Swipe right while holding button
    - 'tap': Press and release without movement
    """
    commands = {
        'up': ['xdotool', 'key', 'super+w'],       # Show all windows
        'down': ['xdotool', 'key', 'Escape'],      # Escape/close
        'left': ['playerctl', 'previous'],         # Previous track
        'right': ['playerctl', 'next'],            # Next track
        'tap': ['playerctl', 'play-pause']         # Play/pause
    }
    
    if direction in commands:
        print(f"Gesture detected: {direction}")
        try:
            subprocess.Popen(
                commands[direction],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except FileNotFoundError:
            print(f"Warning: Command not found for '{direction}' gesture")
            print(f"Make sure required tools are installed: {' '.join(commands[direction])}")

# Main event loop
print("\nGesture mappings:")
print("  ↑ Swipe Up    -> Super+W (Show windows)")
print("  ↓ Swipe Down  -> Escape")
print("  ← Swipe Left  -> Previous track")
print("  → Swipe Right -> Next track")
print("  • Tap         -> Play/Pause")
print("\nPress Ctrl+C to exit\n")

try:
    while True:
        # Efficient event waiting using select()
        r, w, x = select([device.fd], [], [])
        
        for event in device.read():
            # Button press/release events
            if event.type == ecodes.EV_KEY and event.code == 277:  # BTN_FORWARD
                if event.value == 1:  # Button pressed
                    button_pressed = True
                    start_x, start_y = current_x, current_y
                    
                elif event.value == 0 and button_pressed:  # Button released
                    # Calculate movement delta
                    dx = current_x - start_x
                    dy = current_y - start_y
                    
                    # Determine gesture direction
                    if abs(dx) < THRESHOLD and abs(dy) < THRESHOLD:
                        # No significant movement - it's a tap
                        execute_gesture('tap')
                    elif abs(dx) > abs(dy):
                        # Horizontal movement dominates
                        execute_gesture('right' if dx > 0 else 'left')
                    else:
                        # Vertical movement dominates
                        execute_gesture('down' if dy > 0 else 'up')
                    
                    # Reset state
                    button_pressed = False
                    current_x, current_y = 0, 0
            
            # Mouse movement events (only tracked when button is pressed)
            elif event.type == ecodes.EV_REL and button_pressed:
                if event.code == ecodes.REL_X:
                    current_x += event.value
                elif event.code == ecodes.REL_Y:
                    current_y += event.value

except KeyboardInterrupt:
    print("\n\nShutting down gesture handler...")
    sys.exit(0)
except Exception as e:
    print(f"\nError: {e}")
    sys.exit(1)
