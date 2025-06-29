#!/bin/bash

RECO_BIN=""
# create appleboot image
BOARD="nissa"
ROOTFS_DIR="rootfs-chroot"
RECO_ZIP="reco.zip"

if [ "$EUID" -ne 0 ]; then
    echo "the builder is not running as root!! please ensure you run this as root/sudo."
    exit 1
fi

get_reco_url() {
    local board=$1
    local boards_url="https://chromiumdash.appspot.com/cros/fetch_serving_builds?deviceCategory=ChromeOS"

    echo "downloading list of recovery images"
    local reco_url="$(wget -qO- --show-progress $boards_url | python3 -c '
import json, sys

all_builds = json.load(sys.stdin)
board_name = sys.argv[1]
if not board_name in all_builds["builds"]:
    print("Invalid board name: " + board_name, file=sys.stderr)
    sys.exit(1)

board = all_builds["builds"][board_name]
if "models" in board:
    for device in board["models"].values():
        if device["pushRecoveries"]:
            board = device
            break

reco_url = list(board["pushRecoveries"].values())[-1]
print(reco_url)
    ' $board)"
    echo "found recovery url: $reco_url"
    wget "$reco_url" -O "$RECO_ZIP"
    unzip "$RECO_ZIP"
    out=$(unzip -Z1 "$RECO_ZIP")
    mv -- "$out" reco.bin
}

partition_disk() {
  local image_path=$(realpath -m "${1}")
  local bootloader_size="$2"
  local rootfs_name="$3"
  #create partition table with fdisk
  ( 
    echo g #new gpt disk label

    #create bootloader partition
    echo n
    echo #accept default parition number
    echo #accept default first sector
    echo "+${bootloader_size}M" #set partition size
    echo t #change partition type
    echo #accept default parition number
    echo 3CB8E202-3B7E-47DD-8A3C-7FF2A13CFCEC #chromeos rootfs type

    #create rootfs partition
    echo n
    echo #accept default parition number
    echo #accept default first sector
    echo #accept default size to fill rest of image
    echo x #enter expert mode
    echo n #change the partition name
    echo #accept default partition number
    echo "appleboot_rootfs:$rootfs_name" #set partition name
    echo r #return to normal more

    #write changes
    echo w
  ) | fdisk $image_path
}

create_image() {
    local image_path=$(realpath -m "${1}")
    local bootloader_size="$2"
    local rootfs_size="$3"
    local rootfs_name="$4"

    # bootloader + rootfs
    local total_size=$((1 + 32 + $bootloader_size + $rootfs_size))
    rm -rf "${image_path}"
    fallocate -l "${total_size}M" "${image_path}"
    partition_disk $image_path $bootloader_size $rootfs_name
}

# make our debian rootfs
./builder/build.sh "$ROOTFS_DIR"

if [ -z "${RECO_BIN}" ]; then
    get_reco_url $BOARD
    RECO_BIN="reco.bin"
fi

# patch the built rootfs with chromeOS kernel modules
./builder/patch.sh "$ROOTFS_DIR" "$RECO_BIN"

# calculate rootfs size to build image
rootfs_size="$(du -sm "$ROOTFS_DIR" | cut -f 1)"
rootfs_part_size=$(( rootfs_size * 12 / 10 + 5 ))

# create image
create_image "appleboot.bin" 20 "$rootfs_part_size" "debian"
appleboot_loop=$(losetup -f --show -P "appleboot.bin")

# fix some gpt backup header errors
sgdisk -e "$appleboot_loop"

# partition disks
mkfs.ext4 "${appleboot_loop}p1" # bootloader
mkfs.ext4 "${appleboot_loop}p2" # rootfs

# shift bootloader files into bootloader partition
mkdir -p bootloader_mnt
mount "${appleboot_loop}p1" "bootloader_mnt"
cp -arv bootloader/* "bootloader_mnt"
umount "${appleboot_loop}p1"
rm -r bootloader_mnt

# shift rootfs chroot into rootfs partition
mkdir -p rootfs_mnt
mount "${appleboot_loop}p2" "rootfs_mnt"
cp -ar rootfs-chroot/* "rootfs_mnt"
umount "${appleboot_loop}p2"
rm -r rootfs_mnt

# finally, detach the appleboot.bin image from the loop device YAY
losetup -d $appleboot_loop