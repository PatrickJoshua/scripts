# Then ensure your $mod variable is set to Mod4
set $mod Mod4

set $term foot
set $rofi_cmd rofi \
        -terminal '$term'
set $menu $rofi_cmd -show combi -combi-modes "window,drun,run,ssh,combi"

    # Kill focused window
    bindsym $mod+q kill

    # Start your launcher
    bindsym $mod+d exec $menu
    bindsym $mod+x exec rofi -show custom -modi "custom:~/.config/sway/rofi-cmd.sh"
    
    # Reload the configuration file
    bindsym $mod+Shift+c reload

    # Exit sway (logs you out of your Wayland session)
    bindsym $mod+Shift+e exec swaymsg exit

# Others
floating_modifier $mod normal

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
    accel_profile "adaptive"
    pointer_accel 0.5
    drag_lock disabled
}

output * scale 1
output * bg #000000 solid_color
gaps inner 0
default_border none
default_floating_border none

# Fix for anonymous Chromium/Edge tooltips in native Wayland
for_window [app_id="^$" title="^$"] floating enable, no_focus, border none
#for_window [app_id="microsoft-edge"] fullscreen enable

xwayland disable

# Minimal Keyring and Polkit initialization
exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
exec /usr/libexec/lxqt-policykit-agent
exec gnome-keyring-daemon --start --components=secrets

exec ~/.local/bin/microsoft-edge
