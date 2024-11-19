#!/bin/bash

# Set the mount point
MOUNT_POINT="/mnt/usb"

echo 34 > /sys/class/gpio/export && echo out > /sys/class/gpio/gpio34/direction

# Function to log both to the screen and syslog
log_message() {
  local msg="USB automount: $1"
  echo "$msg"  # Echo to the screen
  logger "USB automount: $msg"  # Log to the system log
}

#Blink
blink() {
    echo 1 > /sys/class/gpio/gpio34/value;
    sleep "$1";
    echo 0 > /sys/class/gpio/gpio34/value;
}

escape_sed() {
    echo "$1" | sed -e 's/[]\/$*.^[]/\\&/g'
}

# Check if the mount point exists and if a USB drive is plugged in
USB_DEVICE=$(lsblk -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT | grep -E "vfat|ext4|ntfs|exfat" | grep -E "sd[a-z][0-9]" | awk '{print $1}' | sed 's/[^a-zA-Z0-9]//g' | head -n 1)

if [ -d "$MOUNT_POINT" ]; then
  sudo rmdir "$MOUNT_POINT"
  log_message "/mnt/usb deleted."
fi

# If no USB device is found, exit
if [ -z "$USB_DEVICE" ]; then
  log_message "No USB drive found."
  exit 0
fi

# Create the mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
  sudo mkdir -p "$MOUNT_POINT"
fi

# Construct the full device path
USB_DEVICE="/dev/$USB_DEVICE"

# Debugging: Log and echo the extracted device name
log_message "Extracted device name: $USB_DEVICE"

# Check if the USB drive is already mounted
if mount | grep "$USB_DEVICE" > /dev/null; then
  log_message "USB drive is already mounted."
else
  # Mount the USB drive to the specified mount point
  sudo mount "$USB_DEVICE" "$MOUNT_POINT"
  if [ $? -eq 0 ]; then
    log_message "USB drive mounted successfully at $MOUNT_POINT."
  else
    log_message "Failed to mount USB drive."
    blink "4" && sleep "0.5"
    exit 1
  fi
fi

# Check if the mounted USB drive contains a file femtofox-config.txt
if [ -f "$MOUNT_POINT/femtofox-config.txt" ]; then
  log_message "femtofox-config.txt found on USB drive."

  WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
  USB_CONFIG="$MOUNT_POINT/femtofox-config.txt"

  # Initialize variables
  SSID=""
  PSK=""
  COUNTRY=""
  FOUNDCONFIG="false"

  # Read the fields from the USB config file if they exist
  if grep -q 'ssid=' "$USB_CONFIG"; then
      SSID=$(grep 'ssid=' "$USB_CONFIG" | sed 's/ssid=//' | tr -d '"')
  fi
  if grep -q 'psk=' "$USB_CONFIG"; then
      PSK=$(grep 'psk=' "$USB_CONFIG" | sed 's/psk=//' | tr -d '"')
  fi
  if grep -q 'country=' "$USB_CONFIG"; then
      COUNTRY=$(grep 'country=' "$USB_CONFIG" | sed 's/country=//' | tr -d '"')
  fi

  # Escape special characters for sed
  ESCAPED_SSID=$(escape_sed "$SSID")
  ESCAPED_PSK=$(escape_sed "$PSK")
  ESCAPED_COUNTRY=$(escape_sed "$COUNTRY")

  # Update wpa_supplicant.conf with the new values if they exist
  if [[ -n "$COUNTRY" ]]; then
      sed -i "s/^\(country=\).*/\1$ESCAPED_COUNTRY/" "$WPA_SUPPLICANT_CONF"
      log_message "Updated country in wpa_supplicant.conf from femtofox-config.txt to $COUNTRY."
      FOUNDCONFIG="true"
  fi
  if [[ -n "$SSID" ]]; then
      sed -i "/ssid=/s/\".*\"/\"$ESCAPED_SSID\"/" "$WPA_SUPPLICANT_CONF"
      log_message "Updated SSID in wpa_supplicant.conf from femtofox-config.txt to $SSID."
      FOUNDCONFIG="true"
  fi
  if [[ -n "$PSK" ]]; then
      sed -i "/psk=/s/\".*\"/\"$ESCAPED_PSK\"/" "$WPA_SUPPLICANT_CONF"
      log_message "Updated PSK in wpa_supplicant.conf from femtofox-config.txt."
      FOUNDCONFIG="true"
  fi

  if [ "$FOUNDCONFIG" = true ]; then
    for _ in {1..5}; do
      blink "0.125" && sleep 0.125
    done
    log_message "wpa_supplicant.conf updated, rebooting."
    sleep 2 && reboot

  else
    log_message "femtofox-config.txt does not contain valid configuration info, ignoring."
    for _ in {1..5}; do
      blink "1.5" && sleep 0.5
    done
  fi

else
  log_message "USB drive mounted but femtofox-config.txt not found, ignoring."
  for _ in {1..3}; do
    blink "1.5" && sleep 0.5
  done
fi