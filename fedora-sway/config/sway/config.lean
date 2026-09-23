# Configure keyboard to use the custom layout for the MSI Mod4 key
input "type:keyboard" {
    xkb_layout "custom"
    xkb_variant "msi_mod"
}

# Then ensure your $mod variable is set to Mod4
set $mod Mod4

include /usr/share/sway/config.d/60-bindings-volume.conf
include /usr/share/sway/config.d/60-bindings-brightness.conf

set $term foot
set $rofi_cmd rofi \
        -terminal '$term'
set $menu $rofi_cmd -show combi -combi-modes "window,drun,run,ssh,combi"

    # Kill focused window
    bindsym $mod+q kill

    # Start your launcher
    bindsym $mod+d exec $menu
    bindsym $mod+x exec rofi -show custom -modi "custom:~/.config/sway/rofi-cmd.sh"

    bindsym $mod+t exec $term
    # Binding for floating foot launch
    for_window [app_id="foot-float"] floating enable
    
    # Enable Ctrl+Shift+t to launch a floating foot
    bindsym $mod+Shift+t exec $term --app-id='foot-float'

    bindsym $mod+alt+e exec microsoft-edge

    
    # Reload the configuration file
    bindsym $mod+Shift+c reload

    # Exit sway (logs you out of your Wayland session)
    bindsym $mod+Shift+e exec systemctl --user stop sway-session.service && swaymsg exit

# Others
floating_modifier $mod normal

# Resize windows by holding $mod and scrolling (two-finger scroll on trackpad or scroll wheel) anywhere inside the window
# - Vertical scroll (button4/button5) adjusts height
# - Horizontal scroll (button6/button7) adjusts width
bindsym --whole-window $mod+button4 resize grow height 1px
bindsym --whole-window $mod+button5 resize shrink height 1px
bindsym --whole-window $mod+button6 resize shrink width 1px
bindsym --whole-window $mod+button7 resize grow width 1px

    # Move your focus around
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right
    # Move the focused window with the same, but add Shift
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right

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

    # Toggle the current focus between tiling and floating mode
    bindsym $mod+Shift+space floating toggle

    # Swap focus between the tiling area and the floating area
    bindsym $mod+space focus mode_toggle

    # Clipboard history
    exec wl-paste --watch cliphist store
    exec wl-paste --type image --watch cliphist store
    bindsym $mod+v exec cliphist list | rofi -dmenu | cliphist decode | wl-copy

mode "resize" {
    bindsym Left resize shrink width 10px
    bindsym Down resize grow height 10px
    bindsym Up resize shrink height 10px
    bindsym Right resize grow width 10px

    # Return to default mode
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Touchpad settings
input "type:touchpad" {
    tap enabled
    dwt enabled
    natural_scroll enabled
    #accel_profile "adaptive"
    #pointer_accel 0.2
    drag_lock disabled
    
    accel_profile custom
    
    # Defines the gap in input speed (X-axis) between each point
    accel_step 0.5
    
    # Defines the output multiplier (Y-axis) at each speed step
    accel_points 0.0 0.5 1.5 4.0 8.0
}

output * scale 1
output * bg #000000 solid_color
gaps inner 0

# Completely edge-to-edge windows (0px border). No pixels are wasted between windows.
# Resize tiling/floating windows by holding $mod (Super) and Right-Click dragging anywhere inside the window.
default_border none
default_floating_border none

# Fix for anonymous Chromium/Edge tooltips in native Wayland
for_window [app_id="^$" title="^$"] floating enable, no_focus, border none
#for_window [app_id="microsoft-edge"] fullscreen enable

xwayland disable

# Define the laptop display
#set $laptop eDP-1

# Disable the laptop screen when the lid is closed, enable when open
#bindswitch --reload --locked lid:on output $laptop disable
#bindswitch --reload --locked lid:off output $laptop enable

# swayidle
exec swayidle -w \
    timeout 30 'if grep -q "0" /sys/class/power_supply/*/online 2>/dev/null; then swaymsg "output * power off"; fi' \
    resume 'swaymsg "output * power on"' \
    timeout 300 'if grep -q "0" /sys/class/power_supply/*/online 2>/dev/null; then systemctl suspend; else swaymsg "output * power off"; fi' \
    timeout 18000 'if grep -q "1" /sys/class/power_supply/*/online 2>/dev/null; then systemctl suspend; fi' \

# Minimal Keyring and Polkit initialization
exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway SWAY_ON_BATTERY
#exec /usr/libexec/lxqt-policykit-agent
exec gnome-keyring-daemon --start --components=secrets

# Check battery
bindsym $mod+b exec batt

exec ~/.local/bin/microsoft-edge

# Start systemd graphical session target via sway-session.service
exec systemctl --user start sway-session.service

# Set initial mode on startup based on time
exec ~/scripts/fedora-sway/mode-check.sh
