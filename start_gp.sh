#!/bin/bash

echo "Starting GlobalProtect Daemon (pangps)..."
sudo launchctl load /Library/LaunchDaemons/com.paloaltonetworks.gp.pangps.plist

echo "Starting GlobalProtect User Agent (pangpa)..."
launchctl load /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist
open -a GlobalProtect

echo "GlobalProtect has been started."
