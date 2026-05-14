#!/bin/bash

echo "Stopping GlobalProtect User Agent (pangpa)..."
# We run this WITHOUT sudo because the agent runs in your user space
launchctl unload /Library/LaunchAgents/com.paloaltonetworks.gp.pangpa.plist
killall GlobalProtect

echo "Stopping GlobalProtect Daemon (pangps)..."
# We run this WITH sudo because the daemon is a system-level process
sudo launchctl unload /Library/LaunchDaemons/com.paloaltonetworks.gp.pangps.plist

echo "GlobalProtect has been completely stopped."
