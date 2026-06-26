#!/bin/bash
# Ensure we can find the sway socket even when run from systemd
if [ -z "$SWAYSOCK" ]; then
    export SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n 1)
fi

gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
#swaymsg output "*" bg /usr/share/backgrounds/default-dark.jxl fill
/home/pa3k/.config/sway/scripts/bing-wallpaper.sh
