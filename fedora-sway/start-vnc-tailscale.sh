#!/bin/bash

# Auto-detect active Sway IPC socket if SWAYSOCK is unset or points to a stale socket
if [ -z "$SWAYSOCK" ] || [ ! -S "$SWAYSOCK" ]; then
    ACTIVE_SOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock 2>/dev/null | head -n1)
    if [ -S "$ACTIVE_SOCK" ]; then
        export SWAYSOCK="$ACTIVE_SOCK"
        echo "[i] Auto-detected active SWAYSOCK: $SWAYSOCK"
    fi
fi

# Initialize proxy tracking variables
BYEDPI_STARTED=0
WAS_PROXY_CONFIGURED=0

# Initialize headless display tracking variables
CREATE_HEADLESS=0
TERMINATE_PHYSICAL=0
HEADLESS_RES="1638x639"
HEADLESS_OUTPUT=""
declare -a DISABLED_OUTPUTS=()

# Parse optional command-line flags
for arg in "$@"; do
    case "$arg" in
        --headless)
            CREATE_HEADLESS=1
            TERMINATE_PHYSICAL=0
            ;;
    esac
done

# Prompt to create a HEADLESS display and configure options if not already set and running in interactive terminal
if [ "$CREATE_HEADLESS" -eq 0 ] && { [ -t 0 ] || [ -c /dev/tty ]; }; then
    read -p "Create a HEADLESS display on Sway? [Y/n]: " create_hl < /dev/tty
    create_hl=${create_hl:-y}
    if [[ "$create_hl" =~ ^[Yy]$ ]]; then
        CREATE_HEADLESS=1
        
        # Ask to terminate physical displays
        read -p "Terminate all other physical displays? [y/N]: " term_phys < /dev/tty
        term_phys=${term_phys:-n}
        if [[ "$term_phys" =~ ^[Yy]$ ]]; then
            TERMINATE_PHYSICAL=1
        fi
        
        # Ask for headless display resolution
        read -p "Set HEADLESS display resolution [$HEADLESS_RES]: " hl_res < /dev/tty
        if [ -n "$hl_res" ]; then
            HEADLESS_RES="$hl_res"
        fi
    fi
fi

# Check SSID to see if ByeDPI is required
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes:' | cut -d: -f2 2>/dev/null)

if [ "$CURRENT_SSID" = "Globe-Corp" ]; then
    echo "[i] Active network 'Globe-Corp' detected. ByeDPI activation required."
    
    # Check/Start ByeDPI daemon (ciadpi)
    BYEDPI_BIN="/home/pa3k/.local/bin/ciadpi"
    if [ -x "$BYEDPI_BIN" ]; then
        if ! pgrep -xu "$USER" -f ciadpi >/dev/null; then
            echo "[i] Starting ByeDPI daemon..."
            "$BYEDPI_BIN" --daemon --pidfile /tmp/byedpi.pid -r 1
            BYEDPI_STARTED=1
            echo "[✓] ByeDPI daemon started successfully."
        else
            echo "[i] ByeDPI daemon is already running."
        fi
    else
        echo "[!] Warning: ByeDPI binary ($BYEDPI_BIN) not found or not executable."
    fi

    # Set up Tailscale systemd drop-in proxy configuration
    PROXY_CONF="/etc/systemd/system/tailscaled.service.d/proxy.conf"
    if [ ! -f "$PROXY_CONF" ] || ! grep -q "socks5://127.0.0.1:1080" "$PROXY_CONF" 2>/dev/null; then
        echo "[i] Configuring Tailscale to use ByeDPI proxy..."
        sudo mkdir -p /etc/systemd/system/tailscaled.service.d
        echo -e '[Service]\nEnvironment="ALL_PROXY=socks5://127.0.0.1:1080" "NO_PROXY=localhost,127.0.0.1,100.64.0.0/10"' | sudo tee "$PROXY_CONF" >/dev/null
        WAS_PROXY_CONFIGURED=1
        sudo systemctl daemon-reload
    fi
else
    # Clean up leftover proxy files on any other network to avoid connection issues
    if [ -f "/etc/systemd/system/tailscaled.service.d/proxy.conf" ]; then
        echo "[i] Network '$CURRENT_SSID' does not require ByeDPI. Cleaning up leftover proxy config..."
        sudo rm -f /etc/systemd/system/tailscaled.service.d/proxy.conf
        if [ -d /etc/systemd/system/tailscaled.service.d ] && [ -z "$(ls -A /etc/systemd/system/tailscaled.service.d)" ]; then
            sudo rmdir /etc/systemd/system/tailscaled.service.d
        fi
        sudo systemctl daemon-reload
        WAS_PROXY_CONFIGURED=1 # Force restart of tailscaled below to apply removal
    fi
fi

# Check and manage Tailscale service
if ! systemctl is-active --quiet tailscaled 2>/dev/null; then
    echo "[i] Tailscale service (tailscaled) is not active. Starting..."
    sudo systemctl start tailscaled
    
    # Wait up to 5 seconds for the service to initialize
    for i in {1..5}; do
        if systemctl is-active --quiet tailscaled 2>/dev/null; then
            echo "[✓] Tailscale service started successfully."
            break
        fi
        sleep 1
    done
else
    # If service was active but we updated/removed the proxy config, restart it
    if [ "$WAS_PROXY_CONFIGURED" -eq 1 ]; then
        echo "[i] Restarting Tailscale service to apply configuration changes..."
        sudo systemctl restart tailscaled
        echo "[✓] Tailscale service restarted."
    fi
fi

# Check if swayidle is running and stop it to prevent sleep/lock during VNC
if pgrep -xu "$USER" swayidle >/dev/null; then
    echo "[i] Active swayidle process detected. Temporarily disabling..."
    WAS_SWAYIDLE_RUNNING=1
    pkill -xu "$USER" swayidle
else
    echo "[i] No active swayidle process found."
    WAS_SWAYIDLE_RUNNING=0
fi

# Track ngrok background PID
NGROK_PID=""

cleanup() {
    # Remove traps to prevent recursion/double invocation
    trap - EXIT INT TERM HUP QUIT

    # Restore disabled physical outputs and destroy headless output
    if [ ${#DISABLED_OUTPUTS[@]} -gt 0 ]; then
        echo "[i] Restoring physical outputs..."
        for out in "${DISABLED_OUTPUTS[@]}"; do
            echo "[i] Enabling output: $out"
            swaymsg output "$out" enable >/dev/null 2>&1 || true
        done
    fi

    if [ -n "$HEADLESS_OUTPUT" ]; then
        echo "[i] Destroying headless output: $HEADLESS_OUTPUT"
        swaymsg output "$HEADLESS_OUTPUT" unplug >/dev/null 2>&1 || true
    fi

    # Kill ngrok if it was started
    if [ -n "$NGROK_PID" ]; then
        echo -e "\n[i] Stopping ngrok tunnel..."
        kill "$NGROK_PID" 2>/dev/null || true
    fi

    # Stop ByeDPI daemon if we started it or if pidfile exists
    if [ -f /tmp/byedpi.pid ]; then
        echo "[i] Stopping ByeDPI daemon..."
        kill $(cat /tmp/byedpi.pid) 2>/dev/null || true
        rm -f /tmp/byedpi.pid
        echo "[✓] ByeDPI stopped."
    fi

    # Prompt to stop Tailscale service
    # Read from /dev/tty to ensure input works even under a signal/trap handler
    STOP_TS_SERVICE=0
    if [ -t 0 ] || [ -c /dev/tty ]; then
        echo ""
        read -p "Stop Tailscale service (tailscaled)? [Y/n]: " stop_ts < /dev/tty
        stop_ts=${stop_ts:-y}
        if [[ "$stop_ts" =~ ^[Yy]$ ]]; then
            STOP_TS_SERVICE=1
        fi
    fi

    # Revert Tailscale proxy configurations if we applied them
    if [ "$WAS_PROXY_CONFIGURED" -eq 1 ] && [ "$CURRENT_SSID" = "Globe-Corp" ]; then
        echo "[i] Reverting Tailscale proxy configurations..."
        sudo rm -f /etc/systemd/system/tailscaled.service.d/proxy.conf
        if [ -d /etc/systemd/system/tailscaled.service.d ] && [ -z "$(ls -A /etc/systemd/system/tailscaled.service.d)" ]; then
            sudo rmdir /etc/systemd/system/tailscaled.service.d
        fi
        sudo systemctl daemon-reload
        
        if [ "$STOP_TS_SERVICE" -eq 1 ]; then
            echo "[i] Stopping Tailscale service..."
            sudo systemctl stop tailscaled
            echo "[✓] Tailscale service stopped and proxy configurations reverted."
        else
            sudo systemctl restart tailscaled
            echo "[✓] Tailscale proxy settings reverted to normal."
        fi
    elif [ "$STOP_TS_SERVICE" -eq 1 ]; then
        echo "[i] Stopping Tailscale service..."
        sudo systemctl stop tailscaled
        echo "[✓] Tailscale service stopped."
    fi

    # Restore swayidle if it was running before
    if [ "$WAS_SWAYIDLE_RUNNING" -eq 1 ]; then
        echo "[i] Restoring swayidle configuration..."
        SWAYIDLE_CONFIG="$HOME/.config/sway/config.d/90-swayidle.conf"
        if [ -f "$SWAYIDLE_CONFIG" ]; then
            CMD=$(sed -n '/exec swayidle/,$p' "$SWAYIDLE_CONFIG" | sed 's/exec //')
            CMD_SINGLE_LINE=$(echo "$CMD" | tr '\n' ' ' | tr -d '\\')
            if [ -n "$CMD_SINGLE_LINE" ]; then
                swaymsg exec "$CMD_SINGLE_LINE" >/dev/null 2>&1
                echo "[✓] swayidle restored from configuration."
            else
                swaymsg exec "swayidle -w" >/dev/null 2>&1
                echo "[✓] swayidle restored (default fallback)."
            fi
        else
            swaymsg exec "swayidle -w" >/dev/null 2>&1
            echo "[✓] swayidle restored (default fallback)."
        fi
    fi

    echo "[i] VNC session ended."
}

# Trap exits and standard signals to ensure cleanup is run
trap cleanup EXIT INT TERM HUP QUIT

# Start ngrok in the background
echo "[i] Starting ngrok tunnel..."
ngrok tcp 127.0.0.1:5900 >/dev/null 2>&1 &
NGROK_PID=$!

# Wait briefly and query ngrok local API to retrieve public URL
NGROK_URL=""
for i in {1..10}; do
    sleep 0.8
    # Check if process is still alive
    if ! kill -0 "$NGROK_PID" 2>/dev/null; then
        echo "[!] ngrok failed to start."
        break
    fi
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[] | select(.proto=="tcp") | .public_url' 2>/dev/null)
    if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
        break
    fi
done

# Discover and print IP addresses
echo "============================================="
echo "   VNC Server starting on port 5900"
echo "============================================="
echo "Available IP addresses/URLs to connect to:"

# Wait up to 10 seconds for Tailscale IP to be assigned if service is active
TS_IP=""
if systemctl is-active --quiet tailscaled 2>/dev/null; then
    for i in {1..10}; do
        TS_IP=$(tailscale ip -4 2>/dev/null)
        if [ -n "$TS_IP" ]; then
            break
        fi
        sleep 1
    done
fi

if [ -n "$TS_IP" ]; then
    echo "  - Tailscale: $TS_IP"
fi

# Get all IPv4 addresses excluding loopback and tailscale IP
LOCAL_IPS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')
for ip in $LOCAL_IPS; do
    if [ "$ip" != "$TS_IP" ]; then
        echo "  - Local IP:  $ip"
    fi
done

# Print mDNS address
MDNS_HOST=$(hostname 2>/dev/null || uname -n || echo "localhost")
echo "  - mDNS:      ${MDNS_HOST}.local"

if [ -n "$NGROK_URL" ] && [ "$NGROK_URL" != "null" ]; then
    echo "  - Ngrok TCP: ${NGROK_URL#tcp://}"
else
    echo "  - Ngrok TCP: (Failed to establish or retrieve tunnel)"
fi
echo "============================================="

if [ "$CREATE_HEADLESS" -eq 1 ]; then
    echo "[i] Setting up HEADLESS display..."
    # Get existing outputs before creating the headless one
    EXISTING_OUTPUTS=$(swaymsg -t get_outputs | jq -r '.[] | .name' 2>/dev/null)
    
    # Create the headless output
    if swaymsg create_output >/dev/null 2>&1; then
        # Find the new headless output name
        NEW_OUTPUTS=$(swaymsg -t get_outputs | jq -r '.[] | .name' 2>/dev/null)
        for out in $NEW_OUTPUTS; do
            if [[ "$out" =~ ^HEADLESS- ]] && ! grep -q -w "$out" <<< "$EXISTING_OUTPUTS"; then
                HEADLESS_OUTPUT="$out"
                break
            fi
        done
        
        if [ -n "$HEADLESS_OUTPUT" ]; then
            echo "[✓] Created headless output: $HEADLESS_OUTPUT"
            
            # Set headless output resolution
            echo "[i] Setting resolution of $HEADLESS_OUTPUT to $HEADLESS_RES..."
            if ! swaymsg output "$HEADLESS_OUTPUT" resolution "$HEADLESS_RES" >/dev/null 2>&1; then
                # Fallback to custom mode if resolution fails
                swaymsg output "$HEADLESS_OUTPUT" mode --custom "${HEADLESS_RES}@60Hz" >/dev/null 2>&1 || true
            fi
            
            # Set headless output background to solid black
            echo "[i] Setting background of $HEADLESS_OUTPUT to solid black..."
            swaymsg output "$HEADLESS_OUTPUT" bg "#000000" solid_color >/dev/null 2>&1 || true
            
            # Conditionally disable other physical outputs if requested
            if [ "$TERMINATE_PHYSICAL" -eq 1 ]; then
                # Get list of currently active outputs (other than the new headless one) to disable them
                PHYSICAL_OUTPUTS=$(swaymsg -t get_outputs | jq -r '.[] | select(.active and .name != "'"$HEADLESS_OUTPUT"'") | .name' 2>/dev/null)
                
                for out in $PHYSICAL_OUTPUTS; do
                    echo "[i] Disabling physical output: $out"
                    if swaymsg output "$out" disable >/dev/null 2>&1; then
                        DISABLED_OUTPUTS+=("$out")
                    else
                        echo "[!] Failed to disable physical output: $out"
                    fi
                done
            fi
        else
            echo "[!] Failed to identify the newly created headless output."
        fi
    else
        echo "[!] Failed to create headless output via swaymsg."
    fi
fi

echo "[i] Inhibiting system sleep and lid-close suspend..."
# Start wayvnc on all interfaces with lid-close and system sleep/suspend inhibited
WAYVNC_ARGS=()
if [ -n "$HEADLESS_OUTPUT" ]; then
    WAYVNC_ARGS+=("-o" "$HEADLESS_OUTPUT")
fi
WAYVNC_ARGS+=("0.0.0.0" "5900")

systemd-inhibit --what=handle-lid-switch:sleep --why="VNC Session Active" --who="start-vnc-tailscale.sh" --mode=block wayvnc "${WAYVNC_ARGS[@]}"
