# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs


# Added by Antigravity CLI installer
export PATH="/home/pa3k/.local/bin:$PATH"

# Autostart sway or swedge on tty1
if [ "$(tty)" = "/dev/tty1" ]; then
    # Inform the user of their choices, how to cancel, and the automatic default timeout
    echo "Autostart: Press (1) for swedge, (2) for sway, (3) for swedge (manual), (4) for sway with VNC. Any other key to cancel. Defaulting to swedge in 10 seconds."
    
    timeout=10
    key=""
    keypress=false
    
    # Loop once per second to check for key presses until timeout is reached
    while [ $timeout -gt 0 ]; do
        # Print the dynamic countdown on the current line (carriage-return)
        printf "\rDefaulting to swedge in %d seconds... " "$timeout"
        
        # -s hides input character, -n 1 reads 1 character, -t 1 times out in 1 second
        if read -r -s -n 1 -t 1 key; then
            keypress=true
            break
        fi
        ((timeout--))
    done
    
    # Carriage-return and clear line (\033[K) to clean up terminal output
    printf "\r\033[K"

    # Evaluate the keypress input or handle timeout default
    if [ "$keypress" = "false" ]; then
        # No key was pressed; execute default (swedge)
        echo "Defaulting to swedge..."
        exec swedge
    elif [ "$key" = "1" ]; then
        # Key '1' was pressed; execute swedge
        exec swedge
    elif [ "$key" = "2" ]; then
        # Key '2' was pressed; execute sway
        exec sway
    elif [ "$key" = "3" ]; then
        # Key '3' was pressed; execute swedge
        exec swedge
    elif [ "$key" = "4" ]; then
        # Key '4' was pressed; validate sudo credentials interactively first
        echo "Validating sudo credentials for Tailscale/VNC setup..."
        sudo -v
        # Execute sway with VNC config
        exec sway -c ~/.config/sway/config.vnc
    else
        # Any other key was pressed; cancel autostart and drop to normal bash shell
        echo "Autostart cancelled. Returning to shell."
    fi
fi
