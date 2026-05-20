#!/bin/bash

# Comprehensive Hardware Status Script for MacBook Air (M4)
# Uses built-in macOS tools (ioreg, pmset, vm_stat, sysctl)

chip_name=$(sysctl -n machdep.cpu.brand_string)

echo "==========================================="
echo "    Hardware Status: $chip_name"
echo "==========================================="

# 1. Display Brightness (using provided snippet)
brightness_raw=$(ioreg -rc IOMobileFramebufferShim | awk '/"IOMFBBrightnessLevel" =/ { print $4; exit }')
if [[ -n "$brightness_raw" ]]; then
    # The divisor 27515064 was provided in the snippet
    brightness=$(echo "scale=2; ($brightness_raw / 27515064) * 100" | bc | awk '{printf "%.0f%%", $1}')
    echo "Display Brightness: $brightness"
else
    echo "Display Brightness: Unknown"
fi

# 2. Power State
power_source=$(pmset -g batt | head -n 1 | cut -d "'" -f 2)
batt_info=$(pmset -g batt | grep "InternalBattery")
pct=$(echo "$batt_info" | grep -oE "[0-9]+%")
state=$(echo "$batt_info" | cut -d ";" -f 2 | xargs)

echo "Current Power State: $power_source"
echo "Battery Level:       $pct ($state)"

# 3 & 4. Battery and AC Power Draw
# Get battery stats from ioreg
battery_ioreg=$(ioreg -rw0 -c AppleSmartBattery)
voltage_mv=$(echo "$battery_ioreg" | grep '"Voltage" =' | sed 's/.*= //')
current_ma=$(echo "$battery_ioreg" | grep '"Amperage" =' | sed 's/.*= //')

# Check for InstantAmperage if Amperage is 0 or missing
if [[ -z "$current_ma" || "$current_ma" -eq 0 ]]; then
    current_ma=$(echo "$battery_ioreg" | grep '"InstantAmperage" =' | sed 's/.*= //')
fi

# Calculate Battery Draw (W = V * A)
if [[ -n "$voltage_mv" && -n "$current_ma" ]]; then
    batt_w=$(echo "scale=4; ($current_ma * $voltage_mv) / 1000000" | bc)
    batt_w_fmt=$(printf "%.2f" "$batt_w" 2>/dev/null || echo "$batt_w")
    batt_w_abs=$(echo "$batt_w_fmt" | sed 's/-//')
    
    if (( $(echo "$current_ma < 0" | bc -l) )); then
        echo "Battery Discharge:   $batt_w_abs W"
    elif (( $(echo "$current_ma > 0" | bc -l) )); then
        echo "Battery Charge Rate: $batt_w_abs W"
    else
        echo "Battery Draw:         0.00 W (Idle/Full)"
    fi
else
    echo "Battery Draw:         Unknown"
fi

# AC Power Draw (System Power In - Real-time consumption from AC)
ac_power_mw=$(echo "$battery_ioreg" | sed -n 's/.*"SystemPowerIn"=\([0-9]*\).*/\1/p')
if [[ -n "$ac_power_mw" ]]; then
    ac_power_w=$(echo "scale=2; $ac_power_mw / 1000" | bc)
    ac_power_w_fmt=$(printf "%.2f" "$ac_power_w" 2>/dev/null || echo "$ac_power_w")
    echo "Current AC Draw:     $ac_power_w_fmt W"
fi

# Adapter Info
adapter_w=$(echo "$battery_ioreg" | grep '"Watts" =' | sed 's/.*= //' | head -n 1)
if [[ -n "$adapter_w" ]]; then
    echo "AC Adapter Capacity: ${adapter_w}W"
fi

# 5. RAM Usage
total_ram_bytes=$(sysctl -n hw.memsize)
total_ram_gb=$(echo "scale=2; $total_ram_bytes / 1024 / 1024 / 1024" | bc)

vm_stats=$(vm_stat)
page_size=$(echo "$vm_stats" | grep "page size of" | awk '{print $8}')
wired_pages=$(echo "$vm_stats" | grep "Pages wired down" | awk '{print $4}' | tr -d '.')
active_pages=$(echo "$vm_stats" | grep "Pages active" | awk '{print $3}' | tr -d '.')
comp_pages=$(echo "$vm_stats" | grep "Pages occupied by compressor" | awk '{print $5}' | tr -d '.')

used_bytes=$(( (wired_pages + active_pages + comp_pages) * page_size ))
used_gb=$(echo "scale=2; $used_bytes / 1024 / 1024 / 1024" | bc)
used_gb_fmt=$(printf "%.2f" "$used_gb" 2>/dev/null || echo "$used_gb")
used_pct=$(echo "scale=1; ($used_bytes / $total_ram_bytes) * 100" | bc | awk '{printf "%.1f%%", $1}')

echo "RAM Usage:           ${used_gb_fmt} GB / ${total_ram_gb} GB ($used_pct)"

# 6, 7, 8. Temperatures
echo "--- Temperatures ---"
# Battery Temp (Centicelsius to Celsius)
batt_temp_raw=$(echo "$battery_ioreg" | grep -w '"Temperature"' | sed 's/.*= //' | head -n 1)
if [[ -n "$batt_temp_raw" ]]; then
    batt_temp_c=$(echo "scale=2; $batt_temp_raw / 100" | bc)
    batt_temp_fmt=$(printf "%.2f" "$batt_temp_c" 2>/dev/null || echo "$batt_temp_c")
    echo "Battery:             ${batt_temp_fmt} C"
else
    echo "Battery:             Unknown"
fi

# SoC Virtual Temperature
virt_temp_raw=$(echo "$battery_ioreg" | grep -w '"VirtualTemperature"' | sed 's/.*= //' | head -n 1)
if [[ -n "$virt_temp_raw" ]]; then
    virt_temp_c=$(echo "scale=2; $virt_temp_raw / 100" | bc)
    virt_temp_fmt=$(printf "%.2f" "$virt_temp_c" 2>/dev/null || echo "$virt_temp_c")
    echo "SoC (Virtual):       ${virt_temp_fmt} C"
else
    echo "SoC (Virtual):       Unknown"
fi

# 9. Detailed SoC Metrics (Requires sudo)
if [[ "$1" == "--detailed" ]]; then
    echo "Attempting to get detailed SoC metrics (requires sudo)..."
    pm_out=$(sudo powermetrics -n 1 -i 100 --samplers cpu_power,gpu_power,ane_power,thermal,network,disk 2>/dev/null)
    
    echo "--- SoC Power Consumption ---"
    echo "$pm_out" | grep -iE "^CPU Power:|^GPU Power:|^ANE Power:|^Combined Power" | head -n 4
    
    echo "--- Network Activity ---"
    echo "$pm_out" | grep -iE "^out:|^in:" | head -n 2
    
    echo "--- Disk Activity ---"
    echo "$pm_out" | grep -iE "^read:|^write:" | head -n 2
    
    echo "--- Thermal Pressure ---"
    echo "$pm_out" | grep -iE "Current pressure level:" | sed 's/Current pressure level:/Pressure Level:/'
else
    echo "Note: Run with '--detailed' (requires sudo) for per-component SoC power (CPU/GPU/ANE) and thermal pressure."
fi

echo "==========================================="
