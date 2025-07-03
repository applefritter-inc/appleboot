#!/bin/bash
set -Eeuo pipefail
trap 'rc=$?; fatal_exit "unexpected error (exit code $rc) at line ${LINENO}: \`${BASH_COMMAND}\`!"' ERR

RECO_BIN=""
BOARD=$1
# create appleboot image
ROOTFS_DIR="rootfs-chroot"
RECO_ZIP="reco.zip"
APPLEBOOT_IMAGE="appleboot-${BOARD}.bin"
DELETE_ESSENTIAL="y"
DEPENDENCIES="cpio realpath mkfs.ext4 mkfs.vfat fdisk debootstrap findmnt wget git make"

fatal_exit() {
    echo "FATAL: $1"
    echo "this is fatal, exiting..."
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    fatal_exit "the builder is not running as root!! please ensure you run this as root/sudo."
fi

check_dependencies() {
    local dep_array=$1
    local missing=()
    for cmd in $dep_array; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
        missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        fatal_exit "missing dependencies: ${missing[*]}"
    fi
}

check_dependencies "$DEPENDENCIES"

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
    rm -r "$RECO_ZIP" # remove this, we don't need it anymore
}

partition_disk() {
  local image_path=$(realpath -m "${1}")
  local bootloader_size="$2"
  local rootfs_name="$3"
  #create partition table with fdisk
  ( 
    echo g #new gpt disk label

    #create bootloader partition
    echo n #new partition
    echo #accept default parition number
    echo #accept default first sector
    echo "+${bootloader_size}M" #partition size is 1M
    # change the partition type, if not it will stay as 'linux filesystem'
    echo t #change type
    #echo 1 since this is the only partition as of now, partition 1 is auto selected
    echo 11 # for microsoft basic data partition

    #create rootfs partition
    echo n #new partition
    echo #accept default parition number
    echo #accept default first sector
    echo #accept default size to fill rest of image
    echo x #enter expert mode
    echo n #change the partition name
    echo #accept default partition number
    echo "appleboot_rootfs:$rootfs_name" #set partition name
    echo r #return to normal mode

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
    local extra_rootfs_space=100 # give the rootfs extra space
    local total_size=$(($extra_rootfs_space + $bootloader_size + $rootfs_size))
    rm -rf "${image_path}"
    fallocate -l "${total_size}M" "${image_path}"
    partition_disk $image_path $bootloader_size $rootfs_name
}

echo "welcome to the appleboot image builder!"
echo "if the script fails, the script will immediately exit at that point. if you do not see that appleboot has finished building, something went wrong with the builder!"
echo "please report the issue on github"

# make our debian rootfs
echo "bootstrapping rootfs..."
./builder/build.sh "$ROOTFS_DIR"

if [ -z "${RECO_BIN}" ]; then
    get_reco_url $BOARD
    RECO_BIN="reco.bin"
fi

# patch the built rootfs with chromeOS kernel modules
echo "patching rootfs..."
./builder/patch.sh "$ROOTFS_DIR" "$RECO_BIN"

# calculate rootfs size to build image
rootfs_size="$(du -sm "$ROOTFS_DIR" | cut -f 1)"
rootfs_part_size=$(( rootfs_size * 12 / 10 + 5 ))

# create image
echo "creating appleboot image..."
create_image "$APPLEBOOT_IMAGE" 20 "$rootfs_part_size" "debian"
appleboot_loop=$(losetup -f --show -P "$APPLEBOOT_IMAGE")

# fix some gpt backup header errors
sgdisk -e "$appleboot_loop"

# partition disks
echo "partitioning image..."
mkfs.vfat -F 16 -n BOOTLOADER "${appleboot_loop}p1" # bootloader
mkfs.ext4 "${appleboot_loop}p2" # rootfs

# shift bootloader files into bootloader partition
echo "shifting bootloader files..."
mkdir -p bootloader_mnt
mount "${appleboot_loop}p1" "bootloader_mnt"
cp -rv --no-preserve=ownership,mode bootloader/* bootloader_mnt/
umount "${appleboot_loop}p1"
rm -r bootloader_mnt

# shift rootfs chroot into rootfs partition
echo "shifting rootfs files..."
mkdir -p rootfs_mnt
mount "${appleboot_loop}p2" "rootfs_mnt"
cp -ar rootfs-chroot/* "rootfs_mnt"
umount "${appleboot_loop}p2"
rm -r rootfs_mnt

# finally, detach the image from the loop device YAY
losetup -d $appleboot_loop

if [ -n "$DELETE_ESSENTIAL" ]; then
    echo "cleaning up rootfs-chroot & the reco bin file..."
    rm -rf rootfs-chroot
    rm -rf $RECO_BIN
fi

echo "appleboot has finished building! the image should be at $(pwd)/$APPLEBOOT_IMAGE. successful build."
