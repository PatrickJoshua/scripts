#!/bin/bash

# Directory to save the wallpapers
WP_DIR="$HOME/Pictures/BingWallpapers"
mkdir -p "$WP_DIR"

# Fetch the JSON payload from Bing's API
BING_API="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US"
JSON_RESP=$(curl -s "$BING_API")

# Extract the base URL using jq and append _UHD.jpg for the 4K version
REL_URL=$(echo "$JSON_RESP" | jq -r '.images[0].urlbase')
IMAGE_URL="https://www.bing.com${REL_URL}_UHD.jpg"

# Define the local file path based on today's date
TODAY=$(date +'%Y-%m-%d')
SAVE_PATH="$WP_DIR/bing-$TODAY.jpg"

# Download the image if we haven't already today
if [ ! -f "$SAVE_PATH" ]; then
    curl -s -L -o "$SAVE_PATH" "$IMAGE_URL"
    # Create a symlink pointing to today's wallpaper
    ln -sf "$SAVE_PATH" "$WP_DIR/bing-latest.jpg"
    swaymsg "output * bg $SAVE_PATH fill"
fi

# Apply the wallpaper using swaymsg to all outputs
# Note: If running via cron/systemd, SWAYSOCK must be set in the environment
#export SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock | head -n 1)
