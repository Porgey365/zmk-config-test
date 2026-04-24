#!/bin/bash

# Script to flash firmware to XIAO-SENSE device
# Usage: ./flash-firmware.sh [dongle|left|right|reset]
#
# Examples:
#   ./flash-firmware.sh dongle    # Flash dongle
#   ./flash-firmware.sh left      # Flash left keyboard half
#   ./flash-firmware.sh right     # Flash right keyboard half
#   ./flash-firmware.sh trackball # Flash trackball
#   ./flash-firmware.sh reset     # Flash settings reset

set -e

OUTPUT_DIR="firmware"
TARGET="${1:-dongle}"

# Determine firmware file to flash
case "$TARGET" in
    dongle)
        echo "Looking for totem_dongle firmware..."
        FIRMWARE=$(find "$OUTPUT_DIR" -name "*totem_dongle*.uf2" -type f | head -n 1)
        DEVICE_NAME="dongle"
        ;;
    left)
        echo "Looking for totem_left firmware..."
        FIRMWARE=$(find "$OUTPUT_DIR" -name "*totem_left*.uf2" -type f | head -n 1)
        DEVICE_NAME="left keyboard half"
        ;;
    right)
        echo "Looking for totem_right firmware..."
        FIRMWARE=$(find "$OUTPUT_DIR" -name "*totem_right*.uf2" -type f | head -n 1)
        DEVICE_NAME="right keyboard half"
        ;;
    trackball)
        echo "Looking for totem_trackball firmware..."
        FIRMWARE=$(find "$OUTPUT_DIR" -name "*totem_trackball*.uf2" -type f | head -n 1)
        DEVICE_NAME="trackball"
        ;;
    reset)
        echo "Looking for settings_reset firmware..."
        FIRMWARE=$(find "$OUTPUT_DIR" -name "*settings_reset*.uf2" -type f | head -n 1)
        DEVICE_NAME="device (settings reset)"
        ;;
    *)
        echo "Error: Unknown target '$TARGET'"
        echo "Usage: ./flash-firmware.sh [dongle|left|right|trackball|reset]"
        exit 1
        ;;
esac

if [ -z "$FIRMWARE" ]; then
    echo "Error: Firmware for $DEVICE_NAME not found in $OUTPUT_DIR/"
    echo "Run ./download-firmware.sh first to download firmware"
    exit 1
fi

echo "Found: $FIRMWARE"
echo ""
echo "Waiting for XIAO-SENSE device (10s timeout)..."
echo "Put the $DEVICE_NAME in bootloader mode (double-tap reset button)"

# Wait for device block to appear, then auto-mount if needed
MOUNT_POINT=""
DEVICE_NODE=""
TIMEOUT=10
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT ]; do
    # First check if already mounted at a known path
    for path in "/media/$USER/XIAO-SENSE" "/media/XIAO-SENSE" "/run/media/$USER/XIAO-SENSE"; do
        if [ -d "$path" ]; then
            MOUNT_POINT="$path"
            break 2
        fi
    done

    # Otherwise, locate the block device by label
    DEVICE_NODE=$(lsblk -rno NAME,LABEL | awk '$2=="XIAO-SENSE"{print "/dev/"$1; exit}')
    if [ -n "$DEVICE_NODE" ]; then
        break
    fi

    sleep 1
    ELAPSED=$((ELAPSED + 1))
    echo -n "."
done
echo ""

if [ -z "$MOUNT_POINT" ] && [ -n "$DEVICE_NODE" ]; then
    # Already mounted by another process?
    MOUNT_POINT=$(findmnt -rno TARGET "$DEVICE_NODE" || true)

    if [ -z "$MOUNT_POINT" ]; then
        echo "Mounting $DEVICE_NODE..."
        if command -v udisksctl >/dev/null 2>&1; then
            MOUNT_OUTPUT=$(udisksctl mount -b "$DEVICE_NODE" 2>&1)
            echo "$MOUNT_OUTPUT"
            # udisksctl prints "Mounted /dev/sdX1 at /path" (note: may end with a period on some versions)
            MOUNT_POINT=$(printf '%s' "$MOUNT_OUTPUT" | sed -n 's/.* at \(.*\)\.*$/\1/p' | sed 's/\.$//')
            # Fall back to querying the kernel if parsing failed
            [ -z "$MOUNT_POINT" ] && MOUNT_POINT=$(findmnt -rno TARGET "$DEVICE_NODE" || true)
        else
            MOUNT_POINT="/tmp/xiao-sense-$$"
            mkdir -p "$MOUNT_POINT"
            sudo mount "$DEVICE_NODE" "$MOUNT_POINT"
            NEEDS_UMOUNT=1
        fi
    fi
fi

if [ -z "$MOUNT_POINT" ]; then
    echo "Error: XIAO-SENSE device not found"
    echo "Please put the $DEVICE_NAME in bootloader mode (double-tap reset button)"
    exit 1
fi

echo "Found device at: $MOUNT_POINT"
echo "Copying firmware to $DEVICE_NAME..."

cp "$FIRMWARE" "$MOUNT_POINT/"
sync

echo ""
echo "✓ Firmware flashed successfully to $DEVICE_NAME!"
echo "Device will reboot automatically"
