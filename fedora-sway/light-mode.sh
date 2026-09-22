#!/bin/bash
# Ensure we can find the sway socket even when run from systemd
if [ -z "$SWAYSOCK" ]; then
    export SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n 1)
fi

gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
gsettings set org.gnome.desktop.interface color-scheme 'default'
#swaymsg output "*" bg /usr/share/backgrounds/default.jxl fill

if [ "$SWAY_ON_BATTERY" = "1" ]; then
    swaymsg "output * bg #000000 solid_color" 2>/dev/null
else
    /home/pa3k/.config/sway/scripts/bing-wallpaper.sh
fi

# Signal foot to switch to light mode
pkill -USR2 -x foot
