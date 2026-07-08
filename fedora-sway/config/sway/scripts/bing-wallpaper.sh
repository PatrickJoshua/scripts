#!/bin/bash

# Directory to save the wallpapers
WP_DIR="$HOME/Pictures/BingWallpapers"
mkdir -p "$WP_DIR"

# Ensure SWAYSOCK is set (especially when run from systemd)
if [ -z "$SWAYSOCK" ]; then
    export SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n 1)
fi

# Fetch the JSON payload from Bing's API
BING_API="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US"

# Define today's path
TODAY=$(date +'%Y-%m-%d')
SAVE_PATH="$WP_DIR/bing-$TODAY.jpg"

# Download the image if we haven't already today
if [ ! -f "$SAVE_PATH" ]; then
    # Retry loop to wait for internet connection/API availability (up to 15 retries, ~45s)
    MAX_RETRIES=15
    RETRY_COUNT=0
    JSON_RESP=""
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        JSON_RESP=$(curl -s --connect-timeout 5 "$BING_API")
        # Validate that we got a JSON response containing the expected fields
        if [ -n "$JSON_RESP" ] && echo "$JSON_RESP" | jq -e '.images[0].urlbase' >/dev/null 2>&1; then
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep 3
    done
    
    # If we failed to get a valid response after retries, exit gracefully without breaking anything
    if [ $RETRY_COUNT -eq $MAX_RETRIES ] || [ -z "$JSON_RESP" ]; then
        echo "Failed to fetch Bing API payload (network offline or API down)." >&2
        exit 0
    fi

    # Extract the base URL using jq and append _UHD.jpg for the 4K version
    REL_URL=$(echo "$JSON_RESP" | jq -r '.images[0].urlbase')
    IMAGE_URL="https://www.bing.com${REL_URL}_UHD.jpg"
    
    # Download to a temporary file first to prevent corruption/partial files
    TEMP_SAVE_PATH="$SAVE_PATH.tmp"
    
    # Try downloading the image (retry up to 3 times)
    DOWNLOAD_SUCCESS=false
    for i in {1..3}; do
        if curl -s -L --connect-timeout 10 -o "$TEMP_SAVE_PATH" "$IMAGE_URL"; then
            # Verify the downloaded file is a valid non-empty file (e.g., > 100KB)
            if [ -f "$TEMP_SAVE_PATH" ] && [ $(stat -c%s "$TEMP_SAVE_PATH") -gt 100000 ]; then
                DOWNLOAD_SUCCESS=true
                break
            fi
        fi
        sleep 2
    done
    
    if [ "$DOWNLOAD_SUCCESS" = true ]; then
        # Move temp file to final destination
        mv "$TEMP_SAVE_PATH" "$SAVE_PATH"
        # Update the symlink pointing to today's wallpaper
        ln -sf "$SAVE_PATH" "$WP_DIR/bing-latest.jpg"
    else
        echo "Failed to download a valid image from Bing." >&2
        rm -f "$TEMP_SAVE_PATH"
        exit 1
    fi
fi

# Always apply the wallpaper to all outputs if the file exists
if [ -f "$SAVE_PATH" ]; then
    if [ -n "$SWAYSOCK" ]; then
        swaymsg "output * bg $SAVE_PATH fill"
    fi
fi
