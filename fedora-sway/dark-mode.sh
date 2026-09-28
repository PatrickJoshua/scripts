#!/bin/bash
# Ensure we can find the sway socket even when run from systemd
if [ -z "$SWAYSOCK" ]; then
    export SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n 1)
fi

gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
#swaymsg output "*" bg /usr/share/backgrounds/default-dark.jxl fill

if [ "$SWAY_ON_BATTERY" = "1" ] || grep -q "0" /sys/class/power_supply/*/online 2>/dev/null; then
    swaymsg "output * bg #000000 solid_color" 2>/dev/null
else
    systemctl --user start bing-wallpaper.service 2>/dev/null || /home/pa3k/.config/sway/scripts/bing-wallpaper.sh -n
fi

# Signal foot to switch to dark mode
pkill -USR1 -x foot
