#!/bin/bash

# ==========================================
# Configuration Variables
# ==========================================
NTFS_DEVICE="/dev/nvme0n1p5"  # <--- CHANGE THIS to your actual Windows partition
WINDOWS_MOUNT="/mnt/windowstiny11"
WSL_MOUNT="/mnt/wsl"
VHDX_PATH="$WINDOWS_MOUNT/Users/pa3kj/AppData/Local/wsl/{add96863-7b75-4c21-a4f1-094969a368ef}/ext4.vhdx"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo: sudo $0 {mount|unmount}"
  exit 1
fi

mount_wsl() {
    echo "Starting mount process..."
    
    # 1. Mount NTFS Partition (if not already mounted)
    if ! mountpoint -q "$WINDOWS_MOUNT"; then
        echo "Mounting Windows NTFS partition (Read-Only)..."
        mkdir -p "$WINDOWS_MOUNT"
        mount -t ntfs-3g -o ro "$NTFS_DEVICE" "$WINDOWS_MOUNT"
    fi

    # 2. Load the network block device module
    modprobe nbd
    sleep 1 # Give the kernel a moment to generate /dev/nbd0

    # 3. Attach VHDX and Mount
    echo "Attaching WSL virtual disk..."
    if qemu-nbd -r -c /dev/nbd0 "$VHDX_PATH"; then
	
        sleep 5

        mkdir -p "$WSL_MOUNT"
	if mount -t ext4 -o ro,noload /dev/nbd0 "$WSL_MOUNT"; then
            echo "✅ Success! Your WSL files are available at $WSL_MOUNT"
        else
            echo "❌ Failed to mount the WSL filesystem."
            qemu-nbd -d /dev/nbd0 > /dev/null 2>&1
        fi
    else
        echo "❌ Failed to attach the VHDX file. Is the Windows drive mounted correctly?"
    fi
}

unmount_wsl() {
    echo "Starting unmount process..."

    # 1. Unmount WSL and disconnect the virtual disk
    if mountpoint -q "$WSL_MOUNT"; then
        umount "$WSL_MOUNT"
        echo "Unmounted $WSL_MOUNT"
    fi
    qemu-nbd -d /dev/nbd0 > /dev/null 2>&1
    echo "Disconnected /dev/nbd0"

    # 2. Unmount the Windows NTFS partition
    if mountpoint -q "$WINDOWS_MOUNT"; then
        umount "$WINDOWS_MOUNT"
        echo "Unmounted $WINDOWS_MOUNT"
    fi

    echo "✅ Done. Everything is safely disconnected."
}

# Main script logic
case "$1" in
    mount)
        mount_wsl
        ;;
    unmount)
        unmount_wsl
        ;;
    *)
        echo "Usage: sudo $0 {mount|unmount}"
        exit 1
        ;;
esac
