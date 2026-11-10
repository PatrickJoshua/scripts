#!/bin/bash

if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    read -r TEMP_RAW < /sys/class/thermal/thermal_zone0/temp 2>/dev/null
    if [[ -n "$TEMP_RAW" ]]; then
        echo "Temp: $((TEMP_RAW / 1000))°C"
    fi
fi

for x in {1..2}; do
   echo "Fan $x: $(cat /sys/class/hwmon/hwmon4/fan${x}_input 2>/dev/null) RPM"
done;
