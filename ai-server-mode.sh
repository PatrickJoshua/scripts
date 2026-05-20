#!/bin/bash

# Capture original states to revert later
ORIG_VRAM_LIMIT=$(sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo "0")
ORIG_TRANSPARENCY=$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo "0")

cleanup() {
    echo -e "\n--- Reverting system settings ---"
    
    # Re-enable Spotlight Search Indexing
    echo "Re-enabling Spotlight..."
    sudo mdutil -a -i on
    
    # Restore Transparency
    echo "Restoring UI transparency..."
    if [ "$ORIG_TRANSPARENCY" -eq 1 ]; then
        defaults write com.apple.universalaccess reduceTransparency -bool true
    else
        defaults write com.apple.universalaccess reduceTransparency -bool false
    fi

    # Revert VRAM limit
    echo "Restoring VRAM limit to $ORIG_VRAM_LIMIT..."
    sudo sysctl iogpu.wired_limit_mb=$ORIG_VRAM_LIMIT
    
    # Re-enable Services
    echo "Restarting network services (VNC, AFP, SMB)..."
    [ -f /System/Library/LaunchDaemons/com.apple.screensharing.plist ] && sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null
    [ -f /System/Library/LaunchDaemons/com.apple.AppleFileServer.plist ] && sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.AppleFileServer.plist 2>/dev/null
    [ -f /System/Library/LaunchDaemons/com.apple.smbd.plist ] && sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null
    
    # Refresh UI to apply transparency changes
    echo "Refreshing UI (Finder, Dock)..."
    killall Finder 2>/dev/null
    killall Dock 2>/dev/null

    echo "Cleanup complete. Note: GUI apps and background daemons were not manually restarted (macOS will relaunch them as needed)."
}

# Trap script termination (Ctrl+C, kill, or natural exit)
trap cleanup EXIT SIGINT SIGTERM

# --- Apply Optimizations ---

# 1. Reduce UI Overhead
echo "Reducing UI overhead..."
defaults write com.apple.universalaccess reduceTransparency -bool true

# 2. Set VRAM limits to 14GB (14336 MB)
echo "Setting VRAM limit to 14GB..."
sudo sysctl iogpu.wired_limit_mb=14336

# 3. Disable Spotlight Search Indexing
echo "Disabling Spotlight..."
sudo mdutil -a -i off

# 4. Disable Services (VNC, AFP, SMB)
echo "Disabling network services..."
[ -f /System/Library/LaunchDaemons/com.apple.screensharing.plist ] && sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null
[ -f /System/Library/LaunchDaemons/com.apple.AppleFileServer.plist ] && sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.AppleFileServer.plist 2>/dev/null
[ -f /System/Library/LaunchDaemons/com.apple.smbd.plist ] && sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.smbd.plist 2>/dev/null

# 5. Kill aggressive background daemons
echo "Killing background daemons (iCloud, Siri, Photos)..."
killall -9 bird assistantd photoanalysisd mediaanalysisd sharingd softwareupdated 2>/dev/null
pkill -9 -fi siri 2>/dev/null

# 6. Kill all GUI apps
echo "Closing GUI applications..."
osascript -e 'tell application "System Events" to set quitapps to name of every application process whose visible is true and name is not "Terminal"' -e 'repeat with appname in quitapps' -e 'quit application appname' -e 'end repeat'

# 7. Aggressive Browser/Electron Cleanup
echo "Cleaning up leftover browser/electron helpers..."
killall "Google Chrome Helper" "Brave Browser Helper" "Renderer" 2>/dev/null

# 8. Relaunch Finder and Dock to clear their cache
killall Finder 2>/dev/null
killall Dock 2>/dev/null

# 9. Purge memory
echo "Final memory purge..."
sudo purge

echo "-------------------------------------------------------"
echo "AI Server Mode active. Press Ctrl+C to exit and revert."
echo "-------------------------------------------------------"

# --- Launch llama.cpp ---
# Replace 'sleep infinity' with your server launch command:
# ./llama-server -m models/7b.gguf ...
#sleep infinity
#llama-cli -m ~/projects/DeepSeek-R1-Distill-Qwen-14B-Q5_K_M.gguf -ngl 99 -c 8192 -t 4 -cnv
llama-server -m ~/projects/DeepSeek-R1-Distill-Qwen-14B-Q5_K_M.gguf -ngl 99 -c 8192 -t 4
