# MSI Modern 15 (A11M / MS-1552) Power & Fan Management Setup

This guide documents the complete setup for CPU power capping, TuneD power profile synchronization, and zero-RPM silent fan operation via the `msi-ec` Embedded Controller (EC) driver on Linux (Fedora 44, kernel 7.2+).

---

## 1. System Architecture & Objectives

* **Target Hardware:** MSI Modern 15 A11M (MS-1552 / Intel Iris Xe Graphics).
* **On Battery Behavior:**
  * CPU Maximum Performance Cap: Capped at **30%** via Intel P-State (`/sys/devices/system/cpu/intel_pstate/max_perf_pct`).
  * TuneD Power Profile: Switched to **`powersave`**.
  * MSI EC Preset: Switched to **`super_battery`**.
  * MSI EC Fan Mode: Switched to **`silent`**.
  * Resulting Fan Speed: **0 RPM** (passive cooling below ~50°C, CPU runs at ~33°C).
  * Wallpaper (`swaybg`): Switched to **solid black (`#000000`)** to conserve battery.
* **On AC Power Behavior:**
  * CPU Maximum Performance Cap: Uncapped (**100%**).
  * TuneD Power Profile: Switched to **`throughput-performance`** (or `balanced`).
  * MSI EC Preset: Switched to **`balanced`**.
  * MSI EC Fan Mode: Switched to **`auto`** (firmware-managed thermal curve).
  * Wallpaper (`swaybg`): Restores the dynamic **Bing daily wallpaper** via `bing-wallpaper.service`.

---

## 2. Kernel Driver Setup: `msi-ec-modern`

The standard Linux kernel does not expose fan controls for the MSI MS-1552 Embedded Controller (`/sys/class/hwmon4` only provides read-only RPM sensors). The community driver `timschneeb/msi-ec-modern` provides read and write access to the EC registers.

### 2.1. Prerequisites

Ensure kernel development headers match your currently running kernel:

```bash
# Check running kernel version
uname -r

# Install matching kernel-devel and build tools
sudo dnf install -y kernel-devel gcc make git
```

*(Note: If your running kernel is slightly older than the latest repository package, download the matching `kernel-devel-<version>.rpm` directly from Fedora Koji).*

### 2.2. Clone and Patch for Modern Kernels (6.11+ / 7.x)

```bash
sudo git clone https://github.com/timschneeb/msi-ec-modern.git /usr/src/msi-ec-modern
cd /usr/src/msi-ec-modern
```

In Linux kernel 6.11 and newer, the `platform_driver.remove` callback signature changed from returning `int` to `void`. Additionally:
* **Keyboard Backlight Preservation:** To prevent power preset transitions (`super_battery` on battery, `balanced` on AC) from altering user-defined keyboard lighting, skip writing to `MSI_EC_PRESET_COLUMN_KBD_BL`.
* **Battery Charge Thresholds (`charge_control_end_threshold`):** Register an ACPI battery hook with `battery_hook_register()` targeting EC register `0xD7` (offset `0x80` for end threshold) to retain `/sys/class/power_supply/BAT1/charge_control_end_threshold` for battery charge limiting.

Apply these patches to `msi-ec.c`:

```c
#include <linux/version.h>

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 11, 0)
static void msi_platform_remove(struct platform_device *pdev)
{
        sysfs_remove_groups(&pdev->dev.kobj, msi_platform_groups);
}
#else
static int msi_platform_remove(struct platform_device *pdev)
{
        sysfs_remove_groups(&pdev->dev.kobj, msi_platform_groups);
        return 0;
}
#endif

/* Inside preset_store(): Preserve keyboard backlight level across power preset changes */
for (c = 0; c < ARRAY_SIZE(MSI_EC_PRESET_MEMORY_TABLE); c++) {
        u8 addr = MSI_EC_PRESET_MEMORY_TABLE[c];
        u8 value = MSI_EC_PRESET_VALUE_TABLE[index][c];

        // Do not override keyboard backlight brightness on preset changes
        if (c == MSI_EC_PRESET_COLUMN_KBD_BL)
                continue;
}

/* Battery Hook for /sys/class/power_supply/BAT1/charge_control_end_threshold */
#define MSI_EC_BATTERY_CHARGE_CONTROL_ADDRESS 0xd7
#define MSI_EC_BATTERY_OFFSET_END 0x80
#define MSI_EC_BATTERY_OFFSET_START 0x8a
#define MSI_EC_BATTERY_RANGE_MIN 0x8a
#define MSI_EC_BATTERY_RANGE_MAX 0xe4

static ssize_t charge_control_end_threshold_show(struct device *device,
                                                struct device_attribute *attr, char *buf)
{
        u8 rdata;
        if (ec_read(MSI_EC_BATTERY_CHARGE_CONTROL_ADDRESS, &rdata) < 0)
                return -EIO;
        return sysfs_emit(buf, "%i\n", rdata - MSI_EC_BATTERY_OFFSET_END);
}

static ssize_t charge_control_end_threshold_store(struct device *dev,
                                                 struct device_attribute *attr,
                                                 const char *buf, size_t count)
{
        u8 val;
        if (kstrtou8(buf, 10, &val) < 0)
                return -EINVAL;
        u16 wdata = (u16)val + MSI_EC_BATTERY_OFFSET_END;
        if (wdata < MSI_EC_BATTERY_RANGE_MIN || wdata > MSI_EC_BATTERY_RANGE_MAX)
                return -EINVAL;
        if (ec_write(MSI_EC_BATTERY_CHARGE_CONTROL_ADDRESS, (u8)wdata) < 0)
                return -EIO;
        return count;
}

static DEVICE_ATTR_RW(charge_control_end_threshold);

static struct attribute *msi_battery_attrs[] = {
        &dev_attr_charge_control_end_threshold.attr,
        NULL
};
ATTRIBUTE_GROUPS(msi_battery);

static int msi_battery_add(struct power_supply *battery, struct acpi_battery_hook *hook) {
        return device_add_groups(&battery->dev, msi_battery_groups);
}
static int msi_battery_remove(struct power_supply *battery, struct acpi_battery_hook *hook) {
        device_remove_groups(&battery->dev, msi_battery_groups);
        return 0;
}
static struct acpi_battery_hook msi_battery_hook = {
        .add_battery = msi_battery_add,
        .remove_battery = msi_battery_remove,
        .name = MSI_DRIVER_NAME,
};

/* In msi_ec_init: */
battery_hook_register(&msi_battery_hook);

/* In msi_ec_exit: */
battery_hook_unregister(&msi_battery_hook);
```

### 2.3. Build, Install, and Prioritize Module

Compile and install the module into the kernel `extra/` directory:

```bash
cd /usr/src/msi-ec-modern
make
sudo make install
```

Configure `depmod` to search the `extra` directory before `built-in` / `kernel` to override any minimal in-tree driver:

```bash
echo "search extra built-in" | sudo tee /etc/depmod.d/extra.conf
sudo depmod -a
```

Ensure the module loads automatically on system boot:

```bash
echo "msi-ec" | sudo tee /etc/modules-load.d/msi-ec.conf
```

Verify that the module is loaded and sysfs entries are available:

```bash
sudo modprobe -r msi_ec 2>/dev/null || true
sudo modprobe msi-ec
ls -la /sys/devices/platform/msi-ec/
```

Key control files in `/sys/devices/platform/msi-ec/`:
* `preset`: Accepts `super_battery`, `silent`, `balanced`, `high_performance`.
* `fan_mode`: Accepts `silent`, `auto`, `advanced`.
* `cpu/realtime_fan_speed`: Current fan speed register reading.
* `cpu/realtime_temperature`: Realtime CPU temperature from EC.

---

## 3. TuneD & CPU Frequency Configuration

### 3.1. Persistent Battery Cap Storage

Store the desired battery CPU cap percentage in `/etc/cpu_cap.conf`:

```bash
echo "30" | sudo tee /etc/cpu_cap.conf
```

### 3.2. Critical Sequence Order

When applying limits, **TuneD profile activation must run before writing to `max_perf_pct`**. Switching TuneD profiles resets or re-evaluates P-State attributes; applying `max_perf_pct` *after* the profile switch ensures the 30% cap remains active.

---

## 4. Automation Scripts

### 4.1. Udev Auto-Brightness & Power Handler (`/usr/local/bin/auto-brightness.sh`)

Triggered automatically by udev rules (`/etc/udev/rules.d/99-battery-brightness.rules`) on AC plug / unplug events:

```bash
#!/bin/bash

# Give hardware state a moment to settle
sleep 1

PSTATE_FILE="/sys/devices/system/cpu/intel_pstate/max_perf_pct"
SAVED_CAP_FILE="/etc/cpu_cap.conf"
TMUX_USER="pa3k"

BAT_CAP=100
if [[ -f "$SAVED_CAP_FILE" ]]; then
    BAT_CAP=$(cat "$SAVED_CAP_FILE")
fi

update_tmux() {
    local INTERVAL=$1
    local LABEL=$2
    if sudo -u "$TMUX_USER" tmux has-session 2>/dev/null; then
        sudo -u "$TMUX_USER" tmux set -g status-interval "$INTERVAL"
        sudo -u "$TMUX_USER" tmux set -g status-right " $LABEL #{?#{==:#{client_termname},linux},#(~/scripts/fedora-sway/tmux/tmux-status-bar-stats.sh tty),#(~/scripts/fedora-sway/tmux/tmux-status-bar-stats.sh)} %m/%d %H:%M"
    fi
}

if [ "$1" == "bat" ]; then
    # Screen dimming
    /usr/bin/brightnessctl set 1
    
    # 1. Switch TuneD profile first
    if [[ -f "$PSTATE_FILE" ]]; then
        if (( BAT_CAP >= 40 )); then
            tuned-adm profile balanced
        else
            tuned-adm profile powersave
        fi
        # 2. Apply battery CPU cap after TuneD switch
        echo "$BAT_CAP" > "$PSTATE_FILE"
    fi

    # 3. Set MSI EC to super_battery + silent fan mode (0 RPM)
    if [[ -d "/sys/devices/platform/msi-ec" ]]; then
        echo "super_battery" > /sys/devices/platform/msi-ec/preset 2>/dev/null || true
        echo "silent" > /sys/devices/platform/msi-ec/fan_mode 2>/dev/null || true
    fi

    # 4. Set swaybg to solid black on battery
    update_sway_wallpaper "bat"
    
    update_tmux 300 "5m"

    # 5. Notify on power source change
    send_power_notification "bat"

elif [ "$1" == "ac" ]; then
    # Screen brightening
    /usr/bin/brightnessctl set 30%
    
    # 1. Switch TuneD profile to high performance
    tuned-adm profile throughput-performance 2>/dev/null || tuned-adm profile balanced
    
    # 2. Remove CPU limit
    if [[ -f "$PSTATE_FILE" ]]; then
        echo "100" > "$PSTATE_FILE"
    fi

    # 3. Restore MSI EC to balanced + auto fan curve
    if [[ -d "/sys/devices/platform/msi-ec" ]]; then
        echo "balanced" > /sys/devices/platform/msi-ec/preset 2>/dev/null || true
        echo "auto" > /sys/devices/platform/msi-ec/fan_mode 2>/dev/null || true
    fi

    # 4. Call Bing wallpaper service on AC
    update_sway_wallpaper "ac"
    
    update_tmux 2 "2s"

    # 5. Notify on power source change
    send_power_notification "ac"
fi
```

### 4.2. Waybar CPU Cap Updater (`update_cpu_cap.sh`)

Located at `~/scripts/fedora-sway/config/waybar/scripts/update_cpu_cap.sh`. Used to manually change the persistent cap (e.g. `sudo update_cpu_cap.sh 30`) and update running states.

Key logic snippet:
```bash
if grep -q "1" /sys/class/power_supply/*/online 2>/dev/null; then
    tuned-adm profile throughput-performance 2>/dev/null || tuned-adm profile balanced
    echo "100" > "$PSTATE_FILE"
    if [[ -d "/sys/devices/platform/msi-ec" ]]; then
        echo "balanced" > /sys/devices/platform/msi-ec/preset 2>/dev/null || true
        echo "auto" > /sys/devices/platform/msi-ec/fan_mode 2>/dev/null || true
    fi
else
    if (( VALUE >= 40 )); then
        tuned-adm profile balanced
    else
        tuned-adm profile powersave
    fi
    echo "$VALUE" > "$PSTATE_FILE"
    if [[ -d "/sys/devices/platform/msi-ec" ]]; then
        echo "super_battery" > /sys/devices/platform/msi-ec/preset 2>/dev/null || true
        echo "silent" > /sys/devices/platform/msi-ec/fan_mode 2>/dev/null || true
    fi
fi
```

---

## 5. Verification Commands

To check the operational status at any time:

```bash
# 1. Fan RPM (0 indicates fan is completely off)
cat /sys/class/hwmon/hwmon4/fan1_input

# 2. CPU Temperature (°C)
cat /sys/devices/platform/msi-ec/cpu/realtime_temperature

# 3. MSI EC Active Preset and Fan Mode
cat /sys/devices/platform/msi-ec/preset
cat /sys/devices/platform/msi-ec/fan_mode

# 4. Intel P-State CPU Cap (%)
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct

# 5. TuneD Active Power Profile
tuned-adm active

# 6. Waybar Power Status JSON Output
~/scripts/fedora-sway/config/waybar/scripts/power_status.sh
```
