#!/usr/bin/env bash

# If no command was typed yet, prompt the user
if [ -z "$@" ]; then
    echo "Type a command to see its output..."
else
    # The user typed a command. Execute it, capture the output, and show it in a notification.
    # We use notify-send here because Rofi sometimes struggles to open a new window while the first is still closing.
    OUTPUT=$(eval "$@" 2>&1)
    notify-send "Output of: $@" "$OUTPUT"
fi
