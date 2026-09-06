# Sway & MacBook Touchpad Replication Guide

This guide is designed for an automated agent or user to seamlessly replicate this exact minimal Sway window manager and advanced multitouch trackpad configuration on another Linux machine.

---

## Part 1: Sway Configuration

Save the following content to `~/.config/sway/config`. This configuration provides:
* **Maximized Screen Real Estate:** 1px borders and completely hidden window title bars.
* **Ultra-Slim Status Bar:** A microscopic 10px status bar with an optimized battery-saving 30-second clock update.
* **Native Touchpad Swipes:** 4-finger swipe left/right to change workspaces.
* **MacBook Pro 2012 Function Controls:** Fully mapped volume (with WirePlumber), mic mute, screen brightness, and keyboard backlight brightness.
* **Custom Bindings:** `Mod+t` launches `foot` terminal, and `Ctrl+Shift+e` triggers a direct session exit.

```sway
# Very minimal sway config for MacBook hardware
# Created by Gemini CLI

### Variables
#
# Logo key. On MacBook, Mod4 is the Command (Super) key.
set $mod Mod4

# Home row direction keys, like vim
set $left h
set $down j
set $up k
set $right l

# Your preferred terminal emulator
set $term foot

### Window styling & borders
# Reduce borders to 1 pixel and remove title bars to reclaim max screen space
default_border pixel 1
default_floating_border pixel 1

### Input configuration
#
# Configure MacBook Touchpad with tap-to-click and natural scrolling enabled.
input type:touchpad {
    dwt enabled
    tap enabled
    tap_button_map lrm
    natural_scroll enabled
    middle_emulation enabled
}

# Configure MacBook Keyboard to swap Control and Command (Super)
input type:keyboard {
    xkb_options ctrl:swap_lwin_lctl,ctrl:swap_rwin_rctl
}

# Touchpad gestures
# 4-finger swipe left/right to move workspace
bindgesture swipe:4:right workspace prev
bindgesture swipe:4:left workspace next

### Key bindings
#
# Basics:
#
    # Start terminal (foot) bound to mod+t
    bindsym $mod+t exec foot

    # Kill focused window
    bindsym $mod+Shift+q kill

    # Reload the configuration file
    bindsym $mod+Shift+c reload

    # Exit sway
    bindsym Ctrl+Shift+e exit

#
# Moving around:
#
    # Move your focus around
    bindsym $mod+$left focus left
    bindsym $mod+$down focus down
    bindsym $mod+$up focus up
    bindsym $mod+$right focus right
    # Or use $mod+[up|down|left|right]
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right

    # Move the focused window with the same, but add Shift
    bindsym $mod+Shift+$left move left
    bindsym $mod+Shift+$down move down
    bindsym $mod+Shift+$up move up
    bindsym $mod+Shift+$right move right
    # Ditto, with arrow keys
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right

#
# Workspaces:
#
    # Switch to workspace
    bindsym $mod+1 workspace number 1
    bindsym $mod+2 workspace number 2
    bindsym $mod+3 workspace number 3
    bindsym $mod+4 workspace number 4
    bindsym $mod+5 workspace number 5
    bindsym $mod+6 workspace number 6
    bindsym $mod+7 workspace number 7
    bindsym $mod+8 workspace number 8
    bindsym $mod+9 workspace number 9
    bindsym $mod+0 workspace number 10
    # Move focused container to workspace
    bindsym $mod+Shift+1 move container to workspace number 1
    bindsym $mod+Shift+2 move container to workspace number 2
    bindsym $mod+Shift+3 move container to workspace number 3
    bindsym $mod+Shift+4 move container to workspace number 4
    bindsym $mod+Shift+5 move container to workspace number 5
    bindsym $mod+Shift+6 move container to workspace number 6
    bindsym $mod+Shift+7 move container to workspace number 7
    bindsym $mod+Shift+8 move container to workspace number 8
    bindsym $mod+Shift+9 move container to workspace number 9
    bindsym $mod+Shift+0 move container to workspace number 10

#
# Layout stuff:
#
    # Split current container horizontally or vertically
    bindsym $mod+b splith
    bindsym $mod+v splitv

    # Switch the current container between different layout styles
    bindsym $mod+s layout stacking
    bindsym $mod+w layout tabbed
    bindsym $mod+e layout toggle split

    # Make the current focus fullscreen
    bindsym $mod+f fullscreen

    # Toggle the current focus between tiling and floating mode
    bindsym $mod+Shift+space floating toggle

    # Swap focus between the tiling area and the floating area
    bindsym $mod+space focus mode_toggle

    # Move focus to the parent container
    bindsym $mod+a focus parent

#
# Scratchpad:
#
    # Move the currently focused window to the scratchpad
    bindsym $mod+Shift+minus move scratchpad

    # Show the next scratchpad window or hide focused scratchpad window
    bindsym $mod+minus scratchpad show

#
# Resizing containers:
#
mode "resize" {
    bindsym $left resize shrink width 10px
    bindsym $down resize grow height 10px
    bindsym $up resize shrink height 10px
    bindsym $right resize grow width 10px

    # Ditto, with arrow keys
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px

    # Return to default mode
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

#
# Status Bar:
#
bar {
    position top
    # Use a microscopic font to allow the bar to shrink to exactly 10 pixels without clipping
    font pango:monospace 5.5
    # Tiny bar height (exactly 10px)
    height 10
    # Battery-friendly date and time (no seconds ticking, sleeps for 30s instead of 1s)
    status_command while date +'%Y-%m-%d %H:%M'; do sleep 30; done

    colors {
        statusline #ffffff
        background #323232
        inactive_workspace #32323200 #32323200 #5c5c5c
    }
}

#
# Media, Brightness, and Volume Controls (MacBook Pro 2012):
#
# Screen Brightness
bindsym --locked XF86MonBrightnessUp exec brightnessctl set 5%+
bindsym --locked XF86MonBrightnessDown exec brightnessctl set 5%-

# Keyboard Backlight
bindsym --locked XF86KbdBrightnessUp exec brightnessctl --device="smc::kbd_backlight" set 5%+
bindsym --locked XF86KbdBrightnessDown exec brightnessctl --device="smc::kbd_backlight" set 5%-

# Volume and Mic Mute Controls (PipeWire via wireplumber wpctl)
bindsym --locked XF86AudioRaiseVolume exec wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
bindsym --locked XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym --locked XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym --locked XF86AudioMicMute exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
```

---

## Part 2: macOS-Style Three-Finger Click & Drag

This sets up `linux-3-finger-drag` as an extremely lightweight (~600KB RAM) low-level `uinput` proxy. It handles:
1. **Sustained 3-Finger Drag:** Emulates mouse left-click hold & drag.
2. **Quick 3-Finger Tap:** Passes through verbatim, allowing native **middle-click** to work seamlessly.
3. **Sensitive Trackpads:** Configured with an optimized **200ms** debounce to prevent tap/drag misclassifications.

### 1. Install Rust Toolchain (Compiler & Cargo)
For Arch Linux:
```bash
sudo pacman -Syu --noconfirm rust
```
For Debian/Ubuntu:
```bash
sudo apt update && sudo apt install -y cargo rustc
```

### 2. Shallow Clone the Repository
```bash
git clone --depth 1 https://github.com/lmr97/linux-3-finger-drag.git /tmp/linux-3-finger-drag
```

### 3. Compile the Binary
```bash
cd /tmp/linux-3-finger-drag
cargo build --release
```

### 4. Install the Binary and Permissions
Run the following commands to install the binary to `/usr/bin/`, set up udev rules for the `/dev/uinput` device, assign your user to the `input` group, and load the `uinput` kernel module:

```bash
# Copy binary
sudo cp /tmp/linux-3-finger-drag/target/release/linux-3-finger-drag /usr/bin/

# Set up udev rules for uinput access
sudo cp /tmp/linux-3-finger-drag/60-uinput.rules /etc/udev/rules.d/

# Add current user to the input group (replace 'josh' with target username)
sudo gpasswd --add josh input

# Force uinput module to load on boot
echo uinput | sudo tee /etc/modules-load.d/uinput.conf
sudo modprobe uinput
```

### 5. Install the Config File with Sensitive Hardware Tuning
Create the configuration folder and save the configuration with `entryDebounce` set to **`200`** (this accommodates sensitive trackpad hardware timing variations to ensure middle-click taps trigger effortlessly):

```bash
mkdir -p ~/.config/linux-3-finger-drag
```

Save the following as `~/.config/linux-3-finger-drag/3fd-config.json`:
```json
{
    "acceleration": 1.0,
    "dragEndDelay": 0,
    "logFile": "stdout",
    "logLevel": "info",
    "entryDebounce": 200,
    "probeDelay": 15,
    "pressGrace": 75
}
```

### 6. Set Up the System-Level Systemd Service
To ensure the proxy initiates immediately upon system boot without requiring a manual user session shell, create a system-level Systemd unit file. 

*(Note: We run the service as system-level with explicit user permissions to dynamically leverage the `input` group permissions without requiring a system reboot/logout first).*

Save the following file as `/etc/systemd/system/three-finger-drag.service` (replace `josh` in the `User` and `HOME` blocks with your target username):

```ini
[Unit]
Description=Three-finger drag gestures for Linux
After=udev.service

[Service]
Type=exec
ExecStart=/usr/bin/linux-3-finger-drag
User=josh
Group=input
Environment="HOME=/home/josh"
Restart=on-failure
RestartSec=1

[Install]
WantedBy=multi-user.target
```

### 7. Enable and Start the Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now three-finger-drag.service
```

### 8. Verify the Setup
Run the following to check if the proxy successfully attached to your system's touchpad:
```bash
sudo systemctl status three-finger-drag.service
```

Look for a log confirmation resembling:
`INFO linux_3_finger_drag::init::discovery: Touchpad found: "bcm5974" at /dev/input/eventX`
`INFO linux_3_finger_drag: linux-3-finger-drag started successfully!`
