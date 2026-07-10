#!/bin/bash

# Parse options
FORCE_NEW=false
SET_PREVIOUS=false

while getopts "np" opt; do
    case "$opt" in
        n)
            FORCE_NEW=true
            ;;
        p)
            SET_PREVIOUS=true
            ;;
        *)
            echo "Usage: $0 [-n] [-p]" >&2
            exit 1
            ;;
    esac
done

# Ensure mutually exclusive options are not used together
if [ "$FORCE_NEW" = true ] && [ "$SET_PREVIOUS" = true ]; then
    echo "Error: Options -n and -p are mutually exclusive." >&2
    exit 1
fi

# Directory to save the wallpapers
WP_DIR="$HOME/Pictures/BingWallpapers"
mkdir -p "$WP_DIR"

# Ensure SWAYSOCK is set (especially when run from systemd)
if [ -z "$SWAYSOCK" ]; then
    export SWAYSOCK=$(ls /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n 1)
fi

# Fetch the JSON payload from Bing's API
BING_API="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US"

if [ "$SET_PREVIOUS" = true ]; then
    CURRENT_WP=$(readlink -f "$WP_DIR/bing-latest.jpg")
    
    # Get sorted list of wallpaper files (excluding the symlink and temporary files) using version sort
    shopt -s nullglob
    FILES=()
    while IFS= read -r -d '' f; do
        [ -n "$f" ] && FILES+=("$f")
    done < <(printf "%s\0" "$WP_DIR"/bing-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.jpg | sort -zV)
    
    NUM_FILES=${#FILES[@]}
    PREV_WP=""
    
    if [ $NUM_FILES -gt 1 ]; then
        if [ -n "$CURRENT_WP" ] && [ -f "$CURRENT_WP" ]; then
            # Find the current wallpaper in the array and pick the one before it
            for ((i=0; i<NUM_FILES; i++)); do
                if [ "${FILES[i]}" = "$CURRENT_WP" ]; then
                    if [ $i -gt 0 ]; then
                        PREV_WP="${FILES[i-1]}"
                    fi
                    break
                fi
            done
        else
            # Symlink is missing or broken; default to the second-to-last file
            PREV_WP="${FILES[NUM_FILES-2]}"
        fi
    fi
    
    if [ -z "$PREV_WP" ] || [ ! -f "$PREV_WP" ]; then
        echo "Error: No previous wallpaper is available." >&2
        exit 1
    fi
    
    # Update the symlink pointing to the selected previous wallpaper
    ln -sf "$PREV_WP" "$WP_DIR/bing-latest.jpg"
    SAVE_PATH="$PREV_WP"
else
    # Define today's path
    TODAY=$(date +'%Y-%m-%d')
    SAVE_PATH="$WP_DIR/bing-$TODAY.jpg"

    # Download the image if we haven't already today, or if FORCE_NEW is true
    if [ ! -f "$SAVE_PATH" ] || [ "$FORCE_NEW" = true ]; then
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
        
        # Determine the target path for saving the new wallpaper
        TARGET_PATH="$SAVE_PATH"
        if [ "$FORCE_NEW" = true ] && [ -f "$SAVE_PATH" ]; then
            COUNTER=1
            while [ -f "${SAVE_PATH%.jpg}-$COUNTER.jpg" ]; do
                COUNTER=$((COUNTER + 1))
            done
            TARGET_PATH="${SAVE_PATH%.jpg}-$COUNTER.jpg"
        fi

        # Download to a temporary file first to prevent corruption/partial files
        TEMP_SAVE_PATH="$TARGET_PATH.tmp"
        
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
            # Compare checksum with all of today's wallpapers to avoid duplicates
            NEW_HASH=$(sha256sum "$TEMP_SAVE_PATH" | awk '{print $1}')
            MATCHED_WP=""
            shopt -s nullglob
            for f in "$WP_DIR/bing-$TODAY"*.jpg; do
                if [ -f "$f" ] && [ "$f" != "$TEMP_SAVE_PATH" ]; then
                    OLD_HASH=$(sha256sum "$f" | awk '{print $1}')
                    if [ "$NEW_HASH" = "$OLD_HASH" ]; then
                        MATCHED_WP="$f"
                        break
                    fi
                fi
            done

            if [ -n "$MATCHED_WP" ]; then
                echo "Downloaded wallpaper is identical to an existing wallpaper for today ($MATCHED_WP). Skipping update."
                rm -f "$TEMP_SAVE_PATH"
                # Update the symlink pointing to today's matched wallpaper
                ln -sf "$MATCHED_WP" "$WP_DIR/bing-latest.jpg"
                SAVE_PATH="$MATCHED_WP"
                # Always apply the wallpaper to all outputs if the file exists
                if [ -f "$SAVE_PATH" ] && [ -n "$SWAYSOCK" ]; then
                    swaymsg "output * bg $SAVE_PATH fill"
                fi
                exit 0
            fi

            # Move temp file to its final destination
            mv "$TEMP_SAVE_PATH" "$TARGET_PATH"
            # Update the symlink pointing to today's wallpaper
            ln -sf "$TARGET_PATH" "$WP_DIR/bing-latest.jpg"
            # Set SAVE_PATH to the final target path so it gets applied
            SAVE_PATH="$TARGET_PATH"
        else
            echo "Failed to download a valid image from Bing." >&2
            rm -f "$TEMP_SAVE_PATH"
            exit 1
        fi
    fi
fi

# Always apply the wallpaper to all outputs if the file exists
if [ -f "$SAVE_PATH" ]; then
    if [ -n "$SWAYSOCK" ]; then
        swaymsg "output * bg $SAVE_PATH fill"
    fi
fi
