#!/bin/bash

# this script is solely for dev work, to copy the bootloader payloads into a appleboot-*.bin image.

if [ "$EUID" -ne 0 ]; then
    echo "the builder is not running as root!! please ensure you run this as root/sudo."
    exit 1
fi

bootloader_loop=$(losetup -f --show -P "$reco_bin")
temp_mnt=$(mktemp -d)

mount "$bootloader_loop"p1 $temp_mnt
rm -rf "$temp_mnt"/*
cp -r bootloader/* "$temp_mnt"
umount "$bootloader_loop"p1
losetup -d $bootloader_loop