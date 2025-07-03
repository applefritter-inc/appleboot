#!/bin/bash

DL_PATH="/temp/"
BOOTLOADER_FILES="clamide init.sh main.sh payload.sh"
URL="https://raw.githubusercontent.com/applefritter-inc/appleboot/refs/heads/main/bootloader/"
INTERNET_BOOTLOADER_MAGIC="download_rootfs_force"

if ping -c 1 -W 2 google.com >/dev/null 2>&1; then
    echo "internet reachable! proceeding with usbless bootloader."
else
    echo "FATAL: could not reach google.com! connection test failed! exiting..."
    exit 1
fi

echo "making ${DL_PATH}..."
mkdir -p $DL_PATH # bootloader files

echo "downloading bootloader files..."
for dl in $BOOTLOADER_FILES; do
    echo "downloading ${dl}"
    dl_status=$(curl -LksS -w "%{http_code}" -o "${DL_PATH}${dl}" "${URL}${dl}")
    if [ "$dl_status" -eq 200 ]; then
        echo "download succeeded!"
    else
        echo "FATAL: download failed with status ${dl_status}"
        exit 1
    fi

done

echo "setting necessary permissions..."
chmod +x "${DL_PATH}"*

echo "executing bootloader..."
${DL_PATH}/main.sh "$INTERNET_BOOTLOADER_MAGIC"